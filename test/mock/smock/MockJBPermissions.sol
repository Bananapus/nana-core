/// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {IJBPermissions, JBPermissionIds, JBPermissioned, JBPermissions, JBPermissionsData} from 'src/JBPermissions.sol';
import {JBPermissioned} from 'src/abstract/JBPermissioned.sol';
import {IJBPermissions} from 'src/interfaces/IJBPermissions.sol';
import {JBPermissionIds} from 'src/libraries/JBPermissionIds.sol';
import {JBPermissionsData} from 'src/structs/JBPermissionsData.sol';

contract MockJBPermissions is JBPermissions, Test {

  constructor() JBPermissions() {}
  /// Mocked State Variables
  function set_permissionsOf(address _key0, address _key1, uint256 _key2, uint256 _value) public {
    permissionsOf[_key0][_key1][_key2] = _value;
  }
  
  function mock_call_permissionsOf(address _key0, address _key1, uint256 _key2, uint256 _value) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("permissionsOf(address,address,uint256)", _key0, _key1, _key2),
      abi.encode(_value)
    );
  }
  
  /// Mocked External Functions
  function mock_call_hasPermission(address operator, address account, uint256 projectId, uint256 permissionId, bool _return0) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("hasPermission(address,address,uint256,uint256)", operator, account, projectId, permissionId),
      abi.encode(_return0)
    );
  }
  
  function mock_call_hasPermissions(address operator, address account, uint256 projectId, uint256[] calldata permissionIds, bool _return0) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("hasPermissions(address,address,uint256,uint256[])", operator, account, projectId, permissionIds),
      abi.encode(_return0)
    );
  }
  
  function mock_call_setPermissionsFor(address account, JBPermissionsData calldata permissionsData) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("setPermissionsFor(address,JBPermissionsData)", account, permissionsData),
      abi.encode()
    );
  }
  
  /// Mocked Internal Functions

}
