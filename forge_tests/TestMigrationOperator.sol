// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "forge-std/Test.sol";

import /* {*} from */ "./helpers/TestBaseWorkflow.sol";

/**
 *  @title  Migration operator test
 *
 *  @notice This test suite is meant to test the migration operator contract, the controller and terminal
 *          tests are in their respective test suites.
 *
 *  @dev    One local and one fork test (only ran while using FOUNDRY_PROFILE=CI)
 */
contract TestMigrationOperator_Local is TestBaseWorkflow {
    uint256 projectId;

    JBController controller;
    JBFundingCycleData data;
    JBProjectMetadata projectMetadata;
    JBFundingCycleMetadata metadata;
    JBGroupedSplits[] groupedSplits;
    JBFundAccessConstraints[] fundAccessConstraints;
    IJBPaymentTerminal[] terminals;

    JBMigrationOperator migrationOperator;

    function setUp() public override {
        super.setUp();

        controller = jbController();
        
        // Set some mock fc data
        _initMetadata();

        projectId = jbController().launchProjectFor(
            multisig(),
            projectMetadata,
            data,
            metadata,
            block.timestamp,
            groupedSplits,
            fundAccessConstraints,
            terminals,
            ""
        );

        // Avoid the same block reconfiguration error
        vm.warp(block.timestamp + 1 days);

        migrationOperator = new JBMigrationOperator(jbDirectory());
    }

    /**
     *  @notice Migrate the project launched in the setup().
     *  @dev    The controller and terminal should migrate
     */
    function testMigrationOperator_shouldMigrate() public {
        // deploy the new controller and terminal
        JBController3_0_1 _newJbController = new JBController3_0_1(
            jbOperatorStore(),
            jbProjects(),
            jbDirectory(),
            jbFundingCycleStore(),
            jbTokenStore(),
            jbSplitsStore()
        );

        JBSingleTokenPaymentTerminalStore3_1 jbTerminalStore3_1 =
        new JBSingleTokenPaymentTerminalStore3_1(
            jbDirectory(),
            jbFundingCycleStore(),
            jbPrices()
        );

        JBETHPaymentTerminal3_1 jbEthTerminal3_1 = new JBETHPaymentTerminal3_1(
          jbETHPaymentTerminal().baseWeightCurrency(),
          jbOperatorStore(),
          jbProjects(),
          jbDirectory(),
          jbSplitsStore(),
          jbPrices(),
          address(jbTerminalStore3_1),
          Ownable(address(jbETHPaymentTerminal())).owner()
        );

        address _user = makeAddr("user");
        vm.deal(_user, 10 ether);

        JBETHPaymentTerminal _oldTerminal = jbETHPaymentTerminal();

        vm.prank(_user);
        _oldTerminal.pay{value: 10 ether}(
            projectId,
            10 ether,
            address(0),
            _user,
            /* _minReturnedTokens */
            0,
            /* _preferClaimedTokens */
            false,
            /* _memo */
            "Take my money!",
            /* _delegateMetadata */
            new bytes(0)
        );

        // Set the operator store authorization and reconfigure the funding cycle with correct flags
        _prepareAuthorizations();

        uint256 _balanceJbOldTerminal = jbPaymentTerminalStore().balanceOf(IJBSingleTokenPaymentTerminal(address(_oldTerminal)), projectId);
        uint256 _ETHBalanceJbOldTerminal = address(_oldTerminal).balance;

        // Migrate
        vm.prank(multisig());
        migrationOperator.migrate(
            projectId, IJBMigratable(_newJbController), jbEthTerminal3_1, _oldTerminal
        );

        // Check: the project must have the new controller
        assertEq(jbDirectory().controllerOf(projectId), address(_newJbController));

        // Check: the project must use the new terminal as primary terminal
        assertEq(
            address(jbDirectory().primaryTerminalOf(projectId, JBTokens.ETH)),
            address(jbEthTerminal3_1)
        );
        
        // Check: The balances and actual ETH must have migrated
        assertEq(
            jbTerminalStore3_1.balanceOf(IJBSingleTokenPaymentTerminal(address(jbEthTerminal3_1)), projectId),
            _balanceJbOldTerminal
        );
        assertEq(jbPaymentTerminalStore().balanceOf(IJBSingleTokenPaymentTerminal(address(_oldTerminal)), projectId), 0);

        assertEq(address(jbEthTerminal3_1).balance, _balanceJbOldTerminal);
        assertEq(address(_oldTerminal).balance, _ETHBalanceJbOldTerminal - _balanceJbOldTerminal);
    }

    /**
     *  @notice Even with correct authorizations, the migration should fail if the caller isn't the project owner
     */
    function testMigrationOperator_cannotMigrateIfNotProjectOwner(address _nonOwner) public {
        vm.assume(_nonOwner != multisig());

        JBController3_0_1 _newJbController = new JBController3_0_1(
          jbOperatorStore(),
          jbProjects(),
          jbDirectory(),
          jbFundingCycleStore(),
          jbTokenStore(),
          jbSplitsStore()
        );

        JBSingleTokenPaymentTerminalStore3_1 jbTerminalStore3_1 =
        new JBSingleTokenPaymentTerminalStore3_1(
        jbDirectory(),
        jbFundingCycleStore(),
        jbPrices()
      );

        JBETHPaymentTerminal3_1 jbEthTerminal3_1 = new JBETHPaymentTerminal3_1(
          jbETHPaymentTerminal().baseWeightCurrency(),
          jbOperatorStore(),
          jbProjects(),
          jbDirectory(),
          jbSplitsStore(),
          jbPrices(),
          address(jbTerminalStore3_1),
          Ownable(address(jbETHPaymentTerminal())).owner()
        );

        _prepareAuthorizations();

        // Check: revert if not project owner?
        vm.expectRevert(abi.encodeWithSelector(JBMigrationOperator.UNAUTHORIZED.selector));
        vm.prank(_nonOwner);
        migrationOperator.migrate(
            projectId, IJBMigratable(_newJbController), jbEthTerminal3_1, jbETHPaymentTerminal()
        );
    }

    ////////////////////////////////////////////////////////////////////
    //                            Helpers                             //
    ////////////////////////////////////////////////////////////////////

    /**
     * @notice  Set the correct premigration authorizations in the operator store and fc metadata
     */
    function _prepareAuthorizations() internal {
        // Authorize the migrator contract to migrate by delegation
        uint256[] memory _permissionIndexes = new uint256[](3);
        _permissionIndexes[0] = JBOperations.MIGRATE_CONTROLLER;
        _permissionIndexes[1] = JBOperations.MIGRATE_TERMINAL;
        _permissionIndexes[2] = JBOperations.SET_TERMINALS;

        vm.prank(multisig());
        jbOperatorStore().setOperator(
            JBOperatorData({
                operator: address(migrationOperator),
                domain: projectId,
                permissionIndexes: _permissionIndexes
            })
        );

        // Reconfigure the funding cycle to allow migration and set the new terminal as a project terminal
        metadata.allowControllerMigration = true;
        metadata.allowTerminalMigration = true;
        metadata.global.allowSetTerminals = true;

        vm.prank(multisig());
        jbController().reconfigureFundingCyclesOf(
            projectId, data, metadata, 0, groupedSplits, fundAccessConstraints, ""
        );
        // warp to the next funding cycle
        JBFundingCycle memory fundingCycle = jbFundingCycleStore().currentOf(projectId);
        vm.warp(fundingCycle.start + (fundingCycle.duration) + 1);
    }

    /**
     * @notice  Initialize the funding cycle and fund access constraints data to some generic values
     */
    function _initMetadata() internal {
        projectMetadata = JBProjectMetadata({content: "myIPFSHash", domain: 1});

        data = JBFundingCycleData({
            duration: 14,
            weight: 10 ether,
            discountRate: 0,
            ballot: IJBFundingCycleBallot(address(0))
        });

        metadata = JBFundingCycleMetadata({
            global: JBGlobalFundingCycleMetadata({
                allowSetTerminals: false,
                allowSetController: false,
                pauseTransfers: false
            }),
            reservedRate: 0, // Reserved rate is set in tests, when needed
            redemptionRate: 10_000, //100%
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

        terminals.push(jbETHPaymentTerminal());

        fundAccessConstraints.push(
            JBFundAccessConstraints({
                terminal: jbETHPaymentTerminal(),
                token: JBTokens.ETH,
                distributionLimit: 10 ether,
                overflowAllowance: 5 ether,
                distributionLimitCurrency: 1, // Currency = ETH
                overflowAllowanceCurrency: 1
            })
        );
    }
}

contract TestMigrationOperator_Fork is Test {
    using JBFundingCycleMetadataResolver for JBFundingCycle;

    // Contracts needed
    IJBController oldJbController;
    IJBMigratable newJbController;
    IJBDirectory jbDirectory;
    IJBFundingCycleStore jbFundingCycleStore;
    IJBOperatorStore jbOperatorStore;
    IJBPayoutRedemptionPaymentTerminal jbEthTerminal;
    IJBPayoutRedemptionPaymentTerminal3_1 jbEthPaymentTerminal3_1;
    IJBProjects jbProjects;
    IJBSingleTokenPaymentTerminalStore jbTerminalStore;
    IJBSplitsStore jbSplitsStore;
    IJBTokenStore jbTokenStore;

    JBMigrationOperator migrationOperator;

    // Structure needed
    JBProjectMetadata projectMetadata;
    JBFundingCycleData data;
    JBFundingCycleMetadata metadata;
    JBFundAccessConstraints[] fundAccessConstraints;
    IJBPaymentTerminal[] terminals;
    JBGroupedSplits[] groupedSplits;

    function setUp() public {
        vm.createSelectFork("https://rpc.ankr.com/eth", 16_677_461);

        // Collect the mainnet deployment addresses
        jbEthTerminal = IJBPayoutRedemptionPaymentTerminal(
            stdJson.readAddress(
                vm.readFile("deployments/mainnet/JBETHPaymentTerminal.json"), ".address"
            )
        );
        vm.label(address(jbEthTerminal), "jbEthTerminal");

        jbEthPaymentTerminal3_1 = IJBPayoutRedemptionPaymentTerminal3_1(
            stdJson.readAddress(
                vm.readFile("deployments/mainnet/JBETHPaymentTerminal3_1.json"), ".address"
            )
        );
        vm.label(address(jbEthPaymentTerminal3_1), "jbEthPaymentTerminal3_1");

        oldJbController = IJBController(
            stdJson.readAddress(vm.readFile("deployments/mainnet/JBController.json"), ".address")
        );

        newJbController = IJBMigratable(
            stdJson.readAddress(vm.readFile("deployments/mainnet/JBController3_1.json"), ".address")
        );
        vm.label(address(newJbController), "newJbController");

        jbOperatorStore = IJBOperatorStore(
            stdJson.readAddress(vm.readFile("deployments/mainnet/JBOperatorStore.json"), ".address")
        );
        vm.label(address(jbOperatorStore), "jbOperatorStore");

        jbProjects = oldJbController.projects();
        jbDirectory = oldJbController.directory();
        jbFundingCycleStore = oldJbController.fundingCycleStore();
        jbTokenStore = oldJbController.tokenStore();
        jbSplitsStore = oldJbController.splitsStore();
        jbTerminalStore = IJBSingleTokenPaymentTerminalStore(jbEthTerminal.store());

        // Set some mock fc data
        _initMetadata();

        migrationOperator = new JBMigrationOperator(jbDirectory);
    }

    /**
     * @notice  Test if a project can migrate its controller and terminals using the migrator
     * @dev     The project must have a controller and the correct permission sets in fc and operator store
     *          JuiceboxDAO (id 1) is already using Controller 3.0.1 at that block height
     */
    function testMigrationOperator_migrateAnyExistingProject(uint256 _projectId) public {
        // Migrate only existing projects
        _projectId = bound(_projectId, 1, jbProjects.count());

        // Migrate only project which are not archived/have a controller
        vm.assume(jbDirectory.controllerOf(_projectId) != address(0));

        // JuiceboxDAO is already using Controller 3.0.1 at that block height
        if (_projectId == 1) oldJbController = IJBController(jbDirectory.controllerOf(1));

        _prepareAuthorizations(_projectId);

        vm.prank(jbProjects.ownerOf(_projectId));
        migrationOperator.migrate(
            _projectId, newJbController, jbEthPaymentTerminal3_1, jbEthTerminal
        );

        // Check: the project must have the new controller
        assertEq(jbDirectory.controllerOf(_projectId), address(newJbController));

        // Check: the project must use the new terminal as primary terminal
        assertEq(
            address(jbDirectory.primaryTerminalOf(_projectId, JBTokens.ETH)),
            address(jbEthPaymentTerminal3_1)
        );
    }

    ////////////////////////////////////////////////////////////////////
    //                            Helpers                             //
    ////////////////////////////////////////////////////////////////////

    /**
     * @notice  Set the correct premigration authorizations in the operator store and fc metadata
     */
    function _prepareAuthorizations(uint256 _projectId) internal {
        address _owner = jbProjects.ownerOf(_projectId);

        // Set the correct permissions in the operator store
        uint256[] memory _permissionIndexes = new uint256[](3);
        _permissionIndexes[0] = JBOperations.MIGRATE_CONTROLLER;
        _permissionIndexes[1] = JBOperations.MIGRATE_TERMINAL;
        _permissionIndexes[2] = JBOperations.SET_TERMINALS;

        vm.prank(_owner);
        jbOperatorStore.setOperator(
            JBOperatorData({
                operator: address(migrationOperator),
                domain: _projectId,
                permissionIndexes: _permissionIndexes
            })
        );

        // Set the correct permissions in the funding cycle metadata
        metadata.allowControllerMigration = true;
        metadata.allowTerminalMigration = true;
        metadata.global.allowSetTerminals = true;

        // Reconfigure the project's fc
        vm.prank(_owner);
        oldJbController.reconfigureFundingCyclesOf(
            _projectId, data, metadata, 0, groupedSplits, fundAccessConstraints, ""
        );

        // warp to the next funding cycle
        JBFundingCycle memory fundingCycle = jbFundingCycleStore.currentOf(_projectId);

        vm.warp(
            fundingCycle.duration == 0
                ? fundingCycle.ballot != IJBFundingCycleBallot(address(0))
                    ? block.timestamp + fundingCycle.ballot.duration() + 1
                    : block.timestamp + 1
                : fundingCycle.start + fundingCycle.duration * 2 // skip 2 fc to easily avoid ballot
        );
    }

    /**
     * @notice  Initialize the funding cycle and fund access constraints data to some generic values
     */
    function _initMetadata() internal {
        projectMetadata = JBProjectMetadata({content: "myIPFSHash", domain: 1});

        data = JBFundingCycleData({
            duration: 14,
            weight: 10 ether,
            discountRate: 0,
            ballot: IJBFundingCycleBallot(address(0))
        });

        metadata = JBFundingCycleMetadata({
            global: JBGlobalFundingCycleMetadata({
                allowSetTerminals: false,
                allowSetController: false,
                pauseTransfers: false
            }),
            reservedRate: 0,
            redemptionRate: 10_000,
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

        terminals.push(jbEthTerminal);

        fundAccessConstraints.push(
            JBFundAccessConstraints({
                terminal: jbEthTerminal,
                token: JBTokens.ETH,
                distributionLimit: 10 ether,
                overflowAllowance: 5 ether,
                distributionLimitCurrency: 1,
                overflowAllowanceCurrency: 1
            })
        );
    }
}
