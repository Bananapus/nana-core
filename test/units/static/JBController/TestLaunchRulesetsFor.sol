// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBControllerSetup} from "./JBControllerSetup.sol";

contract TestLaunchRulesetsFor_Local is JBControllerSetup {
    function setUp() public {
        super.controllerSetup();
    }

    modifier whenCallerHasPermission() {
        // mock ownerOf call
        bytes memory _ownerOfCall = abi.encodeCall(IERC721.ownerOf, (1));
        bytes memory _ownerData = abi.encode(address(this));

        mockExpect(address(projects), _ownerOfCall, _ownerData);
        _;
    }

    modifier whenCallerWithoutPermission() {
        // mock ownerOf call
        bytes memory _ownerOfCall = abi.encodeCall(IERC721.ownerOf, (1));
        bytes memory _ownerData = abi.encode(address(1));

        mockExpect(address(projects), _ownerOfCall, _ownerData);

        // mock permission call
        bytes memory _call =
            abi.encodeCall(IJBPermissions.hasPermission, (address(this), address(1), 1, JBPermissionIds.QUEUE_RULESETS));
        mockExpect(address(permissions), _call, abi.encode(false));

        // mock permission call #2 (checks for root priv)
        bytes memory _call2 =
            abi.encodeCall(IJBPermissions.hasPermission, (address(this), address(1), 0, JBPermissionIds.QUEUE_RULESETS));
        mockExpect(address(permissions), _call2, abi.encode(false));
        _;
    }

    function genRuleset()
        public
        pure
        returns (JBTerminalConfig[] memory _terminalConfig, JBRulesetConfig[] memory _rulesetConfig)
    {
        // it should set the controller, queue the rulesets, configure terminals, and emit LaunchRulesets
        JBTerminalConfig[] memory _terminalConfigs = new JBTerminalConfig[](0);
        JBRulesetConfig[] memory _rulesetConfigs = new JBRulesetConfig[](1);

        JBRulesetMetadata memory _metadata = JBRulesetMetadata({
            reservedRate: JBConstants.MAX_RESERVED_RATE / 2, //50%
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

        // Package up the limits for the given terminal.
        JBFundAccessLimitGroup[] memory _fundAccessLimitGroup = new JBFundAccessLimitGroup[](1);

        // Specify a payout limit.
        JBCurrencyAmount[] memory _payoutLimits = new JBCurrencyAmount[](1);
        _payoutLimits[0] = JBCurrencyAmount({amount: 0, currency: uint32(uint160(JBConstants.NATIVE_TOKEN))});

        // Specify a surplus allowance.
        JBCurrencyAmount[] memory _surplusAllowances = new JBCurrencyAmount[](1);
        _surplusAllowances[0] = JBCurrencyAmount({amount: 0, currency: uint32(uint160(JBConstants.NATIVE_TOKEN))});

        _fundAccessLimitGroup[0] = JBFundAccessLimitGroup({
            terminal: address(0),
            token: JBConstants.NATIVE_TOKEN,
            payoutLimits: _payoutLimits,
            surplusAllowances: _surplusAllowances
        });

        // Package up the ruleset configuration.
        _rulesetConfigs[0].mustStartAtOrAfter = 0;
        _rulesetConfigs[0].duration = 0;
        _rulesetConfigs[0].weight = 0;
        _rulesetConfigs[0].decayRate = 0;
        _rulesetConfigs[0].approvalHook = IJBRulesetApprovalHook(address(0));
        _rulesetConfigs[0].metadata = _metadata;
        _rulesetConfigs[0].splitGroups = new JBSplitGroup[](0);
        _rulesetConfigs[0].fundAccessLimitGroups = _fundAccessLimitGroup;

        return (_terminalConfigs, _rulesetConfigs);
    }

    function test_RevertWhen_RulesetLengthIsZero() external {
        // it should revert
        JBTerminalConfig[] memory _terminalConfigs = new JBTerminalConfig[](0);
        JBRulesetConfig[] memory _rulesetConfigs = new JBRulesetConfig[](0);

        vm.expectRevert(abi.encodeWithSignature("RULESETS_ARRAY_EMPTY()"));

        _controller.launchRulesetsFor(1, _rulesetConfigs, _terminalConfigs, "");
    }

    function test_RevertWhen_CallerDoesNotHavePermission() external whenCallerWithoutPermission {
        // it should revert
        JBTerminalConfig[] memory _terminalConfigs = new JBTerminalConfig[](0);
        JBRulesetConfig[] memory _rulesetConfigs = new JBRulesetConfig[](1);

        vm.expectRevert(abi.encodeWithSignature("UNAUTHORIZED()"));

        _controller.launchRulesetsFor(1, _rulesetConfigs, _terminalConfigs, "");
    }

    function test_Revert_GivenTheProjectAlreadyHasRulesets() external whenCallerHasPermission {
        // it should revert
        JBTerminalConfig[] memory _terminalConfigs = new JBTerminalConfig[](0);
        JBRulesetConfig[] memory _rulesetConfigs = new JBRulesetConfig[](1);

        bytes memory _latestRulesetIdOfCall = abi.encodeCall(IJBRulesets.latestRulesetIdOf, (1));
        bytes memory _returnData = abi.encode(1);

        mockExpect(address(rulesets), _latestRulesetIdOfCall, _returnData);

        vm.expectRevert(abi.encodeWithSignature("RULESETS_ALREADY_LAUNCHED()"));

        _controller.launchRulesetsFor(1, _rulesetConfigs, _terminalConfigs, "");
    }

    function test_GivenTheProjectDoesNotYetHaveRulesets() external whenCallerHasPermission {
        // setup: needed for the call chain
        JBTerminalConfig[] memory _terminalConfigs;
        JBRulesetConfig[] memory _rulesetConfigs;
        uint256 _ts = block.timestamp;
        uint256 _projectId = 1;
        (_terminalConfigs, _rulesetConfigs) = genRuleset();

        // inlined to avoid stack2deep
        mockExpect(address(rulesets), abi.encodeCall(IJBRulesets.latestRulesetIdOf, (_projectId)), abi.encode(0));
        mockExpect(
            address(directory),
            abi.encodeCall(IJBDirectory.setControllerOf, (_projectId, IERC165(address(_controller)))),
            ""
        );

        // mock call to rulesets queueFor
        // setup: return data
        JBRuleset memory data = JBRuleset({
            cycleNumber: 1,
            id: _ts,
            basedOnId: 0,
            start: _ts,
            duration: 0,
            weight: 0,
            decayRate: 0,
            approvalHook: IJBRulesetApprovalHook(address(0)),
            metadata: 0
        });

        // Mock call to rulesets queueFor
        bytes memory _queueForCall = abi.encodeCall(
            IJBRulesets.queueFor,
            (_projectId, 0, 0, 0, _rulesetConfigs[0].approvalHook, 75_557_867_929_215_080_413_313, 0)
        );
        bytes memory _queueReturn = abi.encode(data);
        mockExpect(address(rulesets), _queueForCall, _queueReturn);

        // Mock call to splits setSplitGroupsOf
        bytes memory _setSplitsCall =
            abi.encodeCall(IJBSplits.setSplitGroupsOf, (_projectId, _ts, _rulesetConfigs[0].splitGroups));
        bytes memory _splitsReturn = "";
        mockExpect(address(splits), _setSplitsCall, _splitsReturn);

        // Mock call to fundaccesslimits setFundAccessLimitsFor
        bytes memory _fundAccessCall = abi.encodeCall(
            IJBFundAccessLimits.setFundAccessLimitsFor, (_projectId, _ts, _rulesetConfigs[0].fundAccessLimitGroups)
        );
        bytes memory _accessReturn = "";
        mockExpect(address(fundAccessLimits), _fundAccessCall, _accessReturn);

        // event as expected
        vm.expectEmit();
        emit IJBController.LaunchRulesets(_ts, 1, "", address(this));

        _controller.launchRulesetsFor(_projectId, _rulesetConfigs, _terminalConfigs, "");
    }

    function test_GivenCallerOnlyHasQueuePermission() external {
        // it should revert

        // mock ownerOf call
        bytes memory _ownerOfCall = abi.encodeCall(IERC721.ownerOf, (1));
        bytes memory _ownerData = abi.encode(address(1));

        mockExpect(address(projects), _ownerOfCall, _ownerData);

        // mock permission call
        bytes memory _call =
            abi.encodeCall(IJBPermissions.hasPermission, (address(this), address(1), 1, JBPermissionIds.QUEUE_RULESETS));
        mockExpect(address(permissions), _call, abi.encode(true));

        // SET_TERMINALS
        bytes memory _call3 =
            abi.encodeCall(IJBPermissions.hasPermission, (address(this), address(1), 1, JBPermissionIds.SET_TERMINALS));
        mockExpect(address(permissions), _call3, abi.encode(false));

        // mock permission call #2 (checks for root priv)
        bytes memory _call4 =
            abi.encodeCall(IJBPermissions.hasPermission, (address(this), address(1), 0, JBPermissionIds.SET_TERMINALS));
        mockExpect(address(permissions), _call4, abi.encode(false));

        // it should revert
        JBTerminalConfig[] memory _terminalConfigs = new JBTerminalConfig[](0);
        JBRulesetConfig[] memory _rulesetConfigs = new JBRulesetConfig[](1);

        vm.expectRevert(abi.encodeWithSignature("UNAUTHORIZED()"));

        _controller.launchRulesetsFor(1, _rulesetConfigs, _terminalConfigs, "");
    }

    function test_GivenNonOwnerHasBothPermissions() external {
        // it will launch rulesets

        // mock ownerOf call
        bytes memory _ownerOfCall = abi.encodeCall(IERC721.ownerOf, (1));
        bytes memory _ownerData = abi.encode(address(1));

        mockExpect(address(projects), _ownerOfCall, _ownerData);

        // mock permission call
        bytes memory _call =
            abi.encodeCall(IJBPermissions.hasPermission, (address(this), address(1), 1, JBPermissionIds.QUEUE_RULESETS));
        mockExpect(address(permissions), _call, abi.encode(true));

        // SET_TERMINALS
        bytes memory _call3 =
            abi.encodeCall(IJBPermissions.hasPermission, (address(this), address(1), 1, JBPermissionIds.SET_TERMINALS));
        mockExpect(address(permissions), _call3, abi.encode(true));

        // setup: needed for the call chain
        JBTerminalConfig[] memory _terminalConfigs;
        JBRulesetConfig[] memory _rulesetConfigs;
        uint256 _ts = block.timestamp;
        uint256 _projectId = 1;
        (_terminalConfigs, _rulesetConfigs) = genRuleset();

        // inlined to avoid stack2deep
        mockExpect(address(rulesets), abi.encodeCall(IJBRulesets.latestRulesetIdOf, (_projectId)), abi.encode(0));
        mockExpect(
            address(directory),
            abi.encodeCall(IJBDirectory.setControllerOf, (_projectId, IERC165(address(_controller)))),
            ""
        );

        // mock call to rulesets queueFor
        // setup: return data
        JBRuleset memory data = JBRuleset({
            cycleNumber: 1,
            id: _ts,
            basedOnId: 0,
            start: _ts,
            duration: 0,
            weight: 0,
            decayRate: 0,
            approvalHook: IJBRulesetApprovalHook(address(0)),
            metadata: 0
        });

        // Mock call to rulesets queueFor
        bytes memory _queueForCall = abi.encodeCall(
            IJBRulesets.queueFor,
            (_projectId, 0, 0, 0, _rulesetConfigs[0].approvalHook, 75_557_867_929_215_080_413_313, 0)
        );
        bytes memory _queueReturn = abi.encode(data);
        mockExpect(address(rulesets), _queueForCall, _queueReturn);

        // Mock call to splits setSplitGroupsOf
        bytes memory _setSplitsCall =
            abi.encodeCall(IJBSplits.setSplitGroupsOf, (_projectId, _ts, _rulesetConfigs[0].splitGroups));
        bytes memory _splitsReturn = "";
        mockExpect(address(splits), _setSplitsCall, _splitsReturn);

        // Mock call to fundaccesslimits setFundAccessLimitsFor
        bytes memory _fundAccessCall = abi.encodeCall(
            IJBFundAccessLimits.setFundAccessLimitsFor, (_projectId, _ts, _rulesetConfigs[0].fundAccessLimitGroups)
        );
        bytes memory _accessReturn = "";
        mockExpect(address(fundAccessLimits), _fundAccessCall, _accessReturn);

        // event as expected
        vm.expectEmit();
        emit IJBController.LaunchRulesets(_ts, 1, "", address(this));

        _controller.launchRulesetsFor(1, _rulesetConfigs, _terminalConfigs, "");
    }
}
