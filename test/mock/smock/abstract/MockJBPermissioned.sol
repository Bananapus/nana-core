/// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {Context, IJBPermissioned, IJBPermissions, JBPermissioned} from 'src/abstract/JBPermissioned.sol';
import {Context} from 'lib/openzeppelin-contracts/contracts/utils/Context.sol';
import {IJBPermissioned} from 'src/interfaces/IJBPermissioned.sol';
import {IJBPermissions} from 'src/interfaces/IJBPermissions.sol';

contract MockJBPermissioned is JBPermissioned, Test {

  constructor(IJBPermissions permissions) JBPermissioned(permissions) {}
  /// Mocked State Variables
  /// Mocked External Functions
  /// Mocked Internal Functions

}
