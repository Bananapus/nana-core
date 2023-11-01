// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IERC20Metadata} from '@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {JBPayoutRedemptionPaymentTerminal3_1} from './abstract/JBPayoutRedemptionPaymentTerminal3_1.sol';
import {IJBOperatorStore} from './interfaces/IJBOperatorStore.sol';
import {IJBDirectory} from './interfaces/IJBDirectory.sol';
import {IJBSplitsStore} from './interfaces/IJBSplitsStore.sol';
import {IJBPrices} from './interfaces/IJBPrices.sol';
import {IJBProjects} from './interfaces/IJBProjects.sol';

/// @notice Manages the inflows and outflows of an ERC-20 token.
contract JBERC20PaymentTerminal3_1 is JBPayoutRedemptionPaymentTerminal3_1 {
  using SafeERC20 for IERC20;

  //*********************************************************************//
  // -------------------------- internal views ------------------------- //
  //*********************************************************************//

  /// @notice Checks the balance of tokens in this contract.
  /// @return The contract's balance, as a fixed point number with the same amount of decimals as this terminal.
  function _balance() internal view override returns (uint256) {
    return IERC20(token).balanceOf(address(this));
  }

  //*********************************************************************//
  // -------------------------- constructor ---------------------------- //
  //*********************************************************************//

  /// @param _token The token that this terminal manages.
  /// @param _currency The currency that this terminal's token adheres to for price feeds.
  /// @param _baseWeightCurrency The currency to base token issuance on.
  /// @param _payoutSplitsGroup The group that denotes payout splits from this terminal in the splits store.
  /// @param _operatorStore A contract storing operator assignments.
  /// @param _projects A contract which mints ERC-721's that represent project ownership and transfers.
  /// @param _directory A contract storing directories of terminals and controllers for each project.
  /// @param _splitsStore A contract that stores splits for each project.
  /// @param _prices A contract that exposes price feeds.
  /// @param _store A contract that stores the terminal's data.
  /// @param _owner The address that will own this contract.
  constructor(
    IERC20Metadata _token,
    uint256 _currency,
    uint256 _baseWeightCurrency,
    uint256 _payoutSplitsGroup,
    IJBOperatorStore _operatorStore,
    IJBProjects _projects,
    IJBDirectory _directory,
    IJBSplitsStore _splitsStore,
    IJBPrices _prices,
    address _store,
    address _owner
  )
    JBPayoutRedemptionPaymentTerminal3_1(
      address(_token),
      _token.decimals(),
      _currency,
      _baseWeightCurrency,
      _payoutSplitsGroup,
      _operatorStore,
      _projects,
      _directory,
      _splitsStore,
      _prices,
      _store,
      _owner
    )
  // solhint-disable-next-line no-empty-blocks
  {

  }

  //*********************************************************************//
  // ---------------------- internal transactions ---------------------- //
  //*********************************************************************//

  /// @notice Transfers tokens.
  /// @param _from The address from which the transfer should originate.
  /// @param _to The address to which the transfer should go.
  /// @param _amount The amount of the transfer, as a fixed point number with the same number of decimals as this terminal.
  function _transferFrom(address _from, address payable _to, uint256 _amount) internal override {
    _from == address(this)
      ? IERC20(token).safeTransfer(_to, _amount)
      : IERC20(token).safeTransferFrom(_from, _to, _amount);
  }

  /// @notice Logic to be triggered before transferring tokens from this terminal.
  /// @param _to The address to which the transfer is going.
  /// @param _amount The amount of the transfer, as a fixed point number with the same number of decimals as this terminal.
  function _beforeTransferTo(address _to, uint256 _amount) internal override {
    IERC20(token).safeIncreaseAllowance(_to, _amount);
  }

  /// @notice Logic to be triggered if a transfer should be undone
  /// @param _to The address to which the transfer went.
  /// @param _amount The amount of the transfer, as a fixed point number with the same number of decimals as this terminal.
  function _cancelTransferTo(address _to, uint256 _amount) internal override {
    IERC20(token).safeDecreaseAllowance(_to, _amount);
  }
}
