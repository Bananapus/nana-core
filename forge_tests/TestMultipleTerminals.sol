// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import /* {*} from */ "./helpers/TestBaseWorkflow.sol";

import {MockPriceFeed} from "./mock/MockPriceFeed.sol";

contract TestMultipleTerminals_Local is TestBaseWorkflow {
    JBController controller;
    JBProjectMetadata _projectMetadata;
    JBFundingCycleData _data;
    JBFundingCycleMetadata3_2 _metadata;
    JBGroupedSplits[] _groupedSplits;
    MockPriceFeed _priceFeedJbUsd;

    IJBPaymentTerminal[] _terminals;
    JBERC20PaymentTerminal3_2 ERC20terminal;
    JBETHPaymentTerminal ETHterminal;

    JBTokenStore _tokenStore;
    address _projectOwner;

    address caller = address(6942069);

    uint256 FAKE_PRICE = 10;
    uint256 WEIGHT = 1000 * 10 ** 18;
    uint256 projectId;

    function setUp() public override {
        super.setUp();
        vm.label(caller, "caller");

        _groupedSplits.push();
        _groupedSplits[0].group = 1;
        _groupedSplits[0].splits.push(
            JBSplit({
                preferClaimed: false,
                preferAddToBalance: false,
                percent: jbLibraries().SPLITS_TOTAL_PERCENT(),
                projectId: 0,
                beneficiary: payable(caller),
                lockedUntil: 0,
                allocator: IJBSplitAllocator(address(0))
            })
        );

        _projectOwner = multisig();

        _tokenStore = jbTokenStore();

        controller = jbController();

        _projectMetadata = JBProjectMetadata({content: "myIPFSHash", domain: 1});

        _data = JBFundingCycleData({
            duration: 14,
            weight: WEIGHT,
            discountRate: 450_000_000, // out of 1_000_000_000
            ballot: IJBFundingCycleBallot(address(0))
        });

        _metadata = JBFundingCycleMetadata3_2({
            global: JBGlobalFundingCycleMetadata({
                allowSetTerminals: false,
                allowSetController: false,
                pauseTransfers: false
            }),
            reservedRate: 5000, //50%
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
            useTotalOverflowForRedemptions: true,
            useDataSourceForPay: false,
            useDataSourceForRedeem: false,
            dataSource: address(0),
            metadata: 0
        });

            ERC20terminal = new JBERC20PaymentTerminal3_2(
                jbToken(),
                1, // JBSplitsGroupe
                jbOperatorStore(),
                jbProjects(),
                jbDirectory(),
                jbSplitsStore(),
                jbPrices(),
                address(jbPaymentTerminalStore()),
                multisig(),
                permit2()
            );
        
        vm.label(address(ERC20terminal), "JBERC20PaymentTerminalUSD");

        JBFundAccessConstraints3_1[] memory _fundAccessConstraints = new JBFundAccessConstraints3_1[](2);
        JBCurrencyAmount[] memory _distributionLimits = new JBCurrencyAmount[](1);
        JBCurrencyAmount[] memory _overflowAllowances = new JBCurrencyAmount[](1);

        JBCurrencyAmount[] memory _distributionLimits2 = new JBCurrencyAmount[](1);
        JBCurrencyAmount[] memory _overflowAllowances2 = new JBCurrencyAmount[](1);

        _distributionLimits[0] = JBCurrencyAmount({
            value: 10 * 10 ** 18,
            currency: jbLibraries().USD()
        });  

        _overflowAllowances[0] = JBCurrencyAmount({
            value: 5 * 10 ** 18,
            currency: jbLibraries().USD()
        });

        _distributionLimits2[0] = JBCurrencyAmount({
            value: 10 * 10 ** 18,
            currency: jbLibraries().ETH()
        });  

        _overflowAllowances2[0] = JBCurrencyAmount({
            value: 5 * 10 ** 18,
            currency: jbLibraries().ETH()
        });

        ETHterminal = jbETHPaymentTerminal();

        _fundAccessConstraints[0] =
            JBFundAccessConstraints3_1({
                terminal: ERC20terminal,
                token: address(jbToken()),
                distributionLimits: _distributionLimits,
                overflowAllowances: _overflowAllowances
            });

        _fundAccessConstraints[1] = 
            JBFundAccessConstraints3_1({
                terminal: ETHterminal,
                token: jbLibraries().ETHToken(),
                distributionLimits: _distributionLimits2,
                overflowAllowances: _overflowAllowances2
            });

        _terminals.push(ERC20terminal);
        _terminals.push(ETHterminal);

        JBFundingCycleConfiguration[] memory _cycleConfig = new JBFundingCycleConfiguration[](1);

        _cycleConfig[0].mustStartAtOrAfter = 0;
        _cycleConfig[0].data = _data;
        _cycleConfig[0].metadata = _metadata;
        _cycleConfig[0].groupedSplits = _groupedSplits;
        _cycleConfig[0].fundAccessConstraints = _fundAccessConstraints;

        projectId = controller.launchProjectFor(
            _projectOwner,
            _projectMetadata,
            _cycleConfig,
            _terminals,
            ""
        );

        vm.startPrank(_projectOwner);
        MockPriceFeed _priceFeedJbEth = new MockPriceFeed(FAKE_PRICE, 18);
        vm.label(address(_priceFeedJbEth), "MockPrice Feed JB-ETH");

        _priceFeedJbUsd = new MockPriceFeed(FAKE_PRICE, 18);
        vm.label(address(_priceFeedJbEth), "MockPrice Feed JB-USD");

        jbPrices().addFeedFor(
            projectId,
            uint256(uint24(uint160(address(jbToken())))), // currency
            jbLibraries().ETH(), // base weight currency
            _priceFeedJbEth
        );

        jbPrices().addFeedFor(
            projectId,
            uint256(uint24(uint160(address(jbToken())))), // currency
            jbLibraries().USD(), // base weight currency
            _priceFeedJbUsd
        );

        vm.stopPrank();
    }

    function testMultipleTerminal() public {
        // Send some token to the caller, so he can play
        vm.prank(_projectOwner);
        jbToken().transfer(caller, 20 * 10 ** 18);

        // ---- Pay in token ----
        vm.prank(caller); // back to regular msg.sender (bug?)
        jbToken().approve(address(ERC20terminal), 20 * 10 ** 18);
        vm.prank(caller); // back to regular msg.sender (bug?)
        ERC20terminal.pay(projectId, 20 * 10 ** 18, address(0), caller, 0, false, "Forge test", new bytes(0));

        // verify: beneficiary should have a balance of JBTokens (divided by 2 -> reserved rate = 50%)
        // price feed will return FAKE_PRICE; since it's an 18 decimal terminal (ie calling getPrice(18) )
        uint256 _userTokenBalance = PRBMath.mulDiv(20 * 10 ** 18, WEIGHT, FAKE_PRICE) / 2;
        assertEq(_tokenStore.balanceOf(caller, projectId), _userTokenBalance);

        // verify: balance in terminal should be up to date
        assertEq(jbPaymentTerminalStore().balanceOf(ERC20terminal, projectId), 20 * 10 ** 18);

        // ---- Pay in ETH ----
        address beneficiaryTwo = address(696969);
        ETHterminal.pay{value: 20 ether}(
            projectId, 20 ether, address(0), beneficiaryTwo, 0, false, "Forge test", new bytes(0)
        ); // funding target met and 10 ETH are now in the overflow

        // verify: beneficiary should have a balance of JBTokens (divided by 2 -> reserved rate = 50%)
        uint256 _userEthBalance = PRBMath.mulDiv(20 ether, (WEIGHT / 10 ** 18), 2);
        assertEq(_tokenStore.balanceOf(beneficiaryTwo, projectId), _userEthBalance);

        // verify: ETH balance in terminal should be up to date
        assertEq(jbPaymentTerminalStore().balanceOf(ETHterminal, projectId), 20 ether);

        // ---- Use allowance ----
        vm.startPrank(_projectOwner);

        IJBPayoutRedemptionPaymentTerminal3_2(address(ERC20terminal)).useAllowanceOf(
            projectId,
            5 * 10 ** 18, // amt in ETH (overflow allowance currency is in ETH)
            jbLibraries().USD(), // Currency -> (fake price is 10)
            address(0), //token (unused)
            1, // Min wei out
            payable(msg.sender), // Beneficiary
            "MEMO",
            bytes('')
        );
        
        vm.stopPrank();

        // Funds leaving the contract -> take the fee
        assertEq(
            jbToken().balanceOf(msg.sender),
            // Inverse price is returned, normalized to 18 decimals 
            PRBMath.mulDiv(PRBMath.mulDiv((5 * 10 ** 18), _priceFeedJbUsd.currentPrice(18), 10 ** 18), jbLibraries().MAX_FEE(), jbLibraries().MAX_FEE() + ERC20terminal.fee())
        );

        // Distribute the funding target ETH
        uint256 initBalance = caller.balance;
        vm.prank(_projectOwner);
        if (isUsingJbController3_0())
            ETHterminal.distributePayoutsOf(
                projectId,
                10 * 10 ** 18,
                jbLibraries().ETH(), // Currency
                address(0), //token (unused)
                0, // Min wei out
                "Foundry payment" // Memo
            );
        else 
            IJBPayoutRedemptionPaymentTerminal3_2(address(ETHterminal)).distributePayoutsOf(
                projectId,
                10 * 10 ** 18,
                jbLibraries().ETH(), // Currency
                address(0), //token (unused)
                0, // Min wei out
                "" // Memo
            );
        
        // Funds leaving the ecosystem -> fee taken
        assertEq(
            caller.balance,
            initBalance
                + PRBMath.mulDiv(10 * 10 ** 18, jbLibraries().MAX_FEE(), ETHterminal.fee() + jbLibraries().MAX_FEE())
        );

        // redeem eth from the overflow by the token holder:
        uint256 totalSupply;
        if (isUsingJbController3_0()) {
            totalSupply = jbController().totalOutstandingTokensOf(projectId);
        } else {
            totalSupply = IJBController(address(jbController())).totalOutstandingTokensOf(projectId);
        }

        uint256 overflow = jbPaymentTerminalStore().currentTotalOverflowOf(projectId, 18, 1);

        uint256 callerEthBalanceBefore = caller.balance;

        vm.prank(caller);
        ETHterminal.redeemTokensOf(
            caller,
            projectId,
            100_000,
            address(0), //token (unused)
            0,
            payable(caller),
            "gimme my money back",
            new bytes(0)
        );

        assertEq(caller.balance, callerEthBalanceBefore + ((100_000 * overflow) / totalSupply));
    }
}
