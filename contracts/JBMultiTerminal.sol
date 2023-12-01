// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC2771Context} from "@openzeppelin/contracts/metatx/ERC2771Context.sol";
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

/// @notice Generic terminal managing all inflows and outflows of funds into the protocol ecosystem.
contract JBMultiTerminal is JBOperatable, Ownable, ERC2771Context, IJBMultiTerminal {
    // A library that parses the packed funding cycle metadata into a friendlier format.
    using JBFundingCycleMetadataResolver for JBFundingCycle;

    // A library that adds default safety checks to ERC20 functionality.
    using SafeERC20 for IERC20;

    //*********************************************************************//
    // --------------------------- custom errors ------------------------- //
    //*********************************************************************//

    error ACCOUNTING_CONTEXT_ALREADY_SET();
    error FEE_TOO_HIGH();
    error INADEQUATE_DISTRIBUTION_AMOUNT();
    error INADEQUATE_RECLAIM_AMOUNT();
    error INADEQUATE_TOKEN_COUNT();
    error NO_MSG_VALUE_ALLOWED();
    error PAY_TO_ZERO_ADDRESS();
    error PERMIT_ALLOWANCE_NOT_ENOUGH(uint256 transactionAmount, uint256 permitAllowance);
    error REDEEM_TO_ZERO_ADDRESS();
    error TERMINAL_TOKENS_INCOMPATIBLE();
    error TOKEN_NOT_ACCEPTED();

    //*********************************************************************//
    // --------------------- internal stored constants ------------------- //
    //*********************************************************************//

    /// @notice The fee beneficiary project ID is 1, as it should be the first project launched during the deployment process.
    uint256 internal constant _FEE_BENEFICIARY_PROJECT_ID = 1;

    //*********************************************************************//
    // --------------------- internal stored properties ------------------ //
    //*********************************************************************//

    /// @notice Context describing how a token is accounted for by a project.
    /// @custom:param _projectId The ID of the project to which the token accounting context applies.
    /// @custom:param _token The address of the token being accounted for.
    mapping(uint256 => mapping(address => JBAccountingContext)) internal
        _accountingContextForTokenOf;

    /// @notice A list of tokens accepted by each project.
    /// @custom:param _projectId The ID of the project to get a list of accepted tokens for.
    mapping(uint256 => JBAccountingContext[]) internal _accountingContextsOf;

    /// @notice Fees that are being held to be processed later.
    /// @custom:param _projectId The ID of the project for which fees are being held.
    mapping(uint256 => JBFee[]) internal _heldFeesOf;

    //*********************************************************************//
    // ------------------------- public constants ------------------------ //
    //*********************************************************************//

    /// @notice The platform fee percent.
    uint256 public constant override FEE = 25_000_000; // 2.5%

    //*********************************************************************//
    // ---------------- public immutable stored properties --------------- //
    //*********************************************************************//

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

    /// @notice Addresses that can be paid towards from this terminal without incurring a fee.
    /// @dev Only addresses that are considered to be contained within the ecosystem can be feeless. Funds sent outside the ecosystem may incur fees despite being stored as feeless.
    /// @custom:param _address The address that can be paid toward.
    mapping(address => bool) public override isFeelessAddress;

    //*********************************************************************//
    // ------------------------- external views -------------------------- //
    //*********************************************************************//

    /// @notice Information on how a project accounts for tokens.
    /// @param _projectId The ID of the project to get token accounting info for.
    /// @param _token The token to check the accounting info for.
    /// @return The token's accounting info of decimals for the token.
    function accountingContextForTokenOf(uint256 _projectId, address _token)
        external
        view
        override
        returns (JBAccountingContext memory)
    {
        return _accountingContextForTokenOf[_projectId][_token];
    }

    /// @notice The tokens accepted by a project.
    /// @param _projectId The ID of the project to get accepted tokens for.
    /// @return tokenContexts The contexts of the accepted tokens.
    function accountingContextsOf(uint256 _projectId)
        external
        view
        override
        returns (JBAccountingContext[] memory)
    {
        return _accountingContextsOf[_projectId];
    }

    /// @notice Gets the current overflowed amount in this terminal for a specified project, in terms of ETH.
    /// @dev The current overflow is represented as a fixed point number with 18 decimals.
    /// @param _projectId The ID of the project to get overflow for.
    /// @param _decimals The number of decimals included in the fixed point returned value.
    /// @param _currency The currency in which the ETH value is returned.
    /// @return The current amount of ETH overflow that project has in this terminal, as a fixed point number with 18 decimals.
    function currentOverflowOf(uint256 _projectId, uint256 _decimals, uint256 _currency)
        external
        view
        virtual
        override
        returns (uint256)
    {
        return STORE.currentOverflowOf(
            address(this), _projectId, _accountingContextsOf[_projectId], _decimals, _currency
        );
    }

    /// @notice The fees that are currently being held to be processed later for each project.
    /// @param _projectId The ID of the project for which fees are being held.
    /// @return An array of fees that are being held.
    function heldFeesOf(uint256 _projectId) external view override returns (JBFee[] memory) {
        return _heldFeesOf[_projectId];
    }

    //*********************************************************************//
    // -------------------------- public views --------------------------- //
    //*********************************************************************//

    /// @notice Indicates if this contract adheres to the specified interface.
    /// @dev See {IERC165-supportsInterface}.
    /// @param _interfaceId The ID of the interface to check for adherance to.
    /// @return A flag indicating if the provided interface ID is supported.
    function supportsInterface(bytes4 _interfaceId) public view virtual override returns (bool) {
        return _interfaceId == type(IJBPaymentTerminal).interfaceId
            || _interfaceId == type(IJBRedemptionTerminal).interfaceId
            || _interfaceId == type(IJBPayoutTerminal).interfaceId
            || _interfaceId == type(IJBPermitPaymentTerminal).interfaceId
            || _interfaceId == type(IJBMultiTerminal).interfaceId
            || _interfaceId == type(IJBFeeTerminal).interfaceId
            || _interfaceId == type(IERC165).interfaceId;
    }

    //*********************************************************************//
    // -------------------------- internal views ------------------------- //
    //*********************************************************************//

    /// @notice Checks the balance of tokens in this contract.
    /// @param _token The address of the token to which the balance applies.
    /// @return The contract's balance.
    function _balance(address _token) internal view virtual returns (uint256) {
        // If the token is ETH, assume the native token standard.
        return
            _token == JBTokens.ETH ? address(this).balance : IERC20(_token).balanceOf(address(this));
    }

    //*********************************************************************//
    // -------------------------- constructor ---------------------------- //
    //*********************************************************************//

    /// @param _projects A contract which mints ERC-721's that represent project ownership and transfers.
    /// @param _directory A contract storing directories of terminals and controllers for each project.
    /// @param _splitsStore A contract that stores splits for each project.
    /// @param _store A contract that stores the terminal's data.
    /// @param _permit2 A permit2 utility.
    /// @param _owner The address that will own this contract.
    constructor(
        IJBDirectory _directory,
        IJBTerminalStore _store,
        IPermit2 _permit2,
        address _trustedForwarder,
        address _owner
    ) JBOperatable(_directory.operatorStore()) Ownable(_owner) ERC2771Context(_trustedForwarder) {
        DIRECTORY = _directory;
        STORE = _store;
        PERMIT2 = _permit2;
        PROJECTS = _directory.projects();
        SPLITS = _directory.splitsStore();
    }

    //*********************************************************************//
    // ---------------------- external transactions ---------------------- //
    //*********************************************************************//

    /// @notice Pay tokens to a project.
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
        // Accept the funds.
        _amount = _acceptFundsFor(_projectId, _token, _amount, _metadata);

        // Pay the project.
        return _pay(
            _token,
            _amount,
            _msgSender(),
            _projectId,
            _beneficiary,
            _minReturnedTokens,
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
    function addToBalanceOf(
        uint256 _projectId,
        address _token,
        uint256 _amount,
        bool _shouldRefundHeldFees,
        string calldata _memo,
        bytes calldata _metadata
    ) external payable virtual override {
        // Accept the funds.
        _amount = _acceptFundsFor(_projectId, _token, _amount, _metadata);

        // Add to balance.
        _addToBalanceOf(_projectId, _token, _amount, _shouldRefundHeldFees, _memo, _metadata);
    }

    /// @notice Holders can redeem their tokens to claim the project's overflowed tokens, or to trigger rules determined by the project's current funding cycle's data source.
    /// @dev Only a token holder or a designated operator can redeem its tokens.
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
        return _redeemTokensOf(
            _holder, _projectId, _token, _tokenCount, _minReturnedTokens, _beneficiary, _metadata
        );
    }

    /// @notice Distributes payouts for a project with the distribution limit of its current funding cycle.
    /// @dev Payouts are sent to the preprogrammed splits. Any leftover is sent to the project's owner.
    /// @dev Anyone can distribute payouts on a project's behalf. The project can preconfigure a wildcard split that is used to send funds to  _msgSender(). This can be used to incentivize calling this function.
    /// @dev All funds distributed outside of this contract or any feeless terminals incure the protocol fee.
    /// @param _projectId The ID of the project having its payouts distributed.
    /// @param _token The token being distributed. This terminal ignores this property since it only manages one token.
    /// @param _amount The amount of terminal tokens to distribute, as a fixed point number with same number of decimals as this terminal.
    /// @param _currency The expected currency of the amount being distributed. Must match the project's current funding cycle's distribution limit currency.
    /// @param _minReturnedTokens The minimum number of terminal tokens that the `_amount` should be valued at in terms of this terminal's currency, as a fixed point number with the same number of decimals as this terminal.
    /// @return netLeftoverDistributionAmount The amount that was sent to the project owner, as a fixed point number with the same amount of decimals as this terminal.
    function distributePayoutsOf(
        uint256 _projectId,
        address _token,
        uint256 _amount,
        uint256 _currency,
        uint256 _minReturnedTokens
    ) external virtual override returns (uint256 netLeftoverDistributionAmount) {
        return _distributePayoutsOf(_projectId, _token, _amount, _currency, _minReturnedTokens);
    }

    /// @notice Allows a project to send funds from its overflow up to the preconfigured allowance.
    /// @dev Only a project's owner or a designated operator can use its allowance.
    /// @dev Incurs the protocol fee.
    /// @param _projectId The ID of the project to use the allowance of.
    /// @param _token The token being distributed. This terminal ignores this property since it only manages one token.
    /// @param _amount The amount of terminal tokens to use from this project's current allowance, as a fixed point number with the same amount of decimals as this terminal.
    /// @param _currency The expected currency of the amount being distributed. Must match the project's current funding cycle's overflow allowance currency.
    /// @param _minReturnedTokens The minimum number of tokens that the `_amount` should be valued at in terms of this terminal's currency, as a fixed point number with 18 decimals.
    /// @param _beneficiary The address to send the funds to.
    /// @param _memo A memo to pass along to the emitted event.
    /// @return netDistributedAmount The amount of tokens that was distributed to the beneficiary, as a fixed point number with the same amount of decimals as the terminal.
    function useAllowanceOf(
        uint256 _projectId,
        address _token,
        uint256 _amount,
        uint256 _currency,
        uint256 _minReturnedTokens,
        address payable _beneficiary,
        string calldata _memo
    )
        external
        virtual
        override
        requirePermission(PROJECTS.ownerOf(_projectId), _projectId, JBOperations.USE_ALLOWANCE)
        returns (uint256 netDistributedAmount)
    {
        return _useAllowanceOf(
            _projectId, _token, _amount, _currency, _minReturnedTokens, _beneficiary, _memo
        );
    }

    /// @notice Allows a project owner to migrate its funds and operations to a new terminal that accepts the same token type.
    /// @dev Only a project's owner or a designated operator can migrate it.
    /// @param _projectId The ID of the project being migrated.
    /// @param _token The address of the token being migrated.
    /// @param _to The terminal contract that will gain the project's funds.
    /// @return balance The amount of funds that were migrated, as a fixed point number with the same amount of decimals as this terminal.
    function migrateBalanceOf(uint256 _projectId, address _token, IJBPaymentTerminal _to)
        external
        virtual
        override
        requirePermission(PROJECTS.ownerOf(_projectId), _projectId, JBOperations.MIGRATE_TERMINAL)
        returns (uint256 balance)
    {
        // The terminal being migrated to must accept the same token as this terminal.
        if (_to.accountingContextForTokenOf(_projectId, _token).decimals == 0) {
            revert TERMINAL_TOKENS_INCOMPATIBLE();
        }

        // Record the migration in the store.
        balance = STORE.recordMigration(_projectId, _token);

        // Transfer the balance if needed.
        if (balance != 0) {
            // Trigger any inherited pre-transfer logic.
            _beforeTransferFor(address(_to), _token, balance);

            // If this terminal's token is ETH, send it in msg.value.
            uint256 _payValue = _token == JBTokens.ETH ? balance : 0;

            // Withdraw the balance to transfer to the new terminal;
            _to.addToBalanceOf{value: _payValue}(_projectId, _token, balance, false, "", bytes(""));
        }

        emit Migrate(_projectId, _token, _to, balance, _msgSender());
    }

    /// @notice Process any fees that are being held for the project.
    /// @dev Only a project owner, an operator, or the contract's owner can process held fees.
    /// @param _projectId The ID of the project whos held fees should be processed.
    function processFees(uint256 _projectId, address _token)
        external
        virtual
        override
        requirePermissionAllowingOverride(
            PROJECTS.ownerOf(_projectId),
            _projectId,
            JBOperations.PROCESS_FEES,
            _msgSender() == owner()
        )
    {
        // Get a reference to the project's held fees.
        JBFee[] memory _heldFees = _heldFeesOf[_projectId];

        // Delete the held fees.
        delete _heldFeesOf[_projectId];

        // Keep a reference to the amount.
        uint256 _amount;

        // Keep a reference to the number of held fees.
        uint256 _numberOfHeldFees = _heldFees.length;

        // Keep a reference to the fee being iterated on.
        JBFee memory _heldFee;

        // Keep a reference to the terminal that'll receive the fees.
        IJBPaymentTerminal _feeTerminal =
            DIRECTORY.primaryTerminalOf(_FEE_BENEFICIARY_PROJECT_ID, _token);

        // Process each fee.
        for (uint256 _i; _i < _numberOfHeldFees;) {
            // Keep a reference to the held fee being iterated on.
            _heldFee = _heldFees[_i];

            // Get the fee amount.
            _amount = (_heldFee.fee == 0 ? 0 : JBFees.feeIn(_heldFee.amount, _heldFee.fee));

            // Process the fee.
            _processFee(_projectId, _token, _amount, _heldFee.beneficiary, _feeTerminal);

            emit ProcessFee(_projectId, _amount, true, _heldFee.beneficiary, _msgSender());

            unchecked {
                ++_i;
            }
        }
    }

    /// @notice Sets whether projects operating on this terminal can pay towards the specified address without incurring a fee.
    /// @dev Only the owner of this contract can set addresses as feeless.
    /// @param _address The address that can be paid towards while still bypassing fees.
    /// @param _flag A flag indicating whether the terminal should be feeless or not.
    function setFeelessAddress(address _address, bool _flag) external virtual override onlyOwner {
        // Set the flag value.
        isFeelessAddress[_address] = _flag;

        emit SetFeelessAddress(_address, _flag, _msgSender());
    }

    /// @notice Sets accounting context for a token so that a project can begin accepting it.
    /// @dev Only a project owner, a designated operator, or a project's controller can set its accounting context.
    /// @param _projectId The ID of the project having its token accounting context set.
    /// @param _accountingContextConfigs The accounting contexts to set.
    function setAccountingContextsFor(
        uint256 _projectId,
        JBAccountingContextConfig[] calldata _accountingContextConfigs
    )
        external
        override
        requirePermissionAllowingOverride(
            PROJECTS.ownerOf(_projectId),
            _projectId,
            JBOperations.SET_ACCOUNTING_CONTEXT,
            _msgSender() == address(DIRECTORY.controllerOf(_projectId))
        )
    {
        // Keep a reference to the number of accounting context configurations.
        uint256 _numberOfAccountingContextsConfigs = _accountingContextConfigs.length;

        // Keep a reference to the accounting context being iterated on.
        JBAccountingContextConfig calldata _accountingContextConfig;

        // Set each accounting context.
        for (uint256 _i; _i < _numberOfAccountingContextsConfigs;) {
            // Set the accounting context being iterated on.
            _accountingContextConfig = _accountingContextConfigs[_i];

            // Get a storage reference to the currency accounting context for the token.
            JBAccountingContext storage _accountingContext =
                _accountingContextForTokenOf[_projectId][_accountingContextConfig.token];

            // Make sure the token accounting context isn't already set.
            if (_accountingContext.token != address(0)) {
                revert ACCOUNTING_CONTEXT_ALREADY_SET();
            }

            // Define the context from the config.
            _accountingContext.token = _accountingContextConfig.token;
            _accountingContext.decimals = _accountingContextConfig.standard
                == JBTokenStandards.NATIVE
                ? 18
                : IERC20Metadata(_accountingContextConfig.token).decimals();
            _accountingContext.currency = uint32(uint160(_accountingContextConfig.token));
            _accountingContext.standard = _accountingContextConfig.standard;

            // Add the token to the list of accepted tokens of the project.
            _accountingContextsOf[_projectId].push(_accountingContext);

            emit SetAccountingContext(
                _projectId, _accountingContextConfig.token, _accountingContext, _msgSender()
            );

            unchecked {
                ++_i;
            }
        }
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
        if (_msgSender() == address(this)) return _amount;

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
        _transferFor(_msgSender(), payable(address(this)), _token, _amount);

        // The amount should reflect the change in balance.
        return _balance(_token) - _balanceBefore;
    }

    /// @notice Contribute tokens to a project.
    /// @param _token The address of the token being paid.
    /// @param _amount The amount of terminal tokens being received, as a fixed point number with the same amount of decimals as this terminal. If this terminal's token is ETH, this is ignored and msg.value is used in its place.
    /// @param _payer The address making the payment.
    /// @param _projectId The ID of the project being paid.
    /// @param _beneficiary The address to mint tokens for and pass along to the funding cycle's data source and delegate.
    /// @param _minReturnedTokens The minimum number of project tokens expected in return, as a fixed point number with the same amount of decimals as this terminal.
    /// @param _memo A memo to pass along to the emitted event.
    /// @param _metadata Bytes to send along to the data source, delegate, and emitted event, if provided.
    /// @return beneficiaryTokenCount The number of tokens minted for the beneficiary, as a fixed point number with 18 decimals.
    function _pay(
        address _token,
        uint256 _amount,
        address _payer,
        uint256 _projectId,
        address _beneficiary,
        uint256 _minReturnedTokens,
        string memory _memo,
        bytes memory _metadata
    ) internal returns (uint256 beneficiaryTokenCount) {
        // Cant send tokens to the zero address.
        if (_beneficiary == address(0)) revert PAY_TO_ZERO_ADDRESS();

        // Define variables that will be needed outside the scoped section below.
        // Keep a reference to the funding cycle during which the payment is being made.
        JBFundingCycle memory _fundingCycle;

        // Scoped section prevents stack too deep. `_delegateAllocations` and `_tokenCount` only used within scope.
        {
            // Keep a references to the delegate allocations to fulfill and the number of tokens that should be minted to the beneficiary.
            JBPayDelegateAllocation3_1_1[] memory _delegateAllocations;
            uint256 _tokenCount;

            // Get a reference to the token's accounting context.
            JBAccountingContext memory _context = _accountingContextForTokenOf[_projectId][_token];

            // Bundle the amount info into a JBTokenAmount struct.
            JBTokenAmount memory _tokenAmount =
                JBTokenAmount(_token, _amount, _context.decimals, _context.currency);

            // Record the payment.
            (_fundingCycle, _tokenCount, _delegateAllocations) =
                STORE.recordPaymentFrom(_payer, _tokenAmount, _projectId, _beneficiary, _metadata);

            // Mint the tokens if needed.
            if (_tokenCount != 0) {
                // Set token count to be the number of tokens minted for the beneficiary instead of the total amount.
                beneficiaryTokenCount = IJBController3_1(
                    address(DIRECTORY.controllerOf(_projectId))
                ).mintTokensOf(_projectId, _tokenCount, _beneficiary, "", true);
            }

            // The token count for the beneficiary must be greater than or equal to the minimum expected.
            if (beneficiaryTokenCount < _minReturnedTokens) {
                revert INADEQUATE_TOKEN_COUNT();
            }

            // If delegate allocations were specified by the data source, fulfill them.
            if (_delegateAllocations.length != 0) {
                _fulfillPayDelegateAllocationsFor(
                    _projectId,
                    _delegateAllocations,
                    _tokenAmount,
                    _payer,
                    _fundingCycle,
                    _beneficiary,
                    beneficiaryTokenCount,
                    _metadata
                );
            }
        }

        emit Pay(
            _fundingCycle.configuration,
            _fundingCycle.number,
            _projectId,
            _payer,
            _beneficiary,
            _amount,
            beneficiaryTokenCount,
            _memo,
            _metadata,
            _msgSender()
        );
    }

    /// @notice Receives funds belonging to the specified project.
    /// @param _projectId The ID of the project to which the funds received belong.
    /// @param _token The address of the token being added to the project's balance.
    /// @param _amount The amount of tokens to add, as a fixed point number with the same number of decimals as this terminal. If this is an ETH terminal, this is ignored and msg.value is used instead.
    /// @param _shouldRefundHeldFees A flag indicating if held fees should be refunded based on the amount being added.
    /// @param _memo A memo to pass along to the emitted event.
    /// @param _metadata Extra data to pass along to the emitted event.
    function _addToBalanceOf(
        uint256 _projectId,
        address _token,
        uint256 _amount,
        bool _shouldRefundHeldFees,
        string memory _memo,
        bytes memory _metadata
    ) internal {
        // Refund any held fees to make sure the project doesn't pay double for funds going in and out of the protocol.
        uint256 _refundedFees = _shouldRefundHeldFees ? _refundHeldFees(_projectId, _amount) : 0;

        // Record the added funds with any refunded fees.
        STORE.recordAddedBalanceFor(_projectId, _token, _amount + _refundedFees);

        emit AddToBalance(_projectId, _amount, _refundedFees, _memo, _metadata, _msgSender());
    }

    /// @notice Holders can redeem their tokens to claim the project's overflowed tokens, or to trigger rules determined by the project's current funding cycle's data source.
    /// @dev Only a token holder or a designated operator can redeem its tokens.
    /// @param _holder The account to redeem tokens for.
    /// @param _projectId The ID of the project to which the tokens being redeemed belong.
    /// @param _token The address of the token being reclaimed from the redemption.
    /// @param _tokenCount The number of project tokens to redeem, as a fixed point number with 18 decimals.
    /// @param _minReturnedTokens The minimum amount of terminal tokens expected in return, as a fixed point number with the same amount of decimals as the terminal.
    /// @param _beneficiary The address to send the terminal tokens to.
    /// @param _metadata Bytes to send along to the data source, delegate, and emitted event, if provided.
    /// @return reclaimAmount The amount of terminal tokens that the project tokens were redeemed for, as a fixed point number with 18 decimals.
    function _redeemTokensOf(
        address _holder,
        uint256 _projectId,
        address _token,
        uint256 _tokenCount,
        uint256 _minReturnedTokens,
        address payable _beneficiary,
        bytes memory _metadata
    ) internal returns (uint256 reclaimAmount) {
        // Can't send reclaimed funds to the zero address.
        if (_beneficiary == address(0)) revert REDEEM_TO_ZERO_ADDRESS();

        // Define variables that will be needed outside the scoped section below.
        // Keep a reference to the funding cycle during which the redemption is being made.
        JBFundingCycle memory _fundingCycle;

        // Scoped section prevents stack too deep.
        {
            JBRedemptionDelegateAllocation3_1_1[] memory _delegateAllocations;

            // Record the redemption.
            (_fundingCycle, reclaimAmount, _delegateAllocations) = STORE.recordRedemptionFor(
                _holder,
                _projectId,
                _accountingContextForTokenOf[_projectId][_token],
                _accountingContextsOf[_projectId],
                _tokenCount,
                _metadata
            );

            // Set the fee. No fee if the beneficiary is feeless, if the redemption rate is at its max, or if the fee beneficiary doesn't accept the given token.
            uint256 _feePercent = isFeelessAddress[_beneficiary]
                || _fundingCycle.redemptionRate() == JBConstants.MAX_REDEMPTION_RATE ? 0 : FEE;

            // The amount being reclaimed must be at least as much as was expected.
            if (reclaimAmount < _minReturnedTokens) {
                revert INADEQUATE_RECLAIM_AMOUNT();
            }

            // Burn the project tokens.
            if (_tokenCount != 0) {
                IJBController3_1(address(DIRECTORY.controllerOf(_projectId))).burnTokensOf(
                    _holder, _projectId, _tokenCount, ""
                );
            }

            // Keep a reference to the amount being reclaimed that should have fees withheld from.
            uint256 _feeEligibleDistributionAmount;

            // If delegate allocations were specified by the data source, fulfill them.
            if (_delegateAllocations.length != 0) {
                // Get a reference to the token's accounting context.
                JBAccountingContext memory _context =
                    _accountingContextForTokenOf[_projectId][_token];

                // Fulfill the delegates.
                _feeEligibleDistributionAmount += _fulfillRedemptionDelegateAllocationsFor(
                    _projectId,
                    JBTokenAmount(_token, reclaimAmount, _context.decimals, _context.currency),
                    _holder,
                    _tokenCount,
                    _metadata,
                    _fundingCycle,
                    _beneficiary,
                    _delegateAllocations,
                    _feePercent
                );
            }

            // Send the reclaimed funds to the beneficiary.
            if (reclaimAmount != 0) {
                if (_feePercent != 0) {
                    _feeEligibleDistributionAmount += reclaimAmount;
                    // Subtract the fee for the reclaimed amount.
                    reclaimAmount -= JBFees.feeIn(reclaimAmount, _feePercent);
                }

                // Subtract the fee from the reclaim amount.
                if (reclaimAmount != 0) {
                    _transferFor(address(this), _beneficiary, _token, reclaimAmount);
                }
            }

            // Take the fee from all outbound reclaimations.
            _feeEligibleDistributionAmount != 0
                ? _takeFeeFrom(
                    _projectId, _token, _feeEligibleDistributionAmount, _feePercent, _beneficiary, false
                )
                : 0;
        }

        emit RedeemTokens(
            _fundingCycle.configuration,
            _fundingCycle.number,
            _projectId,
            _holder,
            _beneficiary,
            _tokenCount,
            reclaimAmount,
            _metadata,
            _msgSender()
        );
    }

    /// @notice Distributes payouts for a project with the distribution limit of its current funding cycle.
    /// @dev Payouts are sent to the preprogrammed splits. Any leftover is sent to the project's owner.
    /// @dev Anyone can distribute payouts on a project's behalf. The project can preconfigure a wildcard split that is used to send funds to  _msgSender(). This can be used to incentivize calling this function.
    /// @dev All funds distributed outside of this contract or any feeless terminals incure the protocol fee.
    /// @param _projectId The ID of the project having its payouts distributed.
    /// @param _token The token being distributed.
    /// @param _amount The amount of terminal tokens to distribute, as a fixed point number with same number of decimals as this terminal.
    /// @param _currency The expected currency of the amount being distributed. Must match the project's current funding cycle's distribution limit currency.
    /// @param _minReturnedTokens The minimum number of terminal tokens that the `_amount` should be valued at in terms of this terminal's currency, as a fixed point number with the same number of decimals as this terminal.
    /// @return netLeftoverDistributionAmount The amount that was sent to the project owner, as a fixed point number with the same amount of decimals as this terminal.
    function _distributePayoutsOf(
        uint256 _projectId,
        address _token,
        uint256 _amount,
        uint256 _currency,
        uint256 _minReturnedTokens
    ) internal returns (uint256 netLeftoverDistributionAmount) {
        // Record the distribution.
        (JBFundingCycle memory _fundingCycle, uint256 _distributedAmount) = STORE
            .recordDistributionFor(
            _projectId, _accountingContextForTokenOf[_projectId][_token], _amount, _currency
        );

        // The amount being distributed must be at least as much as was expected.
        if (_distributedAmount < _minReturnedTokens) {
            revert INADEQUATE_DISTRIBUTION_AMOUNT();
        }

        // Get a reference to the project owner, which will receive tokens from paying the platform fee
        // and receive any extra distributable funds not allocated to payout splits.
        address payable _projectOwner = payable(PROJECTS.ownerOf(_projectId));

        // Keep a reference to the fee.
        // The fee is 0 if the fee beneficiary doesn't accept the given token.
        uint256 _feePercent = FEE;

        // Payout to splits and get a reference to the leftover transfer amount after all splits have been paid.
        // Also get a reference to the amount that was distributed to splits from which fees should be taken.
        (uint256 _leftoverDistributionAmount, uint256 _feeEligibleDistributionAmount) =
        _distributeToPayoutSplitsOf(
            _projectId, _token, _fundingCycle.configuration, _distributedAmount, _feePercent
        );

        // Take the fee.
        uint256 _feeTaken = _feePercent != 0
            ? _takeFeeFrom(
                _projectId,
                _token,
                _feeEligibleDistributionAmount + _leftoverDistributionAmount,
                _feePercent,
                _projectOwner,
                _fundingCycle.shouldHoldFees()
            )
            : 0;

        // Transfer any remaining balance to the project owner and update returned leftover accordingly.
        if (_leftoverDistributionAmount != 0) {
            // Subtract the fee from the net leftover amount.
            netLeftoverDistributionAmount = _leftoverDistributionAmount
                - (_feePercent == 0 ? 0 : JBFees.feeIn(_leftoverDistributionAmount, _feePercent));

            // Transfer the amount to the project owner.
            _transferFor(address(this), _projectOwner, _token, netLeftoverDistributionAmount);
        }

        emit DistributePayouts(
            _fundingCycle.configuration,
            _fundingCycle.number,
            _projectId,
            _projectOwner,
            _amount,
            _distributedAmount,
            _feeTaken,
            netLeftoverDistributionAmount,
            _msgSender()
        );
    }

    /// @notice Allows a project to send funds from its overflow up to the preconfigured allowance.
    /// @dev Only a project's owner or a designated operator can use its allowance.
    /// @dev Incurs the protocol fee.
    /// @param _projectId The ID of the project to use the allowance of.
    /// @param _token The address of the token who's allowance is being used.
    /// @param _amount The amount of terminal tokens to use from this project's current allowance, as a fixed point number with the same amount of decimals as this terminal.
    /// @param _currency The expected currency of the amount being distributed. Must match the project's current funding cycle's overflow allowance currency.
    /// @param _minReturnedTokens The minimum number of tokens that the `_amount` should be valued at in terms of this terminal's currency, as a fixed point number with 18 decimals.
    /// @param _beneficiary The address to send the funds to.
    /// @param _memo A memo to pass along to the emitted event.
    /// @return netDistributedAmount The amount of tokens that was distributed to the beneficiary, as a fixed point number with the same amount of decimals as the terminal.
    function _useAllowanceOf(
        uint256 _projectId,
        address _token,
        uint256 _amount,
        uint256 _currency,
        uint256 _minReturnedTokens,
        address payable _beneficiary,
        string memory _memo
    ) internal returns (uint256 netDistributedAmount) {
        // Record the use of the allowance.
        (JBFundingCycle memory _fundingCycle, uint256 _distributedAmount) = STORE
            .recordUsedAllowanceOf(
            _projectId, _accountingContextForTokenOf[_projectId][_token], _amount, _currency
        );

        // The amount being withdrawn must be at least as much as was expected.
        if (_distributedAmount < _minReturnedTokens) {
            revert INADEQUATE_DISTRIBUTION_AMOUNT();
        }

        // Get a reference to the project owner, which will receive tokens from paying the platform fee.
        address _projectOwner = PROJECTS.ownerOf(_projectId);

        // Keep a reference to the fee.
        // The fee is 0 if the sender is marked as feeless or if the fee beneficiary project doesn't accept the given token.
        uint256 _feePercent = isFeelessAddress[_msgSender()] ? 0 : FEE;

        unchecked {
            // Take a fee from the `_distributedAmount`, if needed.
            // The net amount is the withdrawn amount without the fee.
            netDistributedAmount = _distributedAmount
                - (
                    _feePercent == 0
                        ? 0
                        : _takeFeeFrom(
                            _projectId,
                            _token,
                            _distributedAmount,
                            _feePercent,
                            _projectOwner,
                            _fundingCycle.shouldHoldFees()
                        )
                );
        }

        // Transfer any remaining balance to the beneficiary.
        if (netDistributedAmount != 0) {
            _transferFor(address(this), _beneficiary, _token, netDistributedAmount);
        }

        emit UseAllowance(
            _fundingCycle.configuration,
            _fundingCycle.number,
            _projectId,
            _beneficiary,
            _amount,
            _distributedAmount,
            netDistributedAmount,
            _memo,
            _msgSender()
        );
    }

    /// @notice Pays out splits for a project's funding cycle configuration.
    /// @param _projectId The ID of the project for which payout splits are being distributed.
    /// @param _token The address of the token being distributed.
    /// @param _domain The domain of the splits to distribute the payout between.
    /// @param _amount The total amount being distributed, as a fixed point number with the same number of decimals as this terminal.
    /// @param _feePercent The percent of fees to take, out of MAX_FEE.
    /// @return If the leftover amount if the splits don't add up to 100%.
    /// @return feeEligibleDistributionAmount The total amount of distributions that are eligible to have fees taken from.
    function _distributeToPayoutSplitsOf(
        uint256 _projectId,
        address _token,
        uint256 _domain,
        uint256 _amount,
        uint256 _feePercent
    ) internal returns (uint256, uint256 feeEligibleDistributionAmount) {
        // The total percentage available to split
        uint256 _leftoverPercentage = JBConstants.SPLITS_TOTAL_PERCENT;

        // Get a reference to the project's payout splits.
        JBSplit[] memory _splits = SPLITS.splitsOf(_projectId, _domain, uint256(uint160(_token)));

        // Keep a reference to the number of splits being iterated on.
        uint256 _numberOfSplits = _splits.length;

        // Keep a reference to the split being iterated on.
        JBSplit memory _split;

        // Transfer between all splits.
        for (uint256 _i; _i < _numberOfSplits;) {
            // Get a reference to the split being iterated on.
            _split = _splits[_i];

            // The amount to send towards the split.
            uint256 _payoutAmount = PRBMath.mulDiv(_amount, _split.percent, _leftoverPercentage);

            // The payout amount substracting any applicable incurred fees.
            uint256 _netPayoutAmount =
                _distributeToPayoutSplit(_split, _projectId, _token, _payoutAmount, _feePercent);

            // If the split allocator is set as feeless, this distribution is not eligible for a fee.
            if (_netPayoutAmount != 0 && _netPayoutAmount != _payoutAmount) {
                feeEligibleDistributionAmount += _payoutAmount;
            }

            if (_payoutAmount != 0) {
                // Subtract from the amount to be sent to the beneficiary.
                unchecked {
                    _amount -= _payoutAmount;
                }
            }

            unchecked {
                // Decrement the leftover percentage.
                _leftoverPercentage -= _split.percent;
            }

            emit DistributeToPayoutSplit(
                _projectId,
                _domain,
                uint256(uint160(_token)),
                _split,
                _payoutAmount,
                _netPayoutAmount,
                _msgSender()
            );

            unchecked {
                ++_i;
            }
        }

        return (_amount, feeEligibleDistributionAmount);
    }

    /// @notice Pays out a split for a project's funding cycle configuration.
    /// @param _split The split to distribute payouts to.
    /// @param _projectId The ID of the project to which the split is originating.
    /// @param _token The address of the token being paid out.
    /// @param _amount The total amount being distributed to the split, as a fixed point number with the same number of decimals as this terminal.
    /// @param _feePercent The percent of fees to take, out of MAX_FEE.
    /// @return netPayoutAmount The amount sent to the split after subtracting fees.
    function _distributeToPayoutSplit(
        JBSplit memory _split,
        uint256 _projectId,
        address _token,
        uint256 _amount,
        uint256 _feePercent
    ) internal returns (uint256 netPayoutAmount) {
        // By default, the net payout amount is the full amount. This will be adjusted if fees are taken.
        netPayoutAmount = _amount;

        // If there's an allocator set, transfer to its `allocate` function.
        if (_split.allocator != IJBSplitAllocator(address(0))) {
            // This distribution is eligible for a fee since the funds are leaving this contract and the allocator isn't listed as feeless.
            if (_feePercent != 0 && !isFeelessAddress[address(_split.allocator)]) {
                unchecked {
                    netPayoutAmount -= JBFees.feeIn(_amount, _feePercent);
                }
            }

            // Trigger any inherited pre-transfer logic.
            _beforeTransferFor(address(_split.allocator), _token, netPayoutAmount);

            // Create the data to send to the allocator.
            JBSplitAllocationData memory _data = JBSplitAllocationData({
                token: _token,
                amount: netPayoutAmount,
                decimals: _accountingContextForTokenOf[_projectId][_token].decimals,
                projectId: _projectId,
                group: uint256(uint160(_token)),
                split: _split
            });

            // Trigger the allocator's `allocate` function.
            bytes memory _reason;

            if (
                ERC165Checker.supportsInterface(
                    address(_split.allocator), type(IJBSplitAllocator).interfaceId
                )
            ) {
                // Keep a reference to the value that'll be paid to the allocator.
                uint256 _payValue = _token == JBTokens.ETH ? netPayoutAmount : 0;

                // If this terminal's token is ETH, send it in msg.value.
                try _split.allocator.allocate{value: _payValue}(_data) {}
                catch (bytes memory __reason) {
                    _reason = __reason.length == 0 ? abi.encode("Allocate fail") : __reason;
                }
            } else {
                _reason = abi.encode("IERC165 fail");
            }

            if (_reason.length != 0) {
                // Revert the payout.
                _revertTransferFrom(
                    _projectId, _token, address(_split.allocator), netPayoutAmount, _amount
                );

                // Set the net payout amount to 0 to signal the reversion.
                netPayoutAmount = 0;

                emit PayoutReverted(_projectId, _split, _amount, _reason, _msgSender());
            }

            // Otherwise, if a project is specified, make a payment to it.
        } else if (_split.projectId != 0) {
            // Get a reference to the Juicebox terminal being used.
            IJBPaymentTerminal _terminal = DIRECTORY.primaryTerminalOf(_split.projectId, _token);

            // The project must have a terminal to send funds to.
            if (_terminal == IJBPaymentTerminal(address(0))) {
                // Set the net payout amount to 0 to signal the reversion.
                netPayoutAmount = 0;

                // Revert the payout.
                _revertTransferFrom(_projectId, _token, address(0), 0, _amount);

                // Specify the reason for reverting.
                bytes memory _reason = "Terminal not found";

                emit PayoutReverted(_projectId, _split, _amount, _reason, _msgSender());
            } else {
                // This distribution is eligible for a fee since the funds are leaving this contract and the terminal isn't listed as feeless.
                if (_terminal != this && _feePercent != 0 && !isFeelessAddress[address(_terminal)])
                {
                    unchecked {
                        netPayoutAmount -= JBFees.feeIn(_amount, _feePercent);
                    }
                }

                // Trigger any inherited pre-transfer logic.
                _beforeTransferFor(address(_terminal), _token, netPayoutAmount);

                // Keep a reference to the amount that'll be paid in.
                uint256 _payValue = _token == JBTokens.ETH ? netPayoutAmount : 0;

                // Add to balance if prefered.
                bytes memory _metadata = bytes(abi.encodePacked(_projectId));
                if (_split.preferAddToBalance) {
                    try _terminal.addToBalanceOf{value: _payValue}(
                        _split.projectId,
                        _token,
                        netPayoutAmount,
                        false,
                        "",
                        // Send the projectId in the metadata as a referral.
                        _metadata
                    ) {} catch (bytes memory _reason) {
                        // Revert the payout.
                        _revertTransferFrom(
                            _projectId, _token, address(_terminal), netPayoutAmount, _amount
                        );

                        // Set the net payout amount to 0 to signal the reversion.
                        netPayoutAmount = 0;

                        emit PayoutReverted(_projectId, _split, _amount, _reason, _msgSender());
                    }
                } else {
                    try _terminal.pay{value: _payValue}(
                        _split.projectId,
                        _token,
                        netPayoutAmount,
                        _split.beneficiary != address(0) ? _split.beneficiary : _msgSender(),
                        0,
                        "",
                        // Send the projectId in the metadata as a referral.
                        _metadata
                    ) {} catch (bytes memory _reason) {
                        // Revert the payout.
                        _revertTransferFrom(
                            _projectId, _token, address(_terminal), netPayoutAmount, _amount
                        );

                        // Set the net payout amount to 0 to signal the reversion.
                        netPayoutAmount = 0;

                        emit PayoutReverted(_projectId, _split, _amount, _reason, _msgSender());
                    }
                }
            }
        } else {
            // This distribution is eligible for a fee since the funds are leaving this contract and the beneficiary isn't listed as feeless.
            // Don't enforce feeless address for the beneficiary since the funds are leaving the ecosystem.
            if (_feePercent != 0) {
                unchecked {
                    netPayoutAmount -= JBFees.feeIn(_amount, _feePercent);
                }
            }

            // If there's a beneficiary, send the funds directly to the beneficiary. Otherwise send to the  _msgSender().
            _transferFor(
                address(this),
                _split.beneficiary != address(0) ? _split.beneficiary : payable(_msgSender()),
                _token,
                netPayoutAmount
            );
        }
    }

    /// @notice Fulfills payment allocations to a list of delegates.
    /// @param _projectId The ID of the project being paid that is forwarding allocations to delegates.
    /// @param _allocations The allocations being fulfilled.
    /// @param _tokenAmount The amount of tokens that were paid in to the project.
    /// @param _payer The address that sent the payment.
    /// @param _fundingCycle The funding cycle during which the payment is being accepted during.
    /// @param _beneficiary The address receiving tokens that result from the payment.
    /// @param _beneficiaryTokenCount The amount of tokens that are being minted for the beneificary.
    /// @param _metadata Bytes to send along to the data source, delegate, and emitted event, if provided.
    function _fulfillPayDelegateAllocationsFor(
        uint256 _projectId,
        JBPayDelegateAllocation3_1_1[] memory _allocations,
        JBTokenAmount memory _tokenAmount,
        address _payer,
        JBFundingCycle memory _fundingCycle,
        address _beneficiary,
        uint256 _beneficiaryTokenCount,
        bytes memory _metadata
    ) internal {
        // The accounting context.
        JBDidPayData3_1_1 memory _data = JBDidPayData3_1_1(
            _payer,
            _projectId,
            _fundingCycle.configuration,
            _tokenAmount,
            _tokenAmount,
            _fundingCycle.weight,
            _beneficiaryTokenCount,
            _beneficiary,
            bytes(""),
            _metadata
        );

        // Keep a reference to the number of allocations there are.
        uint256 _numberOfAllocations = _allocations.length;

        // Keep a reference to the allocation being iterated on.
        JBPayDelegateAllocation3_1_1 memory _allocation;

        // Fulfill each allocation.
        for (uint256 _i; _i < _numberOfAllocations;) {
            // Set the allocation being iterated on.
            _allocation = _allocations[_i];

            // Pass the correct token forwardedAmount to the delegate
            _data.forwardedAmount = JBTokenAmount({
                value: _allocation.amount,
                token: _tokenAmount.token,
                decimals: _tokenAmount.decimals,
                currency: _tokenAmount.currency
            });

            // Pass the correct metadata from the data source.
            _data.dataSourceMetadata = _allocation.metadata;

            // Trigger any inherited pre-transfer logic.
            _beforeTransferFor(
                address(_allocation.delegate), _tokenAmount.token, _allocation.amount
            );

            uint256 _payValue = _tokenAmount.token == JBTokens.ETH ? _allocation.amount : 0;

            // Fulfill the allocation.
            _allocation.delegate.didPay{value: _payValue}(_data);

            emit DelegateDidPay(_allocation.delegate, _data, _allocation.amount, _msgSender());

            unchecked {
                ++_i;
            }
        }
    }

    /// @notice Fulfills redemption allocations to a list of delegates.
    /// @param _projectId The ID of the project being redeemed from that is forwarding allocations to delegates.
    /// @param _beneficiaryTokenAmount The amount of tokens that are being reclaimed from the project.
    /// @param _holder The address that is redeeming.
    /// @param _tokenCount The amount of tokens that are being redeemed by the holder.
    /// @param _metadata Bytes to send along to the data source, delegate, and emitted event, if provided.
    /// @param _fundingCycle The funding cycle during which the redemption is being made during.
    /// @param _beneficiary The address receiving reclaimed treasury tokens that result from the redemption.
    /// @param _allocations The allocations being fulfilled.
    /// @param _feePercent The percent fee that will apply to funds allocated to delegates.
    /// @return feeEligibleDistributionAmount The amount of allocated funds to delegates that are eligible for fees.
    function _fulfillRedemptionDelegateAllocationsFor(
        uint256 _projectId,
        JBTokenAmount memory _beneficiaryTokenAmount,
        address _holder,
        uint256 _tokenCount,
        bytes memory _metadata,
        JBFundingCycle memory _fundingCycle,
        address payable _beneficiary,
        JBRedemptionDelegateAllocation3_1_1[] memory _allocations,
        uint256 _feePercent
    ) internal returns (uint256 feeEligibleDistributionAmount) {
        // Keep a reference to the data that'll get send to delegates.
        JBDidRedeemData3_1_1 memory _data = JBDidRedeemData3_1_1(
            _holder,
            _projectId,
            _fundingCycle.configuration,
            _tokenCount,
            _beneficiaryTokenAmount,
            _beneficiaryTokenAmount,
            _fundingCycle.redemptionRate(),
            _beneficiary,
            "",
            _metadata
        );

        // Keep a reference to the number of allocations there are.
        uint256 _numberOfAllocations = _allocations.length;

        // Keep a reference to the allocation being iterated on.
        JBRedemptionDelegateAllocation3_1_1 memory _allocation;

        for (uint256 _i; _i < _numberOfAllocations;) {
            // Set the allocation being iterated on.
            _allocation = _allocations[_i];

            // Trigger any inherited pre-transfer logic.
            _beforeTransferFor(
                address(_allocation.delegate), _beneficiaryTokenAmount.token, _allocation.amount
            );

            // Get the fee for the delegated amount.
            uint256 _delegatedAmountFee =
                _feePercent == 0 ? 0 : JBFees.feeIn(_allocation.amount, _feePercent);

            // Add the delegated amount to the amount eligible for having a fee taken.
            if (_delegatedAmountFee != 0) {
                feeEligibleDistributionAmount += _allocation.amount;
                _allocation.amount -= _delegatedAmountFee;
            }

            // Set the value of the forwarded amount.
            _data.forwardedAmount = JBTokenAmount({
                value: _allocation.amount,
                token: _beneficiaryTokenAmount.token,
                decimals: _beneficiaryTokenAmount.decimals,
                currency: _beneficiaryTokenAmount.currency
            });

            // Pass the correct metadata from the data source.
            _data.dataSourceMetadata = _allocation.metadata;

            // Keep a reference to the value that will be forwarded.
            uint256 _payValue =
                _beneficiaryTokenAmount.token == JBTokens.ETH ? _allocation.amount : 0;

            // Fulfill the allocation.
            _allocation.delegate.didRedeem{value: _payValue}(_data);

            emit DelegateDidRedeem(
                _allocation.delegate, _data, _allocation.amount, _delegatedAmountFee, _msgSender()
            );

            unchecked {
                ++_i;
            }
        }
    }

    /// @notice Takes a fee into the platform's project, which has an id of _FEE_BENEFICIARY_PROJECT_ID.
    /// @param _projectId The ID of the project having fees taken from.
    /// @param _token The address of the token that the fee is being taken in.
    /// @param _amount The amount of the fee to take, as a floating point number with 18 decimals.
    /// @param _feePercent The percent of fees to take, out of MAX_FEE.
    /// @param _beneficiary The address to mint the platforms tokens for.
    /// @param _shouldHoldFees If fees should be tracked and held back.
    /// @return feeAmount The amount of the fee taken.
    function _takeFeeFrom(
        uint256 _projectId,
        address _token,
        uint256 _amount,
        uint256 _feePercent,
        address _beneficiary,
        bool _shouldHoldFees
    ) internal returns (uint256 feeAmount) {
        // Get a reference to the fee amount.
        feeAmount = JBFees.feeIn(_amount, _feePercent);

        if (_shouldHoldFees) {
            // Store the held fee.
            _heldFeesOf[_projectId].push(JBFee(_amount, uint32(_feePercent), _beneficiary));

            emit HoldFee(_projectId, _amount, _feePercent, _beneficiary, _msgSender());
        } else {
            // Get the terminal that'll receive the fee if one wasn't provided.
            IJBPaymentTerminal _feeTerminal =
                DIRECTORY.primaryTerminalOf(_FEE_BENEFICIARY_PROJECT_ID, _token);

            // Process the fee.
            _processFee(_projectId, _token, feeAmount, _beneficiary, _feeTerminal);

            emit ProcessFee(_projectId, feeAmount, false, _beneficiary, _msgSender());
        }
    }

    /// @notice Process a fee of the specified amount from a project.
    /// @param _projectId The project ID the fee is being paid from.
    /// @param _token The token the fee is being paid in.
    /// @param _amount The fee amount, as a floating point number with 18 decimals.
    /// @param _beneficiary The address to mint the platform's tokens for.
    /// @param _feeTerminal The terminal that'll receive the fees. This'll be filled if one isn't provided.
    function _processFee(
        uint256 _projectId,
        address _token,
        uint256 _amount,
        address _beneficiary,
        IJBPaymentTerminal _feeTerminal
    ) internal {
        if (address(_feeTerminal) == address(0)) {
            _revertTransferFrom(_projectId, _token, address(0), 0, _amount);

            // Specify the reason for reverting.
            bytes memory _reason = "Fee not accepted";

            emit FeeReverted(
                _projectId, _FEE_BENEFICIARY_PROJECT_ID, _amount, _reason, _msgSender()
            );
            return;
        }

        // Trigger any inherited pre-transfer logic if funds will be transferred.
        if (address(_feeTerminal) != address(this)) {
            _beforeTransferFor(address(_feeTerminal), _token, _amount);
        }

        // Keep a reference to the amount that'll be paid in.
        uint256 _payValue = _token == JBTokens.ETH ? _amount : 0;

        try _feeTerminal
            // Send the fee.
            // If this terminal's token is ETH, send it in msg.value.
            .pay{value: _payValue}(
            _FEE_BENEFICIARY_PROJECT_ID,
            _token,
            _amount,
            _beneficiary,
            0,
            "",
            // Send the projectId in the metadata.
            bytes(abi.encodePacked(_projectId))
        ) {} catch (bytes memory _reason) {
            _revertTransferFrom(
                _projectId,
                _token,
                address(_feeTerminal) != address(this) ? address(_feeTerminal) : address(0),
                address(_feeTerminal) != address(this) ? _amount : 0,
                _amount
            );
            emit FeeReverted(
                _projectId, _FEE_BENEFICIARY_PROJECT_ID, _amount, _reason, _msgSender()
            );
        }
    }

    /// @notice Refund fees based on the specified amount.
    /// @param _projectId The project for which fees are being refunded.
    /// @param _amount The amount to base the refund on, as a fixed point number with the same amount of decimals as this terminal.
    /// @return refundedFees How much fees were refunded, as a fixed point number with the same number of decimals as this terminal
    function _refundHeldFees(uint256 _projectId, uint256 _amount)
        internal
        returns (uint256 refundedFees)
    {
        // Get a reference to the project's held fees.
        JBFee[] memory _heldFees = _heldFeesOf[_projectId];

        // Delete the current held fees.
        delete _heldFeesOf[_projectId];

        // Get a reference to the leftover amount once all fees have been settled.
        uint256 leftoverAmount = _amount;

        // Keep a reference to the number of held fees.
        uint256 _numberOfHeldFees = _heldFees.length;

        // Keep a reference to the fee being iterated on.
        JBFee memory _heldFee;

        // Process each fee.
        for (uint256 _i; _i < _numberOfHeldFees;) {
            // Save the fee being iterated on.
            _heldFee = _heldFees[_i];

            if (leftoverAmount == 0) {
                _heldFeesOf[_projectId].push(_heldFee);
            } else {
                // Notice here we take feeIn the stored .amount
                uint256 _feeAmount =
                    (_heldFee.fee == 0 ? 0 : JBFees.feeIn(_heldFee.amount, _heldFee.fee));

                if (leftoverAmount >= _heldFee.amount - _feeAmount) {
                    unchecked {
                        leftoverAmount = leftoverAmount - (_heldFee.amount - _feeAmount);
                        refundedFees += _feeAmount;
                    }
                } else {
                    // And here we overwrite with feeFrom the leftoverAmount
                    _feeAmount =
                        _heldFee.fee == 0 ? 0 : JBFees.feeFrom(leftoverAmount, _heldFee.fee);

                    unchecked {
                        _heldFeesOf[_projectId].push(
                            JBFee(
                                _heldFee.amount - (leftoverAmount + _feeAmount),
                                _heldFee.fee,
                                _heldFee.beneficiary
                            )
                        );
                        refundedFees += _feeAmount;
                    }
                    leftoverAmount = 0;
                }
            }

            unchecked {
                ++_i;
            }
        }

        emit RefundHeldFees(_projectId, _amount, refundedFees, leftoverAmount, _msgSender());
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
            _msgSender(),
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

    /// @notice Returns the sender, prefered to use over `msg.sender`
    /// @return _sender the sender address of this call.
    function _msgSender()
        internal
        view
        override(ERC2771Context, Context)
        returns (address _sender)
    {
        return ERC2771Context._msgSender();
    }

    /// @notice Returns the calldata, prefered to use over `msg.data`
    /// @return _calldata the `msg.data` of this call
    function _msgData()
        internal
        view
        override(ERC2771Context, Context)
        returns (bytes calldata _calldata)
    {
        return ERC2771Context._msgData();
    }
}
