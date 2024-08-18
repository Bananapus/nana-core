// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBSplitsSetup} from "./JBSplitsSetup.sol";

contract TestSetSplitGroupsOf_Local is JBSplitsSetup {
    address _notThis = makeAddr("notThis");
    address payable _bene = payable(makeAddr("guy"));
    uint56 _projectId = 1;
    uint256 _rulesetId = block.timestamp;

    function setUp() public {
        super.splitsSetup();
    }

    function test_WhenCallerIsNotController() external {
        // it will revert with CONTROLLER_UNAUTHORIZED

        // data for call
        JBSplitGroup[] memory _splitsGroup = new JBSplitGroup[](1);
        JBSplit[] memory _splitsArray = new JBSplit[](1);

        // Set up a payout split recipient.
        _splitsArray[0] = JBSplit({
            preferAddToBalance: false,
            percent: JBConstants.SPLITS_TOTAL_PERCENT / 2,
            projectId: _projectId,
            beneficiary: _bene,
            lockedUntil: 0,
            hook: IJBSplitHook(address(0))
        });

        // outer structure
        _splitsGroup[0] = JBSplitGroup({groupId: 0, splits: _splitsArray});

        // mock the directory controllerOf call
        bytes memory _controllerCall = abi.encodeCall(IJBDirectory.controllerOf, (1));
        bytes memory _return = abi.encode(_notThis);
        mockExpect(address(directory), _controllerCall, _return);

        // not controller so revert
        vm.expectRevert(JBControlled.JBControlled_ControllerUnauthorized.selector);
        _splits.setSplitGroupsOf(_projectId, _rulesetId, _splitsGroup);
    }

    modifier whenCallerIsController() {
        // mock the directory controllerOf call
        bytes memory _controllerCall = abi.encodeCall(IJBDirectory.controllerOf, (1));
        bytes memory _return = abi.encode(address(this));
        mockExpect(address(directory), _controllerCall, _return);
        _;
    }

    function test_GivenPreviouslyLockedSplitsAreNotIncluded() external whenCallerIsController {
        // it will revert with PREVIOUS_LOCKED_SPLITS_NOT_INCLUDED

        // data for first call to set locked splits
        JBSplitGroup[] memory _splitsGroup = new JBSplitGroup[](1);
        JBSplit[] memory _splitsArray = new JBSplit[](1);

        // Set up a payout split recipient.
        _splitsArray[0] = JBSplit({
            preferAddToBalance: false,
            percent: JBConstants.SPLITS_TOTAL_PERCENT / 2,
            projectId: _projectId,
            beneficiary: _bene,
            lockedUntil: uint48(block.timestamp + 100),
            hook: IJBSplitHook(address(0))
        });

        // outer structure
        _splitsGroup[0] = JBSplitGroup({groupId: 0, splits: _splitsArray});

        _splits.setSplitGroupsOf(_projectId, _rulesetId, _splitsGroup);

        // Re-set up a payout split recipient.
        _splitsArray[0] = JBSplit({
            preferAddToBalance: false,
            percent: JBConstants.SPLITS_TOTAL_PERCENT / 2,
            projectId: _projectId,
            beneficiary: _bene,
            lockedUntil: 0,
            hook: IJBSplitHook(address(0))
        });

        // outer structure
        _splitsGroup[0] = JBSplitGroup({groupId: 0, splits: _splitsArray});

        vm.expectRevert(abi.encodeWithSignature("PREVIOUS_LOCKED_SPLITS_NOT_INCLUDED()"));
        _splits.setSplitGroupsOf(_projectId, _rulesetId, _splitsGroup);
    }

    function test_GivenAnyConfiguredSplitPercentIsZero() external whenCallerIsController {
        // it will revert with INVALID_SPLIT_PERCENT

        // data for call to set invalid splits
        JBSplitGroup[] memory _splitsGroup = new JBSplitGroup[](1);
        JBSplit[] memory _splitsArray = new JBSplit[](1);

        // Set up a payout split recipient.
        _splitsArray[0] = JBSplit({
            preferAddToBalance: false,
            // invalid percent
            percent: 0,
            projectId: _projectId,
            beneficiary: _bene,
            lockedUntil: 0,
            hook: IJBSplitHook(address(0))
        });

        // outer structure
        _splitsGroup[0] = JBSplitGroup({groupId: 0, splits: _splitsArray});

        vm.expectRevert(abi.encodeWithSignature("INVALID_SPLIT_PERCENT()"));
        _splits.setSplitGroupsOf(_projectId, _rulesetId, _splitsGroup);
    }

    function test_GivenSplitsTotalToGtSPLITS_TOTAL_PERCENT() external whenCallerIsController {
        // it will revert with INVALID_TOTAL_PERCENT

        // data for call with total percent > 100
        JBSplitGroup[] memory _splitsGroup = new JBSplitGroup[](1);
        JBSplit[] memory _splitsArray = new JBSplit[](2);

        // Set up a payout split recipient.
        _splitsArray[0] = JBSplit({
            preferAddToBalance: false,
            percent: JBConstants.SPLITS_TOTAL_PERCENT / 2,
            projectId: _projectId,
            beneficiary: _bene,
            lockedUntil: 0,
            hook: IJBSplitHook(address(0))
        });

        // Set up a second payout split recipient.
        _splitsArray[1] = JBSplit({
            preferAddToBalance: false,
            percent: JBConstants.SPLITS_TOTAL_PERCENT,
            projectId: _projectId,
            beneficiary: _bene,
            lockedUntil: 0,
            hook: IJBSplitHook(address(0))
        });

        // outer structure
        _splitsGroup[0] = JBSplitGroup({groupId: 0, splits: _splitsArray});

        vm.expectRevert(abi.encodeWithSignature("INVALID_TOTAL_PERCENT()"));
        _splits.setSplitGroupsOf(_projectId, _rulesetId, _splitsGroup);
    }

    function test_HappyPath() external whenCallerIsController {
        // it will store splits and emit SetSplit for each configured

        // data for call
        JBSplitGroup[] memory _splitsGroup = new JBSplitGroup[](1);
        JBSplit[] memory _splitsArray = new JBSplit[](2);

        // Set up a valid payout split recipient.
        _splitsArray[0] = JBSplit({
            preferAddToBalance: false,
            percent: JBConstants.SPLITS_TOTAL_PERCENT / 2,
            projectId: _projectId,
            beneficiary: _bene,
            lockedUntil: 0,
            hook: IJBSplitHook(address(0))
        });

        // Set up a second valid payout split recipient.
        _splitsArray[1] = JBSplit({
            preferAddToBalance: false,
            percent: JBConstants.SPLITS_TOTAL_PERCENT / 2,
            projectId: _projectId,
            beneficiary: payable(makeAddr("anotherBene")),
            lockedUntil: 0,
            hook: IJBSplitHook(address(0))
        });

        // outer structure
        _splitsGroup[0] = JBSplitGroup({groupId: 0, splits: _splitsArray});

        // should emit an event for each split
        vm.expectEmit();
        emit IJBSplits.SetSplit(_projectId, block.timestamp, 0, _splitsArray[0], address(this));

        vm.expectEmit();
        emit IJBSplits.SetSplit(_projectId, block.timestamp, 0, _splitsArray[1], address(this));

        _splits.setSplitGroupsOf(_projectId, _rulesetId, _splitsGroup);
    }

    function test_GivenSettingExistingIdDomainAndGroup() external whenCallerIsController {
        // it will overwrite

        // data for call
        JBSplitGroup[] memory _splitsGroup = new JBSplitGroup[](1);
        JBSplit[] memory _splitsArray = new JBSplit[](1);

        // Set up a payout split recipient.
        _splitsArray[0] = JBSplit({
            preferAddToBalance: false,
            percent: JBConstants.SPLITS_TOTAL_PERCENT / 2,
            projectId: _projectId,
            beneficiary: _bene,
            lockedUntil: 0,
            hook: IJBSplitHook(address(0))
        });

        // outer structure
        _splitsGroup[0] = JBSplitGroup({groupId: 0, splits: _splitsArray});

        vm.expectEmit();
        emit IJBSplits.SetSplit(_projectId, block.timestamp, 0, _splitsArray[0], address(this));

        _splits.setSplitGroupsOf(_projectId, _rulesetId, _splitsGroup);

        // Second or "reconfig" call

        // Re-Set up a payout split recipient.
        _splitsArray[0] = JBSplit({
            // Different attributes
            preferAddToBalance: true,
            percent: JBConstants.SPLITS_TOTAL_PERCENT / 3,
            projectId: _projectId,
            beneficiary: _bene,
            lockedUntil: 0,
            hook: IJBSplitHook(address(0))
        });

        // outer structure
        _splitsGroup[0] = JBSplitGroup({groupId: 0, splits: _splitsArray});

        vm.expectEmit();
        emit IJBSplits.SetSplit(_projectId, block.timestamp, 0, _splitsArray[0], address(this));

        _splits.setSplitGroupsOf(_projectId, block.timestamp, _splitsGroup);

        JBSplit[] memory _current = _splits.splitsOf(_projectId, block.timestamp, 0);

        assertEq(_current[0].preferAddToBalance, true);
    }

    function test_GivenAddingNewLockedSplitsIncludingPreviouslyLocked() external whenCallerIsController {
        // it will reconfigure and extend previously locked splits

        // data for call
        JBSplitGroup[] memory _splitsGroup = new JBSplitGroup[](1);
        JBSplit[] memory _splitsArray = new JBSplit[](1);

        // Set up a payout split recipient.
        _splitsArray[0] = JBSplit({
            preferAddToBalance: false,
            percent: JBConstants.SPLITS_TOTAL_PERCENT / 2,
            projectId: _projectId,
            beneficiary: _bene,
            lockedUntil: uint48(block.timestamp + 100),
            hook: IJBSplitHook(address(0))
        });

        // outer structure
        _splitsGroup[0] = JBSplitGroup({groupId: 0, splits: _splitsArray});

        vm.expectEmit();
        emit IJBSplits.SetSplit(_projectId, block.timestamp, 0, _splitsArray[0], address(this));

        _splits.setSplitGroupsOf(_projectId, _rulesetId, _splitsGroup);

        // Second or "reconfig" call

        JBSplit[] memory _splitsArray2 = new JBSplit[](2);

        // Re-Set up a payout split recipient.
        _splitsArray2[0] = JBSplit({
            preferAddToBalance: false,
            percent: JBConstants.SPLITS_TOTAL_PERCENT / 2,
            projectId: _projectId,
            beneficiary: _bene,
            lockedUntil: uint48(block.timestamp + 100),
            hook: IJBSplitHook(address(0))
        });

        // Re-Set up a payout split recipient.
        _splitsArray2[1] = JBSplit({
            preferAddToBalance: true,
            percent: JBConstants.SPLITS_TOTAL_PERCENT / 2,
            projectId: _projectId,
            beneficiary: _bene,
            lockedUntil: uint48(block.timestamp + 200),
            hook: IJBSplitHook(address(0))
        });

        // outer structure
        _splitsGroup[0] = JBSplitGroup({groupId: 0, splits: _splitsArray2});

        vm.expectEmit();
        emit IJBSplits.SetSplit(_projectId, block.timestamp, 0, _splitsArray2[0], address(this));

        _splits.setSplitGroupsOf(_projectId, block.timestamp, _splitsGroup);

        JBSplit[] memory _current = _splits.splitsOf(_projectId, block.timestamp, 0);

        assertEq(_current[0].lockedUntil, block.timestamp + 100);
        assertEq(_current[1].lockedUntil, block.timestamp + 200);
    }

    function test_GivenOverwritingExistingLockedSplitWithReorderedGroup() external whenCallerIsController {
        // it will overwrite

        // data for call
        JBSplitGroup[] memory _splitsGroup = new JBSplitGroup[](1);
        JBSplit[] memory _splitsArray = new JBSplit[](1);

        // Set up a payout split recipient.
        _splitsArray[0] = JBSplit({
            preferAddToBalance: false,
            percent: JBConstants.SPLITS_TOTAL_PERCENT / 2,
            projectId: _projectId,
            beneficiary: _bene,
            lockedUntil: uint48(block.timestamp + 100),
            hook: IJBSplitHook(address(0))
        });

        // outer structure
        _splitsGroup[0] = JBSplitGroup({groupId: 0, splits: _splitsArray});

        vm.expectEmit();
        emit IJBSplits.SetSplit(_projectId, block.timestamp, 0, _splitsArray[0], address(this));

        _splits.setSplitGroupsOf(_projectId, _rulesetId, _splitsGroup);

        // Second or "reconfig" call
        JBSplitGroup[] memory _secondSplitsGroup = new JBSplitGroup[](1);
        JBSplit[] memory _secondSplitsArray = new JBSplit[](2);

        // Re-Set up a payout split recipient.
        _secondSplitsArray[1] = JBSplit({
            preferAddToBalance: false,
            percent: JBConstants.SPLITS_TOTAL_PERCENT / 2,
            projectId: _projectId,
            beneficiary: _bene,
            lockedUntil: uint48(block.timestamp + 100),
            hook: IJBSplitHook(address(0))
        });

        _secondSplitsArray[0] = JBSplit({
            preferAddToBalance: false,
            percent: JBConstants.SPLITS_TOTAL_PERCENT / 2,
            projectId: _projectId,
            beneficiary: _bene,
            lockedUntil: 0,
            hook: IJBSplitHook(address(0))
        });

        // outer structure
        _secondSplitsGroup[0] = JBSplitGroup({groupId: 0, splits: _secondSplitsArray});

        vm.expectEmit();
        emit IJBSplits.SetSplit(_projectId, block.timestamp, 0, _secondSplitsArray[0], address(this));
        emit IJBSplits.SetSplit(_projectId, block.timestamp, 0, _secondSplitsArray[1], address(this));

        _splits.setSplitGroupsOf(_projectId, block.timestamp, _secondSplitsGroup);

        JBSplit[] memory _current = _splits.splitsOf(_projectId, block.timestamp, 0);

        assertEq(_current[0].preferAddToBalance, false);
    }
}
