// SPDX-License-Identifier: MIT
pragma solidity >=0.8.6;

import /* {*} from */ "./helpers/TestBaseWorkflow.sol";

contract TestAllowance_Local is TestBaseWorkflow {
    JBController controller;
    JBProjectMetadata _projectMetadata;
    JBFundingCycleData _data;
    JBFundingCycleMetadata3_2 _metadata;
    JBGroupedSplits[] _groupedSplits;
    IJBPaymentTerminal[] _terminals;
    JBTokenStore _tokenStore;
    address _projectOwner;

    uint256 WEIGHT = 1000 * 10 ** 18;

    function setUp() public override {
        super.setUp();

        _projectOwner = multisig();

        _tokenStore = jbTokenStore();

        controller = jbController();

        _projectMetadata = JBProjectMetadata({content: "myIPFSHash", domain: 1});

        _data = JBFundingCycleData({
            duration: 14,
            weight: WEIGHT,
            discountRate: 450000000,
            ballot: IJBFundingCycleBallot(address(0))
        });

        _metadata = JBFundingCycleMetadata3_2({
            global: JBGlobalFundingCycleMetadata({
                allowSetTerminals: false,
                allowSetController: false,
                pauseTransfers: false
            }),
            reservedRate: 5000, //50%
            redemptionRate: 5000, //50%
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

        _terminals.push(jbETHPaymentTerminal());
    }

    function testAllowance() public {
        JBETHPaymentTerminal terminal = jbETHPaymentTerminal();

        JBFundAccessConstraints3_1[] memory _fundAccessConstraints = new JBFundAccessConstraints3_1[](1);
        JBCurrencyAmount[] memory _distributionLimits = new JBCurrencyAmount[](1);
        JBCurrencyAmount[] memory _overflowAllowances = new JBCurrencyAmount[](1);

         _distributionLimits[0] = JBCurrencyAmount({
            value: 10 ether,
            currency: jbLibraries().ETH()
        });  

        _overflowAllowances[0] = JBCurrencyAmount({
            value: 5 ether,
            currency: jbLibraries().ETH()
        });

        _fundAccessConstraints[0] =
            JBFundAccessConstraints3_1({
                terminal: terminal,
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

        uint256 projectId = controller.launchProjectFor(
            _projectOwner,
            _projectMetadata,
            _cycleConfig,
            _terminals,
            ""
        );

        terminal.pay{value: 20 ether}(
            projectId, 20 ether, address(0), _beneficiary, 0, false, "Forge test", new bytes(0)
        ); // funding target met and 10 ETH are now in the overflow

        // verify: beneficiary should have a balance of JBTokens (divided by 2 -> reserved rate = 50%)
        uint256 _userTokenBalance = PRBMath.mulDiv(20 ether, (WEIGHT / 10 ** 18), 2);
        assertEq(_tokenStore.balanceOf(_beneficiary, projectId), _userTokenBalance);

        // verify: ETH balance in terminal should be up to date
        assertEq(jbPaymentTerminalStore().balanceOf(terminal, projectId), 20 ether);

        // Discretionary use of overflow allowance by project owner (allowance = 5ETH)
        vm.prank(_projectOwner); // Prank only next call
        if (isUsingJbController3_0())
            terminal.useAllowanceOf(
                projectId,
                5 ether,
                1, // Currency
                address(0), //token (unused)
                0, // Min wei out
                payable(_beneficiary), // Beneficiary
                "MEMO",
                bytes('')
            );
        else 
            JBPayoutRedemptionPaymentTerminal3_2(address(terminal)).useAllowanceOf(
                projectId,
                5 ether,
                1, // Currency
                address(0), //token (unused)
                0, // Min wei out
                payable(_beneficiary), // Beneficiary
                "MEMO",
                bytes('')
            );
        assertEq(
            (_beneficiary).balance,
            PRBMath.mulDiv(5 ether, jbLibraries().MAX_FEE(), jbLibraries().MAX_FEE() + terminal.fee())
        );

        // Distribute the funding target ETH -> splits[] is empty -> everything in left-over, to project owner
        vm.prank(_projectOwner);

            JBPayoutRedemptionPaymentTerminal3_2(address(terminal)).distributePayoutsOf(
                projectId,
                10 ether,
                1, // Currency
                address(0), //token (unused)
                0, // Min wei out
                "" // Memo
            );
        assertEq(
            _projectOwner.balance, (10 ether * jbLibraries().MAX_FEE()) / (terminal.fee() + jbLibraries().MAX_FEE())
        );

        // redeem eth from the overflow by the token holder:
        uint256 senderBalance = _tokenStore.balanceOf(_beneficiary, projectId);
        vm.prank(_beneficiary);
        terminal.redeemTokensOf(
            _beneficiary,
            projectId,
            senderBalance,
            address(0), //token (unused)
            0,
            payable(_beneficiary),
            "gimme my money back",
            new bytes(0)
        );

        uint256 tokenBalanceAfter = _tokenStore.balanceOf(_beneficiary, projectId);
        uint256 tokenDiff = tokenBalanceAfter;

        // Redemption fee share: (tokens received from redeem * 2 b/c 50% redemption rate)
        uint256 processedFee = JBFees3_2.feeIn(tokenDiff * 2, jbLibraries().MAX_FEE());

        // verify: beneficiary should have a balance of 0 JBTokens
        assertEq(_tokenStore.balanceOf(_beneficiary, projectId), (processedFee));
    }

    function testFuzzAllowance(uint232 ALLOWANCE, uint232 TARGET, uint256 BALANCE) public {
        BALANCE = bound(BALANCE, 0, jbToken().totalSupply());

        unchecked {
            // Check for overflow
            vm.assume(ALLOWANCE + TARGET >= ALLOWANCE && ALLOWANCE + TARGET >= TARGET);
        }

        uint256 CURRENCY = jbLibraries().ETH(); // Avoid testing revert on this call...

        JBETHPaymentTerminal terminal = jbETHPaymentTerminal();

        JBFundAccessConstraints3_1[] memory _fundAccessConstraints = new JBFundAccessConstraints3_1[](1);
        JBCurrencyAmount[] memory _distributionLimits = new JBCurrencyAmount[](1);
        JBCurrencyAmount[] memory _overflowAllowances = new JBCurrencyAmount[](1);

         _distributionLimits[0] = JBCurrencyAmount({
            value: TARGET,
            currency: jbLibraries().ETH()
        });  

        _overflowAllowances[0] = JBCurrencyAmount({
            value: ALLOWANCE,
            currency: jbLibraries().ETH()
        });

        _fundAccessConstraints[0] =
            JBFundAccessConstraints3_1({
                terminal: terminal,
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

        uint256 projectId = controller.launchProjectFor(
            _projectOwner,
            _projectMetadata,
            _cycleConfig,
            _terminals,
            ""
        );

        terminal.pay{value: BALANCE}(projectId, BALANCE, address(0), _beneficiary, 0, false, "Forge test", new bytes(0));

        // verify: beneficiary should have a balance of JBTokens (divided by 2 -> reserved rate = 50%)
        uint256 _userTokenBalance = PRBMath.mulDiv(BALANCE, (WEIGHT / 10 ** 18), 2);
        if (BALANCE != 0) assertEq(_tokenStore.balanceOf(_beneficiary, projectId), _userTokenBalance);

        // verify: ETH balance in terminal should be up to date
        assertEq(jbPaymentTerminalStore().balanceOf(terminal, projectId), BALANCE);

        vm.startPrank(_projectOwner);

        bool willRevert;

        if (ALLOWANCE == 0) {
            vm.expectRevert(abi.encodeWithSignature("INADEQUATE_CONTROLLER_ALLOWANCE()"));
            willRevert = true;
        } else if (TARGET >= BALANCE || ALLOWANCE > (BALANCE - TARGET)) {
            // Too much to withdraw or no overflow ?
            vm.expectRevert(abi.encodeWithSignature("INADEQUATE_PAYMENT_TERMINAL_STORE_BALANCE()"));
            willRevert = true;
        }
            JBPayoutRedemptionPaymentTerminal3_2(address(terminal)).useAllowanceOf(
                projectId,
                ALLOWANCE,
                CURRENCY, // Currency
                address(0), //token (unused)
                0, // Min wei out
                payable(_beneficiary), // Beneficiary
                "MEMO",
                bytes('')
            );

        if (
            !willRevert && BALANCE != 0 // if allowance ==0 or not enough overflow (target>=balance, allowance > overflow) // there is something to transfer
        ) {
            assertEq(
                (_beneficiary).balance,
                PRBMath.mulDiv(ALLOWANCE, jbLibraries().MAX_FEE(), jbLibraries().MAX_FEE() + terminal.fee())
            );
        }

        if (TARGET > BALANCE) {
            vm.expectRevert(abi.encodeWithSignature("INADEQUATE_PAYMENT_TERMINAL_STORE_BALANCE()"));
        }

        if (TARGET == 0) {
            vm.expectRevert(abi.encodeWithSignature("DISTRIBUTION_AMOUNT_LIMIT_REACHED()"));
        }

        if (isUsingJbController3_0())
            terminal.distributePayoutsOf(
                projectId,
                TARGET,
                1, // Currency
                address(0), //token (unused)
                0, // Min wei out
                "Foundry payment" // Memo
            );
        else 
            JBPayoutRedemptionPaymentTerminal3_2(address(terminal)).distributePayoutsOf(
                projectId,
                TARGET,
                1, // Currency
                address(0), //token (unused)
                0, // Min wei out
                "" // Metadata
            );

        if (TARGET <= BALANCE && TARGET > 1) {
            // Avoid rounding error
            assertEq(
                _projectOwner.balance, (TARGET * jbLibraries().MAX_FEE()) / (terminal.fee() + jbLibraries().MAX_FEE())
            );
        }
    }
}
