// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {PRBMath} from "@paulrberg/contracts/math/PRBMath.sol";
import {IJBController} from "./interfaces/IJBController.sol";
import {IJBDirectory} from "./interfaces/IJBDirectory.sol";
import {IJBRulesetDataHook} from "./interfaces/IJBRulesetDataHook.sol";
import {IJBRulesets} from "./interfaces/IJBRulesets.sol";
import {IJBPrices} from "./interfaces/IJBPrices.sol";
import {IJBPrices} from "./interfaces/IJBPrices.sol";
import {IJBTerminal} from "./interfaces/terminal/IJBTerminal.sol";
import {IJBTerminalStore} from "./interfaces/IJBTerminalStore.sol";
import {JBConstants} from "./libraries/JBConstants.sol";
import {JBFixedPointNumber} from "./libraries/JBFixedPointNumber.sol";
import {JBCurrencyAmount} from "./structs/JBCurrencyAmount.sol";
import {JBRulesetMetadataResolver} from "./libraries/JBRulesetMetadataResolver.sol";
import {JBRuleset} from "./structs/JBRuleset.sol";
import {JBPayHookPayload} from "./structs/JBPayHookPayload.sol";
import {JBPayParamsData} from "./structs/JBPayParamsData.sol";
import {JBRedeemParamsData} from "./structs/JBRedeemParamsData.sol";
import {JBRedeemHookPayload} from "./structs/JBRedeemHookPayload.sol";
import {JBAccountingContext} from "./structs/JBAccountingContext.sol";
import {JBTokenAmount} from "./structs/JBTokenAmount.sol";

/// @notice Manages all bookkeeping for inflows and outflows of funds from any terminal address.
/// @dev This contract expects a project's controller to be an `IJBController`.
contract JBTerminalStore is ReentrancyGuard, IJBTerminalStore {
    // A library that parses the packed ruleset metadata into a friendlier format.
    using JBRulesetMetadataResolver for JBRuleset;

    //*********************************************************************//
    // --------------------------- custom errors ------------------------- //
    //*********************************************************************//
    error INVALID_AMOUNT_TO_SEND_HOOK();
    error PAYOUT_LIMIT_EXCEEDED();
    error RULESET_PAYMENT_PAUSED();
    error INADEQUATE_CONTROLLER_ALLOWANCE();
    error INADEQUATE_TERMINAL_STORE_BALANCE();
    error INSUFFICIENT_TOKENS();
    error INVALID_RULESET();
    error TERMINAL_MIGRATION_NOT_ALLOWED();

    //*********************************************************************//
    // -------------------------- private constants ---------------------- //
    //*********************************************************************//

    /// @notice Constrains `mulDiv` operations on fixed point numbers to a maximum number of decimal points of persisted fidelity.
    uint256 private constant _MAX_FIXED_POINT_FIDELITY = 18;

    //*********************************************************************//
    // ---------------- public immutable stored properties --------------- //
    //*********************************************************************//

    /// @notice The directory of terminals and controllers for projects.
    IJBDirectory public immutable override DIRECTORY;

    /// @notice The contract storing and managing project rulesets.
    IJBRulesets public immutable override RULESETS;

    /// @notice The contract that exposes price feeds.
    IJBPrices public immutable override PRICES;

    //*********************************************************************//
    // --------------------- public stored properties -------------------- //
    //*********************************************************************//

    /// @notice A project's balance of a specific token within a terminal.
    /// @dev The balance is represented as a fixed point number with the same amount of decimals as its relative terminal.
    /// @custom:param _terminal The terminal to get the project's balance within.
    /// @custom:param _projectId The ID of the project to get the balance of.
    /// @custom:param _token The token to get the balance for.
    mapping(address => mapping(uint256 => mapping(address => uint256))) public override balanceOf;

    /// @notice The currency-denominated amount of funds that a project has already paid out from its payout limit during the current ruleset for each terminal, in terms of the payout limit's currency.
    /// @dev Increases as projects pay out funds.
    /// @dev The used payout limit is represented as a fixed point number with the same amount of decimals as the terminal it applies to.
    /// @custom:param _terminal The terminal the payout limit applies to.
    /// @custom:param _projectId The ID of the project to get the used payout limit of.
    /// @custom:param _token The token the payout limit applies to in the terminal.
    /// @custom:param _rulesetCycleNumber The cycle number of the ruleset the payout limit was used during.
    /// @custom:param _currency The currency the payout limit is in terms of.
    mapping(
        address
            => mapping(
                uint256 => mapping(address => mapping(uint256 => mapping(uint256 => uint256)))
            )
    ) public override usedPayoutLimitOf;

    /// @notice The currency-denominated amounts of funds that a project has used from its surplus allowance during the current ruleset for each terminal, in terms of the surplus allowance's currency.
    /// @dev Increases as projects use their allowance.
    /// @dev The used surplus allowance is represented as a fixed point number with the same amount of decimals as the terminal it applies to.
    /// @custom:param _terminal The terminal the surplus allowance applies to.
    /// @custom:param _projectId The ID of the project to get the used surplus allowance of.
    /// @custom:param _token The token the surplus allowance applies to in the terminal.
    /// @custom:param _rulesetId The ID of the ruleset the surplus allowance was used during.
    /// @custom:param _currency The currency the surplus allowance is in terms of.
    mapping(
        address
            => mapping(
                uint256 => mapping(address => mapping(uint256 => mapping(uint256 => uint256)))
            )
    ) public override usedSurplusAllowanceOf;

    //*********************************************************************//
    // ------------------------- external views -------------------------- //
    //*********************************************************************//

    /// @notice Gets the current surplus amount in a terminal for a specified project.
    /// @dev The surplus is the amount of funds a project has in a terminal in excess of its payout limit.
    /// @dev The surplus is represented as a fixed point number with the same amount of decimals as the specified terminal.
    /// @param _terminal The terminal the surplus is being calculated for.
    /// @param _projectId The ID of the project to get surplus for.
    /// @param _accountingContexts The accounting contexts of tokens whose balances should contribute to the surplus being calculated.
    /// @param _currency The currency the resulting amount should be in terms of.
    /// @param _decimals The number of decimals to expect in the resulting fixed point number.
    /// @return The current surplus amount the project has in the specified terminal.
    function currentSurplusOf(
        address _terminal,
        uint256 _projectId,
        JBAccountingContext[] calldata _accountingContexts,
        uint256 _decimals,
        uint256 _currency
    ) external view override returns (uint256) {
        // Return the surplus during the project's current ruleset.
        return _surplusFrom(
            _terminal,
            _projectId,
            _accountingContexts,
            RULESETS.currentOf(_projectId),
            _decimals,
            _currency
        );
    }

    /// @notice Gets the current surplus amount for a specified project across all terminals.
    /// @param _projectId The ID of the project to get the total surplus for.
    /// @param _decimals The number of decimals that the fixed point surplus should include.
    /// @param _currency The currency that the total surplus should be in terms of.
    /// @return The current total surplus amount that the project has across all terminals.
    function currentTotalSurplusOf(uint256 _projectId, uint256 _decimals, uint256 _currency)
        external
        view
        override
        returns (uint256)
    {
        return _currentTotalSurplusOf(_projectId, _decimals, _currency);
    }

    /// @notice The surplus amount that can currently be reclaimed from a terminal by redeeming the specified number of tokens, based on the total token supply and current surplus.
    /// @dev The returned amount in terms of the specified terminal's currency.
    /// @dev The returned amount is represented as a fixed point number with the same amount of decimals as the specified terminal.
    /// @param _terminal The terminal the redeemable amount would come from.
    /// @param _projectId The ID of the project to get the redeemable surplus amount for.
    /// @param _accountingContexts The accounting contexts of tokens whose balances should contribute to the surplus being reclaimed from.
    /// @param _decimals The number of decimals to include in the resulting fixed point number.
    /// @param _currency The currency that the resulting number will be in terms of.
    /// @param _tokenCount The number of tokens to make the calculation with, as a fixed point number with 18 decimals.
    /// @param _useTotalSurplus A flag indicating whether the surplus used in the calculation should be summed from all of the project's terminals. If false, surplus should be limited to the amount in the specified `_terminal`.
    /// @return The amount of surplus tokens that can be reclaimed by redeeming `_tokenCount` tokens as a fixed point number with the specified number of decimals.
    function currentReclaimableSurplusOf(
        address _terminal,
        uint256 _projectId,
        JBAccountingContext[] calldata _accountingContexts,
        uint256 _decimals,
        uint256 _currency,
        uint256 _tokenCount,
        bool _useTotalSurplus
    ) external view override returns (uint256) {
        // Get a reference to the project's current ruleset.
        JBRuleset memory _ruleset = RULESETS.currentOf(_projectId);

        // Get the current surplus amount.
        // Use the project's total surplus across all of its terminals if the flag species specifies so. Otherwise, use the surplus local to the specified terminal.
        uint256 _currentSurplus = _useTotalSurplus
            ? _currentTotalSurplusOf(_projectId, _decimals, _currency)
            : _surplusFrom(_terminal, _projectId, _accountingContexts, _ruleset, _decimals, _currency);

        // If there's no surplus, there's no reclaimable surplus.
        if (_currentSurplus == 0) return 0;

        // Get the number of outstanding tokens the project has.
        uint256 _totalSupply = IJBController(address(DIRECTORY.controllerOf(_projectId)))
            .totalTokenSupplyWithReservedTokensOf(_projectId);

        // Can't redeem more tokens that is in the supply.
        if (_tokenCount > _totalSupply) return 0;

        // Return the reclaimable surplus amount.
        return _reclaimableSurplusDuring(_ruleset, _tokenCount, _totalSupply, _currentSurplus);
    }

    /// @notice The current amount of surplus tokens from a terminal that can be reclaimed by redeeming the specified number of tokens, based on the specified total token supply and surplus amounts.
    /// @param _projectId The ID of the project to get the reclaimable surplus amount for.
    /// @param _tokenCount The number of tokens to make the calculation with, as a fixed point number with 18 decimals.
    /// @param _totalSupply The total number of tokens to make the calculation with, as a fixed point number with 18 decimals.
    /// @param _surplus The surplus amount to make the calculation with, as a fixed point number.
    /// @return The surplus token amount that can be reclaimed, as a fixed point number with the same number of decimals as the provided `_surplus`.
    function currentReclaimableSurplusOf(
        uint256 _projectId,
        uint256 _tokenCount,
        uint256 _totalSupply,
        uint256 _surplus
    ) external view override returns (uint256) {
        // If there's no surplus, there's no reclaimable surplus.
        if (_surplus == 0) return 0;

        // Can't redeem more tokens than is in the supply.
        if (_tokenCount > _totalSupply) return 0;

        // Get a reference to the project's current ruleset.
        JBRuleset memory _ruleset = RULESETS.currentOf(_projectId);

        // Return the reclaimable surplus amount.
        return _reclaimableSurplusDuring(_ruleset, _tokenCount, _totalSupply, _surplus);
    }

    //*********************************************************************//
    // -------------------------- constructor ---------------------------- //
    //*********************************************************************//

    /// @param _directory A contract storing directories of terminals and controllers for each project.
    /// @param _rulesets A contract storing and managing project rulesets.
    /// @param _prices A contract that exposes price feeds.
    constructor(IJBDirectory _directory, IJBRulesets _rulesets, IJBPrices _prices) {
        DIRECTORY = _directory;
        RULESETS = _rulesets;
        PRICES = _prices;
    }

    //*********************************************************************//
    // ---------------------- external transactions ---------------------- //
    //*********************************************************************//

    /// @notice Records a payment to a project.
    /// @dev Mints the project's tokens according to values provided by the ruleset's data hook. If the ruleset has no data hook, mints tokens in proportion with the amount paid.
    /// @param _payer The address that made the payment to the terminal.
    /// @param _amount The amount of tokens being paid. Includes the token being paid, their value, the number of decimals included, and the currency of the amount.
    /// @param _projectId The ID of the project being paid.
    /// @param _beneficiary The address that should be the beneficiary of anything the payment yields (including project tokens minted by the payment).
    /// @param _metadata Bytes to send to the data hook, if the project's current ruleset specifies one.
    /// @return ruleset The ruleset the payment was made during, as a `JBRuleset` struct.
    /// @return tokenCount The number of project tokens that were minted, as a fixed point number with 18 decimals.
    /// @return hookPayloads The data and amounts to send to pay hooks instead of adding to the local balance.
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
            JBRuleset memory ruleset,
            uint256 tokenCount,
            JBPayHookPayload[] memory hookPayloads
        )
    {
        // Get a reference to the project's current ruleset.
        ruleset = RULESETS.currentOf(_projectId);

        // The project must have a ruleset.
        if (ruleset.cycleNumber == 0) revert INVALID_RULESET();

        // The ruleset must not have payments paused.
        if (ruleset.pausePay()) revert RULESET_PAYMENT_PAUSED();

        // The weight according to which new tokens are to be minted, as a fixed point number with 18 decimals.
        uint256 _weight;

        // If the ruleset has a data hook enabled for payments, use it to derive a weight and memo.
        if (ruleset.useDataHookForPay() && ruleset.dataHook() != address(0)) {
            // Create the params that'll be sent to the data hook.
            JBPayParamsData memory _data = JBPayParamsData(
                msg.sender,
                _payer,
                _amount,
                _projectId,
                ruleset.id,
                _beneficiary,
                ruleset.weight,
                ruleset.reservedRate(),
                _metadata
            );
            (_weight, hookPayloads) = IJBRulesetDataHook(ruleset.dataHook()).payParams(_data);
        }
        // Otherwise use the ruleset's weight
        else {
            _weight = ruleset.weight;
        }

        // Keep a reference to the amount that should be added to the project's balance.
        uint256 _balanceDiff = _amount.value;

        // Scoped section preventing stack too deep.
        {
            // Keep a reference to the number of hook payloads.
            uint256 _numberOfHookPayloads = hookPayloads.length;

            // Validate all payload amounts. This needs to be done before returning the hook payloads to ensure valid payload amounts.
            if (_numberOfHookPayloads != 0) {
                for (uint256 _i; _i < _numberOfHookPayloads;) {
                    // Get a reference to the payload amount.
                    uint256 _payloadAmount = hookPayloads[_i].amount;

                    // Validate if non-zero.
                    if (_payloadAmount != 0) {
                        // Can't send more to hook than was paid.
                        if (_payloadAmount > _balanceDiff) {
                            revert INVALID_AMOUNT_TO_SEND_HOOK();
                        }

                        // Decrement the total amount being added to the balance.
                        _balanceDiff = _balanceDiff - _payloadAmount;
                    }

                    unchecked {
                        ++_i;
                    }
                }
            }
        }

        // If there's no amount being recorded, there's nothing left to do.
        if (_amount.value == 0) return (ruleset, 0, hookPayloads);

        // Add the correct balance difference to the token balance of the project.
        if (_balanceDiff != 0) {
            balanceOf[msg.sender][_projectId][_amount.token] =
                balanceOf[msg.sender][_projectId][_amount.token] + _balanceDiff;
        }

        // If there's no weight, the token count must be 0, so there's nothing left to do.
        if (_weight == 0) return (ruleset, 0, hookPayloads);

        // If the terminal should base its weight on a currency other than the terminal's currency, determine the factor.
        // The weight is always a fixed point mumber with 18 decimals. To ensure this, the ratio should use the same number of decimals as the `_amount`.
        uint256 _weightRatio = _amount.currency == ruleset.baseCurrency()
            ? 10 ** _amount.decimals
            : PRICES.pricePerUnitOf(
                _projectId, _amount.currency, ruleset.baseCurrency(), _amount.decimals
            );

        // Find the number of tokens to mint, as a fixed point number with as many decimals as `weight` has.
        tokenCount = PRBMath.mulDiv(_amount.value, _weight, _weightRatio);
    }

    /// @notice Records a redemption from a project.
    /// @dev Redeems the project's tokens according to values provided by the ruleset's data hook. If the ruleset has no data hook, redeems tokens along a redemption bonding curve that is a function of the number of tokens being burned.
    /// @param _holder The account that is redeeming tokens.
    /// @param _projectId The ID of the project being redeemed from.
    /// @param _accountingContext The accounting context of the token being reclaimed by the redemption.
    /// @param _balanceTokenContexts The token contexts whose balances should contribute to the surplus being reclaimed from.
    /// @param _tokenCount The number of project tokens to redeem, as a fixed point number with 18 decimals.
    /// @param _metadata Bytes to send to the data hook, if the project's current ruleset specifies one.
    /// @return ruleset The ruleset during the redemption was made during, as a `JBRuleset` struct.
    /// @return reclaimAmount The amount of tokens reclaimed from the terminal, as a fixed point number with 18 decimals.
    /// @return hookPayloads The data and amounts to send to redeem hooks instead of sending to the beneficiary.
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
            JBRuleset memory ruleset,
            uint256 reclaimAmount,
            JBRedeemHookPayload[] memory hookPayloads
        )
    {
        // Get a reference to the project's current ruleset.
        ruleset = RULESETS.currentOf(_projectId);

        // Get the current surplus amount.
        // Use the local surplus if the ruleset specifies that it should be used. Otherwise, use the project's total surplus across all of its terminals.
        uint256 _currentSurplus = ruleset.useTotalSurplusForRedemptions()
            ? _currentTotalSurplusOf(
                _projectId, _accountingContext.decimals, _accountingContext.currency
            )
            : _surplusFrom(
                msg.sender,
                _projectId,
                _balanceTokenContexts,
                ruleset,
                _accountingContext.decimals,
                _accountingContext.currency
            );

        // Get the total number of outstanding project tokens.
        uint256 _totalSupply = IJBController(address(DIRECTORY.controllerOf(_projectId)))
            .totalTokenSupplyWithReservedTokensOf(_projectId);

        // Can't redeem more tokens that are in the supply.
        if (_tokenCount > _totalSupply) revert INSUFFICIENT_TOKENS();

        if (_currentSurplus != 0) {
            // Calculate reclaim amount using the current surplus amount.
            reclaimAmount =
                _reclaimableSurplusDuring(ruleset, _tokenCount, _totalSupply, _currentSurplus);
        }

        // Create the struct that describes the amount being reclaimed.
        JBTokenAmount memory _reclaimedTokenAmount = JBTokenAmount(
            _accountingContext.token,
            reclaimAmount,
            _accountingContext.decimals,
            _accountingContext.currency
        );

        // If the ruleset has a data hook which is enabled for redemptions, use it to derive a claim amount and memo.
        if (ruleset.useDataHookForRedeem() && ruleset.dataHook() != address(0)) {
            // Yet another scoped section prevents stack too deep. `_state`  only used within scope.
            {
                // Create the params that'll be sent to the data hook.
                JBRedeemParamsData memory _data = JBRedeemParamsData(
                    msg.sender,
                    _holder,
                    _projectId,
                    ruleset.id,
                    _tokenCount,
                    _totalSupply,
                    _currentSurplus,
                    _reclaimedTokenAmount,
                    ruleset.useTotalSurplusForRedemptions(),
                    ruleset.redemptionRate(),
                    _metadata
                );
                (reclaimAmount, hookPayloads) =
                    IJBRulesetDataHook(ruleset.dataHook()).redeemParams(_data);
            }
        }

        // Keep a reference to the amount that should be subtracted from the project's balance.
        uint256 _balanceDiff = reclaimAmount;

        if (hookPayloads.length != 0) {
            // Validate all payload amounts.
            for (uint256 _i; _i < hookPayloads.length;) {
                // Get a reference to the payload amount.
                uint256 _payloadAmount = hookPayloads[_i].amount;

                // Validate if non-zero.
                if (_payloadAmount != 0) {
                    // Increment the total amount being subtracted from the balance.
                    _balanceDiff = _balanceDiff + _payloadAmount;
                }

                unchecked {
                    ++_i;
                }
            }
        }

        // The amount being reclaimed must be within the project's balance.
        if (_balanceDiff > balanceOf[msg.sender][_projectId][_accountingContext.token]) {
            revert INADEQUATE_TERMINAL_STORE_BALANCE();
        }

        // Remove the reclaimed funds from the project's balance.
        if (_balanceDiff != 0) {
            unchecked {
                balanceOf[msg.sender][_projectId][_accountingContext.token] =
                    balanceOf[msg.sender][_projectId][_accountingContext.token] - _balanceDiff;
            }
        }
    }

    /// @notice Records a payout from a project.
    /// @param _projectId The ID of the project that is paying out funds.
    /// @param _accountingContext The context of the token being paid out.
    /// @param _amount The amount to pay out (use from the payout limit), as a fixed point number.
    /// @param _currency The currency of the `_amount`. This must match the project's current ruleset's currency.
    /// @return ruleset The ruleset the payout was made during, as a `JBRuleset` struct.
    /// @return amountPaidOut The amount of terminal tokens paid out, as a fixed point number with the same amount of decimals as its relative terminal.
    function recordPayoutFor(
        uint256 _projectId,
        JBAccountingContext calldata _accountingContext,
        uint256 _amount,
        uint256 _currency
    ) external override nonReentrant returns (JBRuleset memory ruleset, uint256 amountPaidOut) {
        // Get a reference to the project's current ruleset.
        ruleset = RULESETS.currentOf(_projectId);

        // The new total amount which has been paid out during this ruleset.
        uint256 _newUsedPayoutLimitOf = usedPayoutLimitOf[msg.sender][_projectId][_accountingContext
            .token][ruleset.cycleNumber][_currency] + _amount;

        // Amount must be within what is still available to pay out.
        uint256 _payoutLimit = IJBController(address(DIRECTORY.controllerOf(_projectId)))
            .fundAccessLimits().payoutLimitOf(
            _projectId, ruleset.id, msg.sender, _accountingContext.token, _currency
        );

        // Make sure the new used amount is within the payout limit.
        if (_newUsedPayoutLimitOf > _payoutLimit || _payoutLimit == 0) {
            revert PAYOUT_LIMIT_EXCEEDED();
        }

        // Convert the amount to the balance's currency.
        amountPaidOut = (_currency == _accountingContext.currency)
            ? _amount
            : PRBMath.mulDiv(
                _amount,
                10 ** _MAX_FIXED_POINT_FIDELITY, // Use `_MAX_FIXED_POINT_FIDELITY` to keep as much of the `_amount`'s fidelity as possible when converting.
                PRICES.pricePerUnitOf(
                    _projectId, _currency, _accountingContext.currency, _MAX_FIXED_POINT_FIDELITY
                )
            );

        // The amount being paid out must be available.
        if (amountPaidOut > balanceOf[msg.sender][_projectId][_accountingContext.token]) {
            revert INADEQUATE_TERMINAL_STORE_BALANCE();
        }

        // Store the new amount.
        usedPayoutLimitOf[msg.sender][_projectId][_accountingContext.token][ruleset.cycleNumber][_currency]
        = _newUsedPayoutLimitOf;

        // Removed the paid out funds from the project's token balance.
        unchecked {
            balanceOf[msg.sender][_projectId][_accountingContext.token] =
                balanceOf[msg.sender][_projectId][_accountingContext.token] - amountPaidOut;
        }
    }

    /// @notice Records a use of a project's surplus allowance.
    /// @dev When surplus allowance is "used", it is taken out of the project's surplus within a terminal.
    /// @param _projectId The ID of the project to use the surplus allowance of.
    /// @param _accountingContext The accounting context of the token whose balances should contribute to the surplus allowance being reclaimed from.
    /// @param _amount The amount to use from the surplus allowance, as a fixed point number.
    /// @param _currency The currency of the `_amount`. Must match the currency of the surplus allowance.
    /// @return ruleset The ruleset during the surplus allowance is being used during, as a `JBRuleset` struct.
    /// @return usedAmount The amount of terminal tokens used, as a fixed point number with the same amount of decimals as its relative terminal.
    function recordUsedAllowanceOf(
        uint256 _projectId,
        JBAccountingContext calldata _accountingContext,
        uint256 _amount,
        uint256 _currency
    ) external override nonReentrant returns (JBRuleset memory ruleset, uint256 usedAmount) {
        // Get a reference to the project's current ruleset.
        ruleset = RULESETS.currentOf(_projectId);

        // Get a reference to the new used surplus allowance for this ruleset ID.
        uint256 _newUsedSurplusAllowanceOf = usedSurplusAllowanceOf[msg.sender][_projectId][_accountingContext
            .token][ruleset.id][_currency] + _amount;

        // There must be sufficient surplus allowance available.
        uint256 _surplusAllowance = IJBController(address(DIRECTORY.controllerOf(_projectId)))
            .fundAccessLimits().surplusAllowanceOf(
            _projectId, ruleset.id, msg.sender, _accountingContext.token, _currency
        );

        // Make sure the new used amount is within the allowance.
        if (_newUsedSurplusAllowanceOf > _surplusAllowance || _surplusAllowance == 0) {
            revert INADEQUATE_CONTROLLER_ALLOWANCE();
        }

        // Convert the amount to this store's terminal's token.
        usedAmount = _currency == _accountingContext.currency
            ? _amount
            : PRBMath.mulDiv(
                _amount,
                10 ** _MAX_FIXED_POINT_FIDELITY, // Use `_MAX_FIXED_POINT_FIDELITY` to keep as much of the `_amount`'s fidelity as possible when converting.
                PRICES.pricePerUnitOf(
                    _projectId, _currency, _accountingContext.currency, _MAX_FIXED_POINT_FIDELITY
                )
            );

        // Set the token being used as the only one to look for surplus within.
        JBAccountingContext[] memory _accountingContexts = new JBAccountingContext[](1);
        _accountingContexts[0] = _accountingContext;

        // The amount being used must be available in the surplus.
        if (
            usedAmount
                > _surplusFrom(
                    msg.sender,
                    _projectId,
                    _accountingContexts,
                    ruleset,
                    _accountingContext.decimals,
                    _accountingContext.currency
                )
        ) revert INADEQUATE_TERMINAL_STORE_BALANCE();

        // Store the incremented value.
        usedSurplusAllowanceOf[msg.sender][_projectId][_accountingContext.token][ruleset.id][_currency]
        = _newUsedSurplusAllowanceOf;

        // Update the project's balance.
        balanceOf[msg.sender][_projectId][_accountingContext.token] =
            balanceOf[msg.sender][_projectId][_accountingContext.token] - usedAmount;
    }

    /// @notice Records funds being added to a project's balance.
    /// @param _projectId The ID of the project which funds are being added to the balance of.
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
    /// @return balance The project's current balance (which is being migrated), as a fixed point number with the same amount of decimals as its relative terminal.
    function recordTerminalMigration(uint256 _projectId, address _token)
        external
        override
        nonReentrant
        returns (uint256 balance)
    {
        // Get a reference to the project's current ruleset.
        JBRuleset memory _ruleset = RULESETS.currentOf(_projectId);

        // Terminal migration must be allowed.
        if (!_ruleset.allowTerminalMigration()) {
            revert TERMINAL_MIGRATION_NOT_ALLOWED();
        }

        // Return the current balance, which is the amount being migrated.
        balance = balanceOf[msg.sender][_projectId][_token];

        // Set the balance to 0.
        balanceOf[msg.sender][_projectId][_token] = 0;
    }

    //*********************************************************************//
    // --------------------- private helper functions -------------------- //
    //*********************************************************************//

    /// @notice The amount of surplus which is available for reclaiming via redemption given the number of tokens being redeemed, the total supply, the current surplus, and the current ruleset.
    /// @param _ruleset The ruleset during which reclaimable surplus is being calculated.
    /// @param _tokenCount The number of tokens to make the calculation with, as a fixed point number with 18 decimals.
    /// @param _totalSupply The total supply of tokens to make the calculation with, as a fixed point number with 18 decimals.
    /// @param _surplus The surplus amount to make the calculation with.
    /// @return The amount of surplus tokens that can be reclaimed.
    function _reclaimableSurplusDuring(
        JBRuleset memory _ruleset,
        uint256 _tokenCount,
        uint256 _totalSupply,
        uint256 _surplus
    ) private pure returns (uint256) {
        // If the amount being redeemed is the total supply, return the rest of the surplus.
        if (_tokenCount == _totalSupply) return _surplus;

        // If the redemption rate is 0, nothing is claimable.
        if (_ruleset.redemptionRate() == 0) return 0;

        // Get a reference to the linear proportion.
        uint256 _base = PRBMath.mulDiv(_surplus, _tokenCount, _totalSupply);

        // These conditions are all part of the same curve. Edge conditions are separated because fewer operation are necessary.
        if (_ruleset.redemptionRate() == JBConstants.MAX_REDEMPTION_RATE) {
            return _base;
        }

        return PRBMath.mulDiv(
            _base,
            _ruleset.redemptionRate()
                + PRBMath.mulDiv(
                    _tokenCount,
                    JBConstants.MAX_REDEMPTION_RATE - _ruleset.redemptionRate(),
                    _totalSupply
                ),
            JBConstants.MAX_REDEMPTION_RATE
        );
    }

    /// @notice Gets a project's surplus amount in a terminal as measured by a given ruleset, across multiple accounting contexts.
    /// @dev This amount changes as the value of the balance changes in relation to the currency being used to measure various payout limits.
    /// @param _terminal The terminal the surplus is being calculated for.
    /// @param _projectId The ID of the project to get the surplus for.
    /// @param _accountingContexts The accounting contexts of tokens whose balances should contribute to the surplus being calculated.
    /// @param _ruleset The ID of the ruleset to base the surplus on.
    /// @param _targetDecimals The number of decimals to include in the resulting fixed point number.
    /// @param _targetCurrency The currency that the reported surplus is expected to be in terms of.
    /// @return surplus The surplus of funds in terms of `_targetCurrency`, as a fixed point number with `_targetDecimals` decimals.
    function _surplusFrom(
        address _terminal,
        uint256 _projectId,
        JBAccountingContext[] memory _accountingContexts,
        JBRuleset memory _ruleset,
        uint256 _targetDecimals,
        uint256 _targetCurrency
    ) private view returns (uint256 surplus) {
        // Keep a reference to the number of tokens being iterated on.
        uint256 _numberOfTokenAccountingContexts = _accountingContexts.length;

        // Add payout limits from each token.
        for (uint256 _i; _i < _numberOfTokenAccountingContexts;) {
            uint256 _tokenSurplus = _tokenSurplusFrom(
                _terminal,
                _projectId,
                _accountingContexts[_i],
                _ruleset,
                _targetDecimals,
                _targetCurrency
            );
            // Increment the surplus with any remaining balance.
            if (_tokenSurplus > 0) surplus += _tokenSurplus;

            unchecked {
                ++_i;
            }
        }
    }

    /// @notice Get a project's surplus amount of a specific token in a given terminal as measured by a given ruleset (one specific accounting context).
    /// @dev This amount changes as the value of the balance changes in relation to the currency being used to measure the payout limits.
    /// @param _terminal The terminal the surplus is being calculated for.
    /// @param _projectId The ID of the project to get the surplus of.
    /// @param _accountingContext The accounting context of the token whose balance should contribute to the surplus being measured.
    /// @param _ruleset The ID of the ruleset to base the surplus calculation on.
    /// @param _targetDecimals The number of decimals to include in the resulting fixed point number.
    /// @param _targetCurrency The currency that the reported surplus is expected to be in terms of.
    /// @return surplus The surplus of funds in terms of `_targetCurrency`, as a fixed point number with `_targetDecimals` decimals.
    function _tokenSurplusFrom(
        address _terminal,
        uint256 _projectId,
        JBAccountingContext memory _accountingContext,
        JBRuleset memory _ruleset,
        uint256 _targetDecimals,
        uint256 _targetCurrency
    ) private view returns (uint256 surplus) {
        // Keep a reference to the balance.
        surplus = balanceOf[_terminal][_projectId][_accountingContext.token];

        // If needed, adjust the decimals of the fixed point number to have the correct decimals.
        surplus = _accountingContext.decimals == _targetDecimals
            ? surplus
            : JBFixedPointNumber.adjustDecimals(surplus, _accountingContext.decimals, _targetDecimals);

        // Add up all the balances.
        surplus = (surplus == 0 || _accountingContext.currency == _targetCurrency)
            ? surplus
            : PRBMath.mulDiv(
                surplus,
                10 ** _MAX_FIXED_POINT_FIDELITY, // Use `_MAX_FIXED_POINT_FIDELITY` to keep as much of the `_payoutLimitRemaining`'s fidelity as possible when converting.
                PRICES.pricePerUnitOf(
                    _projectId, _accountingContext.currency, _targetCurrency, _MAX_FIXED_POINT_FIDELITY
                )
            );

        // Get a reference to the payout limit during the ruleset for the token.
        JBCurrencyAmount[] memory _payoutLimits = IJBController(
            address(DIRECTORY.controllerOf(_projectId))
        ).fundAccessLimits().payoutLimitsOf(
            _projectId, _ruleset.id, address(_terminal), _accountingContext.token
        );

        // Keep a reference to the payout limit being iterated on.
        JBCurrencyAmount memory _payoutLimit;

        // Keep a reference to the number of payout limits being iterated on.
        uint256 _numberOfPayoutLimits = _payoutLimits.length;

        // Loop through each payout limit to determine the cumulative normalized payout limit remaining.
        for (uint256 _i; _i < _numberOfPayoutLimits;) {
            _payoutLimit = _payoutLimits[_i];

            // Set the payout limit value to the amount still available to pay out during the ruleset.
            _payoutLimit.amount = _payoutLimit.amount
                - usedPayoutLimitOf[_terminal][_projectId][_accountingContext.token][_ruleset
                    .cycleNumber][_payoutLimit.currency];

            // Adjust the decimals of the fixed point number if needed to have the correct decimals.
            _payoutLimit.amount = _accountingContext.decimals == _targetDecimals
                ? _payoutLimit.amount
                : JBFixedPointNumber.adjustDecimals(
                    _payoutLimit.amount, _accountingContext.decimals, _targetDecimals
                );

            // Convert the `_payoutLimit`'s amount to be in terms of the provided currency.
            _payoutLimit.amount = _payoutLimit.amount == 0
                || _payoutLimit.currency == _targetCurrency
                ? _payoutLimit.amount
                : PRBMath.mulDiv(
                    _payoutLimit.amount,
                    10 ** _MAX_FIXED_POINT_FIDELITY, // Use `_MAX_FIXED_POINT_FIDELITY` to keep as much of the `_payoutLimitRemaining`'s fidelity as possible when converting.
                    PRICES.pricePerUnitOf(
                        _projectId, _payoutLimit.currency, _targetCurrency, _MAX_FIXED_POINT_FIDELITY
                    )
                );

            // Decrement from the balance until it reaches zero.
            if (surplus > _payoutLimit.amount) {
                surplus -= _payoutLimit.amount;
            } else {
                return 0;
            }

            unchecked {
                ++_i;
            }
        }
    }

    /// @notice Gets the total current surplus amount across all of a project's terminals.
    /// @dev This amount changes as the value of the balances changes in relation to the currency being used to measure the project's payout limits.
    /// @param _projectId The ID of the project to get the total surplus for.
    /// @param _decimals The number of decimals that the fixed point surplus result should include.
    /// @param _currency The currency that the surplus result should be in terms of.
    /// @return surplus The total surplus of a project's funds in terms of `_currency`, as a fixed point number with the specified number of decimals.
    function _currentTotalSurplusOf(uint256 _projectId, uint256 _decimals, uint256 _currency)
        private
        view
        returns (uint256 surplus)
    {
        // Get a reference to the project's terminals.
        IJBTerminal[] memory _terminals = DIRECTORY.terminalsOf(_projectId);

        // Keep a reference to the number of termainls.
        uint256 _numberOfTerminals = _terminals.length;

        // Add the current surplus for each terminal.
        for (uint256 _i; _i < _numberOfTerminals;) {
            surplus += _terminals[_i].currentSurplusOf(_projectId, _decimals, _currency);
            unchecked {
                ++_i;
            }
        }
    }
}
