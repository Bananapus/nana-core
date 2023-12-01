// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {PRBMath} from "@paulrberg/contracts/math/PRBMath.sol";
import {IJBController3_1} from "./interfaces/IJBController3_1.sol";
import {IJBDirectory} from "./interfaces/IJBDirectory.sol";
import {IJBFundingCycleDataSource3_1_1} from "./interfaces/IJBFundingCycleDataSource3_1_1.sol";
import {IJBFundingCycleStore} from "./interfaces/IJBFundingCycleStore.sol";
import {IJBPrices} from "./interfaces/IJBPrices.sol";
import {IJBPrices} from "./interfaces/IJBPrices.sol";
import {IJBPaymentTerminal} from "./interfaces/terminal/IJBPaymentTerminal.sol";
import {IJBTerminalStore} from "./interfaces/IJBTerminalStore.sol";
import {JBConstants} from "./libraries/JBConstants.sol";
import {JBFixedPointNumber} from "./libraries/JBFixedPointNumber.sol";
import {JBCurrencyAmount} from "./structs/JBCurrencyAmount.sol";
import {JBFundingCycleMetadataResolver} from "./libraries/JBFundingCycleMetadataResolver.sol";
import {JBFundingCycle} from "./structs/JBFundingCycle.sol";
import {JBPayDelegateAllocation3_1_1} from "./structs/JBPayDelegateAllocation3_1_1.sol";
import {JBPayParamsData} from "./structs/JBPayParamsData.sol";
import {JBRedeemParamsData} from "./structs/JBRedeemParamsData.sol";
import {JBRedemptionDelegateAllocation3_1_1} from
    "./structs/JBRedemptionDelegateAllocation3_1_1.sol";
import {JBAccountingContext} from "./structs/JBAccountingContext.sol";
import {JBTokenAmount} from "./structs/JBTokenAmount.sol";

/// @notice Manages all bookkeeping for inflows and outflows of funds from any ISingleTokenPaymentTerminal.
/// @dev This Store expects a project's controller to be an IJBController3_1.
contract JBTerminalStore is ReentrancyGuard, IJBTerminalStore {
    // A library that parses the packed funding cycle metadata into a friendlier format.
    using JBFundingCycleMetadataResolver for JBFundingCycle;

    //*********************************************************************//
    // --------------------------- custom errors ------------------------- //
    //*********************************************************************//
    error INVALID_AMOUNT_TO_SEND_DELEGATE();
    error CURRENCY_MISMATCH();
    error DISTRIBUTION_AMOUNT_LIMIT_REACHED();
    error FUNDING_CYCLE_PAYMENT_PAUSED();
    error FUNDING_CYCLE_DISTRIBUTION_PAUSED();
    error FUNDING_CYCLE_REDEEM_PAUSED();
    error INADEQUATE_CONTROLLER_ALLOWANCE();
    error INADEQUATE_PAYMENT_TERMINAL_STORE_BALANCE();
    error INSUFFICIENT_TOKENS();
    error INVALID_FUNDING_CYCLE();
    error PAYMENT_TERMINAL_MIGRATION_NOT_ALLOWED();

    //*********************************************************************//
    // -------------------------- private constants ---------------------- //
    //*********************************************************************//

    /// @notice Ensures a maximum number of decimal points of persisted fidelity on mulDiv operations of fixed point numbers.
    uint256 private constant _MAX_FIXED_POINT_FIDELITY = 18;

    //*********************************************************************//
    // ---------------- public immutable stored properties --------------- //
    //*********************************************************************//

    /// @notice The directory of terminals and controllers for projects.
    IJBDirectory public immutable override DIRECTORY;

    /// @notice The contract storing all funding cycle configurations.
    IJBFundingCycleStore public immutable override FUNDING_CYCLE_STORE;

    /// @notice The contract that exposes price feeds.
    IJBPrices public immutable override PRICES;

    //*********************************************************************//
    // --------------------- public stored properties -------------------- //
    //*********************************************************************//

    /// @notice The amount of tokens that each project has for each terminal, in terms of the terminal's token.
    /// @dev The balance is represented as a fixed point number with the same amount of decimals as its relative terminal.
    /// @custom:param _terminal The terminal to which the balance applies.
    /// @custom:param _projectId The ID of the project to get the balance of.
    /// @custom:param _token The token to which the balance applies.
    mapping(address => mapping(uint256 => mapping(address => uint256))) public override balanceOf;

    /// @notice The currency-denominated amounts of funds that a project has distributed from its limit during the current funding cycle for each terminal.
    /// @dev Increases as projects use their preconfigured distribution limits.
    /// @dev The used distribution limit is represented as a fixed point number with the same amount of decimals as its relative terminal.
    /// @custom:param _terminal The terminal to which the used distribution limit applies.
    /// @custom:param _projectId The ID of the project to get the used distribution limit of.
    /// @custom:param _token The token to which the used distribution limit applies.
    /// @custom:param _fundingCycleNumber The number of the funding cycle during which the distribution limit was used.
    /// @custom:param _currency The currency for which the distribution limit applies.
    mapping(
        address
            => mapping(
                uint256 => mapping(address => mapping(uint256 => mapping(uint256 => uint256)))
            )
    ) public override usedDistributionLimitOf;

    /// @notice The currency-denominated amounts of funds that a project has used from its allowance during the current funding cycle configuration for each terminal, in terms of the overflow allowance's currency.
    /// @dev Increases as projects use their allowance.
    /// @dev The used allowance is represented as a fixed point number with the same amount of decimals as its relative terminal.
    /// @custom:param _terminal The terminal to which the used overflow allowance applies.
    /// @custom:param _projectId The ID of the project to get the used overflow allowance of.
    /// @custom:param _token The token to which the used overflow allowance applies.
    /// @custom:param _configuration The configuration of the during which the allowance was used.
    /// @custom:param _currency The currency for which the overflow allowance applies.
    mapping(
        address
            => mapping(
                uint256 => mapping(address => mapping(uint256 => mapping(uint256 => uint256)))
            )
    ) public override usedOverflowAllowanceOf;

    //*********************************************************************//
    // ------------------------- external views -------------------------- //
    //*********************************************************************//

    /// @notice Gets the current overflowed amount in a terminal for a specified project.
    /// @dev The current overflow is represented as a fixed point number with the same amount of decimals as the specified terminal.
    /// @param _terminal The terminal for which the overflow is being calculated.
    /// @param _projectId The ID of the project to get overflow for.
    /// @param _accountingContexts The accounting contexts of tokens whose balances should contribute to the overflow being reclaimed from.
    /// @param _currency The currency the result should be in terms of.
    /// @param _decimals The number of decimals to expect in the resulting fixed point number.
    /// @return The current amount of overflow that project has in the specified terminal.
    function currentOverflowOf(
        address _terminal,
        uint256 _projectId,
        JBAccountingContext[] calldata _accountingContexts,
        uint256 _decimals,
        uint256 _currency
    ) external view override returns (uint256) {
        // Return the overflow during the project's current funding cycle.
        return _overflowFrom(
            _terminal,
            _projectId,
            _accountingContexts,
            FUNDING_CYCLE_STORE.currentOf(_projectId),
            _decimals,
            _currency
        );
    }

    /// @notice Gets the current overflowed amount for a specified project across all terminals.
    /// @param _projectId The ID of the project to get total overflow for.
    /// @param _decimals The number of decimals that the fixed point overflow should include.
    /// @param _currency The currency that the total overflow should be in terms of.
    /// @return The current total amount of overflow that project has across all terminals.
    function currentTotalOverflowOf(uint256 _projectId, uint256 _decimals, uint256 _currency)
        external
        view
        override
        returns (uint256)
    {
        return _currentTotalOverflowOf(_projectId, _decimals, _currency);
    }

    /// @notice The current amount of overflowed tokens from a terminal that can be reclaimed by the specified number of tokens, using the total token supply and overflow in the ecosystem.
    /// @dev The current reclaimable overflow is returned in terms of the specified terminal's currency.
    /// @dev The reclaimable overflow is represented as a fixed point number with the same amount of decimals as the specified terminal.
    /// @param _terminal The terminal from which the reclaimable amount would come.
    /// @param _projectId The ID of the project to get the reclaimable overflow amount for.
    /// @param _accountingContexts The accounting contexts of tokens whose balances should contribute to the overflow being reclaimed from.
    /// @param _decimals The number of decimals to include in the resulting fixed point number.
    /// @param _currency The currency the resulting number will be in terms of.
    /// @param _tokenCount The number of tokens to make the calculation with, as a fixed point number with 18 decimals.
    /// @param _useTotalOverflow A flag indicating whether the overflow used in the calculation should be summed from all of the project's terminals. If false, overflow should be limited to the amount in the specified `_terminal`.
    /// @return The amount of overflowed tokens that can be reclaimed, as a fixed point number with the same number of decimals as the provided `_terminal`.
    function currentReclaimableOverflowOf(
        address _terminal,
        uint256 _projectId,
        JBAccountingContext[] calldata _accountingContexts,
        uint256 _decimals,
        uint256 _currency,
        uint256 _tokenCount,
        bool _useTotalOverflow
    ) external view override returns (uint256) {
        // Get a reference to the project's current funding cycle.
        JBFundingCycle memory _fundingCycle = FUNDING_CYCLE_STORE.currentOf(_projectId);

        // Get the amount of current overflow.
        // Use the project's total overflow across all of its terminals if the flag species specifies so. Otherwise, use the overflow local to the specified terminal.
        uint256 _currentOverflow = _useTotalOverflow
            ? _currentTotalOverflowOf(_projectId, _decimals, _currency)
            : _overflowFrom(
                _terminal, _projectId, _accountingContexts, _fundingCycle, _decimals, _currency
            );

        // If there's no overflow, there's no reclaimable overflow.
        if (_currentOverflow == 0) return 0;

        // Get the number of outstanding tokens the project has.
        uint256 _totalSupply = IJBController3_1(address(DIRECTORY.controllerOf(_projectId)))
            .totalOutstandingTokensOf(_projectId);

        // Can't redeem more tokens that is in the supply.
        if (_tokenCount > _totalSupply) return 0;

        // Return the reclaimable overflow amount.
        return
            _reclaimableOverflowDuring(_fundingCycle, _tokenCount, _totalSupply, _currentOverflow);
    }

    /// @notice The current amount of overflowed tokens from a terminal that can be reclaimed by the specified number of tokens, using the specified total token supply and overflow amounts.
    /// @param _projectId The ID of the project to get the reclaimable overflow amount for.
    /// @param _tokenCount The number of tokens to make the calculation with, as a fixed point number with 18 decimals.
    /// @param _totalSupply The total number of tokens to make the calculation with, as a fixed point number with 18 decimals.
    /// @param _overflow The amount of overflow to make the calculation with, as a fixed point number.
    /// @return The amount of overflowed tokens that can be reclaimed, as a fixed point number with the same number of decimals as the provided `_overflow`.
    function currentReclaimableOverflowOf(
        uint256 _projectId,
        uint256 _tokenCount,
        uint256 _totalSupply,
        uint256 _overflow
    ) external view override returns (uint256) {
        // If there's no overflow, there's no reclaimable overflow.
        if (_overflow == 0) return 0;

        // Can't redeem more tokens that is in the supply.
        if (_tokenCount > _totalSupply) return 0;

        // Get a reference to the project's current funding cycle.
        JBFundingCycle memory _fundingCycle = FUNDING_CYCLE_STORE.currentOf(_projectId);

        // Return the reclaimable overflow amount.
        return _reclaimableOverflowDuring(_fundingCycle, _tokenCount, _totalSupply, _overflow);
    }

    //*********************************************************************//
    // -------------------------- constructor ---------------------------- //
    //*********************************************************************//

    /// @param _directory A contract storing directories of terminals and controllers for each project.
    constructor(IJBDirectory _directory) {
        DIRECTORY = _directory;
        FUNDING_CYCLE_STORE = _dreictory.fundingCycleStore();
        PRICES = _directory.prices();
    }

    //*********************************************************************//
    // ---------------------- external transactions ---------------------- //
    //*********************************************************************//

    /// @notice Records newly contributed tokens to a project.
    /// @dev Mints the project's tokens according to values provided by a configured data source. If no data source is configured, mints tokens proportional to the amount of the contribution.
    /// @param _payer The original address that sent the payment to the terminal.
    /// @param _amount The amount of tokens being paid. Includes the token being paid, the value, the number of decimals included, and the currency of the amount.
    /// @param _projectId The ID of the project being paid.
    /// @param _beneficiary The specified address that should be the beneficiary of anything that results from the payment.
    /// @param _metadata Bytes to send along to the data source, if one is provided.
    /// @return fundingCycle The project's funding cycle during which payment was made.
    /// @return tokenCount The number of project tokens that were minted, as a fixed point number with 18 decimals.
    /// @return delegateAllocations The amount to send to delegates instead of adding to the local balance.
    function recordPaymentFrom(
        address _payer,
        JBTokenAmount calldata _amount,
        uint256 _projectId,
        address _beneficiary,
        bytes calldata _metadata
    )
        external
        override
        nonReentrant
        returns (
            JBFundingCycle memory fundingCycle,
            uint256 tokenCount,
            JBPayDelegateAllocation3_1_1[] memory delegateAllocations
        )
    {
        // Get a reference to the current funding cycle for the project.
        fundingCycle = FUNDING_CYCLE_STORE.currentOf(_projectId);

        // The project must have a funding cycle configured.
        if (fundingCycle.number == 0) revert INVALID_FUNDING_CYCLE();

        // Must not be paused.
        if (fundingCycle.payPaused()) revert FUNDING_CYCLE_PAYMENT_PAUSED();

        // The weight according to which new token supply is to be minted, as a fixed point number with 18 decimals.
        uint256 _weight;

        // If the funding cycle has configured a data source, use it to derive a weight and memo.
        if (fundingCycle.useDataSourceForPay() && fundingCycle.dataSource() != address(0)) {
            // Create the params that'll be sent to the data source.
            JBPayParamsData memory _data = JBPayParamsData(
                msg.sender,
                _payer,
                _amount,
                _projectId,
                fundingCycle.configuration,
                _beneficiary,
                fundingCycle.weight,
                fundingCycle.reservedRate(),
                _metadata
            );
            (_weight, delegateAllocations) =
                IJBFundingCycleDataSource3_1_1(fundingCycle.dataSource()).payParams(_data);
        }
        // Otherwise use the funding cycle's weight
        else {
            _weight = fundingCycle.weight;
        }

        // Keep a reference to the amount that should be added to the project's balance.
        uint256 _balanceDiff = _amount.value;

        // Scoped section preventing stack too deep.
        {
            // Keep a reference to the number of delegate allocations.
            uint256 _numberOfDelegateAllocations = delegateAllocations.length;

            // Validate all delegated amounts. This needs to be done before returning the delegate allocations to ensure valid delegated amounts.
            if (_numberOfDelegateAllocations != 0) {
                for (uint256 _i; _i < _numberOfDelegateAllocations;) {
                    // Get a reference to the amount to be delegated.
                    uint256 _delegatedAmount = delegateAllocations[_i].amount;

                    // Validate if non-zero.
                    if (_delegatedAmount != 0) {
                        // Can't delegate more than was paid.
                        if (_delegatedAmount > _balanceDiff) {
                            revert INVALID_AMOUNT_TO_SEND_DELEGATE();
                        }

                        // Decrement the total amount being added to the balance.
                        _balanceDiff = _balanceDiff - _delegatedAmount;
                    }

                    unchecked {
                        ++_i;
                    }
                }
            }
        }

        // If there's no amount being recorded, there's nothing left to do.
        if (_amount.value == 0) return (fundingCycle, 0, delegateAllocations);

        // Add the correct balance difference to the token balance of the project.
        if (_balanceDiff != 0) {
            balanceOf[msg.sender][_projectId][_amount.token] =
                balanceOf[msg.sender][_projectId][_amount.token] + _balanceDiff;
        }

        // If there's no weight, token count must be 0 so there's nothing left to do.
        if (_weight == 0) return (fundingCycle, 0, delegateAllocations);

        // If the terminal should base its weight on a different currency from the terminal's currency, determine the factor.
        // The weight is always a fixed point mumber with 18 decimals. To ensure this, the ratio should use the same number of decimals as the `_amount`.
        uint256 _weightRatio = _amount.currency == fundingCycle.baseCurrency()
            ? 10 ** _amount.decimals
            : PRICES.priceFor(
                _projectId, _amount.currency, fundingCycle.baseCurrency(), _amount.decimals
            );

        // Find the number of tokens to mint, as a fixed point number with as many decimals as `weight` has.
        tokenCount = PRBMath.mulDiv(_amount.value, _weight, _weightRatio);
    }

    /// @notice Records newly redeemed tokens of a project.
    /// @dev Redeems the project's tokens according to values provided by a configured data source. If no data source is configured, redeems tokens along a redemption bonding curve that is a function of the number of tokens being burned.
    /// @param _holder The account that is having its tokens redeemed.
    /// @param _projectId The ID of the project to which the tokens being redeemed belong.
    /// @param _accountingContext The accounting context of the token being reclaimed from the redemption.
    /// @param _balanceTokenContexts The token contexts whose balances should contribute to the overflow being reclaimed from.
    /// @param _tokenCount The number of project tokens to redeem, as a fixed point number with 18 decimals.
    /// @param _metadata Bytes to send along to the data source, if one is provided.
    /// @return fundingCycle The funding cycle during which the redemption was made.
    /// @return reclaimAmount The amount of terminal tokens reclaimed, as a fixed point number with 18 decimals.
    /// @return delegateAllocations The amount to send to delegates instead of sending to the beneficiary.
    function recordRedemptionFor(
        address _holder,
        uint256 _projectId,
        JBAccountingContext calldata _accountingContext,
        JBAccountingContext[] calldata _balanceTokenContexts,
        uint256 _tokenCount,
        bytes memory _metadata
    )
        external
        override
        nonReentrant
        returns (
            JBFundingCycle memory fundingCycle,
            uint256 reclaimAmount,
            JBRedemptionDelegateAllocation3_1_1[] memory delegateAllocations
        )
    {
        // Get a reference to the project's current funding cycle.
        fundingCycle = FUNDING_CYCLE_STORE.currentOf(_projectId);

        // Get the amount of current overflow.
        // Use the local overflow if the funding cycle specifies that it should be used. Otherwise, use the project's total overflow across all of its terminals.
        uint256 _currentOverflow = fundingCycle.useTotalOverflowForRedemptions()
            ? _currentTotalOverflowOf(
                _projectId, _accountingContext.decimals, _accountingContext.currency
            )
            : _overflowFrom(
                msg.sender,
                _projectId,
                _balanceTokenContexts,
                fundingCycle,
                _accountingContext.decimals,
                _accountingContext.currency
            );

        // Get the number of outstanding tokens the project has.
        uint256 _totalSupply = IJBController3_1(address(DIRECTORY.controllerOf(_projectId)))
            .totalOutstandingTokensOf(_projectId);

        // Can't redeem more tokens that is in the supply.
        if (_tokenCount > _totalSupply) revert INSUFFICIENT_TOKENS();

        if (_currentOverflow != 0) {
            // Calculate reclaim amount using the current overflow amount.
            reclaimAmount = _reclaimableOverflowDuring(
                fundingCycle, _tokenCount, _totalSupply, _currentOverflow
            );
        }

        // Create the struct that describes the amount being reclaimed.
        JBTokenAmount memory _reclaimedTokenAmount = JBTokenAmount(
            _accountingContext.token,
            reclaimAmount,
            _accountingContext.decimals,
            _accountingContext.currency
        );

        // If the funding cycle has configured a data source, use it to derive a claim amount and memo.
        if (fundingCycle.useDataSourceForRedeem() && fundingCycle.dataSource() != address(0)) {
            // Yet another scoped section prevents stack too deep. `_state`  only used within scope.
            {
                // Create the params that'll be sent to the data source.
                JBRedeemParamsData memory _data = JBRedeemParamsData(
                    msg.sender,
                    _holder,
                    _projectId,
                    fundingCycle.configuration,
                    _tokenCount,
                    _totalSupply,
                    _currentOverflow,
                    _reclaimedTokenAmount,
                    fundingCycle.useTotalOverflowForRedemptions(),
                    fundingCycle.redemptionRate(),
                    _metadata
                );
                (reclaimAmount, delegateAllocations) =
                    IJBFundingCycleDataSource3_1_1(fundingCycle.dataSource()).redeemParams(_data);
            }
        }

        // Keep a reference to the amount that should be subtracted from the project's balance.
        uint256 _balanceDiff = reclaimAmount;

        if (delegateAllocations.length != 0) {
            // Validate all delegated amounts.
            for (uint256 _i; _i < delegateAllocations.length;) {
                // Get a reference to the amount to be delegated.
                uint256 _delegatedAmount = delegateAllocations[_i].amount;

                // Validate if non-zero.
                if (_delegatedAmount != 0) {
                    // Increment the total amount being subtracted from the balance.
                    _balanceDiff = _balanceDiff + _delegatedAmount;
                }

                unchecked {
                    ++_i;
                }
            }
        }

        // The amount being reclaimed must be within the project's balance.
        if (_balanceDiff > balanceOf[msg.sender][_projectId][_accountingContext.token]) {
            revert INADEQUATE_PAYMENT_TERMINAL_STORE_BALANCE();
        }

        // Remove the reclaimed funds from the project's balance.
        if (_balanceDiff != 0) {
            unchecked {
                balanceOf[msg.sender][_projectId][_accountingContext.token] =
                    balanceOf[msg.sender][_projectId][_accountingContext.token] - _balanceDiff;
            }
        }
    }

    /// @notice Records newly distributed funds for a project.
    /// @param _projectId The ID of the project that is having funds distributed.
    /// @param _accountingContext The context of the token being distributed.
    /// @param _amount The amount to use from the distribution limit, as a fixed point number.
    /// @param _currency The currency of the `_amount`. This must match the project's current funding cycle's currency.
    /// @return fundingCycle The funding cycle during which the distribution was made.
    /// @return distributedAmount The amount of terminal tokens distributed, as a fixed point number with the same amount of decimals as its relative terminal.
    function recordDistributionFor(
        uint256 _projectId,
        JBAccountingContext calldata _accountingContext,
        uint256 _amount,
        uint256 _currency
    )
        external
        override
        nonReentrant
        returns (JBFundingCycle memory fundingCycle, uint256 distributedAmount)
    {
        // Get a reference to the project's current funding cycle.
        fundingCycle = FUNDING_CYCLE_STORE.currentOf(_projectId);

        // The new total amount that has been distributed during this funding cycle.
        uint256 _newUsedDistributionLimitOf = usedDistributionLimitOf[msg.sender][_projectId][_accountingContext
            .token][fundingCycle.number][_currency] + _amount;

        // Amount must be within what is still distributable.
        uint256 _distributionLimit = IJBController3_1(address(DIRECTORY.controllerOf(_projectId)))
            .fundAccessConstraintsStore().distributionLimitOf(
            _projectId, fundingCycle.configuration, msg.sender, _accountingContext.token, _currency
        );

        // Make sure the new used amount is within the distribution limit.
        if (_newUsedDistributionLimitOf > _distributionLimit || _distributionLimit == 0) {
            revert DISTRIBUTION_AMOUNT_LIMIT_REACHED();
        }

        // Convert the amount to the balance's currency.
        distributedAmount = (_currency == _accountingContext.currency)
            ? _amount
            : PRBMath.mulDiv(
                _amount,
                10 ** _MAX_FIXED_POINT_FIDELITY, // Use _MAX_FIXED_POINT_FIDELITY to keep as much of the `_amount`'s fidelity as possible when converting.
                PRICES.priceFor(
                    _projectId, _currency, _accountingContext.currency, _MAX_FIXED_POINT_FIDELITY
                )
            );

        // The amount being distributed must be available.
        if (distributedAmount > balanceOf[msg.sender][_projectId][_accountingContext.token]) {
            revert INADEQUATE_PAYMENT_TERMINAL_STORE_BALANCE();
        }

        // Store the new amount.
        usedDistributionLimitOf[msg.sender][_projectId][_accountingContext.token][fundingCycle
            .number][_currency] = _newUsedDistributionLimitOf;

        // Removed the distributed funds from the project's token balance.
        unchecked {
            balanceOf[msg.sender][_projectId][_accountingContext.token] =
                balanceOf[msg.sender][_projectId][_accountingContext.token] - distributedAmount;
        }
    }

    /// @notice Records newly used allowance funds of a project.
    /// @param _projectId The ID of the project to use the allowance of.
    /// @param _accountingContext The accounting context of the token whose balances should contribute to the overflow being reclaimed from.
    /// @param _amount The amount to use from the allowance, as a fixed point number.
    /// @param _currency The currency of the `_amount`. Must match the currency of the overflow allowance.
    /// @return fundingCycle The funding cycle during which the overflow allowance is being used.
    /// @return usedAmount The amount of terminal tokens used, as a fixed point number with the same amount of decimals as its relative terminal.
    function recordUsedAllowanceOf(
        uint256 _projectId,
        JBAccountingContext calldata _accountingContext,
        uint256 _amount,
        uint256 _currency
    )
        external
        override
        nonReentrant
        returns (JBFundingCycle memory fundingCycle, uint256 usedAmount)
    {
        // Get a reference to the project's current funding cycle.
        fundingCycle = FUNDING_CYCLE_STORE.currentOf(_projectId);

        // Get a reference to the new used overflow allowance for this funding cycle configuration.
        uint256 _newUsedOverflowAllowanceOf = usedOverflowAllowanceOf[msg.sender][_projectId][_accountingContext
            .token][fundingCycle.configuration][_currency] + _amount;

        // There must be sufficient allowance available.
        uint256 _overflowAllowance = IJBController3_1(address(DIRECTORY.controllerOf(_projectId)))
            .fundAccessConstraintsStore().overflowAllowanceOf(
            _projectId, fundingCycle.configuration, msg.sender, _accountingContext.token, _currency
        );

        // Make sure the new used amount is within the allowance.
        if (_newUsedOverflowAllowanceOf > _overflowAllowance || _overflowAllowance == 0) {
            revert INADEQUATE_CONTROLLER_ALLOWANCE();
        }

        // Convert the amount to this store's terminal's token.
        usedAmount = _currency == _accountingContext.currency
            ? _amount
            : PRBMath.mulDiv(
                _amount,
                10 ** _MAX_FIXED_POINT_FIDELITY, // Use _MAX_FIXED_POINT_FIDELITY to keep as much of the `_amount`'s fidelity as possible when converting.
                PRICES.priceFor(
                    _projectId, _currency, _accountingContext.currency, _MAX_FIXED_POINT_FIDELITY
                )
            );

        // Set the token being used as the only one to look for overflow within.
        JBAccountingContext[] memory _accountingContexts = new JBAccountingContext[](1);
        _accountingContexts[0] = _accountingContext;

        // The amount being distributed must be available in the overflow.
        if (
            usedAmount
                > _overflowFrom(
                    msg.sender,
                    _projectId,
                    _accountingContexts,
                    fundingCycle,
                    _accountingContext.decimals,
                    _accountingContext.currency
                )
        ) revert INADEQUATE_PAYMENT_TERMINAL_STORE_BALANCE();

        // Store the incremented value.
        usedOverflowAllowanceOf[msg.sender][_projectId][_accountingContext.token][fundingCycle
            .configuration][_currency] = _newUsedOverflowAllowanceOf;

        // Update the project's balance.
        balanceOf[msg.sender][_projectId][_accountingContext.token] =
            balanceOf[msg.sender][_projectId][_accountingContext.token] - usedAmount;
    }

    /// @notice Records newly added funds for the project.
    /// @param _projectId The ID of the project to which the funds being added belong.
    /// @param _token The token being added to the balance.
    /// @param _amount The amount of terminal tokens added, as a fixed point number with the same amount of decimals as its relative terminal.
    function recordAddedBalanceFor(uint256 _projectId, address _token, uint256 _amount)
        external
        override
    {
        // Increment the balance.
        balanceOf[msg.sender][_projectId][_token] =
            balanceOf[msg.sender][_projectId][_token] + _amount;
    }

    /// @notice Records the migration of funds from this store.
    /// @param _projectId The ID of the project being migrated.
    /// @param _token The token being migrated.
    /// @return balance The project's migrated balance, as a fixed point number with the same amount of decimals as its relative terminal.
    function recordMigration(uint256 _projectId, address _token)
        external
        override
        nonReentrant
        returns (uint256 balance)
    {
        // Get a reference to the project's current funding cycle.
        JBFundingCycle memory _fundingCycle = FUNDING_CYCLE_STORE.currentOf(_projectId);

        // Migration must be allowed.
        if (!_fundingCycle.terminalMigrationAllowed()) {
            revert PAYMENT_TERMINAL_MIGRATION_NOT_ALLOWED();
        }

        // Return the current balance.
        balance = balanceOf[msg.sender][_projectId][_token];

        // Set the balance to 0.
        balanceOf[msg.sender][_projectId][_token] = 0;
    }

    //*********************************************************************//
    // --------------------- private helper functions -------------------- //
    //*********************************************************************//

    /// @notice The amount of overflowed tokens from a terminal that can be reclaimed by the specified number of tokens when measured from the specified.
    /// @dev If the project has an active funding cycle reconfiguration ballot, the project's ballot redemption rate is used.
    /// @param _fundingCycle The funding cycle during which reclaimable overflow is being calculated.
    /// @param _tokenCount The number of tokens to make the calculation with, as a fixed point number with 18 decimals.
    /// @param _totalSupply The total supply of tokens to make the calculation with, as a fixed point number with 18 decimals.
    /// @param _overflow The amount of overflow to make the calculation with.
    /// @return The amount of overflowed tokens that can be reclaimed.
    function _reclaimableOverflowDuring(
        JBFundingCycle memory _fundingCycle,
        uint256 _tokenCount,
        uint256 _totalSupply,
        uint256 _overflow
    ) private pure returns (uint256) {
        // If the amount being redeemed is the total supply, return the rest of the overflow.
        if (_tokenCount == _totalSupply) return _overflow;

        // If the redemption rate is 0, nothing is claimable.
        if (_fundingCycle.redemptionRate() == 0) return 0;

        // Get a reference to the linear proportion.
        uint256 _base = PRBMath.mulDiv(_overflow, _tokenCount, _totalSupply);

        // These conditions are all part of the same curve. Edge conditions are separated because fewer operation are necessary.
        if (_fundingCycle.redemptionRate() == JBConstants.MAX_REDEMPTION_RATE) return _base;

        return PRBMath.mulDiv(
            _base,
            _fundingCycle.redemptionRate()
                + PRBMath.mulDiv(
                    _tokenCount,
                    JBConstants.MAX_REDEMPTION_RATE - _fundingCycle.redemptionRate(),
                    _totalSupply
                ),
            JBConstants.MAX_REDEMPTION_RATE
        );
    }

    /// @notice Gets the amount that is overflowing when measured from the specified funding cycle.
    /// @dev This amount changes as the value of the balance changes in relation to the currency being used to measure the distribution limit.
    /// @param _terminal The terminal for which the overflow is being calculated.
    /// @param _projectId The ID of the project to get overflow for.
    /// @param _accountingContexts The accounting contexts of tokens whose balances should contribute to the overflow being measured.
    /// @param _fundingCycle The ID of the funding cycle to base the overflow on.
    /// @param _targetDecimals The number of decimals to include in the resulting fixed point number.
    /// @param _targetCurrency The currency that the reported overflow is expected to be in terms of.
    /// @return overflow The overflow of funds, as a fixed point number with 18 decimals.
    function _overflowFrom(
        address _terminal,
        uint256 _projectId,
        JBAccountingContext[] memory _accountingContexts,
        JBFundingCycle memory _fundingCycle,
        uint256 _targetDecimals,
        uint256 _targetCurrency
    ) private view returns (uint256 overflow) {
        // Keep a reference to the number of tokens being iterated on.
        uint256 _numberOfTokenAccountingContexts = _accountingContexts.length;

        // Add distribution limits from each token.
        for (uint256 _i; _i < _numberOfTokenAccountingContexts;) {
            uint256 _tokenOverflow = _tokenOverflowFrom(
                _terminal,
                _projectId,
                _accountingContexts[_i],
                _fundingCycle,
                _targetDecimals,
                _targetCurrency
            );
            // Increment the overflow with any remaining balance.
            if (_tokenOverflow > 0) overflow += _tokenOverflow;

            unchecked {
                ++_i;
            }
        }
    }

    /// @notice Gets the amount that is overflowing for a token when measured from the specified funding cycle.
    /// @dev This amount changes as the value of the balance changes in relation to the currency being used to measure the distribution limit.
    /// @param _terminal The terminal for which the overflow is being calculated.
    /// @param _projectId The ID of the project to get overflow for.
    /// @param _accountingContext The accounting context of the token whose balance should contribute to the overflow being measured.
    /// @param _fundingCycle The ID of the funding cycle to base the overflow on.
    /// @param _targetDecimals The number of decimals to include in the resulting fixed point number.
    /// @param _targetCurrency The currency that the reported overflow is expected to be in terms of.
    /// @return overflow The overflow of funds, as a fixed point number with 18 decimals.
    function _tokenOverflowFrom(
        address _terminal,
        uint256 _projectId,
        JBAccountingContext memory _accountingContext,
        JBFundingCycle memory _fundingCycle,
        uint256 _targetDecimals,
        uint256 _targetCurrency
    ) private view returns (uint256 overflow) {
        // Keep a reference to the balance.
        overflow = balanceOf[_terminal][_projectId][_accountingContext.token];

        // Adjust the decimals of the fixed point number if needed to have the correct decimals.
        overflow = _accountingContext.decimals == _targetDecimals
            ? overflow
            : JBFixedPointNumber.adjustDecimals(overflow, _accountingContext.decimals, _targetDecimals);

        // Add up all the balances.
        overflow = (overflow == 0 || _accountingContext.currency == _targetCurrency)
            ? overflow
            : PRBMath.mulDiv(
                overflow,
                10 ** _MAX_FIXED_POINT_FIDELITY, // Use _MAX_FIXED_POINT_FIDELITY to keep as much of the `_distributionLimitRemaining`'s fidelity as possible when converting.
                PRICES.priceFor(
                    _projectId, _accountingContext.currency, _targetCurrency, _MAX_FIXED_POINT_FIDELITY
                )
            );

        // Get a reference to the distribution limit during the funding cycle for the token.
        JBCurrencyAmount[] memory _distributionLimits = IJBController3_1(
            address(DIRECTORY.controllerOf(_projectId))
        ).fundAccessConstraintsStore().distributionLimitsOf(
            _projectId, _fundingCycle.configuration, address(_terminal), _accountingContext.token
        );

        // Keep a reference to the distribution limit being iterated on.
        JBCurrencyAmount memory _distributionLimit;

        // Keep a reference to the number of distribution limits being iterated on.
        uint256 _numberOfDistributionLimits = _distributionLimits.length;

        // Loop through each distribution limit to determine the cumulative normalized distribution limit remaining.
        for (uint256 _i; _i < _numberOfDistributionLimits;) {
            _distributionLimit = _distributionLimits[_i];

            // Set the distribution limit value to the amount still distributable during the funding cycle.
            _distributionLimit.value = _distributionLimit.value
                - usedDistributionLimitOf[_terminal][_projectId][_accountingContext.token][_fundingCycle
                    .number][_distributionLimit.currency];

            // Adjust the decimals of the fixed point number if needed to have the correct decimals.
            _distributionLimit.value = _accountingContext.decimals == _targetDecimals
                ? _distributionLimit.value
                : JBFixedPointNumber.adjustDecimals(
                    _distributionLimit.value, _accountingContext.decimals, _targetDecimals
                );

            // Convert the _distributionRemaining to be in terms of the provided currency.
            _distributionLimit.value = _distributionLimit.value == 0
                || _distributionLimit.currency == _targetCurrency
                ? _distributionLimit.value
                : PRBMath.mulDiv(
                    _distributionLimit.value,
                    10 ** _MAX_FIXED_POINT_FIDELITY, // Use _MAX_FIXED_POINT_FIDELITY to keep as much of the `_distributionLimitRemaining`'s fidelity as possible when converting.
                    PRICES.priceFor(
                        _projectId,
                        _distributionLimit.currency,
                        _targetCurrency,
                        _MAX_FIXED_POINT_FIDELITY
                    )
                );

            // Decrement the balance until it reached zero.
            if (overflow > _distributionLimit.value) overflow -= _distributionLimit.value;
            else return 0;

            unchecked {
                ++_i;
            }
        }
    }

    /// @notice Gets the amount that is currently overflowing across all of a project's terminals.
    /// @dev This amount changes as the value of the balances changes in relation to the currency being used to measure the project's distribution limits.
    /// @param _projectId The ID of the project to get the total overflow for.
    /// @param _decimals The number of decimals that the fixed point overflow should include.
    /// @param _currency The currency that the overflow should be in terms of.
    /// @return overflow The total overflow of a project's funds.
    function _currentTotalOverflowOf(uint256 _projectId, uint256 _decimals, uint256 _currency)
        private
        view
        returns (uint256 overflow)
    {
        // Get a reference to the project's terminals.
        IJBPaymentTerminal[] memory _terminals = DIRECTORY.terminalsOf(_projectId);

        // Keep a reference to the number of termainls.
        uint256 _numberOfTerminals = _terminals.length;

        // Add the current ETH overflow for each terminal.
        for (uint256 _i; _i < _numberOfTerminals;) {
            overflow += _terminals[_i].currentOverflowOf(_projectId, _decimals, _currency);
            unchecked {
                ++_i;
            }
        }
    }
}
