// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import /* {*} from */ "./helpers/TestBaseWorkflow.sol";

/**
 * This system test file verifies the following flow:
 * launch project → issue token → pay project (claimed tokens) →  burn some of the claimed tokens → redeem rest of tokens
 */
contract TestPayBurnRedeemFlow_Local is TestBaseWorkflow {
    JBController private _controller;
    JBETHPaymentTerminal private _terminal;
    JBTokenStore private _tokenStore;

    JBProjectMetadata private _projectMetadata;
    JBFundingCycleData private _data;
    JBFundingCycleMetadata3_2 _metadata;
    JBGroupedSplits[] private _groupedSplits; // Default empty
    IJBPaymentTerminal[] private _terminals; // Default empty

    uint256 private _projectId;
    address private _projectOwner;
    uint256 private _weight = 1000 * 10 ** 18;
    uint256 private _targetInWei = 10 * 10 ** 18;

    function setUp() public override {
        super.setUp();

        _controller = jbController();
        _terminal = jbETHPaymentTerminal();
        _tokenStore = jbTokenStore();

        _projectMetadata = JBProjectMetadata({content: "myIPFSHash", domain: 1});

        _data = JBFundingCycleData({
            duration: 14,
            weight: _weight,
            discountRate: 450000000,
            ballot: IJBFundingCycleBallot(address(0))
        });

        _metadata = JBFundingCycleMetadata3_2({
            global: JBGlobalFundingCycleMetadata({
                allowSetTerminals: false,
                allowSetController: false,
                pauseTransfers: false
            }),
            reservedRate: 0,
            redemptionRate: 10000, //100%
            baseCurrency: 1,
            pausePay: false,
            pauseDistributions: false,
            pauseRedeem: false,
            pauseBurn: false,
            allowMinting: false,
            allowTerminalMigration: false,
            allowControllerMigration: false,
            holdFees: false,
            preferClaimedTokenOverride: false,
            useTotalOverflowForRedemptions: false,
            useDataSourceForPay: false,
            useDataSourceForRedeem: false,
            dataSource: address(0),
            metadata: 0
        });

        _terminals.push(_terminal);

        _projectOwner = multisig();

        JBFundAccessConstraints3_1[] memory _fundAccessConstraints = new JBFundAccessConstraints3_1[](1);
        JBCurrencyAmount[] memory _distributionLimits = new JBCurrencyAmount[](1);
        JBCurrencyAmount[] memory _overflowAllowances = new JBCurrencyAmount[](1);

         _distributionLimits[0] = JBCurrencyAmount({
            value: _targetInWei,
            currency: jbLibraries().ETH()
        });  

        _overflowAllowances[0] = JBCurrencyAmount({
            value: 5 ether,
            currency: jbLibraries().ETH()
        });

        _fundAccessConstraints[0] =
            JBFundAccessConstraints3_1({
                terminal: _terminal,
                token: jbLibraries().ETHToken(),
                distributionLimits: _distributionLimits,
                overflowAllowances: _overflowAllowances
            });

        JBFundingCycleConfiguration[] memory _cycleConfig = new JBFundingCycleConfiguration[](1);

        _cycleConfig[0].mustStartAtOrAfter = 0;
        _cycleConfig[0].data = _data;
        _cycleConfig[0].metadata = _metadata;
        _cycleConfig[0].groupedSplits = _groupedSplits;
        _cycleConfig[0].fundAccessConstraints = _fundAccessConstraints;

        _projectId = _controller.launchProjectFor(
            _projectOwner,
            _projectMetadata,
            _cycleConfig,
            _terminals,
            ""
        );
    }

    function testFuzzPayBurnRedeemFlow(
        bool payPreferClaimed, //false
        bool burnPreferClaimed, //false
        uint96 payAmountInWei, // 1
        uint256 burnTokenAmount, // 0
        uint256 redeemTokenAmount // 0
    ) external {
        // issue an ERC-20 token for project
        vm.prank(_projectOwner);
        _tokenStore.issueFor(_projectId, "TestName", "TestSymbol");

        address _userWallet = address(1234);

        // pay terminal
        _terminal.pay{value: payAmountInWei}(
            _projectId,
            payAmountInWei,
            address(0),
            _userWallet,
            /* _minReturnedTokens */
            0,
            /* _preferClaimedTokens */
            payPreferClaimed,
            /* _memo */
            "Take my money!",
            /* _delegateMetadata */
            new bytes(0)
        );

        // verify: beneficiary should have a balance of JBTokens
        uint256 _userTokenBalance = PRBMathUD60x18.mul(payAmountInWei, _weight);
        assertEq(_tokenStore.balanceOf(_userWallet, _projectId), _userTokenBalance);

        // verify: ETH balance in terminal should be up to date
        uint256 _terminalBalanceInWei = payAmountInWei;
        assertEq(jbPaymentTerminalStore().balanceOf(_terminal, _projectId), _terminalBalanceInWei);

        // burn tokens from beneficiary addr
        if (burnTokenAmount == 0) {
            vm.expectRevert(abi.encodeWithSignature("NO_BURNABLE_TOKENS()"));
        } else if (burnTokenAmount > uint256(type(int256).max) && isUsingJbController3_0()) {
            vm.expectRevert("SafeCast: value doesn't fit in an int256");
        } else if (burnTokenAmount > _userTokenBalance) {
            vm.expectRevert(abi.encodeWithSignature("INSUFFICIENT_FUNDS()"));
        } else {
            _userTokenBalance = _userTokenBalance - burnTokenAmount;
        }

        vm.prank(_userWallet);
        _controller.burnTokensOf(
            _userWallet,
            _projectId,
            /* _tokenCount */
            burnTokenAmount,
            /* _memo */
            "I hate tokens!",
            /* _preferClaimedTokens */
            burnPreferClaimed
        );

        // verify: beneficiary should have a new balance of JBTokens
        assertEq(_tokenStore.balanceOf(_userWallet, _projectId), _userTokenBalance);

        // redeem tokens
        if (redeemTokenAmount > _userTokenBalance) {
            vm.expectRevert(abi.encodeWithSignature("INSUFFICIENT_TOKENS()"));
        } else {
            _userTokenBalance = _userTokenBalance - redeemTokenAmount;
        }

        vm.prank(_userWallet);
        uint256 _reclaimAmtInWei = _terminal.redeemTokensOf(
            /* _holder */
            _userWallet,
            /* _projectId */
            _projectId,
            /* _tokenCount */
            redeemTokenAmount,
            /* token (unused) */
            address(0),
            /* _minReturnedWei */
            0,
            /* _beneficiary */
            payable(_userWallet),
            /* _memo */
            "Refund me now!",
            /* _delegateMetadata */
            new bytes(0)
        );

        // verify: beneficiary should have a new balance of JBTokens
        assertEq(_tokenStore.balanceOf(_userWallet, _projectId), _userTokenBalance);

        // verify: ETH balance in terminal should be up to date
        assertEq(jbPaymentTerminalStore().balanceOf(_terminal, _projectId), _terminalBalanceInWei - _reclaimAmtInWei);
    }
}
