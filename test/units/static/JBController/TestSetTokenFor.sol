// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBControllerSetup} from "./JBControllerSetup.sol";

contract TestSetTokenFor_Local is JBControllerSetup {
    IJBToken _token = IJBToken(makeAddr("token"));
    uint256 _projectId = 1;

    function setUp() public {
        super.controllerSetup();
    }

    function test_WhenCallerIsPermissionedAndCurrentRuleset() external {
        // it will set token

        // mock ownerOf call to auth this contract (caller)
        bytes memory _ownerOfCall = abi.encodeCall(IERC721.ownerOf, (_projectId));
        bytes memory _ownerOfReturn = abi.encode(address(this));
        mockExpect(address(projects), _ownerOfCall, _ownerOfReturn);

        // mock call to JBTokens
        bytes memory _tokensCall = abi.encodeCall(IJBTokens.setTokenFor, (_projectId, _token));
        mockExpect(address(tokens), _tokensCall, "");

        // mock call to JBRulesets

        // setup: return data
        JBRulesetMetadata memory _metadata = JBRulesetMetadata({
            reservedPercent: JBConstants.MAX_RESERVED_PERCENT / 2, //50%
            redemptionRate: JBConstants.MAX_REDEMPTION_RATE / 2, //50%
            baseCurrency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
            pausePay: false,
            pauseCreditTransfers: false,
            allowOwnerMinting: true,
            allowSetCustomToken: true, // Allows authorized to set a token or mint tokens
            allowTerminalMigration: false,
            allowSetTerminals: false,
            ownerMustSendPayouts: false,
            allowSetController: false,
            allowAddAccountingContext: true,
            allowAddPriceFeed: false,
            holdFees: false,
            useTotalSurplusForRedemptions: true,
            useDataHookForPay: false,
            useDataHookForRedeem: false,
            dataHook: address(0),
            metadata: 0
        });

        uint256 _packedMetadata = JBRulesetMetadataResolver.packRulesetMetadata(_metadata);

        JBRuleset memory ruleset = JBRuleset({
            cycleNumber: 1,
            id: uint48(block.timestamp),
            basedOnId: 0,
            start: uint48(block.timestamp),
            duration: 8000,
            weight: 5000,
            decayPercent: 0,
            approvalHook: IJBRulesetApprovalHook(address(0)),
            metadata: _packedMetadata
        });

        bytes memory _currentRulesetCall = abi.encodeCall(IJBRulesets.currentOf, (1));
        mockExpect(address(rulesets), _currentRulesetCall, abi.encode(ruleset));

        _controller.setTokenFor(_projectId, _token);
    }

    function test_WhenCallerIsPermissionedAndNoCurrentRulesetButUpcomingCompatible() external {
        // it will set token

        // mock ownerOf call to auth this contract (caller)
        bytes memory _ownerOfCall = abi.encodeCall(IERC721.ownerOf, (_projectId));
        bytes memory _ownerOfReturn = abi.encode(address(this));
        mockExpect(address(projects), _ownerOfCall, _ownerOfReturn);

        // mock call to JBTokens
        bytes memory _tokensCall = abi.encodeCall(IJBTokens.setTokenFor, (_projectId, _token));
        mockExpect(address(tokens), _tokensCall, "");

        // mock call to JBRulesets

        // setup: return data
        JBRulesetMetadata memory _metadata = JBRulesetMetadata({
            reservedPercent: JBConstants.MAX_RESERVED_PERCENT / 2, //50%
            redemptionRate: JBConstants.MAX_REDEMPTION_RATE / 2, //50%
            baseCurrency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
            pausePay: false,
            pauseCreditTransfers: false,
            allowOwnerMinting: true,
            allowSetCustomToken: true, // Allows authorized to set a token or mint tokens
            allowTerminalMigration: false,
            allowSetTerminals: false,
            ownerMustSendPayouts: false,
            allowSetController: false,
            allowAddAccountingContext: true,
            allowAddPriceFeed: false,
            holdFees: false,
            useTotalSurplusForRedemptions: true,
            useDataHookForPay: false,
            useDataHookForRedeem: false,
            dataHook: address(0),
            metadata: 0
        });

        uint256 _packedMetadata = JBRulesetMetadataResolver.packRulesetMetadata(_metadata);

        JBRuleset memory ruleset = JBRuleset({
            cycleNumber: 0,
            id: 0,
            basedOnId: 0,
            start: 0,
            duration: 0,
            weight: 0,
            decayPercent: 0,
            approvalHook: IJBRulesetApprovalHook(address(0)),
            metadata: 0
        });

        JBRuleset memory upcoming = JBRuleset({
            cycleNumber: 1,
            id: uint48(block.timestamp),
            basedOnId: 0,
            start: uint48(block.timestamp),
            duration: 8000,
            weight: 5000,
            decayPercent: 0,
            approvalHook: IJBRulesetApprovalHook(address(0)),
            metadata: _packedMetadata
        });

        // Will check the current ruleset
        bytes memory _currentRulesetCall = abi.encodeCall(IJBRulesets.currentOf, (1));
        mockExpect(address(rulesets), _currentRulesetCall, abi.encode(ruleset));

        // Will check the upcoming ruleset
        mockExpect(address(rulesets), abi.encodeCall(IJBRulesets.upcomingOf, (1)), abi.encode(upcoming));

        _controller.setTokenFor(_projectId, _token);
    }

    function test_WhenCallerIsPermissionedAndAllowSetTokensEQFalse() external {
        // it will set token

        // mock ownerOf call to auth this contract (caller)
        bytes memory _ownerOfCall = abi.encodeCall(IERC721.ownerOf, (_projectId));
        bytes memory _ownerOfReturn = abi.encode(address(this));
        mockExpect(address(projects), _ownerOfCall, _ownerOfReturn);

        // mock call to JBRulesets

        // setup: return data
        JBRulesetMetadata memory _metadata = JBRulesetMetadata({
            reservedPercent: JBConstants.MAX_RESERVED_PERCENT / 2, //50%
            redemptionRate: JBConstants.MAX_REDEMPTION_RATE / 2, //50%
            baseCurrency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
            pausePay: false,
            pauseCreditTransfers: false,
            allowOwnerMinting: true,
            allowSetCustomToken: false, // Allows authorized to set a token or mint tokens
            allowTerminalMigration: false,
            allowSetTerminals: false,
            ownerMustSendPayouts: false,
            allowSetController: false,
            allowAddAccountingContext: true,
            allowAddPriceFeed: false,
            holdFees: false,
            useTotalSurplusForRedemptions: true,
            useDataHookForPay: false,
            useDataHookForRedeem: false,
            dataHook: address(0),
            metadata: 0
        });

        uint256 _packedMetadata = JBRulesetMetadataResolver.packRulesetMetadata(_metadata);

        JBRuleset memory ruleset = JBRuleset({
            cycleNumber: 1,
            id: uint48(block.timestamp),
            basedOnId: 0,
            start: uint48(block.timestamp),
            duration: 8000,
            weight: 5000,
            decayPercent: 0,
            approvalHook: IJBRulesetApprovalHook(address(0)),
            metadata: _packedMetadata
        });

        bytes memory _currentRulesetCall = abi.encodeCall(IJBRulesets.currentOf, (1));
        mockExpect(address(rulesets), _currentRulesetCall, abi.encode(ruleset));

        vm.expectRevert(JBController.JBController_RulesetSetTokenDisabled.selector);
        _controller.setTokenFor(_projectId, _token);
    }

    function test_WhenCallerIsNotPermissioned() external {
        // it will revert UNAUTHORIZED

        // mock ownerOf call as not this address (unauth)
        bytes memory _ownerOfCall = abi.encodeCall(IERC721.ownerOf, (_projectId));
        bytes memory _ownerOfReturn = abi.encode(address(0));
        mockExpect(address(projects), _ownerOfCall, _ownerOfReturn);

        // mock permissions call as unauth
        bytes memory _permsCall1 = abi.encodeCall(
            IJBPermissions.hasPermission, (address(this), address(0), 1, JBPermissionIds.SET_TOKEN, true, true)
        );
        bytes memory _permsCallReturn1 = abi.encode(false);
        mockExpect(address(permissions), _permsCall1, _permsCallReturn1);

        vm.expectRevert(JBPermissioned.JBPermissioned_Unauthorized.selector);
        _controller.setTokenFor(_projectId, _token);
    }
}
