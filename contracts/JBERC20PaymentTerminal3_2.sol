// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IERC20Metadata} from '@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {IPermit2, IAllowanceTransfer} from 'permit2/src/interfaces/IPermit2.sol';
import {JBPayoutRedemptionPaymentTerminal3_2, IERC165} from './abstract/JBPayoutRedemptionPaymentTerminal3_2.sol';
import {IJBDirectory} from './interfaces/IJBDirectory.sol';
import {IJBOperatorStore} from './interfaces/IJBOperatorStore.sol';
import {IJBProjects} from './interfaces/IJBProjects.sol';
import {IJBSplitsStore} from './interfaces/IJBSplitsStore.sol';
import {IJBPrices3_2} from './interfaces/IJBPrices3_2.sol';
import {IJBPermit2PaymentTerminal} from './interfaces/IJBPermit2PaymentTerminal.sol';
import {JBSingleAllowanceData} from './structs/JBSingleAllowanceData.sol';

/// @notice Manages the inflows and outflows of an ERC-20 token.
contract JBERC20PaymentTerminal3_2 is
  JBPayoutRedemptionPaymentTerminal3_2,
  IJBPermit2PaymentTerminal
{
  using SafeERC20 for IERC20;

  //*********************************************************************//
  // --------------------------- custom errors ------------------------- //
  //*********************************************************************//

  error PERMIT_ALLOWANCE_NOT_ENOUGH(uint256 _transactionAmount, uint256 _permitAllowance);

  //*********************************************************************//
  // ---------------- public immutable stored properties --------------- //
  //*********************************************************************//

  IPermit2 public immutable PERMIT2;

  //*********************************************************************//
  // -------------------------- public views --------------------------- //
  //*********************************************************************//

  /// @notice Indicates if this contract adheres to the specified interface.
  /// @dev See {IERC165-supportsInterface}.
  /// @param _interfaceId The ID of the interface to check for adherance to.
  /// @return A flag indicating if the provided interface ID is supported.
  function supportsInterface(bytes4 _interfaceId)
    public
    view
    virtual
    override(JBPayoutRedemptionPaymentTerminal3_2, IERC165)
    returns (bool)
  {
    return
      _interfaceId == type(IJBPermit2PaymentTerminal).interfaceId ||
      super.supportsInterface(_interfaceId);
  }

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
    uint256 _payoutSplitsGroup,
    IJBOperatorStore _operatorStore,
    IJBProjects _projects,
    IJBDirectory _directory,
    IJBSplitsStore _splitsStore,
    IJBPrices3_2 _prices,
    address _store,
    address _owner,
    IPermit2 _permit2
  )
    JBPayoutRedemptionPaymentTerminal3_2(
      address(_token),
      _token.decimals(),
      uint256(uint24(uint160(address(_token)))), // first 24 bits used for currency.
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
    PERMIT2 = _permit2;
  }

  //*********************************************************************//
  // ----------------------- public transactions ----------------------- //
  //*********************************************************************//

  /// @notice Contribute tokens to a project and sets an allowance for this terminal (using Permit2).
  /// @param _projectId The ID of the project being paid.
  /// @param _amount The amount of terminal tokens being received, as a fixed point number with the same amount of decimals as this terminal. If this terminal's token is ETH, this is ignored and msg.value is used in its place.
  /// @param _token The token being paid. This terminal ignores this property since it only manages one token.
  /// @param _beneficiary The address to mint tokens for and pass along to the funding cycle's data source and delegate.
  /// @param _minReturnedTokens The minimum number of project tokens expected in return, as a fixed point number with the same amount of decimals as this terminal.
  /// @param _preferClaimedTokens A flag indicating whether the request prefers to mint project tokens into the beneficiaries wallet rather than leaving them unclaimed. This is only possible if the project has an attached token contract. Leaving them unclaimed saves gas.
  /// @param _memo A memo to pass along to the emitted event, and passed along the the funding cycle's data source and delegate.  A data source can alter the memo before emitting in the event and forwarding to the delegate.
  /// @param _metadata Bytes to send along to the data source, delegate, and emitted event, if provided.
  /// @param _allowance The allowance to set for this terminal (using Permit2).
  /// @return The number of tokens minted for the beneficiary, as a fixed point number with 18 decimals.
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
  ) external virtual returns (uint256) {
    // If the `_allowance.amount` is less than `_amount` then
    // setting the permit will still not result in a succeful payment
    if (_amount < _allowance.amount) revert PERMIT_ALLOWANCE_NOT_ENOUGH(_amount, _allowance.amount);
    // Get allowance to `spend` tokens for the sender
    _permitAllowance(_allowance);

    // Get a reference to the balance before receiving tokens.
    uint256 _balanceBefore = _balance();

    PERMIT2.transferFrom(msg.sender, address(this), uint160(_amount), address(token));

    // The amount should reflect the change in balance.
    _amount = _balance() - _balanceBefore;

    // Continue with the regular pay flow
    return
      _pay(
        _amount,
        msg.sender,
        _projectId,
        _beneficiary,
        _minReturnedTokens,
        _preferClaimedTokens,
        _memo,
        _metadata
      );
  }

  /// @notice Receives funds belonging to the specified project.
  /// @param _projectId The ID of the project to which the funds received belong.
  /// @param _amount The amount of tokens to add, as a fixed point number with the same number of decimals as this terminal. If this is an ETH terminal, this is ignored and msg.value is used instead.
  /// @param _token The token being paid. This terminal ignores this property since it only manages one currency.
  /// @param _shouldRefundHeldFees A flag indicating if held fees should be refunded based on the amount being added.
  /// @param _memo A memo to pass along to the emitted event.
  /// @param _metadata Extra data to pass along to the emitted event.
  /// @param _allowance The allowance to set for this terminal (using Permit2).
  function addToBalanceOfAndSetAllowance(
    uint256 _projectId,
    uint256 _amount,
    address _token,
    bool _shouldRefundHeldFees,
    string calldata _memo,
    bytes calldata _metadata,
    JBSingleAllowanceData calldata _allowance
  ) external virtual {
    // If the `_allowance.amount` is less than `_amount` then
    // setting the permit will still not result in a succeful payment
    if (_amount < _allowance.amount) revert PERMIT_ALLOWANCE_NOT_ENOUGH(_amount, _allowance.amount);
    // Get allowance to `spend` tokens for the user
    _permitAllowance(_allowance);

    // Get a reference to the balance before receiving tokens.
    uint256 _balanceBefore = _balance();

    PERMIT2.transferFrom(msg.sender, address(this), uint160(_amount), address(token));

    // The amount should reflect the change in balance.
    _amount = _balance() - _balanceBefore;

    // Continue with the regular addToBalanceOf flow
    return _addToBalanceOf(_projectId, _amount, _shouldRefundHeldFees, _memo, _metadata);
  }

  //*********************************************************************//
  // ---------------------- internal transactions ---------------------- //
  //*********************************************************************//

  /// @notice Gets allowance
  /// @param _allowance the allowance to get using permit2
  function _permitAllowance(JBSingleAllowanceData calldata _allowance) internal {
    // Use Permit2 to set the allowance
    PERMIT2.permit(
      msg.sender,
      IAllowanceTransfer.PermitSingle({
        details: IAllowanceTransfer.PermitDetails({
          token: address(token),
          amount: _allowance.amount,
          expiration: _allowance.expiration,
          nonce: _allowance.nonce
        }),
        spender: address(this),
        sigDeadline: _allowance.sigDeadline
      }),
      _allowance.signature
    );
  }

  /// @notice Transfers tokens.
  /// @param _from The address from which the transfer should originate.
  /// @param _to The address to which the transfer should go.
  /// @param _amount The amount of the transfer, as a fixed point number with the same number of decimals as this terminal.
  function _transferFrom(
    address _from,
    address payable _to,
    uint256 _amount
  ) internal override {
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
