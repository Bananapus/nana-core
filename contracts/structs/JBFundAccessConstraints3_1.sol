// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IJBPaymentTerminal} from './../interfaces/IJBPaymentTerminal.sol';
import {JBCurrencyAmount} from './JBCurrencyAmount.sol';

/// @custom:member terminal The terminal within which the distribution limit and the overflow allowance applies.
/// @custom:member token The token for which the fund access constraints apply.
/// @custom:member distributionLimits The currency-denomenated amounts of the distribution limit, as a fixed point number with the same number of decimals as the terminal within which the limit applies.
/// @custom:member overflowAllowances The currency-denomenated amounts of the overflow allowance, as a fixed point number with the same number of decimals as the terminal within which the allowance applies.
struct JBFundAccessConstraints3_1 {
  IJBPaymentTerminal terminal;
  address token;
  JBCurrencyAmount[] distributionLimits;
  JBCurrencyAmount[] overflowAllowances;
}
