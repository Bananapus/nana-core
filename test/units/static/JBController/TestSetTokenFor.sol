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

    function test_WhenCallerIsPermissioned() external {
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
            reservedRate: JBConstants.MAX_RESERVED_RATE / 2, //50%
            redemptionRate: JBConstants.MAX_REDEMPTION_RATE / 2, //50%
            baseCurrency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
            pausePay: false,
            pauseCreditTransfers: false,
            allowOwnerMinting: true,
            allowSetCustomToken: true, // Allows authorized to set a token or mint tokens
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

        uint256 _packedMetadata = JBRulesetMetadataResolver.packRulesetMetadata(_metadata);

        JBRuleset memory ruleset = JBRuleset({
            cycleNumber: 1,
            id: block.timestamp,
            basedOnId: 0,
            start: block.timestamp,
            duration: 8000,
            weight: 5000,
            decayRate: 0,
            approvalHook: IJBRulesetApprovalHook(address(0)),
            metadata: _packedMetadata
        });

        bytes memory _currentRulesetCall = abi.encodeCall(IJBRulesets.currentOf, (1));
        mockExpect(address(rulesets), _currentRulesetCall, abi.encode(ruleset));

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
            reservedRate: JBConstants.MAX_RESERVED_RATE / 2, //50%
            redemptionRate: JBConstants.MAX_REDEMPTION_RATE / 2, //50%
            baseCurrency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
            pausePay: false,
            pauseCreditTransfers: false,
            allowOwnerMinting: true,
            allowSetCustomToken: false, // Allows authorized to set a token or mint tokens
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

        uint256 _packedMetadata = JBRulesetMetadataResolver.packRulesetMetadata(_metadata);

        JBRuleset memory ruleset = JBRuleset({
            cycleNumber: 1,
            id: block.timestamp,
            basedOnId: 0,
            start: block.timestamp,
            duration: 8000,
            weight: 5000,
            decayRate: 0,
            approvalHook: IJBRulesetApprovalHook(address(0)),
            metadata: _packedMetadata
        });

        bytes memory _currentRulesetCall = abi.encodeCall(IJBRulesets.currentOf, (1));
        mockExpect(address(rulesets), _currentRulesetCall, abi.encode(ruleset));

        vm.expectRevert(abi.encodeWithSignature("RULESET_SET_TOKEN_DISABLED()"));
        _controller.setTokenFor(_projectId, _token);
    }

    function test_WhenCallerIsNotPermissioned() external {
        // it will revert UNAUTHORIZED

        // mock ownerOf call as not this address (unauth)
        bytes memory _ownerOfCall = abi.encodeCall(IERC721.ownerOf, (_projectId));
        bytes memory _ownerOfReturn = abi.encode(address(0));
        mockExpect(address(projects), _ownerOfCall, _ownerOfReturn);

        // mock permissions call as unauth
        bytes memory _permsCall1 =
            abi.encodeCall(IJBPermissions.hasPermission, (address(this), address(0), 1, JBPermissionIds.SET_TOKEN));
        bytes memory _permsCallReturn1 = abi.encode(false);
        mockExpect(address(permissions), _permsCall1, _permsCallReturn1);

        // mock permissions call as unauth for root
        bytes memory _permsCall2 =
            abi.encodeCall(IJBPermissions.hasPermission, (address(this), address(0), 0, JBPermissionIds.SET_TOKEN));
        bytes memory _permsCallReturn2 = abi.encode(false);
        mockExpect(address(permissions), _permsCall2, _permsCallReturn2);

        vm.expectRevert(abi.encodeWithSignature("UNAUTHORIZED()"));
        _controller.setTokenFor(_projectId, _token);
    }
}
