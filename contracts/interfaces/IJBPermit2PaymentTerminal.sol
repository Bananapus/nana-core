// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC165} from '@openzeppelin/contracts/utils/introspection/IERC165.sol';
import {IPermit2} from 'permit2/src/interfaces/IPermit2.sol';
import {JBSingleAllowanceData} from '../structs/JBSingleAllowanceData.sol';
import {IJBPaymentTerminal} from './IJBPaymentTerminal.sol';

interface IJBPermit2PaymentTerminal is IJBPaymentTerminal {
  function PERMIT2() external returns (IPermit2 _permit2);

  function payAndSetAllowance(
    uint256 _projectId,
    uint256 _amount,
    address _token,
    address _beneficiary,
    uint256 _minReturnedTokens,
    bool _preferClaimedTokens,
    string calldata _memo,
    bytes calldata _metadata,
    JBSingleAllowanceData calldata _allowance
  ) external returns (uint256 beneficiaryTokenCount);

  function addToBalanceOfAndSetAllowance(
    uint256 _projectId,
    uint256 _amount,
    address _token,
    bool _shouldRefundHeldFees,
    string calldata _memo,
    bytes calldata _metadata,
    JBSingleAllowanceData calldata _allowance
  ) external;
}
