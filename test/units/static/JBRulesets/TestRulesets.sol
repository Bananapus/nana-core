// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";

/**
 * @title
 */
contract TestJBRulesetsUnits_Local is JBTest {
    // Events
    event RulesetQueued(
        uint256 indexed rulesetId,
        uint256 indexed projectId,
        uint256 duration,
        uint256 weight,
        uint256 decayRate,
        IJBRulesetApprovalHook hook,
        uint256 metadata,
        uint256 mustStartAtOrAfter,
        address caller
    );

    event RulesetInitialized(uint256 indexed rulesetId, uint256 indexed projectId, uint256 indexed basedOnId);

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
    uint256 _projectId = 1;
    uint256 _duration = 3 days;
    uint256 _weight = 0;
    uint256 _decayRate = 450_000_000;
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
                    queued.decayRate,
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
                        stored.decayRate,
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
            reservedRate: 0,
            redemptionRate: 0,
            baseCurrency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
            pausePay: false,
            pauseCreditTransfers: false,
            allowOwnerMinting: false,
            allowTerminalMigration: false,
            allowSetTerminals: false,
            allowControllerMigration: false,
            allowSetController: false,
            holdFees: false,
            useTotalSurplusForRedemptions: false,
            useDataHookForPay: false,
            useDataHookForRedeem: false,
            dataHook: address(0),
            metadata: 0
        });

        // Params for tests
        _metadataWithApprovalHook = JBRulesetMetadata({
            reservedRate: 0,
            redemptionRate: 0,
            baseCurrency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
            pausePay: false,
            pauseCreditTransfers: false,
            allowOwnerMinting: false,
            allowTerminalMigration: false,
            allowSetTerminals: false,
            allowControllerMigration: false,
            allowSetController: false,
            holdFees: false,
            useTotalSurplusForRedemptions: false,
            useDataHookForPay: false,
            useDataHookForRedeem: false,
            dataHook: address(_mockApprovalHook),
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
        emit RulesetQueued(
            block.timestamp,
            _projectId,
            _duration,
            _weight,
            _decayRate,
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
            decayRate: _decayRate,
            approvalHook: _hook,
            metadata: _packedMetadata,
            mustStartAtOrAfter: _mustStartAt
        });

        // Get a reference to the now configured ruleset.
        JBRuleset memory configuredRuleset = _rulesets.currentOf(_projectId);

        // Reference queued attributes for sake of comparison.
        JBRuleset memory queued = JBRuleset({
            cycleNumber: 1,
            id: block.timestamp,
            basedOnId: 0,
            start: block.timestamp,
            duration: _duration,
            weight: _weight,
            decayRate: _decayRate,
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
        emit RulesetQueued(
            block.timestamp,
            _projectId,
            _duration,
            _weight,
            _decayRate,
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
            decayRate: _decayRate,
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
            id: block.timestamp,
            basedOnId: 0,
            start: block.timestamp,
            duration: _duration,
            weight: _weight,
            decayRate: _decayRate,
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

        vm.expectRevert(abi.encodeWithSignature("INVALID_RULESET_DURATION()"));

        // Send: Call from this contract as it's been mock authorized above.
        _rulesets.queueFor({
            projectId: _projectId,
            duration: _invalidDuration,
            weight: _weight,
            decayRate: _decayRate,
            approvalHook: _hook,
            metadata: _packedMetadata,
            mustStartAtOrAfter: _mustStartAt
        });
    }

    function testQueueForInvalidDecayRate() public {
        uint256 _invalidDecayRate = JBConstants.MAX_DECAY_RATE + 1;

        // Setup: queueFor will call onlyControllerOf modifier -> Directory.controllerOf to see if caller has proper
        // permissions, encode & mock that.
        bytes memory _encodedCall = abi.encodeCall(IJBDirectory.controllerOf, (1));
        bytes memory _willReturn = abi.encode(address(this));

        mockExpect(address(_directory), _encodedCall, _willReturn);

        vm.expectRevert(abi.encodeWithSignature("INVALID_DECAY_RATE()"));

        // Send: Call from this contract as it's been mock authorized above.
        _rulesets.queueFor({
            projectId: _projectId,
            duration: _duration,
            weight: _weight,
            decayRate: _invalidDecayRate,
            approvalHook: _hook,
            metadata: _packedMetadata,
            mustStartAtOrAfter: _mustStartAt
        });
    }

    function testQueueForInvalidWeight() public {
        uint256 _invalidWeight = uint256(type(uint88).max) + 1;

        // Setup: queueFor will call onlyControllerOf modifier -> Directory.controllerOf to see if caller has proper
        // permissions, encode & mock that.
        bytes memory _encodedCall = abi.encodeCall(IJBDirectory.controllerOf, (1));
        bytes memory _willReturn = abi.encode(address(this));

        mockExpect(address(_directory), _encodedCall, _willReturn);

        vm.expectRevert(abi.encodeWithSignature("INVALID_WEIGHT()"));

        // Send: Call from this contract as it's been mock authorized above.
        _rulesets.queueFor({
            projectId: _projectId,
            duration: _duration,
            weight: _invalidWeight,
            decayRate: _decayRate,
            approvalHook: _hook,
            metadata: _packedMetadata,
            mustStartAtOrAfter: _mustStartAt
        });
    }

    function testFuzzQueueForInvalidEndTime(uint256 _bigDuration, uint256 _bigStartAt) public {
        _bigDuration = bound(_bigDuration, 1, type(uint32).max);

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

        if (_bigDuration + _bigStartAt > type(uint56).max) {
            vm.expectRevert(abi.encodeWithSignature("INVALID_RULESET_END_TIME()"));
        }

        // Send: Call from this contract as it's been mock authorized above.
        _rulesets.queueFor({
            projectId: _projectId,
            duration: _bigDuration,
            weight: _weight,
            decayRate: _decayRate,
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
        vm.expectRevert(abi.encodeWithSignature("INVALID_RULESET_APPROVAL_HOOK()"));

        // Send: Call from this contract as it's been mock authorized above.
        _rulesets.queueFor({
            projectId: _projectId,
            duration: _duration,
            weight: _weight,
            decayRate: _decayRate,
            approvalHook: _mockApprovalHook,
            metadata: _packedWithApprovalHook,
            mustStartAtOrAfter: _mustStartAt
        });

        // try another with any length of code deployed and mock interface support to pass other checks
        deployCodeTo("MockPriceFeed.sol", abi.encode(1, 18), address(_mockApprovalHook));

        bytes memory _encodedCall3 = abi.encodeCall(IERC165.supportsInterface, (type(IJBRulesetApprovalHook).interfaceId));
        bytes memory _willReturn3 = abi.encode(true);

        mockExpect(address(_mockApprovalHook), _encodedCall3, _willReturn3);

        // Send: Call from this contract as it's been mock authorized above.
        _rulesets.queueFor({
            projectId: _projectId,
            duration: _duration,
            weight: _weight,
            decayRate: _decayRate,
            approvalHook: _mockApprovalHook,
            metadata: _packedWithApprovalHook,
            mustStartAtOrAfter: _mustStartAt
        });

        // Mock call to approval hook duration
        bytes memory _encodedDurationCall = abi.encodeCall(IJBRulesetApprovalHook.DURATION, ());
        bytes memory _willReturnDuration = abi.encode(_hookDuration);

        mockExpect(address(_mockApprovalHook), _encodedDurationCall, _willReturnDuration);

        // avoid overwrite
        vm.warp(block.timestamp + 1);

        // Send: Anotha One! Call from this contract as it's been mock authorized above.
        _rulesets.queueFor({
            projectId: _projectId,
            duration: _duration,
            weight: _weight,
            decayRate: _decayRate,
            approvalHook: _mockApprovalHook,
            metadata: _packedWithApprovalHook,
            mustStartAtOrAfter: block.timestamp
        });

        // avoid overwrite
        vm.warp(block.timestamp + 2 days);

        JBRuleset[] memory queuedRulesetsOf =_rulesets.queuedRulesetsOf(_projectId);
        uint256 rulesetId = queuedRulesetsOf[0].id;
        uint256 previouslyApprovedDurationEnds = block.timestamp + 3 days - 2 days - 1;

        // check: 1 ruleset will be enqueued
        assertEq(queuedRulesetsOf.length, 1);

        // Mock call to approvalStatusOf and return an approved status
        bytes memory _encodedApprovalCall = abi.encodeCall(IJBRulesetApprovalHook.approvalStatusOf, (1, rulesetId, previouslyApprovedDurationEnds));
        bytes memory _willReturnStatus = abi.encode(JBApprovalStatus.Approved);

        mockExpect(address(_mockApprovalHook), _encodedApprovalCall, _willReturnStatus);

        // Send: Anotha One! Call from this contract as it's been mock authorized above.
        _rulesets.queueFor({
            projectId: _projectId,
            duration: _duration,
            weight: _weight,
            decayRate: _decayRate,
            approvalHook: _mockApprovalHook,
            metadata: _packedWithApprovalHook,
            mustStartAtOrAfter: block.timestamp
        });
        
        queuedRulesetsOf =_rulesets.queuedRulesetsOf(_projectId);

        // check: 2 rulesets will be enqueued
        assertEq(queuedRulesetsOf.length, 2);

        // avoid overwrite
        vm.warp(block.timestamp + 1);

        queuedRulesetsOf =_rulesets.queuedRulesetsOf(_projectId);
        rulesetId = queuedRulesetsOf[1].id;
        previouslyApprovedDurationEnds = block.timestamp + 6 days - 2 days - 2;

        // Mock call to approvalStatusOf and return an approvalExpected status
        _encodedApprovalCall = abi.encodeCall(IJBRulesetApprovalHook.approvalStatusOf, (1, rulesetId, previouslyApprovedDurationEnds));
        _willReturnStatus = abi.encode(JBApprovalStatus.ApprovalExpected);

        mockExpect(address(_mockApprovalHook), _encodedApprovalCall, _willReturnStatus);

        // Send: Anotha One! Call from this contract as it's been mock authorized above.
        _rulesets.queueFor({
            projectId: _projectId,
            duration: _duration,
            weight: _weight,
            decayRate: _decayRate,
            approvalHook: _mockApprovalHook,
            metadata: _packedWithApprovalHook,
            mustStartAtOrAfter: block.timestamp
        });
        
        queuedRulesetsOf =_rulesets.queuedRulesetsOf(_projectId);

        // check: 2 rulesets will be enqueued, we just overwrote the last queued
        assertEq(queuedRulesetsOf.length, 2);
        assertEq(queuedRulesetsOf[1].id, block.timestamp);

        // avoid overwrite
        vm.warp(block.timestamp + 1);

        queuedRulesetsOf =_rulesets.queuedRulesetsOf(_projectId);
        rulesetId = queuedRulesetsOf[1].id;
        previouslyApprovedDurationEnds = block.timestamp + 6 days - 2 days - 3;

        // Mock call to approvalStatusOf and return a failed status
        _encodedApprovalCall = abi.encodeCall(IJBRulesetApprovalHook.approvalStatusOf, (1, rulesetId, previouslyApprovedDurationEnds));
        _willReturnStatus = abi.encode(JBApprovalStatus.Failed);

        mockExpect(address(_mockApprovalHook), _encodedApprovalCall, _willReturnStatus);

        // Send: Anotha One! Call from this contract as it's been mock authorized above.
        _rulesets.queueFor({
            projectId: _projectId,
            duration: _duration,
            weight: _weight,
            decayRate: _decayRate,
            approvalHook: _mockApprovalHook,
            metadata: _packedWithApprovalHook,
            mustStartAtOrAfter: block.timestamp
        });
        
        queuedRulesetsOf =_rulesets.queuedRulesetsOf(_projectId);

        // check: 2 rulesets will be enqueued, we just overwrote the last queued
        assertEq(queuedRulesetsOf.length, 2);
        assertEq(queuedRulesetsOf[1].id, block.timestamp);

        // avoid overwrite
        vm.warp(block.timestamp + 1);

        queuedRulesetsOf =_rulesets.queuedRulesetsOf(_projectId);
        rulesetId = queuedRulesetsOf[1].id;
        previouslyApprovedDurationEnds = block.timestamp + 6 days - 2 days - 4;

        // Mock call to approvalStatusOf and return an empty status
        _encodedApprovalCall = abi.encodeCall(IJBRulesetApprovalHook.approvalStatusOf, (1, rulesetId, previouslyApprovedDurationEnds));
        _willReturnStatus = abi.encode(JBApprovalStatus.Empty);

        mockExpect(address(_mockApprovalHook), _encodedApprovalCall, _willReturnStatus);

        // Send: Anotha One! Call from this contract as it's been mock authorized above.
        _rulesets.queueFor({
            projectId: _projectId,
            duration: _duration,
            weight: _weight,
            decayRate: _decayRate,
            approvalHook: _mockApprovalHook,
            metadata: _packedWithApprovalHook,
            mustStartAtOrAfter: block.timestamp
        });
        
        queuedRulesetsOf =_rulesets.queuedRulesetsOf(_projectId);

        // check: 2 rulesets will be enqueued, we just overwrote the last queued
        assertEq(queuedRulesetsOf.length, 2);
        assertEq(queuedRulesetsOf[1].id, block.timestamp);
    }
}
