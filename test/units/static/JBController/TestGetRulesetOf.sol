// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBControllerSetup} from "./JBControllerSetup.sol";

/**
 * @title
 */
contract TestGetRulesetOf_Local is JBTest, JBControllerSetup {
    // A library that parses packed ruleset metadata into a friendlier format.
    using JBRulesetMetadataResolver for JBRuleset;

    function setUp() public {
        super.controllerSetup();
    }

    function genMetadata() public pure returns (uint256) {
        uint256 packed = 1;
        packed |= 5000 << 4;
        packed |= 8000 << 20;
        packed |= 1 << 36;
        packed |= 1 << 69;
        packed |= 1 << 71;
        packed |= 1 << 72;
        packed |= 1 << 74;
        packed |= 1 << 76;
        packed |= uint256(uint160(address(0x1234567890123456789012345678901234567890))) << 79;
        packed |= 65_535 << 239;

        return packed;
    }

    function test_WhenRulesetIdIsZero() external {
        // it should return empty ruleset and metadata
    }

    function test_WhenControllerGetRulesetOfIsCalled() external {
        // it should call rulesets and access storage (we avoid setting and reading here)

        // setup: return data
        JBRuleset memory data = JBRuleset({
            cycleNumber: 1,
            id: block.timestamp,
            basedOnId: 0,
            start: block.timestamp,
            duration: 8000,
            weight: 5000,
            decayRate: 0,
            approvalHook: IJBRulesetApprovalHook(address(0x1234567890123456789012345678901234567890)),
            metadata: genMetadata()
        });

        // setup: mock call
        bytes memory _encodedCall = abi.encodeCall(IJBRulesets.getRulesetOf, (1, block.timestamp));
        bytes memory _willReturn = abi.encode(data);

        mockExpect(address(rulesets), _encodedCall, _willReturn);

        // send
        (JBRuleset memory ruleset, JBRulesetMetadata memory metadata) = _controller.getRulesetOf(1, block.timestamp);

        // check: return types make sense
        assertEq(data.duration, ruleset.duration);
        assertEq(metadata.reservedRate, data.expandMetadata().reservedRate);
    }
}
