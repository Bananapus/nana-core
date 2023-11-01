// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import /* {*} from */ "./helpers/TestBaseWorkflow.sol";

/**
 * This system test file verifies the following flow:
 * launch project → issue token → pay project (claimed tokens) →  burn some of the claimed tokens → redeem rest of tokens
 */
contract TestRedeem_Local is TestBaseWorkflow {
    JBController private _controller;
    JBETHPaymentTerminal private _terminal;
    JBETHPaymentTerminal3_2 private _terminal3_2;
    JBTokenStore private _tokenStore;

    JBProjectMetadata private _projectMetadata;
    JBFundingCycleData private _data;
    JBFundingCycleMetadata3_2 _metadata;
    JBGroupedSplits[] private _groupedSplits; // Default empty
    IJBPaymentTerminal[] private _terminals; // Default empty

    uint256 private _projectId;
    address private _projectOwner;
    uint256 private _weight = 1000 * 10 ** 18;
    uint256 private _targetInWei = 1 * 10 ** 18;

    function setUp() public override {
        super.setUp();

        _controller = jbController();
        _terminal = jbETHPaymentTerminal();

        _terminal3_2 = new JBETHPaymentTerminal3_2(
            _jbOperatorStore,
            _jbProjects,
            _jbDirectory,
            _jbSplitsStore,
            _jbPrices,
            address(_jbPaymentTerminalStore3_2),
            _multisig
        );

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
            redemptionRate: 5000,
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
        _terminals.push(_terminal3_2);

        JBFundAccessConstraints3_1[] memory _fundAccessConstraints = new JBFundAccessConstraints3_1[](2);
        JBCurrencyAmount[] memory _distributionLimits = new JBCurrencyAmount[](1);
        JBCurrencyAmount[] memory _overflowAllowances = new JBCurrencyAmount[](1);

        JBCurrencyAmount[] memory _distributionLimits2 = new JBCurrencyAmount[](1);
        JBCurrencyAmount[] memory _overflowAllowances2 = new JBCurrencyAmount[](1);

        _distributionLimits[0] = JBCurrencyAmount({
            value: 1 ether,
            currency: jbLibraries().ETH()
        });  

        _overflowAllowances[0] = JBCurrencyAmount({
            value: 5 ether,
            currency: jbLibraries().ETH()
        });

        _distributionLimits2[0] = JBCurrencyAmount({
            value: 0,
            currency: jbLibraries().ETH()
        });  

        _overflowAllowances2[0] = JBCurrencyAmount({
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

        _fundAccessConstraints[1] = 
            JBFundAccessConstraints3_1({
                terminal: _terminal3_2,
                token: jbLibraries().ETHToken(),
                distributionLimits: _distributionLimits2,
                overflowAllowances: _overflowAllowances2
            });

        JBFundingCycleConfiguration[] memory _cycleConfig = new JBFundingCycleConfiguration[](1);

        _cycleConfig[0].mustStartAtOrAfter = 0;
        _cycleConfig[0].data = _data;
        _cycleConfig[0].metadata = _metadata;
        _cycleConfig[0].groupedSplits = _groupedSplits;
        _cycleConfig[0].fundAccessConstraints = _fundAccessConstraints;

        _projectOwner = multisig();

        // Launch a protocol project first
        _controller.launchProjectFor(
            _projectOwner,
            _projectMetadata,
            _cycleConfig,
            _terminals,
            ""
        );

        _projectId = _controller.launchProjectFor(
            _projectOwner,
            _projectMetadata,
            _cycleConfig,
            _terminals,
            ""
        );
    }

    function testRedeemterminal3_2(uint256 _tokenAmountToRedeem) external {
        bool payPreferClaimed = true; //false
        uint96 payAmountInWei = 10 ether;

        // issue an ERC-20 token for project
        vm.prank(_projectOwner);
        _tokenStore.issueFor(_projectId, "TestName", "TestSymbol");

        address _userWallet = address(1234);

        // pay terminal
        _terminal3_2.pay{value: payAmountInWei}(
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
        assertEq(jbPaymentTerminalStore().balanceOf(_terminal3_2, _projectId), _terminalBalanceInWei);

        // Fuzz 1 to full balance redemption
        _tokenAmountToRedeem = bound(_tokenAmountToRedeem, 1, _userTokenBalance);

        // Test: redeem
        vm.prank(_userWallet);
        uint256 _reclaimAmtInWei = _terminal3_2.redeemTokensOf(
            /* _holder */
            _userWallet,
            /* _projectId */
            _projectId,
            /* _tokenCount */
            _tokenAmountToRedeem,
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

        // Check: correct amount returned, 50% redemption rate
        uint256 _grossRedeemed = PRBMath.mulDiv(
                _tokenAmountToRedeem,
                5000 +
                PRBMath.mulDiv(
                    _tokenAmountToRedeem,
                    JBConstants.MAX_REDEMPTION_RATE - 5000,
                    _userTokenBalance
                ),
                JBConstants.MAX_REDEMPTION_RATE
            );

        // Compute the fee taken
        uint256 _fee =  _grossRedeemed - PRBMath.mulDiv(_grossRedeemed, 1_000_000_000, 25000000 + 1_000_000_000); // 2.5% fee
        
        // Compute the net amount received, still in $project
        uint256 _netReceived = _grossRedeemed - _fee;

        // Convert in actual ETH, based on the weight
        uint256 _convertedInEth = PRBMath.mulDiv(_netReceived, 1e18, _weight);

        // Verify: correct amount returned (2 wei precision)
        assertApproxEqAbs(_reclaimAmtInWei, _convertedInEth, 2, "incorrect amount returned");

        // Verify: beneficiary received correct amount of ETH
        assertEq(payable(_userWallet).balance, _reclaimAmtInWei);

        // verify: beneficiary has correct amount of token
        assertEq(_tokenStore.balanceOf(_userWallet, _projectId), _userTokenBalance - _tokenAmountToRedeem, "incorrect beneficiary balance");

        // verify: ETH balance in terminal should be up to date (with 1 wei precision)
        assertApproxEqAbs(jbPaymentTerminalStore().balanceOf(_terminal3_2, _projectId), _terminalBalanceInWei - _reclaimAmtInWei - (_reclaimAmtInWei * 25 / 1000), 1);
    }
}
