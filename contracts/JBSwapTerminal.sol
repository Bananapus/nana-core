// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC165Checker} from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import {PRBMath} from "@paulrberg/contracts/math/PRBMath.sol";
import {IPermit2} from "@permit2/src/src/interfaces/IPermit2.sol";
import {IAllowanceTransfer} from "@permit2/src/src/interfaces/IPermit2.sol";
import {IJBController3_1} from "./interfaces/IJBController3_1.sol";
import {IJBDirectory} from "./interfaces/IJBDirectory.sol";
import {IJBSplitsStore} from "./interfaces/IJBSplitsStore.sol";
import {IJBOperatable} from "./interfaces/IJBOperatable.sol";
import {IJBOperatorStore} from "./interfaces/IJBOperatorStore.sol";
import {IJBPaymentTerminal} from "./interfaces/terminal/IJBPaymentTerminal.sol";
import {IJBProjects} from "./interfaces/IJBProjects.sol";
import {IJBTerminalStore} from "./interfaces/IJBTerminalStore.sol";
import {IJBSplitAllocator} from "./interfaces/IJBSplitAllocator.sol";
import {JBConstants} from "./libraries/JBConstants.sol";
import {JBFees} from "./libraries/JBFees.sol";
import {JBFundingCycleMetadataResolver} from "./libraries/JBFundingCycleMetadataResolver.sol";
import {JBMetadataResolver} from "./libraries/JBMetadataResolver.sol";
import {JBOperations} from "./libraries/JBOperations.sol";
import {JBTokens} from "./libraries/JBTokens.sol";
import {JBTokenStandards} from "./libraries/JBTokenStandards.sol";
import {JBDidRedeemData3_1_1} from "./structs/JBDidRedeemData3_1_1.sol";
import {JBDidPayData3_1_1} from "./structs/JBDidPayData3_1_1.sol";
import {JBFee} from "./structs/JBFee.sol";
import {JBFundingCycle} from "./structs/JBFundingCycle.sol";
import {JBPayDelegateAllocation3_1_1} from "./structs/JBPayDelegateAllocation3_1_1.sol";
import {JBRedemptionDelegateAllocation3_1_1} from
    "./structs/JBRedemptionDelegateAllocation3_1_1.sol";
import {JBSingleAllowanceData} from "./structs/JBSingleAllowanceData.sol";
import {JBSplit} from "./structs/JBSplit.sol";
import {JBSplitAllocationData} from "./structs/JBSplitAllocationData.sol";
import {JBAccountingContext} from "./structs/JBAccountingContext.sol";
import {JBAccountingContextConfig} from "./structs/JBAccountingContextConfig.sol";
import {JBTokenAmount} from "./structs/JBTokenAmount.sol";
import {JBOperatable} from "./abstract/JBOperatable.sol";
import {
    IJBMultiTerminal,
    IJBFeeTerminal,
    IJBPaymentTerminal,
    IJBRedemptionTerminal,
    IJBPayoutTerminal,
    IJBPermitPaymentTerminal
} from "./interfaces/terminal/IJBMultiTerminal.sol";

/// @notice Terminal providing an intermediate layer when receiving a payment in a token without
///         a native terminal deployed. This terminal will swap the token received for a given token,
///         then use the correct terminal to redirect the payment
///
///         user  -- token A --> swap terminal: swap for B -- token B --> target terminal
///          ^                                                                 | 
///          |____________project token, NFT, etc______________________________|
///
/// @dev    Slippage is prevented by using a quote passed by the user (using the JBMetadataResolver
///         format, along the address of the pool to use) or a twap from the pool's oracle if no quote
///         is provided (the pool to use *must* then be defined by the project owner).
contract JBMultiTerminal is JBOperatable, Ownable, IJBPaymentTerminal, IJBPermitPaymentTerminal {
    // A library that parses the packed funding cycle metadata into a friendlier format.
    using JBFundingCycleMetadataResolver for JBFundingCycle;

    // A library that adds default safety checks to ERC20 functionality.
    using SafeERC20 for IERC20;

    //*********************************************************************//
    // --------------------------- custom errors ------------------------- //
    //*********************************************************************//

    error NO_DEFAULT_POOL_DEFINED();

    //*********************************************************************//
    // --------------------- internal stored constants ------------------- //
    //*********************************************************************//

    //*********************************************************************//
    // --------------------- internal stored properties ------------------ //
    //*********************************************************************//

    //*********************************************************************//
    // ------------------------- public constants ------------------------ //
    //*********************************************************************//

    //*********************************************************************//
    // ---------------- public immutable stored properties --------------- //
    //*********************************************************************//

    /// @notice Mints ERC-721's that represent project ownership and transfers.
    IJBProjects public immutable override PROJECTS;

    /// @notice The directory of terminals and controllers for PROJECTS.
    IJBDirectory public immutable override DIRECTORY;

    /// @notice The contract that stores splits for each project.
    IJBSplitsStore public immutable override SPLITS;

    /// @notice The contract that stores and manages the terminal's data.
    IJBTerminalStore public immutable override STORE;

    /// @notice The permit2 utility.
    IPermit2 public immutable override PERMIT2;

    //*********************************************************************//
    // --------------------- public stored properties -------------------- //
    //*********************************************************************//
    
    // project ID -> token received -> pool to use
    mapping(uint256 => mapping(address => IUniswapV3Pool)) public _poolFor;

    //*********************************************************************//
    // ------------------------- external views -------------------------- //
    //*********************************************************************//

    //*********************************************************************//
    // -------------------------- public views --------------------------- //
    //*********************************************************************//

    /// @notice Indicates if this contract adheres to the specified interface.
    /// @dev See {IERC165-supportsInterface}.
    /// @param _interfaceId The ID of the interface to check for adherance to.
    /// @return A flag indicating if the provided interface ID is supported.
    function supportsInterface(bytes4 _interfaceId) public view virtual override returns (bool) {
        return _interfaceId == type(IJBPaymentTerminal).interfaceId
            || _interfaceId == type(IJBPermitPaymentTerminal).interfaceId
            || _interfaceId == type(IERC165).interfaceId;
    }

    //*********************************************************************//
    // -------------------------- internal views ------------------------- //
    //*********************************************************************//

    //*********************************************************************//
    // -------------------------- constructor ---------------------------- //
    //*********************************************************************//

    /// @param _operatorStore A contract storing operator assignments.
    /// @param _projects A contract which mints ERC-721's that represent project ownership and transfers.
    /// @param _directory A contract storing directories of terminals and controllers for each project.
    /// @param _splitsStore A contract that stores splits for each project.
    /// @param _store A contract that stores the terminal's data.
    /// @param _permit2 A permit2 utility.
    /// @param _owner The address that will own this contract.
    constructor(
        IJBOperatorStore _operatorStore,
        IJBProjects _projects,
        IJBDirectory _directory,
        IJBSplitsStore _splitsStore,
        IJBTerminalStore _store,
        IPermit2 _permit2,
        address _owner
    ) JBOperatable(_operatorStore) Ownable(_owner) {
        PROJECTS = _projects;
        DIRECTORY = _directory;
        SPLITS = _splitsStore;
        STORE = _store;
        PERMIT2 = _permit2;
    }

    //*********************************************************************//
    // ---------------------- external transactions ---------------------- //
    //*********************************************************************//

    /// @notice 
    /// @param _projectId The ID of the project being paid.
    /// @param _amount The amount of terminal tokens being received, as a fixed point number with the same amount of decimals as this terminal. If this terminal's token is ETH, this is ignored and msg.value is used in its place.
    /// @param _token The token being paid. This terminal ignores this property since it only manages one token.
    /// @param _beneficiary The address to mint tokens for and pass along to the funding cycle's data source and delegate.
    /// @param _minReturnedTokens The minimum number of project tokens expected in return, as a fixed point number with the same amount of decimals as this terminal.
    /// @param _memo A memo to pass along to the emitted event.
    /// @param _metadata Bytes to send along to the data source, delegate, and emitted event, if provided.
    /// @return The number of tokens minted for the beneficiary, as a fixed point number with 18 decimals.
    function pay(
        uint256 _projectId,
        address _token,
        uint256 _amount,
        address _beneficiary,
        uint256 _minReturnedTokens,
        string calldata _memo,
        bytes calldata _metadata
    ) external payable virtual override returns (uint256) {
<<<<<<< HEAD
=======
        JBMultiTerminal _terminal = DIRECTORY.primaryTerminalOf(_projectId, _token);

        // Double check the primary terminal accepts the token

        // Accept the funds.
        _amount = _acceptFundsFor(_projectId, _token, _amount, _metadata);

>>>>>>> 2842301 (chore: wip)
        uint256 _minimumReceivedFromSwap;
        IUniswapV3Pool _pool;

        // Check for a quote passed by the user
        (bool _exists, bytes memory _parsedMetadata) =
            JBMetadataResolver.getMetadata(bytes4('SWAP'), _metadata);
        
        // If there is a quote, use it
        if(_exists) {
            (_minimumReceivedFromSwap, _pool) = abi.decode(_parsedMetadata, (uint256, IUniswapV3Pool));
        // If no quote, check there is a pool assigned and get a twap
        } else {
            _pool = _poolFor[_projectId][_token];
            
            // If no default pool, revert - TODO: send back to the caller instead (could be either fee or EOA tho)
            if(address(_pool) == address(0)) revert NO_DEFAULT_POOL_DEFINED();

            // Get a twap from the pool, includes a default max slippage
            _minimumReceivedFromSwap = _getTwapFrom(_pool, _amount);
        }

        JBMultiTerminal _terminal = DIRECTORY.primaryTerminalOf(_projectId, _token);

        address _poolToken0 = _pool.token0();
        address _poolToken1 = _pool.token1();

        address _targetToken = _poolToken0 == _token ? _poolToken1 : _poolToken0;

        if(_poolToken0 == _token) {
            _targetToken = _poolToken1;
        } else {
            if(_poolToken1 != _token) revert TOKEN_NOT_IN_POOL();
            _targetToken = _poolToken0;
        }

        // Check the primary terminal accepts the token (save swap gas if not accepted)
        if(!_terminal.acceptsToken(_targetToken)) revert TOKEN_NOT_ACCEPTED(); // TODO: no revert?
        
        // Accept the funds.
        _amount = _acceptFundsFor(_projectId, _token, _amount, _metadata);

        // Swap (will check if we're within the slippage tolerance in the callback))
        uint256 _receivedFromSwap = _swap(_token, _pool, _amount, _minimumReceivedFromSwap);

        // Unwrap weth if needed


        // Unwrap weth if needed

        // Pay on primary terminal, with correct beneficiary (sender or benficiary if passed)
        _terminal.pay{value: _token == JBToken.ETH ? _receivedFromSwap : 0}(
            _projectId,
<<<<<<< HEAD
            _targetToken,
=======
            _token,
>>>>>>> 2842301 (chore: wip)
            _receivedFromSwap,
            _beneficiary,
            _minReturnedTokens,
            _memo,
            _metadata
        );
<<<<<<< HEAD
=======

>>>>>>> 2842301 (chore: wip)
    }

    /// @notice 
    /// @param _projectId The ID of the project to which the funds received belong.
    /// @param _amount The amount of tokens to add, as a fixed point number with the same number of decimals as this terminal. If this is an ETH terminal, this is ignored and msg.value is used instead.
    /// @param _token The token being paid. This terminal ignores this property since it only manages one currency.
    /// @param _shouldRefundHeldFees A flag indicating if held fees should be refunded based on the amount being added.
    /// @param _memo A memo to pass along to the emitted event.
    /// @param _metadata Extra data to pass along to the emitted event.
    function addToBalanceOf(
        uint256 _projectId,
        address _token,
        uint256 _amount,
        bool _shouldRefundHeldFees,
        string calldata _memo,
        bytes calldata _metadata
    ) external payable virtual override {
        // Check the terminal accepts the token

        // Accept the funds.
        _amount = _acceptFundsFor(_projectId, _token, _amount, _metadata);

        // Check for quote

        // If no quote, check there is a pool assigned and get a twap

        // Try to swap, if fails, revert

        // Unwrap weth if needed

        // Add to balance on primary terminal
    }

<<<<<<< HEAD
    // add a pool to use for a given token in
    function addDefaultPool(uint256 _projectId, address _token, IUniswapV3Pool _pool) external requirePermission(
            projects.ownerOf(_projectId),
            _projectId,
            JBSwapTerminalOperations.MODIFY_DEFAULT_POOL
        ) {
        _poolFor[_projectId][_token] = _pool;
=======
    /// @notice 
    /// @param _holder The account to redeem tokens for.
    /// @param _projectId The ID of the project to which the tokens being redeemed belong.
    /// @param _tokenCount The number of project tokens to redeem, as a fixed point number with 18 decimals.
    /// @param _token The token being reclaimed. This terminal ignores this property since it only manages one token.
    /// @param _minReturnedTokens The minimum amount of terminal tokens expected in return, as a fixed point number with the same amount of decimals as the terminal.
    /// @param _beneficiary The address to send the terminal tokens to.
    /// @param _metadata Bytes to send along to the data source, delegate, and emitted event, if provided.
    /// @return reclaimAmount The amount of terminal tokens that the project tokens were redeemed for, as a fixed point number with 18 decimals.
    function redeemTokensOf(
        address _holder,
        uint256 _projectId,
        address _token,
        uint256 _tokenCount,
        uint256 _minReturnedTokens,
        address payable _beneficiary,
        bytes calldata _metadata
    )
        external
        virtual
        override
        requirePermission(_holder, _projectId, JBOperations.REDEEM_TOKENS)
        returns (uint256 reclaimAmount)
    {
        // Check if the project terminal support the token which will be swapped to _token

        // pull project token from the caller

        // approve the terminal to spend the project token todo: permit2
        
        // call redeem on the terminal

        // try to swap

        // if swap fails, revert 

        // unwrap if needed

        //  send to beneficiary
>>>>>>> 2842301 (chore: wip)
    }

    //*********************************************************************//
    // ---------------------- internal transactions ---------------------- //
    //*********************************************************************//
        /// @notice Accepts an incoming token.
    /// @param _projectId The ID of the project for which the transfer is being accepted.
    /// @param _token The token being accepted.
    /// @param _amount The amount of tokens being accepted.
    /// @param _metadata The metadata in which permit2 context is provided.
    /// @return amount The amount of tokens that have been accepted.
    function _acceptFundsFor(
        uint256 _projectId,
        address _token,
        uint256 _amount,
        bytes calldata _metadata
    ) internal returns (uint256) {
        // Make sure the project has set an accounting context for the token being paid.
        if (_accountingContextForTokenOf[_projectId][_token].token == address(0)) {
            revert TOKEN_NOT_ACCEPTED();
        }

        // If the terminal's token is ETH, override `_amount` with msg.value.
        if (_token == JBTokens.ETH) return msg.value;

        // Amount must be greater than 0.
        if (msg.value != 0) revert NO_MSG_VALUE_ALLOWED();

        // If the terminal is rerouting the tokens within its own functions, there's nothing to transfer.
        if (msg.sender == address(this)) return _amount;

        // Unpack the allowance to use, if any, given by the frontend.
        (bool _exists, bytes memory _parsedMetadata) =
            JBMetadataResolver.getMetadata(bytes4(uint32(uint160(address(this)))), _metadata);

        // Check if the metadata contained permit data.
        if (_exists) {
            // Keep a reference to the allowance context parsed from the metadata.
            (JBSingleAllowanceData memory _allowance) =
                abi.decode(_parsedMetadata, (JBSingleAllowanceData));

            // Make sure the permit allowance is enough for this payment. If not we revert early.
            if (_allowance.amount < _amount) {
                revert PERMIT_ALLOWANCE_NOT_ENOUGH(_amount, _allowance.amount);
            }

            // Set the allowance to `spend` tokens for the user.
            _permitAllowance(_allowance, _token);
        }

        // Get a reference to the balance before receiving tokens.
        uint256 _balanceBefore = _balance(_token);

        // Transfer tokens to this terminal from the msg sender.
        _transferFor(msg.sender, payable(address(this)), _token, _amount);

        // The amount should reflect the change in balance.
        return _balance(_token) - _balanceBefore;
    }

    /// @notice Reverts an expected payout.
    /// @param _projectId The ID of the project having paying out.
    /// @param _token The address of the token having its transfer reverted.
    /// @param _expectedDestination The address the payout was expected to go to.
    /// @param _allowanceAmount The amount that the destination has been allowed to use.
    /// @param _depositAmount The amount of the payout as debited from the project's balance.
    function _revertTransferFrom(
        uint256 _projectId,
        address _token,
        address _expectedDestination,
        uint256 _allowanceAmount,
        uint256 _depositAmount
    ) internal {
        // Cancel allowance if needed.
        if (_allowanceAmount != 0 && _token != JBTokens.ETH) {
            IERC20(_token).safeDecreaseAllowance(_expectedDestination, _allowanceAmount);
        }

        // Add undistributed amount back to project's balance.
        STORE.recordAddedBalanceFor(_projectId, _token, _depositAmount);
    }

    /// @notice Transfers tokens.
    /// @param _from The address from which the transfer should originate.
    /// @param _to The address to which the transfer should go.
    /// @param _token The token being transfered.
    /// @param _amount The amount of the transfer, as a fixed point number with the same number of decimals as this terminal.
    function _transferFor(address _from, address payable _to, address _token, uint256 _amount)
        internal
        virtual
    {
        // If the token is ETH, assume the native token standard.
        if (_token == JBTokens.ETH) return Address.sendValue(_to, _amount);

        if (_from == address(this)) {
            return IERC20(_token).safeTransfer(_to, _amount);
        }

        // If there's sufficient approval, transfer normally.
        if (IERC20(_token).allowance(address(_from), address(this)) >= _amount) {
            return IERC20(_token).safeTransferFrom(_from, _to, _amount);
        }

        // Otherwise we attempt to use the PERMIT2 method.
        PERMIT2.transferFrom(_from, _to, uint160(_amount), _token);
    }

    /// @notice Logic to be triggered before transferring tokens from this terminal.
    /// @param _to The address to which the transfer is going.
    /// @param _token The token being transfered.
    /// @param _amount The amount of the transfer, as a fixed point number with the same number of decimals as this terminal.
    function _beforeTransferFor(address _to, address _token, uint256 _amount) internal virtual {
        // If the token is ETH, assume the native token standard.
        if (_token == JBTokens.ETH) return;
        IERC20(_token).safeIncreaseAllowance(_to, _amount);
    }

    /// @notice Sets the permit2 allowance for a token.
    /// @param _allowance the allowance to get using permit2
    /// @param _token The token being allowed.
    function _permitAllowance(JBSingleAllowanceData memory _allowance, address _token) internal {
        PERMIT2.permit(
            msg.sender,
            IAllowanceTransfer.PermitSingle({
                details: IAllowanceTransfer.PermitDetails({
                    token: _token,
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
}
