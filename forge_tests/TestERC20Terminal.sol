// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import /* {*} from */ "./helpers/TestBaseWorkflow.sol";
import {MockMaliciousAllocator, GasGussler} from "./mock/MockMaliciousAllocator.sol";
import {MockMaliciousTerminal} from "./mock/MockMaliciousTerminal.sol";
import {MockPriceFeed} from "./mock/MockPriceFeed.sol";

import {PermitSignature} from 'permit2/test/utils/PermitSignature.sol';

contract TestERC20Terminal_Local is TestBaseWorkflow, PermitSignature {
    event PayoutReverted(uint256 indexed projectId, JBSplit split, uint256 amount, bytes reason, address caller);

    event FeeReverted(
        uint256 indexed projectId, uint256 indexed feeProjectId, uint256 amount, bytes reason, address caller
    );

    IJBSplitAllocator _allocator;
    JBController controller;
    JBProjectMetadata _projectMetadata;
    JBFundingCycleData _data;
    JBFundingCycleMetadata3_2 _metadata;
    JBGroupedSplits[] _groupedSplits;
    IJBPaymentTerminal[] _terminals;
    JBTokenStore _tokenStore;
    MockMaliciousTerminal _badTerminal;
    address _projectOwner;

    uint256 WEIGHT = 1000 * 10 ** 18;
    uint256 FAKE_PRICE = 18;

    // Permit2 stuffs
    bytes32 DOMAIN_SEPARATOR;

    address from;
    uint256 fromPrivateKey;

    function setUp() public override {
        super.setUp();

        fromPrivateKey = 0x12341234;
        from = vm.addr(fromPrivateKey);

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

        _terminals.push(jbERC20PaymentTerminal());

        _badTerminal = new MockMaliciousTerminal(
            jbToken(),
            1, // JBSplitsGroupe
            jbOperatorStore(),
            jbProjects(),
            jbDirectory(),
            jbSplitsStore(),
            jbPrices(),
            jbPaymentTerminalStore(),
            multisig()
        );

        DOMAIN_SEPARATOR = permit2().DOMAIN_SEPARATOR();
    }

    function launchProjectSTD() public returns (uint256, uint256){
        JBFundAccessConstraints3_1[] memory _splitProjectFundAccessConstraints = new JBFundAccessConstraints3_1[](1);
        IJBPaymentTerminal[] memory _splitProjectTerminals = new IJBPaymentTerminal[](1);
        JBGroupedSplits[] memory _allocationSplits = new JBGroupedSplits[](1); // Default empty
        JBERC20PaymentTerminal3_2 terminal = jbERC20PaymentTerminal();

        JBFundAccessConstraints3_1[] memory _fundAccessConstraints = new JBFundAccessConstraints3_1[](1);
        JBCurrencyAmount[] memory _distributionLimits = new JBCurrencyAmount[](1);
        JBCurrencyAmount[] memory _overflowAllowances = new JBCurrencyAmount[](1);

         _distributionLimits[0] = JBCurrencyAmount({
            value: 10 * 10 ** 18,
            currency: jbLibraries().ETH()
        });  

        _overflowAllowances[0] = JBCurrencyAmount({
            value: 5 * 10 ** 18,
            currency: jbLibraries().ETH()
        });

        _fundAccessConstraints[0] =
            JBFundAccessConstraints3_1({
                terminal: terminal,
                token: address(jbToken()),
                distributionLimits: _distributionLimits,
                overflowAllowances: _overflowAllowances
            });

        _splitProjectFundAccessConstraints[0] = JBFundAccessConstraints3_1({
            terminal: _badTerminal,
            token: address(jbToken()),
            distributionLimits: _distributionLimits,
            overflowAllowances: _overflowAllowances
        });
        _splitProjectTerminals[0] = IJBPaymentTerminal(address(_badTerminal));

        JBFundingCycleConfiguration[] memory _cycleConfig = new JBFundingCycleConfiguration[](1);

        _cycleConfig[0].mustStartAtOrAfter = 0;
        _cycleConfig[0].data = _data;
        _cycleConfig[0].metadata = _metadata;
        _cycleConfig[0].groupedSplits = _allocationSplits;
        _cycleConfig[0].fundAccessConstraints = _fundAccessConstraints;

        JBFundingCycleConfiguration[] memory _cycleConfig2 = new JBFundingCycleConfiguration[](1);

        _cycleConfig2[0].mustStartAtOrAfter = 0;
        _cycleConfig2[0].data = _data;
        _cycleConfig2[0].metadata = _metadata;
        _cycleConfig2[0].groupedSplits = _groupedSplits;
        _cycleConfig2[0].fundAccessConstraints = _splitProjectFundAccessConstraints;

        uint256 projectId = controller.launchProjectFor(
            _projectOwner,
            _projectMetadata,
            _cycleConfig,
            _terminals,
            ""
        );

        //project to allocato funds
        uint256 allocationProjectId = controller.launchProjectFor(
            _projectOwner,
            _projectMetadata,
            _cycleConfig,
            _splitProjectTerminals,
            ""
        );

        vm.startPrank(_projectOwner);
        MockPriceFeed _priceFeedJbEth = new MockPriceFeed(FAKE_PRICE, 18);
        vm.label(address(_priceFeedJbEth), "MockPrice Feed MyToken-ETH");

        jbPrices().addFeedFor(
            projectId,
            uint256(uint24(uint160(address(jbToken())))), // currency
            jbLibraries().ETH(), // base weight currency
            _priceFeedJbEth
        );

        vm.stopPrank();

        return (projectId, allocationProjectId);
    }

    function launch2ProjectsSTD() public returns (uint256, uint256) {
        JBFundAccessConstraints3_1[] memory _splitProjectFundAccessConstraints = new JBFundAccessConstraints3_1[](1);
        IJBPaymentTerminal[] memory _splitProjectTerminals = new IJBPaymentTerminal[](1);
        JBGroupedSplits[] memory _allocationSplits = new JBGroupedSplits[](1); // Default empty
        JBERC20PaymentTerminal3_2 terminal = jbERC20PaymentTerminal();

        JBFundAccessConstraints3_1[] memory _fundAccessConstraints = new JBFundAccessConstraints3_1[](1);
        JBCurrencyAmount[] memory _distributionLimits = new JBCurrencyAmount[](1);
        JBCurrencyAmount[] memory _overflowAllowances = new JBCurrencyAmount[](1);

         _distributionLimits[0] = JBCurrencyAmount({
            value: 10 * 10 ** 18,
            currency: jbLibraries().ETH()
        });  

        _overflowAllowances[0] = JBCurrencyAmount({
            value: 5 * 10 ** 18,
            currency: jbLibraries().ETH()
        });

        _fundAccessConstraints[0] =
            JBFundAccessConstraints3_1({
                terminal: terminal,
                token: address(jbToken()),
                distributionLimits: _distributionLimits,
                overflowAllowances: _overflowAllowances
            });

        _splitProjectFundAccessConstraints[0] = 
            JBFundAccessConstraints3_1({
                terminal: _badTerminal,
                token: address(jbToken()),
                distributionLimits: _distributionLimits,
                overflowAllowances: _overflowAllowances
            });

        _splitProjectTerminals[0] = IJBPaymentTerminal(address(_badTerminal));

        JBFundingCycleConfiguration[] memory _cycleConfig = new JBFundingCycleConfiguration[](1);

        _cycleConfig[0].mustStartAtOrAfter = 0;
        _cycleConfig[0].data = _data;
        _cycleConfig[0].metadata = _metadata;
        _cycleConfig[0].groupedSplits = _allocationSplits;
        _cycleConfig[0].fundAccessConstraints = _fundAccessConstraints;

        uint256 projectId = controller.launchProjectFor(
            _projectOwner,
            _projectMetadata,
            _cycleConfig,
            _terminals,
            ""
        );

        JBFundingCycleConfiguration[] memory _cycleConfig2 = new JBFundingCycleConfiguration[](1);

        _cycleConfig2[0].mustStartAtOrAfter = 0;
        _cycleConfig2[0].data = _data;
        _cycleConfig2[0].metadata = _metadata;
        _cycleConfig2[0].groupedSplits = _groupedSplits;
        _cycleConfig2[0].fundAccessConstraints = _splitProjectFundAccessConstraints;

        //project to allocato funds
        uint256 allocationProjectId = controller.launchProjectFor(
            _projectOwner,
            _projectMetadata,
            _cycleConfig2,
            _splitProjectTerminals,
            ""
        );

        // setting splits
        JBSplit[] memory _splits = new JBSplit[](1);
        _splits[0] = JBSplit({
            preferClaimed: false,
            preferAddToBalance: true,
            projectId: allocationProjectId,
            beneficiary: payable(makeAddr("user")),
            lockedUntil: 0,
            allocator: IJBSplitAllocator(address(0)),
            percent: JBConstants.SPLITS_TOTAL_PERCENT
        });

        _allocationSplits[0] = JBGroupedSplits({group: 1, splits: _splits});

        (JBFundingCycle memory _currentFundingCycle,) = controller.currentFundingCycleOf(projectId);

        vm.prank(_projectOwner);
        jbSplitsStore().set(projectId, _currentFundingCycle.configuration, _allocationSplits);

        vm.startPrank(_projectOwner);
        MockPriceFeed _priceFeedJbEth = new MockPriceFeed(FAKE_PRICE, 18);
        vm.label(address(_priceFeedJbEth), "MockPrice Feed MyToken-ETH");

        jbPrices().addFeedFor(
            projectId,
            uint256(uint24(uint160(address(jbToken())))), // currency
            jbLibraries().ETH(), // base weight currency
            _priceFeedJbEth
        );

        vm.stopPrank();

        return (projectId, allocationProjectId);
    }

    function launchProjectSTDFuzzed(uint232 ALLOWANCE, uint232 TARGET, uint256 BALANCE) public returns (uint256) {

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
                terminal: jbERC20PaymentTerminal(),
                token: address(jbToken()),
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

        vm.startPrank(_projectOwner);
        MockPriceFeed _priceFeedJbEth = new MockPriceFeed(FAKE_PRICE, 18);
        vm.label(address(_priceFeedJbEth), "MockPrice Feed MyToken-ETH");

        jbPrices().addFeedFor(
            projectId,
            uint256(uint24(uint160(address(jbToken())))), // currency
            jbLibraries().ETH(), // base weight currency
            _priceFeedJbEth
        );

        vm.stopPrank();

        return projectId;
    }

    function testAddToBalanceOfAndSetAllowance() public {
        JBERC20PaymentTerminal3_2 terminal = jbERC20PaymentTerminal();

        JBFundAccessConstraints3_1[] memory _fundAccessConstraints = new JBFundAccessConstraints3_1[](1);
        JBCurrencyAmount[] memory _distributionLimits = new JBCurrencyAmount[](1);
        JBCurrencyAmount[] memory _overflowAllowances = new JBCurrencyAmount[](1);

         _distributionLimits[0] = JBCurrencyAmount({
            value: 6 * 10 ** 18,
            currency: jbLibraries().ETH()
        });  

        _overflowAllowances[0] = JBCurrencyAmount({
            value: 5 * 10 ** 18,
            currency: jbLibraries().ETH()
        });

        _fundAccessConstraints[0] =
            JBFundAccessConstraints3_1({
                terminal: terminal,
                token: address(jbToken()),
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

        vm.startPrank(_projectOwner);
        MockPriceFeed _priceFeedJbEth = new MockPriceFeed(FAKE_PRICE, 18);
        vm.label(address(_priceFeedJbEth), "MockPrice Feed MyToken-ETH");

        jbPrices().addFeedFor(
            projectId,
            uint256(uint24(uint160(address(jbToken())))), // currency
            jbLibraries().ETH(), // base weight currency
            _priceFeedJbEth
        );

        vm.stopPrank();

        address caller = msg.sender;
        vm.label(caller, "caller");
        vm.prank(_multisig);
        jbToken().transfer(from, 1e18 + 1);

        IAllowanceTransfer.PermitDetails memory details =
            IAllowanceTransfer.PermitDetails({token: address(jbToken()), amount: uint160(1e18), expiration: uint48(block.timestamp + 5), nonce: 0});

        IAllowanceTransfer.PermitSingle memory permit =
            IAllowanceTransfer.PermitSingle({
            details: details,
            spender: address(terminal),
            sigDeadline: block.timestamp + 100
        });

        bytes memory sig = getPermitSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

        JBSingleAllowanceData memory permitData = 
            JBSingleAllowanceData({
                sigDeadline: block.timestamp + 100,
                amount: uint160(1e18),
                expiration: uint48(block.timestamp + 5),
                nonce: uint48(0),
                signature: sig
        });

        vm.prank(from);
        jbToken().approve(address(permit2()), 1e18);

        vm.prank(from);
        terminal.addToBalanceOfAndSetAllowance(
            projectId, 
            1e18,
            address(0),
            false,
            "testing permit2",
            new bytes(0),
            permitData
        );

        /* vm.prank(caller); // back to regular msg.sender (bug?)
        jbToken().approve(address(terminal), 1e18);
        vm.prank(caller); // back to regular msg.sender (bug?)
        terminal.pay(projectId, 1e18, address(0), msg.sender, 0, false, "Forge test", new bytes(0)); // funding target met and 10 token are now in the overflow */

    }

    function testERC20PayAndSetAllowance() public {
        JBERC20PaymentTerminal3_2 terminal = jbERC20PaymentTerminal();

        JBFundAccessConstraints3_1[] memory _fundAccessConstraints = new JBFundAccessConstraints3_1[](1);
        JBCurrencyAmount[] memory _distributionLimits = new JBCurrencyAmount[](1);
        JBCurrencyAmount[] memory _overflowAllowances = new JBCurrencyAmount[](1);

         _distributionLimits[0] = JBCurrencyAmount({
            value: 6 * 10 ** 18,
            currency: jbLibraries().ETH()
        });  

        _overflowAllowances[0] = JBCurrencyAmount({
            value: 5 * 10 ** 18,
            currency: jbLibraries().ETH()
        });

        _fundAccessConstraints[0] =
            JBFundAccessConstraints3_1({
                terminal: terminal,
                token: address(jbToken()),
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

        vm.startPrank(_projectOwner);
        MockPriceFeed _priceFeedJbEth = new MockPriceFeed(FAKE_PRICE, 18);
        vm.label(address(_priceFeedJbEth), "MockPrice Feed MyToken-ETH");

        jbPrices().addFeedFor(
            projectId,
            uint256(uint24(uint160(address(jbToken())))), // currency
            jbLibraries().ETH(), // base weight currency
            _priceFeedJbEth
        );

        vm.stopPrank();

        address caller = msg.sender;
        vm.label(caller, "caller");
        vm.prank(_multisig);
        jbToken().transfer(from, 1e18 + 1);

        IAllowanceTransfer.PermitDetails memory details =
            IAllowanceTransfer.PermitDetails({token: address(jbToken()), amount: uint160(1e18), expiration: uint48(block.timestamp + 5), nonce: 0});

        IAllowanceTransfer.PermitSingle memory permit =
            IAllowanceTransfer.PermitSingle({
            details: details,
            spender: address(terminal),
            sigDeadline: block.timestamp + 100
        });

        bytes memory sig = getPermitSignature(permit, fromPrivateKey, DOMAIN_SEPARATOR);

        /* permit2().permit(from, permit, sig); */

        JBSingleAllowanceData memory permitData = 
            JBSingleAllowanceData({
                sigDeadline: block.timestamp + 100,
                amount: uint160(1e18),
                expiration: uint48(block.timestamp + 5),
                nonce: uint48(0),
                signature: sig
        });

        vm.prank(from);
        jbToken().approve(address(permit2()), 1e18);

        vm.prank(from);
        terminal.payAndSetAllowance(
            projectId, 
            1e18,
            address(0),
            msg.sender,
            0,
            false,
            "testing permit2",
            new bytes(0),
            permitData
        );

        /* vm.prank(caller); // back to regular msg.sender (bug?)
        jbToken().approve(address(terminal), 1e18);
        vm.prank(caller); // back to regular msg.sender (bug?)
        terminal.pay(projectId, 1e18, address(0), msg.sender, 0, false, "Forge test", new bytes(0)); // funding target met and 10 token are now in the overflow */

    }

    function testAllowanceERC20() public {
        JBERC20PaymentTerminal3_2 terminal = jbERC20PaymentTerminal();

        JBFundAccessConstraints3_1[] memory _fundAccessConstraints = new JBFundAccessConstraints3_1[](1);
        JBCurrencyAmount[] memory _distributionLimits = new JBCurrencyAmount[](1);
        JBCurrencyAmount[] memory _overflowAllowances = new JBCurrencyAmount[](1);

         _distributionLimits[0] = JBCurrencyAmount({
            value: 6 * 10 ** 18,
            currency: jbLibraries().ETH()
        });  

        _overflowAllowances[0] = JBCurrencyAmount({
            value: 5 * 10 ** 18,
            currency: jbLibraries().ETH()
        });

        _fundAccessConstraints[0] =
            JBFundAccessConstraints3_1({
                terminal: terminal,
                token: address(jbToken()),
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

        vm.startPrank(_projectOwner);
        MockPriceFeed _priceFeedJbEth = new MockPriceFeed(FAKE_PRICE, 18);
        vm.label(address(_priceFeedJbEth), "MockPrice Feed MyToken-ETH");

        jbPrices().addFeedFor(
            projectId,
            uint256(uint24(uint160(address(jbToken())))), // currency
            jbLibraries().ETH(), // base weight currency
            _priceFeedJbEth
        );

        vm.stopPrank();

        address caller = msg.sender;
        vm.label(caller, "caller");
        vm.prank(_projectOwner);
        jbToken().transfer(caller, 1e18);

        vm.prank(caller); // back to regular msg.sender (bug?)
        jbToken().approve(address(terminal), 1e18);
        vm.prank(caller); // back to regular msg.sender (bug?)
        terminal.pay(projectId, 1e18, address(0), msg.sender, 0, false, "Forge test", new bytes(0)); // funding target met and 10 token are now in the overflow

        // verify: beneficiary should have a balance of JBTokens (Price = 18, divided by 2 -> reserved rate = 50%)
        emit log_string("user Token balance check");
        uint256 _userTokenBalance = PRBMath.mulDiv(1e18 / 2, WEIGHT, 18);
        assertEq(_tokenStore.balanceOf(msg.sender, projectId), _userTokenBalance);

        // verify: balance in terminal should be up to date
        emit log_string("Terminal Token balance check");
        assertEq(jbPaymentTerminalStore().balanceOf(terminal, projectId), 1e18);

        // Discretionary use of overflow allowance by project owner (allowance = 5ETH)
        vm.prank(_projectOwner); // Prank only next call
        
        IJBPayoutRedemptionPaymentTerminal3_2(address(terminal)).useAllowanceOf(
            projectId,
            5 * 10 ** 18,
            1, // Currency
            address(0), //token (unused)
            0, // Min wei out
            payable(msg.sender), // Beneficiary
            "MEMO",
            bytes("")
        );

        assertEq(
            jbToken().balanceOf(msg.sender),
            // 18 tokens per ETH && fees
            PRBMath.mulDiv(5 * 18, jbLibraries().MAX_FEE(), jbLibraries().MAX_FEE() + terminal.fee())
        );

        // Distribute the funding target ETH -> splits[] is empty -> everything in left-over, to project owner
        uint256 initBalance = jbToken().balanceOf(_projectOwner);
        uint256 distributedAmount = PRBMath.mulDiv(
            6 * 10 ** 18,
            10**18, // Use _MAX_FIXED_POINT_FIDELITY to keep as much of the `_amount.value`'s fidelity as possible when converting.
            jbPrices().priceFor(1, jbLibraries().ETH(), uint256(uint24(uint160(address(jbToken())))), 18)
        );
        vm.prank(_projectOwner);

            IJBPayoutRedemptionPaymentTerminal3_2(address(terminal)).distributePayoutsOf(
                projectId,
                6 * 10 ** 18,
                1, // Currency
                address(0), //token (unused)
                0, // Min wei out
                "" // metadata
            );

        // Funds leaving the ecosystem -> fee taken
        assertEq(
            jbToken().balanceOf(_projectOwner),
            initBalance + PRBMath.mulDiv(distributedAmount, jbLibraries().MAX_FEE(), jbLibraries().MAX_FEE() + terminal.fee())
        );

        // redeem eth from the overflow by the token holder:
        uint256 senderBalance = _tokenStore.balanceOf(msg.sender, projectId);
        vm.prank(msg.sender);
        terminal.redeemTokensOf(
            msg.sender,
            projectId,
            senderBalance,
            address(0), //token (unused)
            0,
            payable(msg.sender),
            "gimme my money back",
            new bytes(0)
        );

        // verify: beneficiary should have a balance of 0 JBTokens
        assertEq(_tokenStore.balanceOf(msg.sender, projectId), 0);
    }

    function testAllocation_to_reverting_allocator_should_revoke_allowance() public {
        address _user = makeAddr("user");

        _allocator = new MockMaliciousAllocator();
        JBGroupedSplits[] memory _allocationSplits = new JBGroupedSplits[](1); // Default empty
        JBERC20PaymentTerminal3_2 terminal = jbERC20PaymentTerminal();

        JBFundAccessConstraints3_1[] memory _fundAccessConstraints = new JBFundAccessConstraints3_1[](1);
        JBCurrencyAmount[] memory _distributionLimits = new JBCurrencyAmount[](1);
        JBCurrencyAmount[] memory _overflowAllowances = new JBCurrencyAmount[](1);

         _distributionLimits[0] = JBCurrencyAmount({
            value: 10 * 10 ** 18,
            currency: jbLibraries().ETH()
        });  

        _overflowAllowances[0] = JBCurrencyAmount({
            value: 5 * 10 ** 18,
            currency: jbLibraries().ETH()
        });

        _fundAccessConstraints[0] =
            JBFundAccessConstraints3_1({
                terminal: terminal,
                token: address(jbToken()),
                distributionLimits: _distributionLimits,
                overflowAllowances: _overflowAllowances
            });

        JBFundingCycleConfiguration[] memory _cycleConfig = new JBFundingCycleConfiguration[](1);

        _cycleConfig[0].mustStartAtOrAfter = 0;
        _cycleConfig[0].data = _data;
        _cycleConfig[0].metadata = _metadata;
        _cycleConfig[0].groupedSplits = _allocationSplits;
        _cycleConfig[0].fundAccessConstraints = _fundAccessConstraints;

        uint256 projectId = controller.launchProjectFor(
            _projectOwner,
            _projectMetadata,
            _cycleConfig,
            _terminals,
            ""
        );

        // setting splits
        JBSplit[] memory _splits = new JBSplit[](1);
        _splits[0] = JBSplit({
            preferClaimed: false,
            preferAddToBalance: true,
            projectId: 0,
            beneficiary: payable(_user),
            lockedUntil: 0,
            allocator: _allocator,
            percent: JBConstants.SPLITS_TOTAL_PERCENT
        });

        _allocationSplits[0] = JBGroupedSplits({group: 1, splits: _splits});

        (JBFundingCycle memory _currentFundingCycle,) = controller.currentFundingCycleOf(projectId);

        vm.prank(_projectOwner);
        jbSplitsStore().set(projectId, _currentFundingCycle.configuration, _allocationSplits);

        vm.startPrank(_projectOwner);
        MockPriceFeed _priceFeedJbEth = new MockPriceFeed(FAKE_PRICE, 18);
        vm.label(address(_priceFeedJbEth), "MockPrice Feed MyToken-ETH");

        jbPrices().addFeedFor(
            projectId,
            uint256(uint24(uint160(address(jbToken())))), // currency
            jbLibraries().ETH(), // base weight currency
            _priceFeedJbEth
        );

        vm.stopPrank();

        // fund user
        vm.prank(_projectOwner);
        jbToken().transfer(_user, 20 * 10 ** 18);

        // pay project
        vm.prank(_user);
        jbToken().approve(address(terminal), 20 * 10 ** 18);
        vm.prank(_user);
        terminal.pay(projectId, 20 * 10 ** 18, address(0), msg.sender, 0, false, "Forge test", new bytes(0)); // funding target met and 10 token are now in the overflow

        // using controller 3.1
        if (!isUsingJbController3_0()) {
            uint256 _projectStoreBalanceBeforeDistribution =
                jbPaymentTerminalStore().balanceOf(IJBSingleTokenPaymentTerminal(address(terminal)), projectId);

            vm.prank(_projectOwner);
            IJBPayoutRedemptionPaymentTerminal3_2(address(terminal)).distributePayoutsOf(
                projectId,
                10 * 10 ** 18,
                1, // Currency
                address(0), //token (unused)
                0, // Min wei out
                "allocation" // metadata
            );
            uint256 _projectStoreBalanceAfterDistribution =
                jbPaymentTerminalStore().balanceOf(IJBSingleTokenPaymentTerminal(address(terminal)), projectId);

            assertEq(jbToken().allowance(address(terminal), address(_allocator)), 0);
            assertEq(_projectStoreBalanceAfterDistribution, _projectStoreBalanceBeforeDistribution);
        }
    }

    function testAllocation_to_non_allocator_contract_should_revoke_allowance() public {
        address _user = makeAddr("user");

        _allocator = IJBSplitAllocator(address(new GasGussler())); // Whatever other contract with a fallback

        JBGroupedSplits[] memory _allocationSplits = new JBGroupedSplits[](1); // Default empty
        JBERC20PaymentTerminal3_2 terminal = jbERC20PaymentTerminal();

        JBFundAccessConstraints3_1[] memory _fundAccessConstraints = new JBFundAccessConstraints3_1[](1);
        JBCurrencyAmount[] memory _distributionLimits = new JBCurrencyAmount[](1);
        JBCurrencyAmount[] memory _overflowAllowances = new JBCurrencyAmount[](1);

         _distributionLimits[0] = JBCurrencyAmount({
            value: 10 * 10 ** 18,
            currency: jbLibraries().ETH()
        });  

        _overflowAllowances[0] = JBCurrencyAmount({
            value: 5 * 10 ** 18,
            currency: jbLibraries().ETH()
        });

        _fundAccessConstraints[0] =
            JBFundAccessConstraints3_1({
                terminal: terminal,
                token: address(jbToken()),
                distributionLimits: _distributionLimits,
                overflowAllowances: _overflowAllowances
            });

        JBFundingCycleConfiguration[] memory _cycleConfig = new JBFundingCycleConfiguration[](1);

        _cycleConfig[0].mustStartAtOrAfter = 0;
        _cycleConfig[0].data = _data;
        _cycleConfig[0].metadata = _metadata;
        _cycleConfig[0].groupedSplits = _allocationSplits;
        _cycleConfig[0].fundAccessConstraints = _fundAccessConstraints;

        uint256 projectId = controller.launchProjectFor(
            _projectOwner,
            _projectMetadata,
            _cycleConfig,
            _terminals,
            ""
        );

        // setting splits
        JBSplit[] memory _splits = new JBSplit[](1);
        _splits[0] = JBSplit({
            preferClaimed: false,
            preferAddToBalance: true,
            projectId: 0,
            beneficiary: payable(_user),
            lockedUntil: 0,
            allocator: _allocator,
            percent: JBConstants.SPLITS_TOTAL_PERCENT
        });

        _allocationSplits[0] = JBGroupedSplits({group: 1, splits: _splits});

        (JBFundingCycle memory _currentFundingCycle,) = controller.currentFundingCycleOf(projectId);

        vm.prank(_projectOwner);
        jbSplitsStore().set(projectId, _currentFundingCycle.configuration, _allocationSplits);

        vm.startPrank(_projectOwner);
        MockPriceFeed _priceFeedJbEth = new MockPriceFeed(FAKE_PRICE, 18);
        vm.label(address(_priceFeedJbEth), "MockPrice Feed MyToken-ETH");

        jbPrices().addFeedFor(
            projectId,
            uint256(uint24(uint160(address(jbToken())))), // currency
            jbLibraries().ETH(), // base weight currency
            _priceFeedJbEth
        );

        vm.stopPrank();

        // fund user
        vm.prank(_projectOwner);
        jbToken().transfer(_user, 20 * 10 ** 18);

        // pay project
        vm.prank(_user);
        jbToken().approve(address(terminal), 20 * 10 ** 18);
        vm.prank(_user);
        terminal.pay(projectId, 20 * 10 ** 18, address(0), msg.sender, 0, false, "Forge test", new bytes(0)); // funding target met and 10 token are now in the overflow

        if (!isUsingJbController3_0()) {
            uint256 _projectStoreBalanceBeforeDistribution =
                jbPaymentTerminalStore().balanceOf(IJBSingleTokenPaymentTerminal(address(terminal)), projectId);

            // using controller 3.1
            vm.prank(_projectOwner);
            IJBPayoutRedemptionPaymentTerminal3_2(address(terminal)).distributePayoutsOf(
                projectId,
                10 * 10 ** 18,
                1, // Currency
                address(0), //token (unused)
                0, // Min wei out
                "allocation" // metadata
            );
            uint256 _projectStoreBalanceAfterDistribution =
                jbPaymentTerminalStore().balanceOf(IJBSingleTokenPaymentTerminal(address(terminal)), projectId);

            assertEq(jbToken().allowance(address(terminal), address(_allocator)), 0);
            assertEq(_projectStoreBalanceAfterDistribution, _projectStoreBalanceBeforeDistribution);
        }
    }

    function testAllocation_to_an_eoa_should_revoke_allowance() public {
        address _user = makeAddr("user");
        IJBSplitAllocator _randomEOA = IJBSplitAllocator(makeAddr("randomEOA"));

        JBGroupedSplits[] memory _allocationSplits = new JBGroupedSplits[](1); // Default empty
        JBERC20PaymentTerminal3_2 terminal = jbERC20PaymentTerminal();

        JBFundAccessConstraints3_1[] memory _fundAccessConstraints = new JBFundAccessConstraints3_1[](1);
        JBCurrencyAmount[] memory _distributionLimits = new JBCurrencyAmount[](1);
        JBCurrencyAmount[] memory _overflowAllowances = new JBCurrencyAmount[](1);

         _distributionLimits[0] = JBCurrencyAmount({
            value: 10 * 10 ** 18,
            currency: jbLibraries().ETH()
        });  

        _overflowAllowances[0] = JBCurrencyAmount({
            value: 5 * 10 ** 18,
            currency: jbLibraries().ETH()
        });

        _fundAccessConstraints[0] =
            JBFundAccessConstraints3_1({
                terminal: terminal,
                token: address(jbToken()),
                distributionLimits: _distributionLimits,
                overflowAllowances: _overflowAllowances
            });

        JBFundingCycleConfiguration[] memory _cycleConfig = new JBFundingCycleConfiguration[](1);

        _cycleConfig[0].mustStartAtOrAfter = 0;
        _cycleConfig[0].data = _data;
        _cycleConfig[0].metadata = _metadata;
        _cycleConfig[0].groupedSplits = _allocationSplits;
        _cycleConfig[0].fundAccessConstraints = _fundAccessConstraints;

        uint256 projectId = controller.launchProjectFor(
            _projectOwner,
            _projectMetadata,
            _cycleConfig,
            _terminals,
            ""
        );

        // setting splits
        JBSplit[] memory _splits = new JBSplit[](1);
        _splits[0] = JBSplit({
            preferClaimed: false,
            preferAddToBalance: true,
            projectId: 0,
            beneficiary: payable(_user),
            lockedUntil: 0,
            allocator: _randomEOA,
            percent: JBConstants.SPLITS_TOTAL_PERCENT
        });

        _allocationSplits[0] = JBGroupedSplits({group: 1, splits: _splits});

        (JBFundingCycle memory _currentFundingCycle,) = controller.currentFundingCycleOf(projectId);

        vm.prank(_projectOwner);
        jbSplitsStore().set(projectId, _currentFundingCycle.configuration, _allocationSplits);

        vm.startPrank(_projectOwner);
        MockPriceFeed _priceFeedJbEth = new MockPriceFeed(FAKE_PRICE, 18);
        vm.label(address(_priceFeedJbEth), "MockPrice Feed MyToken-ETH");

        jbPrices().addFeedFor(
            projectId,
            uint256(uint24(uint160(address(jbToken())))), // currency
            jbLibraries().ETH(), // base weight currency
            _priceFeedJbEth
        );

        vm.stopPrank();

        // fund user
        vm.prank(_projectOwner);
        jbToken().transfer(_user, 20 * 10 ** 18);

        // pay project
        vm.prank(_user);
        jbToken().approve(address(terminal), 20 * 10 ** 18);
        vm.prank(_user);
        terminal.pay(projectId, 20 * 10 ** 18, address(0), msg.sender, 0, false, "Forge test", new bytes(0)); // funding target met and 10 token are now in the overflow

        if (!isUsingJbController3_0()) {

            uint256 distributedAmount = PRBMath.mulDiv(
            10 * 10 ** 18,
            10**18, // Use _MAX_FIXED_POINT_FIDELITY to keep as much of the `_amount.value`'s fidelity as possible when converting.
            jbPrices().priceFor(1, jbLibraries().ETH(), uint256(uint24(uint160(address(jbToken())))), 18)
        );

            uint256 _projectStoreBalanceBeforeDistribution =
                jbPaymentTerminalStore().balanceOf(IJBSingleTokenPaymentTerminal(address(terminal)), projectId);

            vm.expectEmit(true, true, true, true);
            emit PayoutReverted(projectId, _splits[0], distributedAmount, abi.encode("IERC165 fail"), address(this));

            IJBPayoutRedemptionPaymentTerminal3_2(address(terminal)).distributePayoutsOf(
                projectId,
                10 * 10 ** 18,
                1, // Currency
                address(0), //token (unused)
                0, // Min wei out
                "allocation" // metadata
            );
            uint256 _projectStoreBalanceAfterDistribution =
                jbPaymentTerminalStore().balanceOf(IJBSingleTokenPaymentTerminal(address(terminal)), projectId);

            assertEq(jbToken().allowance(address(terminal), address(_allocator)), 0);
            assertEq(_projectStoreBalanceAfterDistribution, _projectStoreBalanceBeforeDistribution);
        }
    }


    function testDistribution_to_malicious_terminal_by_adding_balance(uint256 _revertReason) public {
        _revertReason = bound(_revertReason, 0, 3);
        address _user = makeAddr("user");
        JBERC20PaymentTerminal3_2 terminal = jbERC20PaymentTerminal();

        (uint256 projectId, uint256 allocationProjectId) = launch2ProjectsSTD();

        // fund user
        vm.prank(_projectOwner);
        jbToken().transfer(_user, 20 * 10 ** 18);

        // pay project
        vm.prank(_user);
        jbToken().approve(address(terminal), 20 * 10 ** 18);
        vm.prank(_user);
        terminal.pay(projectId, 20 * 10 ** 18, address(0), msg.sender, 0, false, "Forge test", new bytes(0)); // funding target met and 10 token are now in the overflow

        if (!isUsingJbController3_0()) {

            // setting splits
            JBSplit[] memory _splits = new JBSplit[](1);
            _splits[0] = JBSplit({
                preferClaimed: false,
                preferAddToBalance: true,
                projectId: allocationProjectId,
                beneficiary: payable(makeAddr("user")),
                lockedUntil: 0,
                allocator: IJBSplitAllocator(address(0)),
                percent: JBConstants.SPLITS_TOTAL_PERCENT
            });
            
            uint256 _projectStoreBalanceBeforeDistribution =
                jbPaymentTerminalStore().balanceOf(IJBSingleTokenPaymentTerminal(address(terminal)), projectId);

            // using controller 3.1
            _badTerminal.setRevertMode(_revertReason);
            bytes memory _reason;

            if (_revertReason == 1) {
                _reason = abi.encodeWithSignature("NopeNotGonnaDoIt()");
            } else if (_revertReason == 2) {
                _reason = abi.encodeWithSignature("Error(string)", "thanks no thanks");
            } else if (_revertReason == 3) {
                bytes4 _panickSelector = bytes4(keccak256("Panic(uint256)"));
                _reason = abi.encodePacked(_panickSelector, uint256(0x11));
            }

            vm.expectEmit(true, true, true, true);
            // Stack is too deep so I'm hardcoding the distributedAmount - see tests above for calc
            emit PayoutReverted(projectId, _splits[0], 180, _reason, address(this));

            IJBPayoutRedemptionPaymentTerminal3_2(address(terminal)).distributePayoutsOf(
                projectId,
                10 * 10 ** 18,
                1, // Currency
                address(0), //token (unused)
                0, // Min wei out
                "allocation" // metadata
            );
            uint256 _projectStoreBalanceAfterDistribution =
                jbPaymentTerminalStore().balanceOf(IJBSingleTokenPaymentTerminal(address(terminal)), projectId);

            assertEq(jbToken().allowance(address(terminal), address(_allocator)), 0);
            assertEq(_projectStoreBalanceAfterDistribution, _projectStoreBalanceBeforeDistribution);
        }
    }

    function testDistribution_to_malicious_terminal_by_paying_project(uint256 _revertReason) public {
        _revertReason = bound(_revertReason, 0, 3);

        address _user = makeAddr("user");
        (uint256 projectId, uint256 allocationProjectId) = launchProjectSTD();

        JBFundAccessConstraints3_1[] memory _splitProjectFundAccessConstraints = new JBFundAccessConstraints3_1[](1);
        IJBPaymentTerminal[] memory _splitProjectTerminals = new IJBPaymentTerminal[](1);
        JBGroupedSplits[] memory _allocationSplits = new JBGroupedSplits[](1); // Default empty
        JBERC20PaymentTerminal3_2 terminal = jbERC20PaymentTerminal();

        // setting splits
        JBSplit[] memory _splits = new JBSplit[](1);
        _splits[0] = JBSplit({
            preferClaimed: false,
            preferAddToBalance: false,
            projectId: allocationProjectId,
            beneficiary: payable(_user),
            lockedUntil: 0,
            allocator: IJBSplitAllocator(address(0)),
            percent: JBConstants.SPLITS_TOTAL_PERCENT
        });

        _allocationSplits[0] = JBGroupedSplits({group: 1, splits: _splits});

        (JBFundingCycle memory _currentFundingCycle,) = controller.currentFundingCycleOf(projectId);

        vm.startPrank(_projectOwner);
        jbSplitsStore().set(projectId, _currentFundingCycle.configuration, _allocationSplits);

        // fund user
        jbToken().transfer(_user, 20 * 10 ** 18);
        vm.stopPrank();
        // pay project
        vm.startPrank(_user);
        jbToken().approve(address(terminal), 20 * 10 ** 18);
        
        terminal.pay(projectId, 20 * 10 ** 18, address(0), msg.sender, 0, false, "Forge test", new bytes(0)); // funding target met and 10 token are now in the overflow
        vm.stopPrank();

        if (!isUsingJbController3_0()) {
            uint256 _projectStoreBalanceBeforeDistribution =
                jbPaymentTerminalStore().balanceOf(IJBSingleTokenPaymentTerminal(address(terminal)), projectId);

            _badTerminal.setRevertMode(_revertReason);
            bytes memory _reason;

            if (_revertReason == 1) {
                _reason = abi.encodeWithSignature("NopeNotGonnaDoIt()");
            } else if (_revertReason == 2) {
                _reason = abi.encodeWithSignature("Error(string)", "thanks no thanks");
            } else if (_revertReason == 3) {
                bytes4 _panickSelector = bytes4(keccak256("Panic(uint256)"));
                _reason = abi.encodePacked(_panickSelector, uint256(0x11));
            }

            vm.expectEmit(true, true, true, true);
            // Stack is too deep so I'm hardcoding the distributedAmount - see testAllowanceERC20 above for calc
            emit PayoutReverted(projectId, _splits[0], 180, _reason, address(this));

            IJBPayoutRedemptionPaymentTerminal3_2(address(terminal)).distributePayoutsOf(
                projectId,
                10 * 10 ** 18,
                1, // Currency
                address(0), //token (unused)
                0, // Min wei out
                "allocation" // metadata
            );
            uint256 _projectStoreBalanceAfterDistribution =
                jbPaymentTerminalStore().balanceOf(IJBSingleTokenPaymentTerminal(address(terminal)), projectId);

            assertEq(jbToken().allowance(address(terminal), address(_allocator)), 0);
            assertEq(_projectStoreBalanceAfterDistribution, _projectStoreBalanceBeforeDistribution);
        }
    }

    function testFuzzedAllowanceERC20(uint232 ALLOWANCE, uint232 TARGET, uint256 BALANCE) public {
        BALANCE = bound(BALANCE, 1e18, jbToken().totalSupply());
        
        JBERC20PaymentTerminal3_2 terminal = jbERC20PaymentTerminal();

        uint256 projectId = launchProjectSTDFuzzed(ALLOWANCE, TARGET, BALANCE);

        uint256 balanceInTokens = PRBMath.mulDiv(BALANCE, 10**18, jbPrices().priceFor(projectId, 1, 13787699, 18));
        uint256 allowanceInTokens = PRBMath.mulDiv(ALLOWANCE, 10**18, jbPrices().priceFor(projectId, 1, 13787699, 18));
        uint256 targetInTokens = PRBMath.mulDiv(TARGET, 10**18, jbPrices().priceFor(projectId, 1, 13787699, 18));

        address caller = msg.sender;
        vm.label(caller, "caller");
        vm.prank(_projectOwner);
        jbToken().transfer(caller, balanceInTokens);

        vm.prank(caller); // back to regular msg.sender (bug?)
        jbToken().approve(address(terminal), balanceInTokens);
        vm.prank(caller); // back to regular msg.sender (bug?)
        terminal.pay(projectId, balanceInTokens, address(0), msg.sender, 0, false, "Forge test", new bytes(0)); // funding target met and 10 ETH are now in the overflow

        // verify: beneficiary should have a balance of JBTokens (divided by 2 -> reserved rate = 50%)
        uint256 _userTokenBalance = PRBMath.mulDiv(balanceInTokens, WEIGHT, 18) / 2;
        if (balanceInTokens != 0) assertEq(_tokenStore.balanceOf(msg.sender, projectId), _userTokenBalance);

        // verify: ETH balance in terminal should be up to date
        assertEq(jbPaymentTerminalStore().balanceOf(terminal, projectId), balanceInTokens);

        bool willRevert;

        // Discretionary use of overflow allowance by project owner (allowance = 5ETH)
        if (ALLOWANCE == 0) {
            vm.expectRevert(abi.encodeWithSignature("INADEQUATE_CONTROLLER_ALLOWANCE()"));
            willRevert = true;
        } else if (allowanceInTokens != 0 && (TARGET >= BALANCE || ALLOWANCE > (BALANCE - TARGET))) {
            // Too much to withdraw or no overflow ?
            vm.expectRevert(abi.encodeWithSignature("INADEQUATE_PAYMENT_TERMINAL_STORE_BALANCE()"));
            willRevert = true;
        }

        vm.prank(_projectOwner); // Prank only next call
        IJBPayoutRedemptionPaymentTerminal3_2(address(terminal)).useAllowanceOf(
            projectId,
            ALLOWANCE,
            1, // Currency
            address(0), //token (unused)
            0, // Min wei out
            payable(msg.sender), // Beneficiary
            "MEMO",
            ""
        );

        if (BALANCE > 1 && !willRevert) {
            uint256 expectedBalance = PRBMath.mulDiv(allowanceInTokens, jbLibraries().MAX_FEE(), jbLibraries().MAX_FEE() + terminal.fee());
            assertApproxEqAbs(jbToken().balanceOf(msg.sender), expectedBalance, 1);
        }

        // Distribute the funding target ETH -> no split then beneficiary is the project owner
        uint256 initBalance = jbToken().balanceOf(_projectOwner);

        if (targetInTokens != 0 && TARGET >= BALANCE) {
            vm.expectRevert(abi.encodeWithSignature("INADEQUATE_PAYMENT_TERMINAL_STORE_BALANCE()"));
        }

        if (TARGET == 0) {
            vm.expectRevert(abi.encodeWithSignature("DISTRIBUTION_AMOUNT_LIMIT_REACHED()"));
        }

        vm.prank(_projectOwner);
            IJBPayoutRedemptionPaymentTerminal3_2(address(terminal)).distributePayoutsOf(
                projectId,
                TARGET,
                1, // Currency
                address(0), //token (unused)
                0, // Min wei out
                "Foundry payment" // Memo
            );

        // Funds leaving the ecosystem -> fee taken
        if (TARGET <= BALANCE && TARGET > 1) {
            assertApproxEqAbs(
                jbToken().balanceOf(_projectOwner),
                initBalance + PRBMath.mulDiv(targetInTokens, jbLibraries().MAX_FEE(), jbLibraries().MAX_FEE() + terminal.fee()),
                2
            );
        }

        // redeem eth from the overflow by the token holder:
        uint256 senderBalance = _tokenStore.balanceOf(msg.sender, projectId);

        vm.prank(msg.sender);
        terminal.redeemTokensOf(
            msg.sender,
            projectId,
            senderBalance,
            address(0), //token (unused)
            0,
            payable(msg.sender),
            "gimme my token back",
            new bytes(0)
        );

        uint256 tokenBalanceAfter = _tokenStore.balanceOf(_beneficiary, projectId);
        uint256 processedFee = JBFees3_2.feeIn(tokenBalanceAfter * 2, jbLibraries().MAX_FEE());

        // verify: beneficiary should have a balance of 0 JBTokens
        assertEq(_tokenStore.balanceOf(msg.sender, projectId), 0);
    }
}
