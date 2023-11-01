// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC165} from '@openzeppelin/contracts/utils/introspection/IERC165.sol';
import {JBFundAccessConstraints3_1} from './../structs/JBFundAccessConstraints3_1.sol';
import {JBCurrencyAmount} from './../structs/JBCurrencyAmount.sol';
import {IJBPaymentTerminal} from './IJBPaymentTerminal.sol';

interface IJBFundAccessConstraintsStore3_1 is IERC165 {
  event SetFundAccessConstraints(
    uint256 indexed fundingCycleConfiguration,
    uint256 indexed projectId,
    JBFundAccessConstraints3_1 constraints,
    address caller
  );

  function distributionLimitsOf(
    uint256 projectId,
    uint256 configuration,
    IJBPaymentTerminal terminal,
    address token
  ) external view returns (JBCurrencyAmount[] memory distributionLimits);

  function distributionLimitOf(
    uint256 projectId,
    uint256 configuration,
    IJBPaymentTerminal terminal,
    address token,
    uint256 currency
  ) external view returns (uint256 distributionLimit);

  function overflowAllowancesOf(
    uint256 projectId,
    uint256 configuration,
    IJBPaymentTerminal terminal,
    address token
  ) external view returns (JBCurrencyAmount[] memory overflowAllowances);

  function overflowAllowanceOf(
    uint256 projectId,
    uint256 configuration,
    IJBPaymentTerminal terminal,
    address token,
    uint256 currency
  ) external view returns (uint256 overflowAllowance);

  function setFor(
    uint256 projectId,
    uint256 configuration,
    JBFundAccessConstraints3_1[] memory fundAccessConstaints
  ) external;
}
