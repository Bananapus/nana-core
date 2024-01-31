// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBControllerSetup} from "./JBControllerSetup.sol";

contract TestLaunchProjectFor_Local is JBControllerSetup {
    string _metadata = "JUICAY_DATA";
    string _memo = "JUICAY_MEMO";

    function setUp() public {
        super.controllerSetup();
    }

    modifier whenCalledDefault() {
        // we must mock calls to Projects, Directory, Rulesets, possibly Splits, and possibly a second call to directory

        bytes memory projectsCall = abi.encodeCall(IJBProjects.createFor, (address(this)));
        bytes memory projectsReturn = abi.encode(1);
        mockExpect(address(projects), projectsCall, projectsReturn);

        bytes memory setControllerCall =
            abi.encodeCall(IJBDirectory.setControllerOf, (1, IERC165(address(_controller))));
        bytes memory setControllerReturn = abi.encode();
        mockExpect(address(directory), setControllerCall, setControllerReturn);
        _;
    }

    function test_GivenMetadataIsProvided() external whenCalledDefault {
        // it will set metadata

        JBRulesetConfig[] memory _rulesets = new JBRulesetConfig[](0);
        JBTerminalConfig[] memory _terminals = new JBTerminalConfig[](0);

        vm.expectEmit();
        emit IJBController.LaunchProject(0, 1, _metadata, "", address(this));

        _controller.launchProjectFor(address(this), _metadata, _rulesets, _terminals, "");
    }

    /* function test_GivenValidRulesetsAreProvided() external whenCalled {
        // it will set rulesets
    } */

    function test_GivenRulesetHasInvalidReservedRate() external whenCalledDefault {
        // it will revert INVALID_RESERVED_RATE()

        JBRulesetMetadata memory _rulesMetadata = JBRulesetMetadata({
            reservedRate: JBConstants.MAX_RESERVED_RATE + 1, // Too damn high
            redemptionRate: JBConstants.MAX_REDEMPTION_RATE / 2, //50%
            baseCurrency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
            pausePay: false,
            pauseCreditTransfers: false,
            allowOwnerMinting: false,
            allowTerminalMigration: false,
            allowSetTerminals: false,
            allowControllerMigration: false,
            allowSetController: false,
            holdFees: false,
            useTotalSurplusForRedemptions: true,
            useDataHookForPay: false,
            useDataHookForRedeem: false,
            dataHook: address(0),
            metadata: 0
        });

        JBFundAccessLimitGroup[] memory _fundAccessLimitGroup = new JBFundAccessLimitGroup[](0);
        JBTerminalConfig[] memory _terminals = new JBTerminalConfig[](0);

        // Package up the ruleset configuration.
        JBRulesetConfig[] memory _rulesetConfigurations = new JBRulesetConfig[](1);
        _rulesetConfigurations[0].mustStartAtOrAfter = 0;
        _rulesetConfigurations[0].duration = 0;
        _rulesetConfigurations[0].weight = 1e18;
        _rulesetConfigurations[0].decayRate = 0;
        _rulesetConfigurations[0].approvalHook = IJBRulesetApprovalHook(address(0));
        _rulesetConfigurations[0].metadata = _rulesMetadata;
        _rulesetConfigurations[0].splitGroups = new JBSplitGroup[](0);
        _rulesetConfigurations[0].fundAccessLimitGroups = _fundAccessLimitGroup;

        vm.expectRevert(abi.encodeWithSignature("INVALID_RESERVED_RATE()"));
        _controller.launchProjectFor(address(this), _metadata, _rulesetConfigurations, _terminals, _memo);
    }

    function test_GivenRulesetHasInvalidRedemptionRate() external whenCalledDefault {
        // it will revert INVALID_REDEMPTION_RATE()

        JBRulesetMetadata memory _rulesMetadata = JBRulesetMetadata({
            reservedRate: JBConstants.MAX_RESERVED_RATE / 2,
            redemptionRate: JBConstants.MAX_REDEMPTION_RATE + 1, //50%
            baseCurrency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
            pausePay: false,
            pauseCreditTransfers: false,
            allowOwnerMinting: false,
            allowTerminalMigration: false,
            allowSetTerminals: false,
            allowControllerMigration: false,
            allowSetController: false,
            holdFees: false,
            useTotalSurplusForRedemptions: true,
            useDataHookForPay: false,
            useDataHookForRedeem: false,
            dataHook: address(0),
            metadata: 0
        });

        JBFundAccessLimitGroup[] memory _fundAccessLimitGroup = new JBFundAccessLimitGroup[](0);
        JBTerminalConfig[] memory _terminals = new JBTerminalConfig[](0);

        // Package up the ruleset configuration.
        JBRulesetConfig[] memory _rulesetConfigurations = new JBRulesetConfig[](1);
        _rulesetConfigurations[0].mustStartAtOrAfter = 0;
        _rulesetConfigurations[0].duration = 0;
        _rulesetConfigurations[0].weight = 1e18;
        _rulesetConfigurations[0].decayRate = 0;
        _rulesetConfigurations[0].approvalHook = IJBRulesetApprovalHook(address(0));
        _rulesetConfigurations[0].metadata = _rulesMetadata;
        _rulesetConfigurations[0].splitGroups = new JBSplitGroup[](0);
        _rulesetConfigurations[0].fundAccessLimitGroups = _fundAccessLimitGroup;

        vm.expectRevert(abi.encodeWithSignature("INVALID_REDEMPTION_RATE()"));
        _controller.launchProjectFor(address(this), _metadata, _rulesetConfigurations, _terminals, _memo);
    }

    /* function test_GivenTerminalsAreProvided() external whenCalled {
        // it will set terminals
    } */

    function test_GivenMemoIsProvided() external whenCalledDefault {
        // it will be included in the emit

        JBRulesetConfig[] memory _rulesets = new JBRulesetConfig[](0);
        JBTerminalConfig[] memory _terminals = new JBTerminalConfig[](0);

        vm.expectEmit();
        emit IJBController.LaunchProject(0, 1, _metadata, _memo, address(this));

        _controller.launchProjectFor(address(this), _metadata, _rulesets, _terminals, _memo);
    }

    /* function test_GivenDirectoryExists() external whenCalled {
        // it will setControllerOf to itself
    } */
}
