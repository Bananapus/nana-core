// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IERC20Metadata} from '@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {JBPayoutRedemptionPaymentTerminal3_1_2} from './abstract/JBPayoutRedemptionPaymentTerminal3_1_2.sol';
import {IJBDirectory} from './interfaces/IJBDirectory.sol';
import {IJBOperatorStore} from './interfaces/IJBOperatorStore.sol';
import {IJBProjects} from './interfaces/IJBProjects.sol';
import {IJBSplitsStore} from './interfaces/IJBSplitsStore.sol';
import {IJBPrices} from './interfaces/IJBPrices.sol';

/// @notice Manages the inflows and outflows of an ERC-20 token.
contract JBSwapPaymentTerminal is JBPayoutRedemptionPaymentTerminal3_1_2 {
  using SafeERC20 for IERC20;

  //*********************************************************************//
  // -------------------------- internal views ------------------------- //
  //*********************************************************************//

  /// @notice Checks the balance of tokens in this contract.
  /// @return The contract's balance, as a fixed point number with the same amount of decimals as this terminal.
  function _balance() internal view override returns (uint256) {
    return IERC20(token).balanceOf(address(this));
  }

  /// @notice A flag indicating if this terminal accepts the specified token.
  /// @param _token The token to check if this terminal accepts or not.
  /// @param _projectId The project ID to check for token acceptance.
  /// @return The flag.
  function acceptsToken(address _token, uint256 _projectId) external view override returns (bool) {
    return true; //TODO return probability of swap succeeding.
  }

  /// @notice The decimals that should be used in fixed number accounting for the specified token.
  /// @param _token The token to check for the decimals of.
  /// @return The number of decimals for the token.
  function decimalsForToken(address _token) external view override returns (uint256) {
    return 18; // TODO read from ERC20 interface.
  }

  /// @notice The currency that should be used for the specified token.
  /// @param _token The token to check for the currency of.
  /// @return The currency index.
  function currencyForToken(address _token) external view override returns (uint256) {
    return 0; // No need
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
    JBPayoutRedemptionPaymentTerminal3_1_2(
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

  /// @notice Contribute any tokens to a project.
  /// @param _projectId The ID of the project being paid.
  /// @param _amount The amount of terminal tokens being received, as a fixed point number with the same amount of decimals as this terminal. If this terminal's token is ETH, this is ignored and msg.value is used in its place.
  /// @param _token The token being paid, that'll be converted to the token the project wants via an AMM swap if they don't already match.
  /// @param _beneficiary The address to mint tokens for and pass along to the funding cycle's data source and delegate.
  /// @param _minReturnedTokens The minimum number of project tokens expected in return, as a fixed point number with the same amount of decimals as this terminal.
  /// @param _preferClaimedTokens A flag indicating whether the request prefers to mint project tokens into the beneficiaries wallet rather than leaving them unclaimed. This is only possible if the project has an attached token contract. Leaving them unclaimed saves gas.
  /// @param _memo A memo to pass along to the emitted event, and passed along the the funding cycle's data source and delegate.  A data source can alter the memo before emitting in the event and forwarding to the delegate.
  /// @param _metadata Bytes to send along to the data source, delegate, and emitted event, if provided.
  /// @return The number of tokens minted for the beneficiary, as a fixed point number with 18 decimals.
  function pay(
    uint256 _projectId,
    uint256 _amount,
    address _token,
    address _beneficiary,
    uint256 _minReturnedTokens,
    bool _preferClaimedTokens,
    string calldata _memo,
    bytes calldata _metadata
  ) public payable virtual override returns (uint256) {
    // The goal is to convert the incoming token into the one we can accept.
    // if the incoming token is the one we accept, do nothing.
    // else, try to swap the incoming token into the one we accept.

    // If the incoming token isn't the one we want, swap.
    if (_token != token) {
      address _payer;
      // Wrap ETH into WETH if relevant.
      if (_token == JBTokens.ETH) {
        WETH.deposit{value: _amount}();
        _payer = address(this);
      } else {
        _payer = msg.sender;
      }

      uint256 _fee;

      // Unpack the quote from the pool, given by the frontend.
      (bool _quoteExists, _metadata) = JBDelegateMetadataLib.getMetadata(123, _metadata);
      if (_quoteExists) (_fee) = abi.decode(_metadata, (uint256, uint256));
      else _fee = 3000; // TODO some default

      // swap. update _amount to match the amount of the desired tokens came in.
      _amount = _swap(_payer, _amount, _token, _fee);
    }

    super.pay(
      _projectId,
      _amount,
      token,
      _beneficiary,
      _minReturnedTokens,
      _preferClaimedTokens,
      _memo,
      _metadata
    );
  }

  /// @notice The Uniswap V3 pool callback where the token transfer is expected to happen.
  /// @param _amount0Delta The amount of token 0 being used for the swap.
  /// @param _amount1Delta The amount of token 1 being used for the swap.
  /// @param _data Data passed in by the swap operation.
  function uniswapV3SwapCallback(
    int256 _amount0Delta,
    int256 _amount1Delta,
    bytes calldata _data
  ) external override {
    // Unpack the data passed in through the swap hook.
    (
      address _payer,
      address _tokenWithWETH,
      address _desiredTokenWithWETH,
      bool _projectTokenIsZero,
      bytes32 _poolId
    ) = abi.decode(_data, (address, address, address, bool, bytes32));

    // Keep a reference to a flag indicating if the pool will reference the project token as the first in the pair.
    bool _desiredTokenIs0 = _desiredTokenWithWETH < _tokenWithWETH;

    // Compute the corresponding pool's address, which is a function of both tokens and the specified fee.
    IUniswapV3Pool _pool = IUniswapV3Pool(
      address(
        uint160(
          uint256(
            keccak256(
              abi.encodePacked(
                hex'ff',
                UNISWAP_V3_FACTORY,
                _poolId,
                // POOL_INIT_CODE_HASH from https://github.com/Uniswap/v3-periphery/blob/main/contracts/libraries/PoolAddress.sol
                bytes32(0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54)
              )
            )
          )
        )
      )
    );

    // Make sure this call is being made from within the swap execution.
    if (msg.sender != _pool) revert JuiceBuyback_Unauthorized();

    // Keep a reference to the amount of tokens that should be sent to fulfill the swap (the positive delta)
    uint256 _amountToSendToPool = _amount0Delta < 0
      ? uint256(_amount1Delta)
      : uint256(_amount0Delta);

    // Wrap ETH into WETH if relevant (do not rely on ETH delegate balance to support pure WETH terminals)
    if (_token == JBTokens.ETH) {
      WETH.deposit{value: _amountToSendToPool}();
      _payer = address(this);
    }

    // Transfer the token to the pool.
    IERC20(_tokenWithWETH).safeTransferFrom(_payer, msg.sender, _amountToSendToPool);
  }

  /// @param _payer The source of the funds being swapped.
  /// @param _token The token being swapped.
  /// @param _amount The amount of tokens that are being used with which to make the swap.
  /// @param _fee The fee of the pool to use.
  function _swap(
    uint256 _payer,
    uint256 _amount,
    address _token,
    uint256 _fee
  ) internal returns (uint256 amountReceived) {
    // Get the terminal token, using WETH if the token paid in is ETH.
    address _tokenWithWETH = _token == JBTokens.ETH ? address(WETH) : _token;

    address _desiredToken = token;

    address _desiredTokenwithWETH = _desiredToken == JBTokens.ETH ? address(WETH) : _desiredToken;

    // Keep a reference to a flag indicating if the pool will reference the project token as the first in the pair.
    bool _projectTokenIs0 = address(_projectToken) < _terminalToken;

    bytes32 _poolId = keccak256(
      abi.encode(
        _projectTokenIs0 ? _desiredTokenwithWETH : _tokenWithWETH,
        _projectTokenIs0 ? _tokenWithWETH : _desiredTokenwithWETH,
        _fee
      )
    );

    // Compute the corresponding pool's address, which is a function of both tokens and the specified fee.
    IUniswapV3Pool _pool = IUniswapV3Pool(
      address(
        uint160(
          uint256(
            keccak256(
              abi.encodePacked(
                hex'ff',
                UNISWAP_V3_FACTORY,
                _poolId,
                // POOL_INIT_CODE_HASH from https://github.com/Uniswap/v3-periphery/blob/main/contracts/libraries/PoolAddress.sol
                bytes32(0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54)
              )
            )
          )
        )
      )
    );

    // Try swapping.
    try
      _pool.swap({
        recipient: address(this),
        zeroForOne: !_projectTokenIs0,
        amountSpecified: int256(_amount),
        sqrtPriceLimitX96: _projectTokenIs0
          ? TickMath.MAX_SQRT_RATIO - 1
          : TickMath.MIN_SQRT_RATIO + 1,
        data: abi.encode(_payer, _token, _desiredTokenwithWETH, _projectTokenIs0, _poolId)
      })
    returns (int256 amount0, int256 amount1) {
      // If the swap succeded, take note of the amount of tokens received. This will return as negative since it is an exact input.
      amountReceived = uint256(-(_projectTokenIs0 ? amount0 : amount1));

      // Convert back to ETH if needed.
      if (_desiredToken == JBTokens.ETH) WETH.withdraw{value: amountReceived}();
    } catch {
      // If the swap failed, return.
      return 0;
    }
  }
}
