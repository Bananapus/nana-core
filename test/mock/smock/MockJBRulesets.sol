/// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {IJBDirectory, IJBRulesetApprovalHook, IJBRulesets, JBApprovalStatus, JBConstants, JBControlled, JBRuleset, JBRulesetWeightCache, JBRulesets, mulDiv} from 'src/JBRulesets.sol';
import {mulDiv} from 'lib/prb-math/src/Common.sol';
import {JBControlled} from 'src/abstract/JBControlled.sol';
import {JBApprovalStatus} from 'src/enums/JBApprovalStatus.sol';
import {JBConstants} from 'src/libraries/JBConstants.sol';
import {IJBDirectory} from 'src/interfaces/IJBDirectory.sol';
import {IJBRulesetApprovalHook} from 'src/interfaces/IJBRulesetApprovalHook.sol';
import {IJBRulesets} from 'src/interfaces/IJBRulesets.sol';
import {JBRuleset} from 'src/structs/JBRuleset.sol';
import {JBRulesetWeightCache} from 'src/structs/JBRulesetWeightCache.sol';

contract MockJBRulesets is JBRulesets, Test {

  constructor(IJBDirectory directory) JBRulesets(directory) {}
  /// Mocked State Variables
  function set_latestRulesetIdOf(uint256 _key0, uint256 _value) public {
    latestRulesetIdOf[_key0] = _value;
  }
  
  function mock_call_latestRulesetIdOf(uint256 _key0, uint256 _value) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("latestRulesetIdOf(uint256)", _key0),
      abi.encode(_value)
    );
  }
  
  /// Mocked External Functions
  function mock_call_getRulesetOf(uint256 projectId, uint256 rulesetId, JBRuleset memory ruleset) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("getRulesetOf(uint256,uint256)", projectId, rulesetId),
      abi.encode(ruleset)
    );
  }
  
  function mock_call_latestQueuedRulesetOf(uint256 projectId, JBRuleset memory ruleset, JBApprovalStatus approvalStatus) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("latestQueuedRulesetOf(uint256)", projectId),
      abi.encode(ruleset, approvalStatus)
    );
  }
  
  function mock_call_upcomingRulesetOf(uint256 projectId, JBRuleset memory ruleset) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("upcomingRulesetOf(uint256)", projectId),
      abi.encode(ruleset)
    );
  }
  
  function mock_call_currentOf(uint256 projectId, JBRuleset memory ruleset) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("currentOf(uint256)", projectId),
      abi.encode(ruleset)
    );
  }
  
  function mock_call_currentApprovalStatusForLatestRulesetOf(uint256 projectId, JBApprovalStatus _return0) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("currentApprovalStatusForLatestRulesetOf(uint256)", projectId),
      abi.encode(_return0)
    );
  }
  
  function mock_call_queueFor(uint256 projectId, uint256 duration, uint256 weight, uint256 decayRate, IJBRulesetApprovalHook approvalHook, uint256 metadata, uint256 mustStartAtOrAfter, JBRuleset memory _return0) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("queueFor(uint256,uint256,uint256,uint256,IJBRulesetApprovalHook,uint256,uint256)", projectId, duration, weight, decayRate, approvalHook, metadata, mustStartAtOrAfter),
      abi.encode(_return0)
    );
  }
  
  function mock_call_updateRulesetWeightCache(uint256 projectId) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("updateRulesetWeightCache(uint256)", projectId),
      abi.encode()
    );
  }
  
  /// Mocked Internal Functions

}
