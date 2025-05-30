// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBRulesetWeightCache} from "src/structs/JBRulesetWeightCache.sol";

contract TestJBRulesetsUnits_Local is JBTest {
    // Contracts
    JBRulesets public _rulesets;
    IJBDirectory internal _directory;
    IJBPermissions internal _permissions;

    // Necessary params
    JBRulesetMetadata private _metadata;
    JBRulesetMetadata private _metadataWithApprovalHook;
    IJBRulesetApprovalHook private _mockApprovalHook = IJBRulesetApprovalHook(makeAddr("hook"));
    uint256 _packedMetadata;
    uint256 _packedWithApprovalHook;
    uint64 _projectId = 1;
    uint32 _duration = 3 days;
    uint112 _weight = 0;
    uint32 _weightCutPercent = 450_000_000;
    uint256 _mustStartAt = 0;
    uint256 _hookDuration = 1 days;
    IJBRulesetApprovalHook private _hook = IJBRulesetApprovalHook(address(0));

    function equals(JBRuleset memory queued, JBRuleset memory stored) internal pure returns (bool) {
        // Just compare the output of hashing all fields packed.
        return (
            keccak256(
                abi.encodePacked(
                    queued.cycleNumber,
                    queued.id,
                    queued.basedOnId,
                    queued.start,
                    queued.duration,
                    queued.weight,
                    queued.weightCutPercent,
                    queued.approvalHook,
                    queued.metadata
                )
            )
                == keccak256(
                    abi.encodePacked(
                        stored.cycleNumber,
                        stored.id,
                        stored.basedOnId,
                        stored.start,
                        stored.duration,
                        stored.weight,
                        stored.weightCutPercent,
                        stored.approvalHook,
                        stored.metadata
                    )
                )
        );
    }

    function setUp() public {
        // Mock contracts and label them
        _directory = IJBDirectory(makeAddr("JBDirectory"));
        _permissions = IJBPermissions(makeAddr("JBPermissions"));

        // Instantiate the contract being tested
        _rulesets = new JBRulesets(_directory);

        // Params for tests
        _metadata = JBRulesetMetadata({
            reservedPercent: 0,
            cashOutTaxRate: 0,
            baseCurrency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
            pausePay: false,
            pauseCreditTransfers: false,
            allowOwnerMinting: false,
            allowSetCustomToken: false,
            allowTerminalMigration: false,
            allowSetTerminals: false,
            ownerMustSendPayouts: false,
            allowSetController: false,
            allowAddAccountingContext: true,
            allowAddPriceFeed: false,
            holdFees: false,
            useTotalSurplusForCashOuts: false,
            useDataHookForPay: false,
            useDataHookForCashOut: false,
            dataHook: address(0),
            metadata: 0
        });

        // Params for tests
        _metadataWithApprovalHook = JBRulesetMetadata({
            reservedPercent: 0,
            cashOutTaxRate: 0,
            baseCurrency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
            pausePay: false,
            pauseCreditTransfers: false,
            allowOwnerMinting: false,
            allowSetCustomToken: false,
            allowTerminalMigration: false,
            allowSetTerminals: false,
            ownerMustSendPayouts: false,
            allowSetController: false,
            allowAddAccountingContext: true,
            allowAddPriceFeed: false,
            holdFees: false,
            useTotalSurplusForCashOuts: false,
            useDataHookForPay: false,
            useDataHookForCashOut: false,
            dataHook: address(0),
            metadata: 0
        });

        _packedMetadata = JBRulesetMetadataResolver.packRulesetMetadata(_metadata);
        _packedWithApprovalHook = JBRulesetMetadataResolver.packRulesetMetadata(_metadataWithApprovalHook);
    }

    function testQueueForHappyPath() public {
        // Setup: queueFor will call onlyControllerOf modifier -> Directory.controllerOf to see if caller has proper
        // permissions, encode & mock that.
        bytes memory _encodedCall = abi.encodeCall(IJBDirectory.controllerOf, (1));
        bytes memory _willReturn = abi.encode(address(this));

        mockExpect(address(_directory), _encodedCall, _willReturn);

        // Setup: expect ruleset event (RulesetQueued) is emitted
        vm.expectEmit();
        emit IJBRulesets.RulesetQueued(
            block.timestamp,
            _projectId,
            _duration,
            _weight,
            _weightCutPercent,
            _hook,
            _packedMetadata,
            block.timestamp,
            address(this)
        );

        // Send: Call from this contract as it's been mock authorized above.
        _rulesets.queueFor({
            projectId: _projectId,
            duration: _duration,
            weight: _weight,
            weightCutPercent: _weightCutPercent,
            approvalHook: _hook,
            metadata: _packedMetadata,
            mustStartAtOrAfter: _mustStartAt
        });

        // Get a reference to the now configured ruleset.
        JBRuleset memory configuredRuleset = _rulesets.currentOf(_projectId);

        // Reference queued attributes for sake of comparison.
        JBRuleset memory queued = JBRuleset({
            cycleNumber: 1,
            id: uint48(block.timestamp),
            basedOnId: 0,
            start: uint48(block.timestamp),
            duration: _duration,
            weight: _weight,
            weightCutPercent: _weightCutPercent,
            approvalHook: _hook,
            metadata: configuredRuleset.metadata
        });

        // Check: structs are the same.
        bool same = equals(queued, configuredRuleset);
        assertEq(same, true);
    }

    function testQueueForPastMustStart() public {
        // Setup: queueFor will call onlyControllerOf modifier -> Directory.controllerOf to see if caller has proper
        // permissions, encode & mock that.
        bytes memory _encodedCall = abi.encodeCall(IJBDirectory.controllerOf, (1));
        bytes memory _willReturn = abi.encode(address(this));

        mockExpect(address(_directory), _encodedCall, _willReturn);

        // Setup: expect ruleset event (RulesetQueued) is emitted
        vm.expectEmit();
        emit IJBRulesets.RulesetQueued(
            block.timestamp,
            _projectId,
            _duration,
            _weight,
            _weightCutPercent,
            _hook,
            _packedMetadata,
            block.timestamp - 1,
            address(this)
        );

        // Send: Call from this contract as it's been mock authorized above.
        _rulesets.queueFor({
            projectId: _projectId,
            duration: _duration,
            weight: _weight,
            weightCutPercent: _weightCutPercent,
            approvalHook: _hook,
            metadata: _packedMetadata,
            // Set this in the past
            mustStartAtOrAfter: block.timestamp - 1
        });

        // Get a reference to the now configured ruleset.
        JBRuleset memory configuredRuleset = _rulesets.currentOf(_projectId);

        // Reference queued attributes for sake of comparison.
        JBRuleset memory queued = JBRuleset({
            cycleNumber: 1,
            id: uint48(block.timestamp),
            basedOnId: 0,
            start: uint48(block.timestamp - 1),
            duration: _duration,
            weight: _weight,
            weightCutPercent: _weightCutPercent,
            approvalHook: _hook,
            metadata: configuredRuleset.metadata
        });

        // Check: structs are the same.
        bool same = equals(queued, configuredRuleset);
        assertEq(same, true);
    }

    function testQueueForInvalidDuration() public {
        uint256 _invalidDuration = uint256(type(uint32).max) + 1;

        // Setup: queueFor will call onlyControllerOf modifier -> Directory.controllerOf to see if caller has proper
        // permissions, encode & mock that.
        bytes memory _encodedCall = abi.encodeCall(IJBDirectory.controllerOf, (1));
        bytes memory _willReturn = abi.encode(address(this));

        mockExpect(address(_directory), _encodedCall, _willReturn);

        vm.expectRevert(
            abi.encodeWithSelector(
                JBRulesets.JBRulesets_InvalidRulesetDuration.selector, _invalidDuration, type(uint32).max
            )
        );

        // Send: Call from this contract as it's been mock authorized above.
        _rulesets.queueFor({
            projectId: _projectId,
            duration: _invalidDuration,
            weight: _weight,
            weightCutPercent: _weightCutPercent,
            approvalHook: _hook,
            metadata: _packedMetadata,
            mustStartAtOrAfter: _mustStartAt
        });
    }

    function testQueueForInvalidWeightCutPercent() public {
        uint256 _invalidWeightCutPercent = JBConstants.MAX_WEIGHT_CUT_PERCENT + 1;

        // Setup: queueFor will call onlyControllerOf modifier -> Directory.controllerOf to see if caller has proper
        // permissions, encode & mock that.
        bytes memory _encodedCall = abi.encodeCall(IJBDirectory.controllerOf, (1));
        bytes memory _willReturn = abi.encode(address(this));

        mockExpect(address(_directory), _encodedCall, _willReturn);

        vm.expectRevert(
            abi.encodeWithSelector(JBRulesets.JBRulesets_InvalidWeightCutPercent.selector, _invalidWeightCutPercent)
        );

        // Send: Call from this contract as it's been mock authorized above.
        _rulesets.queueFor({
            projectId: _projectId,
            duration: _duration,
            weight: _weight,
            weightCutPercent: _invalidWeightCutPercent,
            approvalHook: _hook,
            metadata: _packedMetadata,
            mustStartAtOrAfter: _mustStartAt
        });
    }

    function testQueueForInvalidWeight() public {
        uint256 _invalidWeight = uint256(type(uint112).max) + 1;

        // Setup: queueFor will call onlyControllerOf modifier -> Directory.controllerOf to see if caller has proper
        // permissions, encode & mock that.
        bytes memory _encodedCall = abi.encodeCall(IJBDirectory.controllerOf, (1));
        bytes memory _willReturn = abi.encode(address(this));

        mockExpect(address(_directory), _encodedCall, _willReturn);

        vm.expectRevert(
            abi.encodeWithSelector(JBRulesets.JBRulesets_InvalidWeight.selector, _invalidWeight, type(uint112).max)
        );

        // Send: Call from this contract as it's been mock authorized above.
        _rulesets.queueFor({
            projectId: _projectId,
            duration: _duration,
            weight: _invalidWeight,
            weightCutPercent: _weightCutPercent,
            approvalHook: _hook,
            metadata: _packedMetadata,
            mustStartAtOrAfter: _mustStartAt
        });
    }

    function testFuzzQueueForInvalidEndTime(uint256 _bigDuration, uint256 _bigStartAt) public {
        _bigDuration = bound(_bigDuration, 1, type(uint32).max);
        _bigStartAt = bound(_bigStartAt, 1, type(uint48).max);

        // Setup: queueFor will call onlyControllerOf modifier -> Directory.controllerOf to see if caller has proper
        // permissions, encode & mock that.
        bytes memory _encodedCall = abi.encodeCall(IJBDirectory.controllerOf, (1));
        bytes memory _willReturn = abi.encode(address(this));

        mockExpect(address(_directory), _encodedCall, _willReturn);

        // Use unchecked arithmetic to force an overflow.
        uint256 _sum;
        unchecked {
            _sum = _bigDuration + _bigStartAt;
        }

        // Sum should always be less if overflowed
        if (_bigDuration > _sum) {
            vm.expectRevert(stdError.arithmeticError);
        }

        if (_bigDuration + _bigStartAt > type(uint48).max) {
            vm.expectRevert(
                abi.encodeWithSelector(
                    JBRulesets.JBRulesets_InvalidRulesetEndTime.selector, _bigDuration + _bigStartAt, type(uint48).max
                )
            );
        }

        // Send: Call from this contract as it's been mock authorized above.
        _rulesets.queueFor({
            projectId: _projectId,
            duration: _bigDuration,
            weight: _weight,
            weightCutPercent: _weightCutPercent,
            approvalHook: _hook,
            metadata: _packedMetadata,
            mustStartAtOrAfter: _bigStartAt
        });
    }

    function testQueueApprovalHookCodeReqsAndLogic() public {
        // Setup: queueFor will call onlyControllerOf modifier -> Directory.controllerOf to see if caller has proper
        // permissions, encode & mock that.
        bytes memory _encodedCall = abi.encodeCall(IJBDirectory.controllerOf, (1));
        bytes memory _willReturn = abi.encode(address(this));

        // note: this applies to subsequent calls unless we clear mocks
        mockExpect(address(_directory), _encodedCall, _willReturn);

        // will revert since code length is zero
        vm.expectRevert(
            abi.encodeWithSelector(JBRulesets.JBRulesets_InvalidRulesetApprovalHook.selector, _mockApprovalHook)
        );

        // Send: Call from this contract as it's been mock authorized above.
        _rulesets.queueFor({
            projectId: _projectId,
            duration: _duration,
            weight: _weight,
            weightCutPercent: _weightCutPercent,
            approvalHook: _mockApprovalHook,
            metadata: _packedWithApprovalHook,
            mustStartAtOrAfter: _mustStartAt
        });

        // try another with any length of code deployed and mock interface support to pass other checks
        bytes memory code = address(_rulesets).code;
        vm.etch(address(_mockApprovalHook), code);

        bytes memory _encodedCall3 =
            abi.encodeCall(IERC165.supportsInterface, (type(IJBRulesetApprovalHook).interfaceId));
        bytes memory _willReturn3 = abi.encode(true);

        mockExpect(address(_mockApprovalHook), _encodedCall3, _willReturn3);

        // Send: Call from this contract as it's been mock authorized above.
        _rulesets.queueFor({
            projectId: _projectId,
            duration: _duration,
            weight: _weight,
            weightCutPercent: _weightCutPercent,
            approvalHook: _mockApprovalHook,
            metadata: _packedWithApprovalHook,
            mustStartAtOrAfter: _mustStartAt
        });

        uint256 firstId = block.timestamp;

        // Mock call to approval hook duration
        bytes memory _encodedDurationCall = abi.encodeCall(IJBRulesetApprovalHook.DURATION, ());
        bytes memory _willReturnDuration = abi.encode(_hookDuration);

        mockExpect(address(_mockApprovalHook), _encodedDurationCall, _willReturnDuration);

        // avoid overwrite
        vm.warp(block.timestamp + 1);

        uint256 latestId = block.timestamp;

        // Send: Anotha One! Call from this contract as it's been mock authorized above.
        _rulesets.queueFor({
            projectId: _projectId,
            duration: _duration,
            weight: _weight,
            weightCutPercent: _weightCutPercent,
            approvalHook: _mockApprovalHook,
            metadata: _packedWithApprovalHook,
            mustStartAtOrAfter: block.timestamp
        });

        // avoid overwrite
        vm.warp(block.timestamp + 2 days);
        uint256 previouslyApprovedDurationEnds = block.timestamp + 3 days - 2 days - 1;

        // Mock call to approvalStatusOf and return an approved status
        bytes memory _encodedApprovalCall =
            abi.encodeCall(IJBRulesetApprovalHook.approvalStatusOf, (1, latestId, previouslyApprovedDurationEnds));
        bytes memory _willReturnStatus = abi.encode(JBApprovalStatus.Approved);

        mockExpect(address(_mockApprovalHook), _encodedApprovalCall, _willReturnStatus);

        // Send: Anotha One! Call from this contract as it's been mock authorized above.
        _rulesets.queueFor({
            projectId: _projectId,
            duration: _duration,
            weight: _weight,
            weightCutPercent: _weightCutPercent,
            approvalHook: _mockApprovalHook,
            metadata: _packedWithApprovalHook,
            mustStartAtOrAfter: block.timestamp
        });

        latestId = block.timestamp;

        // avoid overwrite
        vm.warp(block.timestamp + 1);

        previouslyApprovedDurationEnds = block.timestamp + 6 days - 2 days - 2;

        // Mock call to approvalStatusOf and return an approvalExpected status
        _encodedApprovalCall =
            abi.encodeCall(IJBRulesetApprovalHook.approvalStatusOf, (1, latestId, previouslyApprovedDurationEnds));
        _willReturnStatus = abi.encode(JBApprovalStatus.ApprovalExpected);

        mockExpect(address(_mockApprovalHook), _encodedApprovalCall, _willReturnStatus);

        // Send: Anotha One! Call from this contract as it's been mock authorized above.
        _rulesets.queueFor({
            projectId: _projectId,
            duration: _duration,
            weight: _weight,
            weightCutPercent: _weightCutPercent,
            approvalHook: _mockApprovalHook,
            metadata: _packedWithApprovalHook,
            mustStartAtOrAfter: block.timestamp
        });

        latestId = block.timestamp;

        // avoid overwrite
        vm.warp(block.timestamp + 1);
        previouslyApprovedDurationEnds = block.timestamp + 6 days - 2 days - 3;

        // Mock call to approvalStatusOf and return a failed status
        _encodedApprovalCall =
            abi.encodeCall(IJBRulesetApprovalHook.approvalStatusOf, (1, latestId, previouslyApprovedDurationEnds));
        _willReturnStatus = abi.encode(JBApprovalStatus.Failed);

        mockExpect(address(_mockApprovalHook), _encodedApprovalCall, _willReturnStatus);

        // Send: Anotha One! Call from this contract as it's been mock authorized above.
        _rulesets.queueFor({
            projectId: _projectId,
            duration: _duration,
            weight: _weight,
            weightCutPercent: _weightCutPercent,
            approvalHook: _mockApprovalHook,
            metadata: _packedWithApprovalHook,
            mustStartAtOrAfter: block.timestamp
        });

        latestId = block.timestamp;

        // avoid overwrite
        vm.warp(block.timestamp + 1);

        previouslyApprovedDurationEnds = block.timestamp + 6 days - 2 days - 4;

        // Mock call to approvalStatusOf and return an empty status
        _encodedApprovalCall =
            abi.encodeCall(IJBRulesetApprovalHook.approvalStatusOf, (1, latestId, previouslyApprovedDurationEnds));
        _willReturnStatus = abi.encode(JBApprovalStatus.Empty);

        mockExpect(address(_mockApprovalHook), _encodedApprovalCall, _willReturnStatus);

        // Send: Anotha One! Call from this contract as it's been mock authorized above.
        _rulesets.queueFor({
            projectId: _projectId,
            duration: _duration,
            weight: _weight,
            weightCutPercent: _weightCutPercent,
            approvalHook: _mockApprovalHook,
            metadata: _packedWithApprovalHook,
            mustStartAtOrAfter: block.timestamp
        });

        JBRuleset[] memory queuedRulesetsOf = _rulesets.allOf(_projectId, block.timestamp, 3);

        // check: 2 rulesets will be enqueued, we just overwrote the last queued
        assertEq(queuedRulesetsOf.length, 3);
        assertEq(queuedRulesetsOf[0].id, block.timestamp);

        // check first timestamp
        assertEq(queuedRulesetsOf[2].id, firstId);
    }

    function test_WhenCacheIsUpdatedTooSoon() external {
        // the weight cut multiple will be re-used if it's the same.

        // Setup: queueFor will call onlyControllerOf modifier -> Directory.controllerOf to see if caller has proper
        // permissions, encode & mock that.
        bytes memory _encodedCall = abi.encodeCall(IJBDirectory.controllerOf, (1));
        bytes memory _willReturn = abi.encode(address(this));

        mockExpect(address(_directory), _encodedCall, _willReturn);

        _rulesets.queueFor({
            projectId: _projectId,
            duration: 1 days, // 3 days
            weight: 1e18,
            weightCutPercent: JBConstants.MAX_WEIGHT_CUT_PERCENT / 10,
            approvalHook: _hook,
            metadata: _packedMetadata,
            mustStartAtOrAfter: 0
        });

        vm.warp(block.timestamp + (20_000 days));

        // Update the weight cache
        vm.expectEmit();
        emit IJBRulesets.WeightCacheUpdated(_projectId, 0, 20_000, address(this));
        _rulesets.updateRulesetWeightCache(_projectId);

        // Update the weight cache during the same block, which will mirror the previous call.
        vm.expectEmit();
        emit IJBRulesets.WeightCacheUpdated(_projectId, 0, 20_000, address(this));
        _rulesets.updateRulesetWeightCache(_projectId);
    }

    function test_QueueForApprovalHookDNSupportInterface() external {
        //

        // Setup: queueFor will call onlyControllerOf modifier -> Directory.controllerOf to see if caller has proper
        // permissions, mock that call.
        bytes memory _encodedCall = abi.encodeCall(IJBDirectory.controllerOf, (1));
        bytes memory _willReturn = abi.encode(address(this));

        mockExpect(address(_directory), _encodedCall, _willReturn);

        mockExpect(
            address(123),
            abi.encodeCall(IERC165.supportsInterface, (type(IJBRulesetApprovalHook).interfaceId)),
            abi.encode(false)
        );

        // Since hook address is not 0 interface support will be checked.
        vm.expectRevert(
            abi.encodeWithSelector(
                JBRulesets.JBRulesets_InvalidRulesetApprovalHook.selector, (IJBRulesetApprovalHook(address(123)))
            )
        );
        _rulesets.queueFor({
            projectId: _projectId,
            duration: 1 days, // 3 days
            weight: 1e18,
            weightCutPercent: JBConstants.MAX_WEIGHT_CUT_PERCENT / 10,
            approvalHook: IJBRulesetApprovalHook(address(123)),
            metadata: _packedMetadata,
            mustStartAtOrAfter: 0
        });
    }

    function test_QueueForApprovalHookDNSupportInterfaceCatch() external {
        // Setup: queueFor will call onlyControllerOf modifier -> Directory.controllerOf to see if caller has proper
        // permissions, mock that call.
        bytes memory _encodedCall = abi.encodeCall(IJBDirectory.controllerOf, (1));
        bytes memory _willReturn = abi.encode(address(this));

        mockExpect(address(_directory), _encodedCall, _willReturn);

        vm.mockCallRevert(
            address(123), abi.encodeCall(IERC165.supportsInterface, (type(IJBRulesetApprovalHook).interfaceId)), "ERROR"
        );

        // Since hook address is not 0 interface support will be checked.
        vm.expectRevert(
            abi.encodeWithSelector(
                JBRulesets.JBRulesets_InvalidRulesetApprovalHook.selector, (IJBRulesetApprovalHook(address(123)))
            )
        );
        _rulesets.queueFor({
            projectId: _projectId,
            duration: 1 days, // 3 days
            weight: 1e18,
            weightCutPercent: JBConstants.MAX_WEIGHT_CUT_PERCENT / 10,
            approvalHook: IJBRulesetApprovalHook(address(123)),
            metadata: _packedMetadata,
            mustStartAtOrAfter: 0
        });
    }
}
