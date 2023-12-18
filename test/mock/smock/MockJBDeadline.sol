/// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {ERC165, IERC165, IJBRulesetApprovalHook, JBApprovalStatus, JBDeadline, JBRuleset} from 'src/JBDeadline.sol';
import {ERC165} from 'lib/openzeppelin-contracts/contracts/utils/introspection/ERC165.sol';
import {IERC165} from 'lib/openzeppelin-contracts/contracts/utils/introspection/IERC165.sol';
import {JBApprovalStatus} from 'src/enums/JBApprovalStatus.sol';
import {IJBRulesetApprovalHook} from 'src/interfaces/IJBRulesetApprovalHook.sol';
import {JBRuleset} from 'src/structs/JBRuleset.sol';

contract MockJBDeadline is JBDeadline, Test {

  constructor(uint256 duration) JBDeadline(duration) {}
  /// Mocked State Variables
  /// Mocked External Functions
  function mock_call_approvalStatusOf(uint256 projectId, uint256 rulesetId, uint256 start, JBApprovalStatus _return0) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("approvalStatusOf(uint256,uint256,uint256)", projectId, rulesetId, start),
      abi.encode(_return0)
    );
  }
  
  function mock_call_supportsInterface(bytes4 interfaceId, bool _return0) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("supportsInterface(bytes4)", interfaceId),
      abi.encode(_return0)
    );
  }
  
  /// Mocked Internal Functions

}
