/// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {IJBDirectory, IJBProjects, IJBSplitHook, IJBSplits, JBConstants, JBControlled, JBPermissionIds, JBPermissioned, JBSplit, JBSplitGroup, JBSplits} from 'src/JBSplits.sol';
import {JBPermissioned} from 'src/abstract/JBPermissioned.sol';
import {IJBDirectory} from 'src/interfaces/IJBDirectory.sol';
import {IJBProjects} from 'src/interfaces/IJBProjects.sol';
import {IJBSplits} from 'src/interfaces/IJBSplits.sol';
import {IJBSplitHook} from 'src/interfaces/IJBSplitHook.sol';
import {JBConstants} from 'src/libraries/JBConstants.sol';
import {JBPermissionIds} from 'src/libraries/JBPermissionIds.sol';
import {JBSplitGroup} from 'src/structs/JBSplitGroup.sol';
import {JBSplit} from 'src/structs/JBSplit.sol';
import {JBControlled} from 'src/abstract/JBControlled.sol';

contract MockJBSplits is JBSplits, Test {

  constructor(IJBDirectory directory) JBSplits(directory) {}
  /// Mocked State Variables
  function set_FALLBACK_RULESET_ID(uint256 _FALLBACK_RULESET_ID) public {
    FALLBACK_RULESET_ID = _FALLBACK_RULESET_ID;
  }
  
  function mock_call_FALLBACK_RULESET_ID(uint256 _FALLBACK_RULESET_ID) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("FALLBACK_RULESET_ID()"),
      abi.encode(_FALLBACK_RULESET_ID)
    );
  }
  
  /// Mocked External Functions
  function mock_call_splitsOf(uint256 projectId, uint256 rulesetId, uint256 groupId, JBSplit[] memory splits) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("splitsOf(uint256,uint256,uint256)", projectId, rulesetId, groupId),
      abi.encode(splits)
    );
  }
  
  function mock_call_setSplitGroupsOf(uint256 projectId, uint256 rulesetId, JBSplitGroup[] calldata splitGroups) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("setSplitGroupsOf(uint256,uint256,JBSplitGroup[])", projectId, rulesetId, splitGroups),
      abi.encode()
    );
  }
  
  /// Mocked Internal Functions

}
