// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC165} from '@openzeppelin/contracts/utils/introspection/IERC165.sol';
import {JBDidPayData3_2} from './../structs/JBDidPayData3_2.sol';

/// @title Pay delegate
/// @notice Delegate called after JBTerminal.pay(..) logic completion (if passed by the funding cycle datasource)
interface IJBPayDelegate3_2 is IERC165 {
  /// @notice This function is called by JBPaymentTerminal.pay(..), after the execution of its logic
  /// @dev Critical business logic should be protected by an appropriate access control
  /// @param data the data passed by the terminal, as a JBDidPayData3_2 struct:
  function didPay(JBDidPayData3_2 calldata data) external payable;
}
