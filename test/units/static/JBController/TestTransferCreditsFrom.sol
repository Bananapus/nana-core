// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBControllerSetup} from "./JBControllerSetup.sol";

contract TestTransferCreditsFrom_Local is JBControllerSetup {
    using JBRulesetMetadataResolver for JBRulesetMetadata;

    address _holder = makeAddr("hodler");
    uint256 _projectId = 1;
    uint256 _rootId = 0;
    uint256 _amount = 1e18;
    address _beneficiary = makeAddr("bene");

    function setUp() public {
        super.controllerSetup();
    }

    modifier whenCallerIsPermissioned() {
        // it will call permissions
        bytes memory _permCall = abi.encodeCall(
            IJBPermissions.hasPermission,
            (address(this), _holder, _projectId, JBPermissionIds.TRANSFER_CREDITS, true, true)
        );
        bytes memory _permReturn = abi.encode(true);
        mockExpect(address(permissions), _permCall, _permReturn);
        _;
    }

    function test_GivenRulesetAllowsCreditTransfers() external whenCallerIsPermissioned {
        // it will call JBTokens to transfer the credits

        // data for JBRulesets currentOf call
        JBRulesetMetadata memory _rulesMetadata = JBRulesetMetadata({
            reservedRate: JBConstants.MAX_RESERVED_RATE / 2,
            redemptionRate: JBConstants.MAX_REDEMPTION_RATE / 2,
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

        uint256 _packed = _rulesMetadata.packRulesetMetadata();

        // mocked ruleset that allows credit transfer
        JBRuleset memory _returnedRuleset = JBRuleset({
            cycleNumber: 1,
            id: block.timestamp,
            basedOnId: 0,
            start: block.timestamp,
            duration: 100,
            weight: 1e18,
            decayRate: 0,
            approvalHook: IJBRulesetApprovalHook(address(0)),
            metadata: _packed
        });

        // mock the call to JBRulesets currentOf
        bytes memory _rulesetCall = abi.encodeCall(IJBRulesets.currentOf, (_projectId));
        bytes memory _rulesetCallReturn = abi.encode(_returnedRuleset);
        mockExpect(address(rulesets), _rulesetCall, _rulesetCallReturn);

        // mock the subsequent call to JBTokens transferCreditsFrom
        bytes memory _transferCall =
            abi.encodeCall(IJBTokens.transferCreditsFrom, (_holder, _projectId, _beneficiary, _amount));
        bytes memory _transferCallReturn = "";
        mockExpect(address(tokens), _transferCall, _transferCallReturn);

        _controller.transferCreditsFrom(_holder, _projectId, _beneficiary, _amount);
    }

    function test_GivenRulesetDoesNotAllowCreditTransfers() external whenCallerIsPermissioned {
        // it will revert CREDIT_TRANSFERS_PAUSED

        // data for JBRulesets currentOf call
        JBRulesetMetadata memory _rulesMetadata = JBRulesetMetadata({
            reservedRate: JBConstants.MAX_RESERVED_RATE / 2,
            redemptionRate: JBConstants.MAX_REDEMPTION_RATE / 2,
            baseCurrency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
            pausePay: false,
            // will revert in this case
            pauseCreditTransfers: true,
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

        uint256 _packed = _rulesMetadata.packRulesetMetadata();

        // mocked ruleset that allows credit transfer
        JBRuleset memory _returnedRuleset = JBRuleset({
            cycleNumber: 1,
            id: block.timestamp,
            basedOnId: 0,
            start: block.timestamp,
            duration: 100,
            weight: 1e18,
            decayRate: 0,
            approvalHook: IJBRulesetApprovalHook(address(0)),
            metadata: _packed
        });

        // mock the call to JBRulesets currentOf
        bytes memory _rulesetCall = abi.encodeCall(IJBRulesets.currentOf, (_projectId));
        bytes memory _rulesetCallReturn = abi.encode(_returnedRuleset);
        mockExpect(address(rulesets), _rulesetCall, _rulesetCallReturn);

        vm.expectRevert(abi.encodeWithSignature("CREDIT_TRANSFERS_PAUSED()"));
        _controller.transferCreditsFrom(_holder, _projectId, _beneficiary, _amount);
    }

    function test_WhenCallerIsNotPermissioned() external {
        // it will revert UNAUTHORIZED
        // it will call permissions
        bytes memory _permCall = abi.encodeCall(
            IJBPermissions.hasPermission,
            (address(this), _holder, _projectId, JBPermissionIds.TRANSFER_CREDITS, true, true)
        );
        bytes memory _permReturn = abi.encode(false);
        mockExpect(address(permissions), _permCall, _permReturn);

        // will revert
        vm.expectRevert(abi.encodeWithSignature("UNAUTHORIZED()"));
        _controller.transferCreditsFrom(_holder, _projectId, _beneficiary, _amount);
    }
}
