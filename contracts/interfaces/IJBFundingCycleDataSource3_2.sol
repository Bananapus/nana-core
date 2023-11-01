// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC165} from '@openzeppelin/contracts/utils/introspection/IERC165.sol';
import {JBPayDelegateAllocation3_2} from './../structs/JBPayDelegateAllocation3_2.sol';
import {JBPayParamsData} from './../structs/JBPayParamsData.sol';
import {JBRedeemParamsData} from './../structs/JBRedeemParamsData.sol';
import {JBRedemptionDelegateAllocation3_2} from './../structs/JBRedemptionDelegateAllocation3_2.sol';

/// @title Datasource
/// @notice The datasource is called by JBPayoutRedemptionPaymentTerminals on pay and redemption, and provide an extra layer of logic to use a custom weight, a custom memo and/or a pay/redeem delegate
interface IJBFundingCycleDataSource3_2 is IERC165 {
  /// @notice The datasource implementation for JBPaymentTerminal.pay(..)
  /// @param data the data passed to the data source in terminal.pay(..), as a JBPayParamsData struct:
  /// @return weight the weight to use to override the funding cycle weight
  /// @return memo the memo to override the pay(..) memo
  /// @return delegateAllocations The amount to send to delegates instead of adding to the local balance.
  function payParams(
    JBPayParamsData calldata data
  )
    external
    view
    returns (
      uint256 weight,
      string memory memo,
      JBPayDelegateAllocation3_2[] memory delegateAllocations
    );

  /// @notice The datasource implementation for JBPaymentTerminal.redeemTokensOf(..)
  /// @param data the data passed to the data source in terminal.redeemTokensOf(..), as a JBRedeemParamsData struct:
  /// @return reclaimAmount The amount to claim, overriding the terminal logic.
  /// @return memo The memo to override the redeemTokensOf(..) memo.
  /// @return delegateAllocations The amount to send to delegates instead of adding to the beneficiary.
  function redeemParams(
    JBRedeemParamsData calldata data
  )
    external
    view
    returns (
      uint256 reclaimAmount,
      string memory memo,
      JBRedemptionDelegateAllocation3_2[] memory delegateAllocations
    );
}
