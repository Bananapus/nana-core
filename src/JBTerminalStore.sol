// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {mulDiv} from "@prb/math/src/Common.sol";

import {IJBController} from "./interfaces/IJBController.sol";
import {IJBDirectory} from "./interfaces/IJBDirectory.sol";
import {IJBPrices} from "./interfaces/IJBPrices.sol";
import {IJBRulesetDataHook} from "./interfaces/IJBRulesetDataHook.sol";
import {IJBRulesets} from "./interfaces/IJBRulesets.sol";
import {IJBTerminalStore} from "./interfaces/IJBTerminalStore.sol";
import {JBFixedPointNumber} from "./libraries/JBFixedPointNumber.sol";
import {JBRedemptions} from "./libraries/JBRedemptions.sol";
import {JBRulesetMetadataResolver} from "./libraries/JBRulesetMetadataResolver.sol";
import {JBSurplus} from "./libraries/JBSurplus.sol";
import {JBAccountingContext} from "./structs/JBAccountingContext.sol";
import {JBBeforePayRecordedContext} from "./structs/JBBeforePayRecordedContext.sol";
import {JBBeforeRedeemRecordedContext} from "./structs/JBBeforeRedeemRecordedContext.sol";
import {JBCurrencyAmount} from "./structs/JBCurrencyAmount.sol";
import {JBPayHookSpecification} from "./structs/JBPayHookSpecification.sol";
import {JBRedeemHookSpecification} from "./structs/JBRedeemHookSpecification.sol";
import {JBRuleset} from "./structs/JBRuleset.sol";
import {JBTokenAmount} from "./structs/JBTokenAmount.sol";

/// @notice Manages all bookkeeping for inflows and outflows of funds from any terminal address.
/// @dev This contract expects a project's controller to be an `IJBController`.
contract JBTerminalStore is IJBTerminalStore {
    // A library that parses the packed ruleset metadata into a friendlier format.
    using JBRulesetMetadataResolver for JBRuleset;

    //*********************************************************************//
    // --------------------------- custom errors ------------------------- //
    //*********************************************************************//

    error JBTerminalStore_InadequateControllerAllowance(uint256 amount, uint256 allowance);
    error JBTerminalStore_InadequateControllerPayoutLimit(uint256 amount, uint256 limit);
    error JBTerminalStore_InadequateTerminalStoreBalance(uint256 amount, uint256 balance);
    error JBTerminalStore_InsufficientTokens(uint256 count, uint256 totalSupply);
    error JBTerminalStore_InvalidAmountToForwardHook(uint256 amount, uint256 paidAmount);
    error JBTerminalStore_RulesetNotFound();
    error JBTerminalStore_RulesetPaymentPaused();
    error JBTerminalStore_TerminalMigrationNotAllowed();

    //*********************************************************************//
    // -------------------------- internal constants --------------------- //
    //*********************************************************************//

    /// @notice Constrains `mulDiv` operations on fixed point numbers to a maximum number of decimal points of persisted
    /// fidelity.
    uint256 internal constant _MAX_FIXED_POINT_FIDELITY = 18;

    //*********************************************************************//
    // ---------------- public immutable stored properties --------------- //
    //*********************************************************************//

    /// @notice The directory of terminals and controllers for projects.
    IJBDirectory public immutable override DIRECTORY;

    /// @notice The contract that exposes price feeds.
    IJBPrices public immutable override PRICES;

    /// @notice The contract storing and managing project rulesets.
    IJBRulesets public immutable override RULESETS;

    //*********************************************************************//
    // --------------------- public stored properties -------------------- //
    //*********************************************************************//

    /// @notice A project's balance of a specific token within a terminal.
    /// @dev The balance is represented as a fixed point number with the same amount of decimals as its relative
    /// terminal.
    /// @custom:param terminal The terminal to get the project's balance within.
    /// @custom:param projectId The ID of the project to get the balance of.
    /// @custom:param token The token to get the balance for.
    mapping(address terminal => mapping(uint256 projectId => mapping(address token => uint256))) public override
        balanceOf;

    /// @notice The currency-denominated amount of funds that a project has already paid out from its payout limit
    /// during the current ruleset for each terminal, in terms of the payout limit's currency.
    /// @dev Increases as projects pay out funds.
    /// @dev The used payout limit is represented as a fixed point number with the same amount of decimals as the
    /// terminal it applies to.
    /// @custom:param terminal The terminal the payout limit applies to.
    /// @custom:param projectId The ID of the project to get the used payout limit of.
    /// @custom:param token The token the payout limit applies to in the terminal.
    /// @custom:param rulesetCycleNumber The cycle number of the ruleset the payout limit was used during.
    /// @custom:param currency The currency the payout limit is in terms of.
    mapping(
        address terminal
            => mapping(
                uint256 projectId
                    => mapping(
                        address token => mapping(uint256 rulesetCycleNumber => mapping(uint256 currency => uint256))
                    )
            )
    ) public override usedPayoutLimitOf;

    /// @notice The currency-denominated amounts of funds that a project has used from its surplus allowance during the
    /// current ruleset for each terminal, in terms of the surplus allowance's currency.
    /// @dev Increases as projects use their allowance.
    /// @dev The used surplus allowance is represented as a fixed point number with the same amount of decimals as the
    /// terminal it applies to.
    /// @custom:param terminal The terminal the surplus allowance applies to.
    /// @custom:param projectId The ID of the project to get the used surplus allowance of.
    /// @custom:param token The token the surplus allowance applies to in the terminal.
    /// @custom:param rulesetId The ID of the ruleset the surplus allowance was used during.
    /// @custom:param currency The currency the surplus allowance is in terms of.
    mapping(
        address terminal
            => mapping(
                uint256 projectId
                    => mapping(address token => mapping(uint256 rulesetId => mapping(uint256 currency => uint256)))
            )
    ) public override usedSurplusAllowanceOf;

    //*********************************************************************//
    // -------------------------- constructor ---------------------------- //
    //*********************************************************************//

    /// @param directory A contract storing directories of terminals and controllers for each project.
    /// @param prices A contract that exposes price feeds.
    /// @param rulesets A contract storing and managing project rulesets.
    constructor(IJBDirectory directory, IJBPrices prices, IJBRulesets rulesets) {
        DIRECTORY = directory;
        PRICES = prices;
        RULESETS = rulesets;
    }

    //*********************************************************************//
    // ------------------------- external views -------------------------- //
    //*********************************************************************//

    /// @notice Returns the number of surplus terminal tokens that would be reclaimed by redeeming a given project's
    /// tokens based on its current ruleset and the given total project token supply and total terminal token surplus.
    /// @param projectId The ID of the project whose project tokens would be redeemed.
    /// @param tokensRedeemed The number of project tokens that would be redeemed, as a fixed point number with 18
    /// decimals.
    /// @param totalSupply The total project token supply, as a fixed point number with 18 decimals.
    /// @param surplus The total terminal token surplus amount, as a fixed point number.
    /// @return The number of surplus terminal tokens that would be reclaimed, as a fixed point number with the same
    /// number of decimals as the provided `surplus`.
    function currentReclaimableSurplusOf(
        uint256 projectId,
        uint256 tokensRedeemed,
        uint256 totalSupply,
        uint256 surplus
    )
        external
        view
        override
        returns (uint256)
    {
        // If there's no surplus, nothing can be reclaimed.
        if (surplus == 0) return 0;

        // Can't redeem more tokens than are in the total supply.
        if (tokensRedeemed > totalSupply) return 0;

        // Get a reference to the project's current ruleset.
        JBRuleset memory ruleset = RULESETS.currentOf(projectId);

        // Return the amount of surplus terminal tokens that would be reclaimed.
        return JBRedemptions.reclaimFrom({
            surplus: surplus,
            tokensRedeemed: tokensRedeemed,
            totalSupply: totalSupply,
            redemptionRate: ruleset.redemptionRate()
        });
    }

    /// @notice Returns the number of surplus terminal tokens that would be reclaimed from a terminal by redeeming a
    /// given number of tokens, based on the total token supply and total surplus.
    /// @dev The returned amount in terms of the specified `terminal`'s base currency.
    /// @dev The returned amount is represented as a fixed point number with the same amount of decimals as the
    /// specified terminal.
    /// @param terminal The terminal that would be redeemed from. If `useTotalSurplus` is true, this is ignored.
    /// @param projectId The ID of the project whose tokens would be redeemed.
    /// @param accountingContexts The accounting contexts of the surplus terminal tokens that would be reclaimed
    /// @param decimals The number of decimals to include in the resulting fixed point number.
    /// @param currency The currency that the resulting number will be in terms of.
    /// @param tokensRedeemed The number of tokens that would be redeemed, as a fixed point number with 18 decimals.
    /// @param useTotalSurplus Whether the total surplus should be summed across all of the project's terminals. If
    /// false, only the `terminal`'s surplus is used.
    /// @return The amount of surplus terminal tokens that would be reclaimed by redeeming `tokensRedeemed` tokens.
    function currentReclaimableSurplusOf(
        address terminal,
        uint256 projectId,
        JBAccountingContext[] calldata accountingContexts,
        uint256 decimals,
        uint256 currency,
        uint256 tokensRedeemed,
        bool useTotalSurplus
    )
        external
        view
        override
        returns (uint256)
    {
        // Get a reference to the project's current ruleset.
        JBRuleset memory ruleset = RULESETS.currentOf(projectId);

        // Get the current surplus amount.
        // If `useTotalSurplus` is true, use the total surplus across all terminals. Otherwise, get the `terminal`'s
        // surplus.
        uint256 currentSurplus = useTotalSurplus
            ? JBSurplus.currentSurplusOf({
                projectId: projectId,
                terminals: DIRECTORY.terminalsOf(projectId),
                decimals: decimals,
                currency: currency
            })
            : _surplusFrom(terminal, projectId, accountingContexts, ruleset, decimals, currency);

        // If there's no surplus, nothing can be reclaimed.
        if (currentSurplus == 0) return 0;

        // Get the project token's total supply.
        uint256 totalSupply =
            IJBController(address(DIRECTORY.controllerOf(projectId))).totalTokenSupplyWithReservedTokensOf(projectId);

        // Can't redeem more tokens than are in the total supply.
        if (tokensRedeemed > totalSupply) return 0;

        // Return the amount of surplus terminal tokens that would be reclaimed.
        return JBRedemptions.reclaimFrom({
            surplus: currentSurplus,
            tokensRedeemed: tokensRedeemed,
            totalSupply: totalSupply,
            redemptionRate: ruleset.redemptionRate()
        });
    }

    /// @notice Gets the current surplus amount in a terminal for a specified project.
    /// @dev The surplus is the amount of funds a project has in a terminal in excess of its payout limit.
    /// @dev The surplus is represented as a fixed point number with the same amount of decimals as the specified
    /// terminal.
    /// @param terminal The terminal the surplus is being calculated for.
    /// @param projectId The ID of the project to get surplus for.
    /// @param accountingContexts The accounting contexts of tokens whose balances should contribute to the surplus
    /// being calculated.
    /// @param currency The currency the resulting amount should be in terms of.
    /// @param decimals The number of decimals to expect in the resulting fixed point number.
    /// @return The current surplus amount the project has in the specified terminal.
    function currentSurplusOf(
        address terminal,
        uint256 projectId,
        JBAccountingContext[] calldata accountingContexts,
        uint256 decimals,
        uint256 currency
    )
        external
        view
        override
        returns (uint256)
    {
        // Return the surplus during the project's current ruleset.
        return _surplusFrom({
            terminal: terminal,
            projectId: projectId,
            accountingContexts: accountingContexts,
            ruleset: RULESETS.currentOf(projectId),
            targetDecimals: decimals,
            targetCurrency: currency
        });
    }

    /// @notice Gets the current surplus amount for a specified project across all terminals.
    /// @param projectId The ID of the project to get the total surplus for.
    /// @param decimals The number of decimals that the fixed point surplus should include.
    /// @param currency The currency that the total surplus should be in terms of.
    /// @return The current total surplus amount that the project has across all terminals.
    function currentTotalSurplusOf(
        uint256 projectId,
        uint256 decimals,
        uint256 currency
    )
        external
        view
        override
        returns (uint256)
    {
        return JBSurplus.currentSurplusOf({
            projectId: projectId,
            terminals: DIRECTORY.terminalsOf(projectId),
            decimals: decimals,
            currency: currency
        });
    }

    //*********************************************************************//
    // -------------------------- internal views ------------------------- //
    //*********************************************************************//

    /// @notice Gets a project's surplus amount in a terminal as measured by a given ruleset, across multiple accounting
    /// contexts.
    /// @dev This amount changes as the value of the balance changes in relation to the currency being used to measure
    /// various payout limits.
    /// @param terminal The terminal the surplus is being calculated for.
    /// @param projectId The ID of the project to get the surplus for.
    /// @param accountingContexts The accounting contexts of tokens whose balances should contribute to the surplus
    /// being calculated.
    /// @param ruleset The ID of the ruleset to base the surplus on.
    /// @param targetDecimals The number of decimals to include in the resulting fixed point number.
    /// @param targetCurrency The currency that the reported surplus is expected to be in terms of.
    /// @return surplus The surplus of funds in terms of `targetCurrency`, as a fixed point number with
    /// `targetDecimals` decimals.
    function _surplusFrom(
        address terminal,
        uint256 projectId,
        JBAccountingContext[] memory accountingContexts,
        JBRuleset memory ruleset,
        uint256 targetDecimals,
        uint256 targetCurrency
    )
        internal
        view
        returns (uint256 surplus)
    {
        // Add payout limits from each token.
        for (uint256 i; i < accountingContexts.length; i++) {
            uint256 tokenSurplus = _tokenSurplusFrom({
                terminal: terminal,
                projectId: projectId,
                accountingContext: accountingContexts[i],
                ruleset: ruleset,
                targetDecimals: targetDecimals,
                targetCurrency: targetCurrency
            });
            // Increment the surplus with any remaining balance.
            if (tokenSurplus > 0) surplus += tokenSurplus;
        }
    }

    /// @notice Get a project's surplus amount of a specific token in a given terminal as measured by a given ruleset
    /// (one specific accounting context).
    /// @dev This amount changes as the value of the balance changes in relation to the currency being used to measure
    /// the payout limits.
    /// @param terminal The terminal the surplus is being calculated for.
    /// @param projectId The ID of the project to get the surplus of.
    /// @param accountingContext The accounting context of the token whose balance should contribute to the surplus
    /// being measured.
    /// @param ruleset The ID of the ruleset to base the surplus calculation on.
    /// @param targetDecimals The number of decimals to include in the resulting fixed point number.
    /// @param targetCurrency The currency that the reported surplus is expected to be in terms of.
    /// @return surplus The surplus of funds in terms of `targetCurrency`, as a fixed point number with
    /// `targetDecimals` decimals.
    function _tokenSurplusFrom(
        address terminal,
        uint256 projectId,
        JBAccountingContext memory accountingContext,
        JBRuleset memory ruleset,
        uint256 targetDecimals,
        uint256 targetCurrency
    )
        internal
        view
        returns (uint256 surplus)
    {
        // Keep a reference to the balance.
        surplus = balanceOf[terminal][projectId][accountingContext.token];

        // If needed, adjust the decimals of the fixed point number to have the correct decimals.
        surplus = accountingContext.decimals == targetDecimals
            ? surplus
            : JBFixedPointNumber.adjustDecimals({
                value: surplus,
                decimals: accountingContext.decimals,
                targetDecimals: targetDecimals
            });

        // Add up all the balances.
        surplus = (surplus == 0 || accountingContext.currency == targetCurrency)
            ? surplus
            : mulDiv(
                surplus,
                10 ** _MAX_FIXED_POINT_FIDELITY, // Use `_MAX_FIXED_POINT_FIDELITY` to keep as much of the
                    // `_payoutLimitRemaining`'s fidelity as possible when converting.
                PRICES.pricePerUnitOf({
                    projectId: projectId,
                    pricingCurrency: accountingContext.currency,
                    unitCurrency: targetCurrency,
                    decimals: _MAX_FIXED_POINT_FIDELITY
                })
            );

        // Get a reference to the payout limit during the ruleset for the token.
        JBCurrencyAmount[] memory payoutLimits = IJBController(address(DIRECTORY.controllerOf(projectId)))
            .FUND_ACCESS_LIMITS().payoutLimitsOf({
            projectId: projectId,
            rulesetId: ruleset.id,
            terminal: address(terminal),
            token: accountingContext.token
        });

        // Loop through each payout limit to determine the cumulative normalized payout limit remaining.
        for (uint256 i; i < payoutLimits.length; i++) {
            JBCurrencyAmount memory payoutLimit = payoutLimits[i];

            // Set the payout limit value to the amount still available to pay out during the ruleset.
            payoutLimit.amount = uint224(
                payoutLimit.amount
                    - usedPayoutLimitOf[terminal][projectId][accountingContext.token][ruleset.cycleNumber][payoutLimit
                        .currency]
            );

            // Adjust the decimals of the fixed point number if needed to have the correct decimals.
            payoutLimit.amount = accountingContext.decimals == targetDecimals
                ? payoutLimit.amount
                : uint224(
                    JBFixedPointNumber.adjustDecimals({
                        value: payoutLimit.amount,
                        decimals: accountingContext.decimals,
                        targetDecimals: targetDecimals
                    })
                );

            // Convert the `payoutLimit`'s amount to be in terms of the provided currency.
            payoutLimit.amount = payoutLimit.amount == 0 || payoutLimit.currency == targetCurrency
                ? payoutLimit.amount
                : uint224(
                    mulDiv(
                        payoutLimit.amount,
                        10 ** _MAX_FIXED_POINT_FIDELITY, // Use `_MAX_FIXED_POINT_FIDELITY` to keep as much of the
                            // `payoutLimitRemaining`'s fidelity as possible when converting.
                        PRICES.pricePerUnitOf({
                            projectId: projectId,
                            pricingCurrency: payoutLimit.currency,
                            unitCurrency: targetCurrency,
                            decimals: _MAX_FIXED_POINT_FIDELITY
                        })
                    )
                );

            // Decrement from the balance until it reaches zero.
            if (surplus > payoutLimit.amount) {
                surplus -= payoutLimit.amount;
            } else {
                return 0;
            }
        }
    }

    //*********************************************************************//
    // ---------------------- external transactions ---------------------- //
    //*********************************************************************//

    /// @notice Records funds being added to a project's balance.
    /// @param projectId The ID of the project which funds are being added to the balance of.
    /// @param token The token being added to the balance.
    /// @param amount The amount of terminal tokens added, as a fixed point number with the same amount of decimals as
    /// its relative terminal.
    function recordAddedBalanceFor(uint256 projectId, address token, uint256 amount) external override {
        // Increment the balance.
        balanceOf[msg.sender][projectId][token] = balanceOf[msg.sender][projectId][token] + amount;
    }

    /// @notice Records a payment to a project.
    /// @dev Mints the project's tokens according to values provided by the ruleset's data hook. If the ruleset has no
    /// data hook, mints tokens in proportion with the amount paid.
    /// @param payer The address that made the payment to the terminal.
    /// @param amount The amount of tokens being paid. Includes the token being paid, their value, the number of
    /// decimals included, and the currency of the amount.
    /// @param projectId The ID of the project being paid.
    /// @param beneficiary The address that should be the beneficiary of anything the payment yields (including project
    /// tokens minted by the payment).
    /// @param metadata Bytes to send to the data hook, if the project's current ruleset specifies one.
    /// @return ruleset The ruleset the payment was made during, as a `JBRuleset` struct.
    /// @return tokenCount The number of project tokens that were minted, as a fixed point number with 18 decimals.
    /// @return hookSpecifications A list of pay hooks, including data and amounts to send to them. The terminal should
    /// fulfill these specifications.
    function recordPaymentFrom(
        address payer,
        JBTokenAmount calldata amount,
        uint256 projectId,
        address beneficiary,
        bytes calldata metadata
    )
        external
        override
        returns (JBRuleset memory ruleset, uint256 tokenCount, JBPayHookSpecification[] memory hookSpecifications)
    {
        // Get a reference to the project's current ruleset.
        ruleset = RULESETS.currentOf(projectId);

        // The project must have a ruleset.
        if (ruleset.cycleNumber == 0) revert JBTerminalStore_RulesetNotFound();

        // The ruleset must not have payments paused.
        if (ruleset.pausePay()) revert JBTerminalStore_RulesetPaymentPaused();

        // The weight according to which new tokens are to be minted, as a fixed point number with 18 decimals.
        uint256 weight;

        // If the ruleset has a data hook enabled for payments, use it to derive a weight and memo.
        if (ruleset.useDataHookForPay() && ruleset.dataHook() != address(0)) {
            // Create the pay context that'll be sent to the data hook.
            JBBeforePayRecordedContext memory context = JBBeforePayRecordedContext({
                terminal: msg.sender,
                payer: payer,
                amount: amount,
                projectId: uint56(projectId),
                rulesetId: ruleset.id,
                beneficiary: beneficiary,
                weight: ruleset.weight,
                reservedPercent: ruleset.reservedPercent(),
                metadata: metadata
            });

            (weight, hookSpecifications) = IJBRulesetDataHook(ruleset.dataHook()).beforePayRecordedWith(context);
        }
        // Otherwise use the ruleset's weight
        else {
            weight = ruleset.weight;
        }

        // Keep a reference to the amount that should be added to the project's balance.
        uint256 balanceDiff = amount.value;

        // Ensure that the specifications have valid amounts.
        if (hookSpecifications.length != 0) {
            for (uint256 i; i < hookSpecifications.length; i++) {
                // Get a reference to the specification's amount.
                uint256 specifiedAmount = hookSpecifications[i].amount;

                // Ensure the amount is non-zero.
                if (specifiedAmount != 0) {
                    // Can't send more to hook than was paid.
                    if (specifiedAmount > balanceDiff) {
                        revert JBTerminalStore_InvalidAmountToForwardHook(specifiedAmount, balanceDiff);
                    }

                    // Decrement the total amount being added to the local balance.
                    balanceDiff -= specifiedAmount;
                }
            }
        }

        // If there's no amount being recorded, there's nothing left to do.
        if (amount.value == 0) return (ruleset, 0, hookSpecifications);

        // Add the correct balance difference to the token balance of the project.
        if (balanceDiff != 0) {
            balanceOf[msg.sender][projectId][amount.token] =
                balanceOf[msg.sender][projectId][amount.token] + balanceDiff;
        }

        // If there's no weight, the token count must be 0, so there's nothing left to do.
        if (weight == 0) return (ruleset, 0, hookSpecifications);

        // If the terminal should base its weight on a currency other than the terminal's currency, determine the
        // factor. The weight is always a fixed point mumber with 18 decimals. To ensure this, the ratio should use the
        // same
        // number of decimals as the `amount`.
        uint256 weightRatio = amount.currency == ruleset.baseCurrency()
            ? 10 ** amount.decimals
            : PRICES.pricePerUnitOf({
                projectId: projectId,
                pricingCurrency: amount.currency,
                unitCurrency: ruleset.baseCurrency(),
                decimals: amount.decimals
            });

        // Find the number of tokens to mint, as a fixed point number with as many decimals as `weight` has.
        tokenCount = mulDiv(amount.value, weight, weightRatio);
    }

    /// @notice Records a payout from a project.
    /// @param projectId The ID of the project that is paying out funds.
    /// @param accountingContext The context of the token being paid out.
    /// @param amount The amount to pay out (use from the payout limit), as a fixed point number.
    /// @param currency The currency of the `amount`. This must match the project's current ruleset's currency.
    /// @return ruleset The ruleset the payout was made during, as a `JBRuleset` struct.
    /// @return amountPaidOut The amount of terminal tokens paid out, as a fixed point number with the same amount of
    /// decimals as its relative terminal.
    function recordPayoutFor(
        uint256 projectId,
        JBAccountingContext calldata accountingContext,
        uint256 amount,
        uint256 currency
    )
        external
        override
        returns (JBRuleset memory ruleset, uint256 amountPaidOut)
    {
        // Get a reference to the project's current ruleset.
        ruleset = RULESETS.currentOf(projectId);

        // Convert the amount to the balance's currency.
        amountPaidOut = (currency == accountingContext.currency)
            ? amount
            : mulDiv(
                amount,
                10 ** _MAX_FIXED_POINT_FIDELITY, // Use `_MAX_FIXED_POINT_FIDELITY` to keep as much of the `_amount`'s
                    // fidelity as possible when converting.
                PRICES.pricePerUnitOf({
                    projectId: projectId,
                    pricingCurrency: currency,
                    unitCurrency: accountingContext.currency,
                    decimals: _MAX_FIXED_POINT_FIDELITY
                })
            );

        // The amount being paid out must be available.
        if (amountPaidOut > balanceOf[msg.sender][projectId][accountingContext.token]) {
            revert JBTerminalStore_InadequateTerminalStoreBalance(
                amountPaidOut, balanceOf[msg.sender][projectId][accountingContext.token]
            );
        }

        // Removed the paid out funds from the project's token balance.
        unchecked {
            balanceOf[msg.sender][projectId][accountingContext.token] =
                balanceOf[msg.sender][projectId][accountingContext.token] - amountPaidOut;
        }

        // The new total amount which has been paid out during this ruleset.
        uint256 newUsedPayoutLimitOf =
            usedPayoutLimitOf[msg.sender][projectId][accountingContext.token][ruleset.cycleNumber][currency] + amount;

        // Store the new amount.
        usedPayoutLimitOf[msg.sender][projectId][accountingContext.token][ruleset.cycleNumber][currency] =
            newUsedPayoutLimitOf;

        // Amount must be within what is still available to pay out.
        uint256 payoutLimit = IJBController(address(DIRECTORY.controllerOf(projectId))).FUND_ACCESS_LIMITS()
            .payoutLimitOf({
            projectId: projectId,
            rulesetId: ruleset.id,
            terminal: msg.sender,
            token: accountingContext.token,
            currency: currency
        });

        // Make sure the new used amount is within the payout limit.
        if (newUsedPayoutLimitOf > payoutLimit || payoutLimit == 0) {
            revert JBTerminalStore_InadequateControllerPayoutLimit(newUsedPayoutLimitOf, payoutLimit);
        }
    }

    /// @notice Records a redemption from a project.
    /// @dev Redeems the project's tokens according to values provided by the ruleset's data hook. If the ruleset has no
    /// data hook, redeems tokens along a redemption bonding curve that is a function of the number of tokens being
    /// burned.
    /// @param holder The account that is redeeming tokens.
    /// @param projectId The ID of the project being redeemed from.
    /// @param redeemCount The number of project tokens to redeem, as a fixed point number with 18 decimals.
    /// @param accountingContext The accounting context of the token being reclaimed by the redemption.
    /// @param balanceAccountingContexts The accounting contexts of the tokens whose balances should contribute to the
    /// surplus being reclaimed from.
    /// @param metadata Bytes to send to the data hook, if the project's current ruleset specifies one.
    /// @return ruleset The ruleset during the redemption was made during, as a `JBRuleset` struct. This ruleset will
    /// have a redemption rate provided by the redemption hook if applicable.
    /// @return reclaimAmount The amount of tokens reclaimed from the terminal, as a fixed point number with 18
    /// decimals.
    /// @return redemptionRate The redemption rate influencing the reclaim amount.
    /// @return hookSpecifications A list of redeem hooks, including data and amounts to send to them. The terminal
    /// should fulfill these specifications.
    function recordRedemptionFor(
        address holder,
        uint256 projectId,
        uint256 redeemCount,
        JBAccountingContext calldata accountingContext,
        JBAccountingContext[] calldata balanceAccountingContexts,
        bytes memory metadata
    )
        external
        override
        returns (
            JBRuleset memory ruleset,
            uint256 reclaimAmount,
            uint256 redemptionRate,
            JBRedeemHookSpecification[] memory hookSpecifications
        )
    {
        // Get a reference to the project's current ruleset.
        ruleset = RULESETS.currentOf(projectId);

        // Get the current surplus amount.
        // Use the local surplus if the ruleset specifies that it should be used. Otherwise, use the project's total
        // surplus across all of its terminals.
        uint256 currentSurplus = ruleset.useTotalSurplusForRedemptions()
            ? JBSurplus.currentSurplusOf({
                projectId: projectId,
                terminals: DIRECTORY.terminalsOf(projectId),
                decimals: accountingContext.decimals,
                currency: accountingContext.currency
            })
            : _surplusFrom({
                terminal: msg.sender,
                projectId: projectId,
                accountingContexts: balanceAccountingContexts,
                ruleset: ruleset,
                targetDecimals: accountingContext.decimals,
                targetCurrency: accountingContext.currency
            });

        // Get the total number of outstanding project tokens.
        uint256 totalSupply =
            IJBController(address(DIRECTORY.controllerOf(projectId))).totalTokenSupplyWithReservedTokensOf(projectId);

        // Can't redeem more tokens that are in the supply.
        if (redeemCount > totalSupply) revert JBTerminalStore_InsufficientTokens(redeemCount, totalSupply);

        // If the ruleset has a data hook which is enabled for redemptions, use it to derive a claim amount and memo.
        if (ruleset.useDataHookForRedeem() && ruleset.dataHook() != address(0)) {
            // Create the redeem context that'll be sent to the data hook.
            JBBeforeRedeemRecordedContext memory context = JBBeforeRedeemRecordedContext({
                terminal: msg.sender,
                holder: holder,
                projectId: uint56(projectId),
                rulesetId: ruleset.id,
                redeemCount: redeemCount,
                totalSupply: totalSupply,
                surplus: JBTokenAmount({
                    token: accountingContext.token,
                    value: currentSurplus,
                    decimals: accountingContext.decimals,
                    currency: accountingContext.currency
                }),
                useTotalSurplus: ruleset.useTotalSurplusForRedemptions(),
                redemptionRate: ruleset.redemptionRate(),
                metadata: metadata
            });

            (redemptionRate, redeemCount, totalSupply, hookSpecifications) =
                IJBRulesetDataHook(ruleset.dataHook()).beforeRedeemRecordedWith(context);
        } else {
            redemptionRate = ruleset.redemptionRate();
        }

        if (currentSurplus != 0) {
            // Calculate reclaim amount using the current surplus amount.
            reclaimAmount = JBRedemptions.reclaimFrom({
                surplus: currentSurplus,
                tokensRedeemed: redeemCount,
                totalSupply: totalSupply,
                redemptionRate: redemptionRate
            });
        }

        // Keep a reference to the amount that should be added to the project's balance.
        uint256 balanceDiff = reclaimAmount;

        // Ensure that the specifications have valid amounts.
        if (hookSpecifications.length != 0) {
            // Loop through each specification.
            for (uint256 i; i < hookSpecifications.length; i++) {
                // Get a reference to the specification's amount.
                uint256 specificationAmount = hookSpecifications[i].amount;

                // Ensure the amount is non-zero.
                if (specificationAmount != 0) {
                    // Increment the total amount being subtracted from the balance.
                    balanceDiff += specificationAmount;
                }
            }
        }

        // The amount being reclaimed must be within the project's balance.
        if (balanceDiff > balanceOf[msg.sender][projectId][accountingContext.token]) {
            revert JBTerminalStore_InadequateTerminalStoreBalance(
                balanceDiff, balanceOf[msg.sender][projectId][accountingContext.token]
            );
        }

        // Remove the reclaimed funds from the project's balance.
        if (balanceDiff != 0) {
            unchecked {
                balanceOf[msg.sender][projectId][accountingContext.token] =
                    balanceOf[msg.sender][projectId][accountingContext.token] - balanceDiff;
            }
        }
    }

    /// @notice Records the migration of funds from this store.
    /// @param projectId The ID of the project being migrated.
    /// @param token The token being migrated.
    /// @return balance The project's current balance (which is being migrated), as a fixed point number with the same
    /// amount of decimals as its relative terminal.
    function recordTerminalMigration(uint256 projectId, address token) external override returns (uint256 balance) {
        // Get a reference to the project's current ruleset.
        JBRuleset memory ruleset = RULESETS.currentOf(projectId);

        // Terminal migration must be allowed.
        if (!ruleset.allowTerminalMigration()) {
            revert JBTerminalStore_TerminalMigrationNotAllowed();
        }

        // Return the current balance, which is the amount being migrated.
        balance = balanceOf[msg.sender][projectId][token];

        // Set the balance to 0.
        balanceOf[msg.sender][projectId][token] = 0;
    }

    /// @notice Records a use of a project's surplus allowance.
    /// @dev When surplus allowance is "used", it is taken out of the project's surplus within a terminal.
    /// @param projectId The ID of the project to use the surplus allowance of.
    /// @param accountingContext The accounting context of the token whose balances should contribute to the surplus
    /// allowance being reclaimed from.
    /// @param amount The amount to use from the surplus allowance, as a fixed point number.
    /// @param currency The currency of the `amount`. Must match the currency of the surplus allowance.
    /// @return ruleset The ruleset during the surplus allowance is being used during, as a `JBRuleset` struct.
    /// @return usedAmount The amount of terminal tokens used, as a fixed point number with the same amount of decimals
    /// as its relative terminal.
    function recordUsedAllowanceOf(
        uint256 projectId,
        JBAccountingContext calldata accountingContext,
        uint256 amount,
        uint256 currency
    )
        external
        override
        returns (JBRuleset memory ruleset, uint256 usedAmount)
    {
        // Get a reference to the project's current ruleset.
        ruleset = RULESETS.currentOf(projectId);

        // Convert the amount to this store's terminal's token.
        usedAmount = currency == accountingContext.currency
            ? amount
            : mulDiv(
                amount,
                10 ** _MAX_FIXED_POINT_FIDELITY, // Use `_MAX_FIXED_POINT_FIDELITY` to keep as much of the `amount`'s
                    // fidelity as possible when converting.
                PRICES.pricePerUnitOf({
                    projectId: projectId,
                    pricingCurrency: currency,
                    unitCurrency: accountingContext.currency,
                    decimals: _MAX_FIXED_POINT_FIDELITY
                })
            );

        // Set the token being used as the only one to look for surplus within.
        JBAccountingContext[] memory accountingContexts = new JBAccountingContext[](1);
        accountingContexts[0] = accountingContext;

        uint256 surplus = _surplusFrom({
            terminal: msg.sender,
            projectId: projectId,
            accountingContexts: accountingContexts,
            ruleset: ruleset,
            targetDecimals: accountingContext.decimals,
            targetCurrency: accountingContext.currency
        });

        // The amount being used must be available in the surplus.
        if (usedAmount > surplus) revert JBTerminalStore_InadequateTerminalStoreBalance(usedAmount, surplus);

        // Update the project's balance.
        balanceOf[msg.sender][projectId][accountingContext.token] =
            balanceOf[msg.sender][projectId][accountingContext.token] - usedAmount;

        // Get a reference to the new used surplus allowance for this ruleset ID.
        uint256 newUsedSurplusAllowanceOf =
            usedSurplusAllowanceOf[msg.sender][projectId][accountingContext.token][ruleset.id][currency] + amount;

        // Store the incremented value.
        usedSurplusAllowanceOf[msg.sender][projectId][accountingContext.token][ruleset.id][currency] =
            newUsedSurplusAllowanceOf;

        // There must be sufficient surplus allowance available.
        uint256 surplusAllowance = IJBController(address(DIRECTORY.controllerOf(projectId))).FUND_ACCESS_LIMITS()
            .surplusAllowanceOf({
            projectId: projectId,
            rulesetId: ruleset.id,
            terminal: msg.sender,
            token: accountingContext.token,
            currency: currency
        });

        // Make sure the new used amount is within the allowance.
        if (newUsedSurplusAllowanceOf > surplusAllowance || surplusAllowance == 0) {
            revert JBTerminalStore_InadequateControllerAllowance(newUsedSurplusAllowanceOf, surplusAllowance);
        }
    }
}
