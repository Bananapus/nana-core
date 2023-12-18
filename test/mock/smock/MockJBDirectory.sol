/// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {IERC165, IJBDirectory, IJBDirectoryAccessControl, IJBPermissions, IJBProjects, IJBTerminal, JBDirectory, JBPermissionIds, JBPermissioned, JBRuleset, JBRulesetMetadataResolver, Ownable} from 'src/JBDirectory.sol';
import {Ownable} from 'lib/openzeppelin-contracts/contracts/access/Ownable.sol';
import {IERC165} from 'lib/openzeppelin-contracts/contracts/utils/introspection/IERC165.sol';
import {JBPermissioned} from 'src/abstract/JBPermissioned.sol';
import {IJBDirectory} from 'src/interfaces/IJBDirectory.sol';
import {IJBDirectoryAccessControl} from 'src/interfaces/IJBDirectoryAccessControl.sol';
import {IJBPermissions} from 'src/interfaces/IJBPermissions.sol';
import {IJBTerminal} from 'src/interfaces/terminal/IJBTerminal.sol';
import {IJBProjects} from 'src/interfaces/IJBProjects.sol';
import {JBRulesetMetadataResolver} from 'src/libraries/JBRulesetMetadataResolver.sol';
import {JBPermissionIds} from 'src/libraries/JBPermissionIds.sol';
import {JBRuleset} from 'src/structs/JBRuleset.sol';

contract MockJBDirectory is JBDirectory, Test {

  constructor(IJBPermissions permissions, IJBProjects projects, address owner) JBDirectory(permissions, projects, owner) {}
  /// Mocked State Variables
  function set_controllerOf(uint256 _key0, IERC165 _value) public {
    controllerOf[_key0] = _value;
  }
  
  function mock_call_controllerOf(uint256 _key0, IERC165 _value) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("controllerOf(uint256)", _key0),
      abi.encode(_value)
    );
  }
  
  function set_isAllowedToSetFirstController(address _key0, bool _value) public {
    isAllowedToSetFirstController[_key0] = _value;
  }
  
  function mock_call_isAllowedToSetFirstController(address _key0, bool _value) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("isAllowedToSetFirstController(address)", _key0),
      abi.encode(_value)
    );
  }
  
  /// Mocked External Functions
  function mock_call_terminalsOf(uint256 projectId, IJBTerminal[] memory _return0) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("terminalsOf(uint256)", projectId),
      abi.encode(_return0)
    );
  }
  
  function mock_call_primaryTerminalOf(uint256 projectId, address token, IJBTerminal _return0) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("primaryTerminalOf(uint256,address)", projectId, token),
      abi.encode(_return0)
    );
  }
  
  function mock_call_isTerminalOf(uint256 projectId, IJBTerminal terminal, bool _return0) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("isTerminalOf(uint256,IJBTerminal)", projectId, terminal),
      abi.encode(_return0)
    );
  }
  
  function mock_call_setControllerOf(uint256 projectId, IERC165 controller) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("setControllerOf(uint256,IERC165)", projectId, controller),
      abi.encode()
    );
  }
  
  function mock_call_setTerminalsOf(uint256 projectId, IJBTerminal[] calldata terminals) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("setTerminalsOf(uint256,IJBTerminal[])", projectId, terminals),
      abi.encode()
    );
  }
  
  function mock_call_setPrimaryTerminalOf(uint256 projectId, address token, IJBTerminal terminal) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("setPrimaryTerminalOf(uint256,address,IJBTerminal)", projectId, token, terminal),
      abi.encode()
    );
  }
  
  function mock_call_setIsAllowedToSetFirstController(address addr, bool flag) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("setIsAllowedToSetFirstController(address,bool)", addr, flag),
      abi.encode()
    );
  }
  
  /// Mocked Internal Functions

}
