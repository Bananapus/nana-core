// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import /* {*} from */ "./helpers/TestBaseWorkflow.sol";
import {MockMaliciousAllocator, GasGussler} from "./mock/MockMaliciousAllocator.sol";
import {MockMaliciousTerminal} from "./mock/MockMaliciousTerminal.sol";

contract TestERC20Terminal_Local is TestBaseWorkflow {
    event PayoutReverted(uint256 indexed projectId, JBSplit split, uint256 amount, bytes reason, address caller);

    event FeeReverted(
        uint256 indexed projectId, uint256 indexed feeProjectId, uint256 amount, bytes reason, address caller
    );

    IJBSplitAllocator _allocator;
    JBController controller;
    JBProjectMetadata _projectMetadata;
    JBFundingCycleData _data;
    JBFundingCycleMetadata _metadata;
    JBGroupedSplits[] _groupedSplits;
    JBFundAccessConstraints[] _fundAccessConstraints;
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

        _metadata = JBFundingCycleMetadata({
            global: JBGlobalFundingCycleMetadata({
                allowSetTerminals: false,
                allowSetController: false,
                pauseTransfers: false
            }),
            reservedRate: 5000, //50%
            redemptionRate: 5000, //50%
            ballotRedemptionRate: 0,
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
    }

    function testAllowanceERC20() public {
        JBERC20PaymentTerminal terminal = jbERC20PaymentTerminal();

        _fundAccessConstraints.push(
            JBFundAccessConstraints({
                terminal: terminal,
                token: address(jbToken()),
                distributionLimit: 10 * 10 ** 18,
                overflowAllowance: 5 * 10 ** 18,
                distributionLimitCurrency: jbLibraries().ETH(),
                overflowAllowanceCurrency: jbLibraries().ETH()
            })
        );

        uint256 projectId = controller.launchProjectFor(
            _projectOwner,
            _projectMetadata,
            _data,
            _metadata,
            block.timestamp,
            _groupedSplits,
            _fundAccessConstraints,
            _terminals,
            ""
        );

        address caller = msg.sender;
        vm.label(caller, "caller");
        vm.prank(_projectOwner);
        jbToken().transfer(caller, 20 * 10 ** 18);

        vm.prank(caller); // back to regular msg.sender (bug?)
        jbToken().approve(address(terminal), 20 * 10 ** 18);
        vm.prank(caller); // back to regular msg.sender (bug?)
        terminal.pay(projectId, 20 * 10 ** 18, address(0), msg.sender, 0, false, "Forge test", new bytes(0)); // funding target met and 10 token are now in the overflow

        // verify: beneficiary should have a balance of JBTokens (divided by 2 -> reserved rate = 50%)
        uint256 _userTokenBalance = PRBMath.mulDiv(20, WEIGHT, 2); // 18dec is in WEIGHT
        assertEq(_tokenStore.balanceOf(msg.sender, projectId), _userTokenBalance);

        // verify: balance in terminal should be up to date
        assertEq(jbPaymentTerminalStore().balanceOf(terminal, projectId), 20 * 10 ** 18);

        // Discretionary use of overflow allowance by project owner (allowance = 5ETH)
        vm.prank(_projectOwner); // Prank only next call
        if (isUsingJbController3_0()) {
            terminal.useAllowanceOf(
                projectId,
                5 * 10 ** 18,
                1, // Currency
                address(0), //token (unused)
                0, // Min wei out
                payable(msg.sender), // Beneficiary
                "MEMO"
            );
        } else {
            IJBPayoutRedemptionPaymentTerminal3_1(address(terminal)).useAllowanceOf(
                projectId,
                5 * 10 ** 18,
                1, // Currency
                address(0), //token (unused)
                0, // Min wei out
                payable(msg.sender), // Beneficiary
                "MEMO",
                bytes("")
            );
        }

        assertEq(
            jbToken().balanceOf(msg.sender),
            PRBMath.mulDiv(5 * 10 ** 18, jbLibraries().MAX_FEE(), jbLibraries().MAX_FEE() + terminal.fee())
        );

        // Distribute the funding target ETH -> splits[] is empty -> everything in left-over, to project owner
        uint256 initBalance = jbToken().balanceOf(_projectOwner);
        vm.prank(_projectOwner);

        if (isUsingJbController3_0()) {
            terminal.distributePayoutsOf(
                projectId,
                10 * 10 ** 18,
                1, // Currency
                address(0), //token (unused)
                0, // Min wei out
                "Foundry payment" // Memo
            );
        } else {
            IJBPayoutRedemptionPaymentTerminal3_1(address(terminal)).distributePayoutsOf(
                projectId,
                10 * 10 ** 18,
                1, // Currency
                address(0), //token (unused)
                0, // Min wei out
                "" // metadata
            );
        }

        // Funds leaving the ecosystem -> fee taken
        assertEq(
            jbToken().balanceOf(_projectOwner),
            initBalance + (10 * 10 ** 18 * jbLibraries().MAX_FEE()) / (terminal.fee() + jbLibraries().MAX_FEE())
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
        JBERC20PaymentTerminal terminal = jbERC20PaymentTerminal();

        _fundAccessConstraints.push(
            JBFundAccessConstraints({
                terminal: terminal,
                token: address(jbToken()),
                distributionLimit: 10 * 10 ** 18,
                overflowAllowance: 5 * 10 ** 18,
                distributionLimitCurrency: jbLibraries().ETH(),
                overflowAllowanceCurrency: jbLibraries().ETH()
            })
        );

        uint256 projectId = controller.launchProjectFor(
            _projectOwner,
            _projectMetadata,
            _data,
            _metadata,
            block.timestamp,
            _allocationSplits,
            _fundAccessConstraints,
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
            IJBPayoutRedemptionPaymentTerminal3_1(address(terminal)).distributePayoutsOf(
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
        JBERC20PaymentTerminal terminal = jbERC20PaymentTerminal();

        _fundAccessConstraints.push(
            JBFundAccessConstraints({
                terminal: terminal,
                token: address(jbToken()),
                distributionLimit: 10 * 10 ** 18,
                overflowAllowance: 5 * 10 ** 18,
                distributionLimitCurrency: jbLibraries().ETH(),
                overflowAllowanceCurrency: jbLibraries().ETH()
            })
        );

        uint256 projectId = controller.launchProjectFor(
            _projectOwner,
            _projectMetadata,
            _data,
            _metadata,
            block.timestamp,
            _allocationSplits,
            _fundAccessConstraints,
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
            IJBPayoutRedemptionPaymentTerminal3_1(address(terminal)).distributePayoutsOf(
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
        JBERC20PaymentTerminal terminal = jbERC20PaymentTerminal();

        _fundAccessConstraints.push(
            JBFundAccessConstraints({
                terminal: terminal,
                token: address(jbToken()),
                distributionLimit: 10 * 10 ** 18,
                overflowAllowance: 5 * 10 ** 18,
                distributionLimitCurrency: jbLibraries().ETH(),
                overflowAllowanceCurrency: jbLibraries().ETH()
            })
        );

        uint256 projectId = controller.launchProjectFor(
            _projectOwner,
            _projectMetadata,
            _data,
            _metadata,
            block.timestamp,
            _allocationSplits,
            _fundAccessConstraints,
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

            vm.expectEmit(true, true, true, true);
            emit PayoutReverted(projectId, _splits[0], 10 * 10 ** 18, abi.encode("IERC165 fail"), address(this));

            IJBPayoutRedemptionPaymentTerminal3_1(address(terminal)).distributePayoutsOf(
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

    function testAllocation_should_emit_event_with_correct_reason_when_reverting(uint256 _revertReason) public {
        // Test only for v3.1
        if (!isUsingJbController3_0()) {
            _revertReason = bound(_revertReason, 0, 3);
            address _user = makeAddr("user");

            _allocator = new MockMaliciousAllocator();

            JBGroupedSplits[] memory _allocationSplits = new JBGroupedSplits[](1); // Default empty
            JBERC20PaymentTerminal terminal = jbERC20PaymentTerminal();

            _fundAccessConstraints.push(
                JBFundAccessConstraints({
                    terminal: terminal,
                    token: address(jbToken()),
                    distributionLimit: 10 * 10 ** 18,
                    overflowAllowance: 5 * 10 ** 18,
                    distributionLimitCurrency: jbLibraries().ETH(),
                    overflowAllowanceCurrency: jbLibraries().ETH()
                })
            );

            uint256 projectId = controller.launchProjectFor(
                _projectOwner,
                _projectMetadata,
                _data,
                _metadata,
                block.timestamp,
                _allocationSplits,
                _fundAccessConstraints,
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

            // fund user
            vm.prank(_projectOwner);
            jbToken().transfer(_user, 20 * 10 ** 18);

            // pay project
            vm.prank(_user);
            jbToken().approve(address(terminal), 20 * 10 ** 18);

            vm.prank(_user);
            terminal.pay(projectId, 20 * 10 ** 18, address(0), msg.sender, 0, false, "Forge test", new bytes(0)); // funding target met and 10 token are now in the overflow

            MockMaliciousAllocator(address(_allocator)).setRevertMode(_revertReason);
            bytes memory _reason;

            if (_revertReason == 1) {
                _reason = abi.encodeWithSignature("NopeNotGonnaDoIt()");
            } else if (_revertReason == 2) {
                _reason = abi.encodeWithSignature("Error(string)", "thanks no thanks");
            } else if (_revertReason == 3) {
                bytes4 _panickSelector = bytes4(keccak256("Panic(uint256)"));
                _reason = abi.encodePacked(_panickSelector, uint256(0x11)); // eg underflow, panick code 0x11
            }

            vm.expectEmit(true, true, true, true);
            emit PayoutReverted(projectId, _splits[0], 1 * 10 ** 18, _reason, address(this));

            IJBPayoutRedemptionPaymentTerminal3_1(address(terminal)).distributePayoutsOf(
                projectId,
                1 * 10 ** 18,
                1, // Currency
                address(0), //token (unused)
                0, // Min wei out
                "allocation" // metadata
            );
        }
    }

    function testFeeDistribution_to_malicious_terminal(uint256 _revertReason) public {
        // Test only for v3.1
        if (!isUsingJbController3_0()) {
            _revertReason = bound(_revertReason, 0, 3);

            address _user = makeAddr("user");
            address _beneficiary = makeAddr("beneficiary");

            MockMaliciousTerminal _badTerminal = new MockMaliciousTerminal(
              jbToken(),
              jbLibraries().ETH(), // currency
              jbLibraries().ETH(), // base weight currency
              1, // JBSplitsGroupe
              jbOperatorStore(),
              jbProjects(),
              jbDirectory(),
              jbSplitsStore(),
              jbPrices(),
              jbPaymentTerminalStore(),
               multisig()
            );

            JBFundAccessConstraints[] memory _feeBeneficiaryProjectFundAccessConstraints =
                new JBFundAccessConstraints[](1);
            IJBPaymentTerminal[] memory _feeBeneficiaryProjectTerminals = new IJBPaymentTerminal[](1);
            JBGroupedSplits[] memory _allocationSplits = new JBGroupedSplits[](1); // Default empty
            JBERC20PaymentTerminal terminal = jbERC20PaymentTerminal();

            _fundAccessConstraints.push(
                JBFundAccessConstraints({
                    terminal: terminal,
                    token: address(jbToken()),
                    distributionLimit: 10 * 10 ** 18,
                    overflowAllowance: 5 * 10 ** 18,
                    distributionLimitCurrency: jbLibraries().ETH(),
                    overflowAllowanceCurrency: jbLibraries().ETH()
                })
            );

            _feeBeneficiaryProjectFundAccessConstraints[0] = JBFundAccessConstraints({
                terminal: _badTerminal,
                token: address(jbToken()),
                distributionLimit: 10 * 10 ** 18,
                overflowAllowance: 5 * 10 ** 18,
                distributionLimitCurrency: jbLibraries().ETH(),
                overflowAllowanceCurrency: jbLibraries().ETH()
            });
            _feeBeneficiaryProjectTerminals[0] = IJBPaymentTerminal(address(_badTerminal));

            uint256 feeBeneficiaryProjectId = controller.launchProjectFor(
                _projectOwner,
                _projectMetadata,
                _data,
                _metadata,
                block.timestamp,
                _allocationSplits,
                _feeBeneficiaryProjectFundAccessConstraints,
                _feeBeneficiaryProjectTerminals,
                ""
            );

            uint256 distributionProjectId = controller.launchProjectFor(
                _projectOwner,
                _projectMetadata,
                _data,
                _metadata,
                block.timestamp,
                _groupedSplits,
                _fundAccessConstraints,
                _terminals,
                ""
            );

            // setting splits
            JBSplit[] memory _splits = new JBSplit[](1);
            _splits[0] = JBSplit({
                preferClaimed: false,
                preferAddToBalance: false,
                projectId: 0,
                beneficiary: payable(_beneficiary),
                lockedUntil: 0,
                allocator: IJBSplitAllocator(address(0)),
                percent: JBConstants.SPLITS_TOTAL_PERCENT
            });

            _allocationSplits[0] = JBGroupedSplits({group: 1, splits: _splits});

            (JBFundingCycle memory _currentFundingCycle,) = controller.currentFundingCycleOf(distributionProjectId);

            vm.prank(_projectOwner);
            jbSplitsStore().set(distributionProjectId, _currentFundingCycle.configuration, _allocationSplits);

            // fund user
            vm.prank(_projectOwner);
            jbToken().transfer(_user, 20 * 10 ** 18);

            // pay project
            vm.prank(_user);
            jbToken().approve(address(terminal), 20 * 10 ** 18);
            vm.prank(_user);
            terminal.pay(
                distributionProjectId, 20 * 10 ** 18, address(0), msg.sender, 0, false, "Forge test", new bytes(0)
            ); // funding target met and 10 token are now in the overflow

            uint256 _distributionAmount = 10 * 10 ** 18;
            // calculating fee
            uint256 _feeCollected = _distributionAmount
                - (PRBMath.mulDiv(_distributionAmount, JBConstants.MAX_FEE, terminal.fee() + JBConstants.MAX_FEE));

            // fee distribution
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
            emit FeeReverted(distributionProjectId, feeBeneficiaryProjectId, _feeCollected, _reason, _projectOwner);

            vm.prank(_projectOwner);
            IJBPayoutRedemptionPaymentTerminal3_1(address(terminal)).distributePayoutsOf(
                distributionProjectId,
                _distributionAmount,
                1, // Currency
                address(0), //token (unused)
                0, // Min wei out
                "distribution" // metadata
            );
        }
    }

    function testDistribution_to_malicious_terminal_by_adding_balance(uint256 _revertReason) public {
        _revertReason = bound(_revertReason, 0, 3);
        address _user = makeAddr("user");

        MockMaliciousTerminal _badTerminal = new MockMaliciousTerminal(
            jbToken(),
            jbLibraries().ETH(), // currency
            jbLibraries().ETH(), // base weight currency
            1, // JBSplitsGroupe
            jbOperatorStore(),
            jbProjects(),
            jbDirectory(),
            jbSplitsStore(),
            jbPrices(),
            jbPaymentTerminalStore(),
            multisig()
        );
        JBFundAccessConstraints[] memory _splitProjectFundAccessConstraints = new JBFundAccessConstraints[](1);
        IJBPaymentTerminal[] memory _splitProjectTerminals = new IJBPaymentTerminal[](1);
        JBGroupedSplits[] memory _allocationSplits = new JBGroupedSplits[](1); // Default empty
        JBERC20PaymentTerminal terminal = jbERC20PaymentTerminal();

        _fundAccessConstraints.push(
            JBFundAccessConstraints({
                terminal: terminal,
                token: address(jbToken()),
                distributionLimit: 10 * 10 ** 18,
                overflowAllowance: 5 * 10 ** 18,
                distributionLimitCurrency: jbLibraries().ETH(),
                overflowAllowanceCurrency: jbLibraries().ETH()
            })
        );

        _splitProjectFundAccessConstraints[0] = JBFundAccessConstraints({
            terminal: _badTerminal,
            token: address(jbToken()),
            distributionLimit: 10 * 10 ** 18,
            overflowAllowance: 5 * 10 ** 18,
            distributionLimitCurrency: jbLibraries().ETH(),
            overflowAllowanceCurrency: jbLibraries().ETH()
        });
        _splitProjectTerminals[0] = IJBPaymentTerminal(address(_badTerminal));

        uint256 projectId = controller.launchProjectFor(
            _projectOwner,
            _projectMetadata,
            _data,
            _metadata,
            block.timestamp,
            _allocationSplits,
            _fundAccessConstraints,
            _terminals,
            ""
        );

        //project to allocato funds
        uint256 allocationProjectId = controller.launchProjectFor(
            _projectOwner,
            _projectMetadata,
            _data,
            _metadata,
            block.timestamp,
            _groupedSplits,
            _splitProjectFundAccessConstraints,
            _splitProjectTerminals,
            ""
        );

        // setting splits
        JBSplit[] memory _splits = new JBSplit[](1);
        _splits[0] = JBSplit({
            preferClaimed: false,
            preferAddToBalance: true,
            projectId: allocationProjectId,
            beneficiary: payable(_user),
            lockedUntil: 0,
            allocator: IJBSplitAllocator(address(0)),
            percent: JBConstants.SPLITS_TOTAL_PERCENT
        });

        _allocationSplits[0] = JBGroupedSplits({group: 1, splits: _splits});

        (JBFundingCycle memory _currentFundingCycle,) = controller.currentFundingCycleOf(projectId);

        vm.prank(_projectOwner);
        jbSplitsStore().set(projectId, _currentFundingCycle.configuration, _allocationSplits);

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
            emit PayoutReverted(projectId, _splits[0], 10 * 10 ** 18, _reason, address(this));

            IJBPayoutRedemptionPaymentTerminal3_1(address(terminal)).distributePayoutsOf(
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

        MockMaliciousTerminal _badTerminal = new MockMaliciousTerminal(
            jbToken(),
            jbLibraries().ETH(), // currency
            jbLibraries().ETH(), // base weight currency
            1, // JBSplitsGroupe
            jbOperatorStore(),
            jbProjects(),
            jbDirectory(),
            jbSplitsStore(),
            jbPrices(),
            jbPaymentTerminalStore(),
            multisig()
        );
        JBFundAccessConstraints[] memory _splitProjectFundAccessConstraints = new JBFundAccessConstraints[](1);
        IJBPaymentTerminal[] memory _splitProjectTerminals = new IJBPaymentTerminal[](1);
        JBGroupedSplits[] memory _allocationSplits = new JBGroupedSplits[](1); // Default empty
        JBERC20PaymentTerminal terminal = jbERC20PaymentTerminal();

        _fundAccessConstraints.push(
            JBFundAccessConstraints({
                terminal: terminal,
                token: address(jbToken()),
                distributionLimit: 10 * 10 ** 18,
                overflowAllowance: 5 * 10 ** 18,
                distributionLimitCurrency: jbLibraries().ETH(),
                overflowAllowanceCurrency: jbLibraries().ETH()
            })
        );

        _splitProjectFundAccessConstraints[0] = JBFundAccessConstraints({
            terminal: _badTerminal,
            token: address(jbToken()),
            distributionLimit: 10 * 10 ** 18,
            overflowAllowance: 5 * 10 ** 18,
            distributionLimitCurrency: jbLibraries().ETH(),
            overflowAllowanceCurrency: jbLibraries().ETH()
        });
        _splitProjectTerminals[0] = IJBPaymentTerminal(address(_badTerminal));

        uint256 projectId = controller.launchProjectFor(
            _projectOwner,
            _projectMetadata,
            _data,
            _metadata,
            block.timestamp,
            _allocationSplits,
            _fundAccessConstraints,
            _terminals,
            ""
        );

        //project to allocato funds
        uint256 allocationProjectId = controller.launchProjectFor(
            _projectOwner,
            _projectMetadata,
            _data,
            _metadata,
            block.timestamp,
            _groupedSplits,
            _splitProjectFundAccessConstraints,
            _splitProjectTerminals,
            ""
        );

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

        vm.prank(_projectOwner);
        jbSplitsStore().set(projectId, _currentFundingCycle.configuration, _allocationSplits);

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
            emit PayoutReverted(projectId, _splits[0], 10 * 10 ** 18, _reason, address(this));

            IJBPayoutRedemptionPaymentTerminal3_1(address(terminal)).distributePayoutsOf(
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
        BALANCE = bound(BALANCE, 0, jbToken().totalSupply());

        JBERC20PaymentTerminal terminal = jbERC20PaymentTerminal();

        _fundAccessConstraints.push(
            JBFundAccessConstraints({
                terminal: terminal,
                token: address(jbToken()),
                distributionLimit: TARGET,
                overflowAllowance: ALLOWANCE,
                distributionLimitCurrency: jbLibraries().ETH(),
                overflowAllowanceCurrency: jbLibraries().ETH()
            })
        );

        uint256 projectId = controller.launchProjectFor(
            _projectOwner,
            _projectMetadata,
            _data,
            _metadata,
            block.timestamp,
            _groupedSplits,
            _fundAccessConstraints,
            _terminals,
            ""
        );

        address caller = msg.sender;
        vm.label(caller, "caller");
        vm.prank(_projectOwner);
        jbToken().transfer(caller, BALANCE);

        vm.prank(caller); // back to regular msg.sender (bug?)
        jbToken().approve(address(terminal), BALANCE);
        vm.prank(caller); // back to regular msg.sender (bug?)
        terminal.pay(projectId, BALANCE, address(0), msg.sender, 0, false, "Forge test", new bytes(0)); // funding target met and 10 ETH are now in the overflow

        // verify: beneficiary should have a balance of JBTokens (divided by 2 -> reserved rate = 50%)
        uint256 _userTokenBalance = PRBMath.mulDiv(BALANCE, (WEIGHT / 10 ** 18), 2);
        if (BALANCE != 0) assertEq(_tokenStore.balanceOf(msg.sender, projectId), _userTokenBalance);

        // verify: ETH balance in terminal should be up to date
        assertEq(jbPaymentTerminalStore().balanceOf(terminal, projectId), BALANCE);

        bool willRevert;

        // Discretionary use of overflow allowance by project owner (allowance = 5ETH)
        if (ALLOWANCE == 0) {
            vm.expectRevert(abi.encodeWithSignature("INADEQUATE_CONTROLLER_ALLOWANCE()"));
            willRevert = true;
        } else if (TARGET >= BALANCE || ALLOWANCE > (BALANCE - TARGET)) {
            // Too much to withdraw or no overflow ?
            vm.expectRevert(abi.encodeWithSignature("INADEQUATE_PAYMENT_TERMINAL_STORE_BALANCE()"));
            willRevert = true;
        }

        vm.prank(_projectOwner); // Prank only next call
        if (isUsingJbController3_0()) {
            terminal.useAllowanceOf(
                projectId,
                ALLOWANCE,
                1, // Currency
                address(0), //token (unused)
                0, // Min wei out
                payable(msg.sender), // Beneficiary
                "MEMO"
            );
        } else {
            IJBPayoutRedemptionPaymentTerminal3_1(address(terminal)).useAllowanceOf(
                projectId,
                ALLOWANCE,
                1, // Currency
                address(0), //token (unused)
                0, // Min wei out
                payable(msg.sender), // Beneficiary
                "MEMO",
                ""
            );
        }

        if (BALANCE > 1 && !willRevert) {
            assertEq(
                jbToken().balanceOf(msg.sender),
                PRBMath.mulDiv(ALLOWANCE, jbLibraries().MAX_FEE(), jbLibraries().MAX_FEE() + terminal.fee())
            );
        }

        // Distribute the funding target ETH -> no split then beneficiary is the project owner
        uint256 initBalance = jbToken().balanceOf(_projectOwner);

        if (TARGET > BALANCE) {
            vm.expectRevert(abi.encodeWithSignature("INADEQUATE_PAYMENT_TERMINAL_STORE_BALANCE()"));
        }

        if (TARGET == 0) {
            vm.expectRevert(abi.encodeWithSignature("DISTRIBUTION_AMOUNT_LIMIT_REACHED()"));
        }

        vm.prank(_projectOwner);
        if (isUsingJbController3_0()) {
            terminal.distributePayoutsOf(
                projectId,
                TARGET,
                1, // Currency
                address(0), //token (unused)
                0, // Min wei out
                "Foundry payment" // Memo
            );
        } else {
            IJBPayoutRedemptionPaymentTerminal3_1(address(terminal)).distributePayoutsOf(
                projectId,
                TARGET,
                1, // Currency
                address(0), //token (unused)
                0, // Min wei out
                "Foundry payment" // Memo
            );
        }
        // Funds leaving the ecosystem -> fee taken
        if (TARGET <= BALANCE && TARGET > 1) {
            assertEq(
                jbToken().balanceOf(_projectOwner),
                initBalance + PRBMath.mulDiv(TARGET, jbLibraries().MAX_FEE(), terminal.fee() + jbLibraries().MAX_FEE())
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

        // verify: beneficiary should have a balance of 0 JBTokens
        assertEq(_tokenStore.balanceOf(msg.sender, projectId), 0);
    }
}
