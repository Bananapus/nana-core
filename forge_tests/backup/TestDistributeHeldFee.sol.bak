// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import /* {*} from */ "./helpers/TestBaseWorkflow.sol";

import {JBFeeType} from '../contracts/enums/JBFeeType.sol';
import {IJBFeeGauge3_1} from '../contracts/interfaces/IJBFeeGauge3_1.sol';

contract TestDistributeHeldFee_Local is TestBaseWorkflow {
    JBController private _controller;
    JBETHPaymentTerminal private _terminal;
    JBTokenStore private _tokenStore;

    JBProjectMetadata private _projectMetadata;
    JBFundingCycleData private _data;
    JBFundingCycleMetadata3_2 private _metadata;
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
            holdFees: true,
            preferClaimedTokenOverride: false,
            useTotalOverflowForRedemptions: false,
            useDataSourceForPay: false,
            useDataSourceForRedeem: false,
            dataSource: address(0),
            metadata: 0
        });

        _terminals.push(_terminal);

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

        _projectOwner = multisig();

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

    function testHeldFeeReimburse(uint256 payAmountInWei, uint256 fee, uint256 feeDiscount) external {
        // Assuming we don't revert when distributing too much and avoid rounding errors
        payAmountInWei = bound(payAmountInWei, 1, _targetInWei);
        fee = bound(fee, 0, 50_000_000);
        feeDiscount = bound(feeDiscount, 0, jbLibraries().MAX_FEE());
        
        address _userWallet = address(1234);

        vm.prank(multisig());
        _terminal.setFee(fee);

        IJBFeeGauge feeGauge = IJBFeeGauge(makeAddr("FeeGauge"));
        vm.etch(address(feeGauge), new bytes(0x1));
        vm.mockCall(
            address(feeGauge),
            abi.encodeCall(IJBFeeGauge3_1.currentDiscountFor, (_projectId, JBFeeType.PAYOUT)),
            abi.encode(feeDiscount)
        );
        vm.prank(multisig());
        _terminal.setFeeGauge(address(feeGauge));

        uint256 discountedFee = fee - PRBMath.mulDiv(fee, feeDiscount, jbLibraries().MAX_FEE());

        // -- pay --
        _terminal.pay{value: payAmountInWei}(
            _projectId,
            payAmountInWei,
            address(0),
            /* _beneficiary */
            _userWallet,
            /* _minReturnedTokens */
            0,
            /* _preferClaimedTokens */
            false,
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

        // -- distribute --
        if (isUsingJbController3_0())
            _terminal.distributePayoutsOf(
                _projectId,
                payAmountInWei,
                jbLibraries().ETH(),
                address(0), //token (unused)
                /*min out*/
                0,
                /*LFG*/
                "lfg"
            );
        else 
            IJBPayoutRedemptionPaymentTerminal3_2(address(_terminal)).distributePayoutsOf(
               _projectId,
                payAmountInWei,
                jbLibraries().ETH(),
                address(0), //token (unused)
                /*min out*/
                0,
                ""
            );
        

        // verify: should have held the fee, if there is one
        if (discountedFee > 0) {
            assertEq(_terminal.heldFeesOf(_projectId)[0].fee, _terminal.fee());
            assertEq(_terminal.heldFeesOf(_projectId)[0].feeDiscount, feeDiscount);
            assertEq(_terminal.heldFeesOf(_projectId)[0].amount, payAmountInWei);
        }

        // -- add to balance --
        // Will get the fee reimbursed:
        uint256 heldFee = payAmountInWei
            - PRBMath.mulDiv(payAmountInWei, jbLibraries().MAX_FEE(), discountedFee + jbLibraries().MAX_FEE()); // no discount
        uint256 balanceBefore = jbPaymentTerminalStore().balanceOf(_terminal, _projectId);

        if (isUsingJbController3_0()) 
            _terminal.addToBalanceOf{value: payAmountInWei}(
                _projectId,
                payAmountInWei,
                address(0),
                "thanks for all the fish",
                /* _delegateMetadata */
                new bytes(0)
            );
        else 
            IJBFeeHoldingTerminal(address(_terminal)).addToBalanceOf{value: payAmountInWei}(
                _projectId,
                payAmountInWei,
                address(0),
                /* _shouldRefundHeldFees */
                true,
                "thanks for all the fish",
                /* _delegateMetadata */
                new bytes(0)
            );

        // verify: project should get the fee back (plus the addToBalance amount)
        assertEq(jbPaymentTerminalStore().balanceOf(_terminal, _projectId), balanceBefore + heldFee + payAmountInWei);
    }

    function testFeeGetsHeldSpecialCase() public {
        uint256 feeDiscount = 0;
        uint256 fee = 50_000_000;
        uint256 payAmountInWei = 1000000000; // The same value as 100% in the split (makes it easy to leave `1` left over)

        JBSplit[] memory _jbSplits = new JBSplit[](1);
        _jbSplits[0] = JBSplit(
            false,
            false,
            1000000000 - 1, // We make it so there is exactly `1` left over (note: change the subtraction to be anything else than 1 for this test to pass)
            0,
            payable(address(5)),
            0,
            IJBSplitAllocator(address(0))
        );

        JBGroupedSplits[] memory _groupedSplitsLocal = new JBGroupedSplits[](1);

        _groupedSplitsLocal[0] = JBGroupedSplits(_terminal.payoutSplitsGroup(), _jbSplits);

        JBFundingCycleConfiguration[] memory _cycleConfig = new JBFundingCycleConfiguration[](1);

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

        _cycleConfig[0].mustStartAtOrAfter = 0;
        _cycleConfig[0].data = _data;
        _cycleConfig[0].metadata = _metadata;
        _cycleConfig[0].groupedSplits = _groupedSplitsLocal;
        _cycleConfig[0].fundAccessConstraints = _fundAccessConstraints;

        _projectId = _controller.launchProjectFor(
            _projectOwner,
            _projectMetadata,
            _cycleConfig,
            _terminals,
            ""
        );

        address _userWallet = address(1234);
        vm.deal(_userWallet, payAmountInWei);
        vm.prank(multisig());
        _terminal.setFee(fee);

        IJBFeeGauge feeGauge = IJBFeeGauge(makeAddr("FeeGauge"));
        vm.etch(address(feeGauge), new bytes(0x1));
        vm.mockCall(
            address(feeGauge),
            abi.encodeCall(IJBFeeGauge3_1.currentDiscountFor, (_projectId, JBFeeType.PAYOUT)),
            abi.encode(feeDiscount)
        );
        vm.prank(multisig());
        _terminal.setFeeGauge(address(feeGauge));

        // -- pay --
        _terminal.pay{value: payAmountInWei}(
            _projectId,
            payAmountInWei,
            address(0),
            /* _beneficiary */
            _userWallet,
            /* _minReturnedTokens */
            0,
            /* _preferClaimedTokens */
            false,
            /* _memo */
            "Take my money!",
            /* _delegateMetadata */
            new bytes(0)
        );

        // verify: ETH balance in terminal should be up to date
        uint256 _terminalBalanceInWei = payAmountInWei;
        assertEq(jbPaymentTerminalStore().balanceOf(_terminal, _projectId), _terminalBalanceInWei);

        // -- distribute --
        if (isUsingJbController3_0())
            _terminal.distributePayoutsOf(
               _projectId,
                payAmountInWei,
                jbLibraries().ETH(),
                address(0), //token (unused)
                /*min out*/
                0,
                /*LFG*/
                "lfg"
            );
        else 
            IJBPayoutRedemptionPaymentTerminal3_2(address(_terminal)).distributePayoutsOf(
               _projectId,
                payAmountInWei,
                jbLibraries().ETH(),
                address(0), //token (unused)
                /*min out*/
                0,
                /*LFG*/
                "lfg"
            );

        // Verify that a fee was held
        assertEq(_terminal.heldFeesOf(_projectId).length, 1);

        // verify: should have held the fee
        assertEq(_terminal.heldFeesOf(_projectId)[0].fee, _terminal.fee());
        assertEq(_terminal.heldFeesOf(_projectId)[0].feeDiscount, feeDiscount);
        assertEq(_terminal.heldFeesOf(_projectId)[0].amount, payAmountInWei);
    }
}
