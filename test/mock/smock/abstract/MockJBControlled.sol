/// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {IJBControlled, IJBDirectory, JBControlled} from 'src/abstract/JBControlled.sol';
import {IJBControlled} from 'src/interfaces/IJBControlled.sol';
import {IJBDirectory} from 'src/interfaces/IJBDirectory.sol';

contract MockJBControlled is JBControlled, Test {

  constructor(IJBDirectory directory) JBControlled(directory) {}
  /// Mocked State Variables
  /// Mocked External Functions
  /// Mocked Internal Functions

}
