// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBControllerSetup} from "./JBControllerSetup.sol";

/**
 * @title
 */
contract TestRulesetViews_Local is JBControllerSetup {
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
        packed |= 1 << 72;
        packed |= 1 << 73;
        packed |= 1 << 74;
        packed |= 1 << 77;
        packed |= uint256(uint160(address(0x1234567890123456789012345678901234567890))) << 80;
        packed |= 65_535 << 240;

        return packed;
    }

    function test_getRulesetOf() external {
        // it should call rulesets and access storage (we avoid setting and reading here)

        // setup: return data
        JBRuleset memory data = JBRuleset({
            cycleNumber: 1,
            id: uint48(block.timestamp),
            basedOnId: 0,
            start: uint48(block.timestamp),
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

        // check: return makes sense
        assertEq(data.duration, ruleset.duration);
        assertEq(metadata.reservedRate, data.expandMetadata().reservedRate);
    }

    function test_latestQueuedOf() external {
        // setup: return data
        JBRuleset memory data = JBRuleset({
            cycleNumber: 1,
            id: uint48(block.timestamp),
            basedOnId: 0,
            start: uint48(block.timestamp),
            duration: 8000,
            weight: 5000,
            decayRate: 0,
            approvalHook: IJBRulesetApprovalHook(address(0x1234567890123456789012345678901234567890)),
            metadata: genMetadata()
        });

        // setup: mock call
        bytes memory _encodedCall = abi.encodeCall(IJBRulesets.latestQueuedOf, (1));
        bytes memory _willReturn = abi.encode(data, JBApprovalStatus.Empty);

        mockExpect(address(rulesets), _encodedCall, _willReturn);

        // send
        (JBRuleset memory ruleset, JBRulesetMetadata memory metadata, JBApprovalStatus approvalStatus) =
            _controller.latestQueuedRulesetOf(1);

        // check: return makes sense
        assertEq(data.duration, ruleset.duration);
        assertEq(metadata.reservedRate, data.expandMetadata().reservedRate);
        assertEq(abi.encode(approvalStatus), abi.encode(JBApprovalStatus.Empty));
    }

    function test_queuedRulesetsOf() external {
        // setup: return data
        JBRuleset memory data = JBRuleset({
            cycleNumber: 1,
            id: uint48(block.timestamp),
            basedOnId: 0,
            start: uint48(block.timestamp),
            duration: 8000,
            weight: 100,
            decayRate: 0,
            approvalHook: IJBRulesetApprovalHook(address(0x1234567890123456789012345678901234567890)),
            metadata: genMetadata()
        });

        // setup: return data
        JBRuleset memory data2 = JBRuleset({
            cycleNumber: 1,
            id: uint48(block.timestamp),
            basedOnId: 0,
            start: uint48(block.timestamp),
            duration: 8000,
            weight: 200,
            decayRate: 0,
            approvalHook: IJBRulesetApprovalHook(address(0x1234567890123456789012345678901234567890)),
            metadata: genMetadata()
        });

        JBRuleset[] memory rulesetsArray = new JBRuleset[](2);
        rulesetsArray[0] = data;
        rulesetsArray[1] = data2;

        // setup: mock call
        bytes memory _encodedCall = abi.encodeCall(IJBRulesets.rulesetsOf, (1, block.timestamp, 2));
        bytes memory _willReturn = abi.encode(rulesetsArray);

        mockExpect(address(rulesets), _encodedCall, _willReturn);

        // send
        (JBRulesetWithMetadata[] memory queuedRulesets) = _controller.rulesetsOf(1, block.timestamp, 2);

        // check: return makes sense
        assertEq(rulesetsArray[0].weight, queuedRulesets[0].ruleset.weight);
    }

    function test_upcomingOf() external {
        // setup: return data
        JBRuleset memory data = JBRuleset({
            cycleNumber: 1,
            id: uint48(block.timestamp),
            basedOnId: 0,
            start: uint48(block.timestamp),
            duration: 8000,
            weight: 5000,
            decayRate: 0,
            approvalHook: IJBRulesetApprovalHook(address(0x1234567890123456789012345678901234567890)),
            metadata: genMetadata()
        });

        // setup: mock call
        bytes memory _encodedCall = abi.encodeCall(IJBRulesets.upcomingOf, (1));
        bytes memory _willReturn = abi.encode(data, JBApprovalStatus.Empty);

        mockExpect(address(rulesets), _encodedCall, _willReturn);

        // send
        (JBRuleset memory ruleset, JBRulesetMetadata memory metadata) = _controller.upcomingRulesetOf(1);

        // check: return makes sense
        assertEq(data.duration, ruleset.duration);
        assertEq(metadata.reservedRate, data.expandMetadata().reservedRate);
    }

    function test_SetTerminalAllowed() public {
        // setup: return data
        JBRuleset memory data = JBRuleset({
            cycleNumber: 1,
            id: uint48(block.timestamp),
            basedOnId: 0,
            start: uint48(block.timestamp),
            duration: 8000,
            weight: 5000,
            decayRate: 0,
            approvalHook: IJBRulesetApprovalHook(address(0x1234567890123456789012345678901234567890)),
            metadata: genMetadata()
        });

        // setup: mock call
        bytes memory _encodedCall = abi.encodeCall(IJBRulesets.currentOf, (1));
        bytes memory _willReturn = abi.encode(data);

        mockExpect(address(rulesets), _encodedCall, _willReturn);

        // send
        (bool allowed) = _controller.setTerminalsAllowed(1);

        // check: return makes sense
        assertEq(allowed, true);
    }

    function testSetControllerAllowed() public {
        // setup: return data
        JBRuleset memory data = JBRuleset({
            cycleNumber: 1,
            id: uint48(block.timestamp),
            basedOnId: 0,
            start: uint48(block.timestamp),
            duration: 8000,
            weight: 5000,
            decayRate: 0,
            approvalHook: IJBRulesetApprovalHook(address(0x1234567890123456789012345678901234567890)),
            metadata: genMetadata()
        });

        // setup: mock call
        bytes memory _encodedCall = abi.encodeCall(IJBRulesets.currentOf, (1));
        bytes memory _willReturn = abi.encode(data);

        mockExpect(address(rulesets), _encodedCall, _willReturn);

        // send
        (bool allowed) = _controller.setControllerAllowed(1);

        // check: return makes sense
        assertEq(allowed, true);
    }
}
