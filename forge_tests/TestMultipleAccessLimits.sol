// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import /* {*} from */ "./helpers/TestBaseWorkflow.sol";
import {MockPriceFeed} from "./mock/MockPriceFeed.sol";

/*  */
contract TestMultipleDistLimits_Local is TestBaseWorkflow {
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

    uint256 FAKE_PRICE = 0.0006 ether;

    function setUp() public override {
        super.setUp();

        _controller = jbController();

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

        _terminals.push(_terminal3_2);

        JBFundAccessConstraints3_1[] memory _fundAccessConstraints = new JBFundAccessConstraints3_1[](1);
        JBCurrencyAmount[] memory _distributionLimits = new JBCurrencyAmount[](2);
        JBCurrencyAmount[] memory _overflowAllowances = new JBCurrencyAmount[](1);

        _distributionLimits[0] = JBCurrencyAmount({
            value: 1 ether,
            currency: jbLibraries().ETH()
        });

        _distributionLimits[1] = JBCurrencyAmount({
            value: 3500000000,
            currency: jbLibraries().USD()
        });

        _overflowAllowances[0] = JBCurrencyAmount({
            value: 5 ether,
            currency: jbLibraries().ETH()
        });

        _fundAccessConstraints[0] = 
            JBFundAccessConstraints3_1({
                terminal: _terminal3_2,
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

        _projectOwner = multisig();

        _projectId = _controller.launchProjectFor(
            _projectOwner,
            _projectMetadata,
            _cycleConfig,
            _terminals,
            ""
        );

        vm.startPrank(_projectOwner);
        MockPriceFeed _priceFeedEthUsd = new MockPriceFeed(FAKE_PRICE, 6);
        vm.label(address(_priceFeedEthUsd), "MockPrice Feed MyToken-ETH");

        jbPrices().addFeedFor(
            jbLibraries().ETH(), // currency
            jbLibraries().USD(), // base weight currency
            _priceFeedEthUsd
        );
        vm.stopPrank();
    }

    function testAccessConstraintsDelineation() external {
        address _userWallet = address(1234);
        uint256 _userPayAmount = 1.5 ether;

        JBFundAccessConstraints3_1[] memory _fundAccessConstraints = new JBFundAccessConstraints3_1[](1);
        JBCurrencyAmount[] memory _distributionLimits = new JBCurrencyAmount[](2);
        JBCurrencyAmount[] memory _overflowAllowances = new JBCurrencyAmount[](1);

        _distributionLimits[0] = JBCurrencyAmount({
            value: 1 ether,
            currency: jbLibraries().ETH()
        });

        _distributionLimits[1] = JBCurrencyAmount({
            value: 2000000000,
            currency: jbLibraries().USD()
        });

        _overflowAllowances[0] = JBCurrencyAmount({
            value: 1,
            currency: 1
        });

        _fundAccessConstraints[0] = 
            JBFundAccessConstraints3_1({
                terminal: _terminal3_2,
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

        _projectOwner = multisig();

        vm.prank(_projectOwner);
        
        _projectId = _controller.launchProjectFor(
            _projectOwner,
            _projectMetadata,
            _cycleConfig,
            _terminals,
            ""
        );

        vm.deal(_userWallet, _userPayAmount);
        vm.prank(_userWallet);

        _terminal3_2.pay{value: _userPayAmount}(
            _projectId,
            _userPayAmount,
            address(0),
            _userWallet,
            0,
            false,
            "Take my money!",
            new bytes(0)
        );

        uint256 initTerminalBalance = address(_terminal3_2).balance;

        // verify: beneficiary should have a balance of JBTokens
        uint256 _userTokenBalance = PRBMathUD60x18.mul(_userPayAmount, _weight);
        assertEq(_tokenStore.balanceOf(_userWallet, _projectId), _userTokenBalance);

        vm.prank(_projectOwner);

        // First dist meets our ETH limit (important below)
        _terminal3_2.distributePayoutsOf(
            _projectId,
            1 ether,
            jbLibraries().ETH(),
            address(0), //token (unused)
            0,
            "lfg"
        );

        // Funds leaving the ecosystem -> fee taken
        assertEq(
            address(_terminal3_2).balance,
            initTerminalBalance - PRBMath.mulDiv(1 ether, jbLibraries().MAX_FEE(), jbLibraries().MAX_FEE() + _terminal3_2.fee())
        );

        // Price for the amount (in USD) that is distributable based on the terminals current balance
        uint256 distributableAmount = PRBMath.mulDiv(
            0.5 ether,
            10**18, // Use _MAX_FIXED_POINT_FIDELITY to keep as much of the `_amount.value`'s fidelity as possible when converting.
            jbPrices().priceFor(jbLibraries().ETH(), jbLibraries().USD(), 18)
        );

        // Confirm that anything over the distributableAmount (0.5 eth in USD) will fail via paymentterminalstore3_2
        // This doesn't work when expecting & calling distributePayoutsOf bc of chained calls
        vm.prank(address(_terminal3_2));
        vm.expectRevert(abi.encodeWithSignature("INADEQUATE_PAYMENT_TERMINAL_STORE_BALANCE()"));
        _jbPaymentTerminalStore3_2.recordDistributionFor(2, distributableAmount + 1, 2);

        // Should succeed with distributableAmount
        vm.prank(_projectOwner);
        _terminal3_2.distributePayoutsOf(
            _projectId,
            distributableAmount,
            jbLibraries().USD(),
            address(0), //token (unused)
            0,
            "lfg"
        );

        // Pay in another 0.5 ETH
        vm.deal(_userWallet, 0.5 ether);
        vm.prank(_userWallet);

        _terminal3_2.pay{value: 0.5 ether}(
            _projectId,
            0.5 ether,
            address(0),
            _userWallet,
            0,
            false,
            "Take my money!",
            new bytes(0)
        );

        // Trying to distribute via our ETH distLimit will fail (currency is ETH or 1)
        vm.prank(address(_terminal3_2));
        vm.expectRevert(abi.encodeWithSignature("DISTRIBUTION_AMOUNT_LIMIT_REACHED()"));
        _jbPaymentTerminalStore3_2.recordDistributionFor(2, 0.5 ether, 1);

        // But distribution via USD limit will succeed 
        vm.prank(_projectOwner);
        _terminal3_2.distributePayoutsOf(
            _projectId,
            distributableAmount,
            jbLibraries().USD(),
            address(0), //token (unused)
            0,
            "lfg"
        );
        
    }

    function testFuzzedInvalidAllowanceCurrencyOrdering(uint24 ALLOWCURRENCY) external {
        JBFundAccessConstraints3_1[] memory _fundAccessConstraints = new JBFundAccessConstraints3_1[](1);
        JBCurrencyAmount[] memory _distributionLimits = new JBCurrencyAmount[](1);
        JBCurrencyAmount[] memory _overflowAllowances = new JBCurrencyAmount[](2);

        _distributionLimits[0] = JBCurrencyAmount({
            value: 1,
            currency: jbLibraries().ETH()
        });

        _overflowAllowances[0] = JBCurrencyAmount({
            value: 1,
            currency: ALLOWCURRENCY
        });

        _overflowAllowances[1] = JBCurrencyAmount({
            value: 1,
            currency: ALLOWCURRENCY == 0 ? 0 : ALLOWCURRENCY - 1
        });

        _fundAccessConstraints[0] = 
            JBFundAccessConstraints3_1({
                terminal: _terminal3_2,
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

        _projectOwner = multisig();

        vm.prank(_projectOwner);

        vm.expectRevert(abi.encodeWithSignature("INVALID_OVERFLOW_ALLOWANCE_CURRENCY_ORDERING()"));
        
        _projectId = _controller.launchProjectFor(
            _projectOwner,
            _projectMetadata,
            _cycleConfig,
            _terminals,
            ""
        );
    }

    function testFuzzedInvalidDistCurrencyOrdering(uint24 DISTCURRENCY) external {
        JBFundAccessConstraints3_1[] memory _fundAccessConstraints = new JBFundAccessConstraints3_1[](1);
        JBCurrencyAmount[] memory _distributionLimits = new JBCurrencyAmount[](2);
        JBCurrencyAmount[] memory _overflowAllowances = new JBCurrencyAmount[](1);

        _distributionLimits[0] = JBCurrencyAmount({
            value: 1,
            currency: DISTCURRENCY
        });

        _distributionLimits[1] = JBCurrencyAmount({
            value: 1,
            currency: DISTCURRENCY == 0 ? 0 : DISTCURRENCY - 1
        });

        _overflowAllowances[0] = JBCurrencyAmount({
            value: 1,
            currency: 1
        });

        _fundAccessConstraints[0] = 
            JBFundAccessConstraints3_1({
                terminal: _terminal3_2,
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

        _projectOwner = multisig();

        vm.prank(_projectOwner);

        vm.expectRevert(abi.encodeWithSignature("INVALID_DISTRIBUTION_LIMIT_CURRENCY_ORDERING()"));
        
        _projectId = _controller.launchProjectFor(
            _projectOwner,
            _projectMetadata,
            _cycleConfig,
            _terminals,
            ""
        );
    }

    function testFuzzedConfigureAccess(uint232 DISTLIMIT, uint232 ALLOWLIMIT, uint256 DISTCURRENCY, uint256 ALLOWCURRENCY) external {
        DISTCURRENCY = bound(uint256(DISTCURRENCY), uint256(0), type(uint24).max - 1);
        ALLOWCURRENCY = bound(uint256(ALLOWCURRENCY), uint256(0), type(uint24).max - 1);
        
        JBFundAccessConstraints3_1[] memory _fundAccessConstraints = new JBFundAccessConstraints3_1[](1);
        JBCurrencyAmount[] memory _distributionLimits = new JBCurrencyAmount[](2);
        JBCurrencyAmount[] memory _overflowAllowances = new JBCurrencyAmount[](2);

        _distributionLimits[0] = JBCurrencyAmount({
            value: DISTLIMIT,
            currency: DISTCURRENCY
        });

        _distributionLimits[1] = JBCurrencyAmount({
            value: DISTLIMIT,
            currency: DISTCURRENCY + 1
        });

        _overflowAllowances[0] = JBCurrencyAmount({
            value: ALLOWLIMIT,
            currency: ALLOWCURRENCY
        });

        _overflowAllowances[1] = JBCurrencyAmount({
            value: ALLOWLIMIT,
            currency: ALLOWCURRENCY + 1
        });

        _fundAccessConstraints[0] = 
            JBFundAccessConstraints3_1({
                terminal: _terminal3_2,
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

        _projectOwner = multisig();

        vm.prank(_projectOwner);
        _projectId = _controller.launchProjectFor(
            _projectOwner,
            _projectMetadata,
            _cycleConfig,
            _terminals,
            ""
        );
    }

    function testFailMultipleDistroLimitCurrenciesOverLimit() external {
        address _userWallet = address(1234);
        uint256 _userPayAmount = 2 ether;
        vm.deal(_userWallet, _userPayAmount);
        vm.prank(_userWallet);

        _terminal3_2.pay{value: _userPayAmount}(
            _projectId,
            _userPayAmount,
            address(0),
            _userWallet,
            0,
            false,
            "Take my money!",
            new bytes(0)
        );

        // verify: beneficiary should have a balance of JBTokens
        uint256 _userTokenBalance = PRBMathUD60x18.mul(_userPayAmount, _weight);
        assertEq(_tokenStore.balanceOf(_userWallet, _projectId), _userTokenBalance);

        uint256 initTerminalBalance = address(_terminal3_2).balance;

        vm.startPrank(_projectOwner);

        // First dist should be fine based on price
        _terminal3_2.distributePayoutsOf(
            _projectId,
            1800000000,
            jbLibraries().USD(),
            address(0), //token (unused)
            0,
            "lfg"
        );

        vm.stopPrank();

        uint256 distributedAmount = PRBMath.mulDiv(
            1800000000,
            10**18, // Use _MAX_FIXED_POINT_FIDELITY to keep as much of the `_amount.value`'s fidelity as possible when converting.
            jbPrices().priceFor(jbLibraries().USD(), jbLibraries().ETH(), 18)
        );

        // Funds leaving the ecosystem -> fee taken
        assertEq(
            address(_terminal3_2).balance,
            initTerminalBalance - PRBMath.mulDiv(distributedAmount, jbLibraries().MAX_FEE(), jbLibraries().MAX_FEE() + _terminal3_2.fee())
        );

        // First dist should be fine based on price
        vm.prank(_projectOwner);
        _terminal3_2.distributePayoutsOf(
            _projectId,
            1700000000,
            jbLibraries().USD(),
            address(0), //token (unused)
            0,
            "lfg"
        );

        vm.stopPrank();
    }

    function testMultipleDistroLimitCurrencies() external {
        address _userWallet = address(1234);
        uint256 _userPayAmount = 3 ether;
        vm.deal(_userWallet, _userPayAmount);
        vm.prank(_userWallet);

        _terminal3_2.pay{value: _userPayAmount}(
            _projectId,
            _userPayAmount,
            address(0),
            _userWallet,
            0,
            false,
            "Take my money!",
            new bytes(0)
        );

        // verify: beneficiary should have a balance of JBTokens
        uint256 _userTokenBalance = PRBMathUD60x18.mul(_userPayAmount, _weight);
        assertEq(_tokenStore.balanceOf(_userWallet, _projectId), _userTokenBalance);

        uint256 initTerminalBalance = address(_terminal3_2).balance;
        uint256 ownerBalanceBeforeFirst = _projectOwner.balance;

        vm.prank(_projectOwner);

        _terminal3_2.distributePayoutsOf(
            _projectId,
            3000000000,
            jbLibraries().USD(),
            address(0), //token (unused)
            0,
            "lfg"
        );

        uint256 distributedAmount = PRBMath.mulDiv(
            3000000000,
            10**18, // Use _MAX_FIXED_POINT_FIDELITY to keep as much of the `_amount.value`'s fidelity as possible when converting.
            jbPrices().priceFor(jbLibraries().USD(), jbLibraries().ETH(), 18)
        );

        assertEq(
            _projectOwner.balance,
            ownerBalanceBeforeFirst + PRBMath.mulDiv(distributedAmount, jbLibraries().MAX_FEE(), jbLibraries().MAX_FEE() + _terminal3_2.fee())
        );

        // Funds leaving the ecosystem -> fee taken
        assertEq(
            address(_terminal3_2).balance,
            initTerminalBalance - PRBMath.mulDiv(distributedAmount, jbLibraries().MAX_FEE(), jbLibraries().MAX_FEE() + _terminal3_2.fee())
        );

        uint256 balanceBeforeEthDist = address(_terminal3_2).balance;
        uint256 ownerBalanceBeforeEthDist = _projectOwner.balance;

        _terminal3_2.distributePayoutsOf(
            _projectId,
            1 ether,
            jbLibraries().ETH(),
            address(0), //token (unused)
            0,
            "lfg"
        );

        // Funds leaving the ecosystem -> fee taken
        assertEq(
            _projectOwner.balance,
            ownerBalanceBeforeEthDist + PRBMath.mulDiv(1 ether, jbLibraries().MAX_FEE(), jbLibraries().MAX_FEE() + _terminal3_2.fee())
        );

        assertEq(
            address(_terminal3_2).balance,
            balanceBeforeEthDist - PRBMath.mulDiv(1 ether, jbLibraries().MAX_FEE(), jbLibraries().MAX_FEE() + _terminal3_2.fee())
        );
    }
}
