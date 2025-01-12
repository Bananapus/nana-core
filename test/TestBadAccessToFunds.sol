// SPDX-License-Identifier: MIT
pragma solidity >=0.8.6;

import /* {*} from */ "./helpers/TestBaseWorkflow.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract TestBadAccessToFunds_Local is TestBaseWorkflow {
    uint256 private constant _FEE_PROJECT_ID = 1;
    uint8 private constant _WEIGHT_DECIMALS = 18; // FIXED
    uint8 private constant _NATIVE_DECIMALS = 18; // FIXED
    uint8 private constant _PRICE_FEED_DECIMALS = 10;
    uint256 private constant _USD_PRICE_PER_NATIVE = 2000 * 10 ** _PRICE_FEED_DECIMALS; // 2000 USDC == 1 native token

    IJBController private _controller;
    IJBPrices private _prices;
    IJBMultiTerminal private _terminal;
    IJBTokens private _tokens;
    address private _projectOwner;
    address private _beneficiary;
    MockERC20 private _usdcToken;
    uint256 private _projectId;
    address private _user = makeAddr("user");

    uint224 private _nativeCurrencySurplusAllowance;
    uint224 private _nativeCurrencyPayoutLimit;
    uint224 private _usdCurrencySurplusAllowance;
    uint224 private _usdCurrencyPayoutLimit;

    uint112 private _weight;
    JBRulesetMetadata private _metadata;

    function setUp() public override {
        super.setUp();

        _projectId = 1; // Fee projectId
        _projectOwner = multisig();
        _beneficiary = beneficiary();
        _usdcToken = usdcToken();
        _tokens = jbTokens();
        _controller = jbController();
        _prices = jbPrices();
        _terminal = jbMultiTerminal();
        _weight = uint112(1000 * 10 ** _WEIGHT_DECIMALS);

        _metadata = JBRulesetMetadata({
            reservedPercent: JBConstants.MAX_RESERVED_PERCENT / 2, //50%
            cashOutTaxRate: JBConstants.MAX_CASH_OUT_TAX_RATE / 2, //50%
            baseCurrency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
            pausePay: false,
            pauseCreditTransfers: false,
            allowOwnerMinting: false,
            allowSetCustomToken: false,
            allowTerminalMigration: false,
            allowSetTerminals: false,
            ownerMustSendPayouts: false,
            allowSetController: false,
            allowAddAccountingContext: true,
            allowAddPriceFeed: true,
            holdFees: false,
            useTotalSurplusForCashOuts: true,
            useDataHookForPay: false,
            useDataHookForCashOut: false,
            dataHook: address(0),
            metadata: 0
        });

        _nativeCurrencySurplusAllowance = type(uint224).max; // Allows self minting tokens forever
        _nativeCurrencyPayoutLimit = 0;

        // Package up the limits for the given terminal.
        JBFundAccessLimitGroup[] memory _fundAccessLimitGroup = new JBFundAccessLimitGroup[](1);

        // Specify payout limits.
        JBCurrencyAmount[] memory _payoutLimits = new JBCurrencyAmount[](1);
        _payoutLimits[0] =
            JBCurrencyAmount({amount: _nativeCurrencyPayoutLimit, currency: uint32(uint160(JBConstants.NATIVE_TOKEN))});

        // Specify surplus allowances.
        JBCurrencyAmount[] memory _surplusAllowances = new JBCurrencyAmount[](1);
        _surplusAllowances[0] = JBCurrencyAmount({
            amount: _nativeCurrencySurplusAllowance,
            currency: uint32(uint160(JBConstants.NATIVE_TOKEN))
        });

        _fundAccessLimitGroup[0] = JBFundAccessLimitGroup({
            terminal: address(_terminal),
            token: JBConstants.NATIVE_TOKEN,
            payoutLimits: _payoutLimits,
            surplusAllowances: _surplusAllowances
        });

        // Package up the ruleset configuration.
        JBRulesetConfig[] memory _rulesetConfigurations = new JBRulesetConfig[](1);
        _rulesetConfigurations[0].mustStartAtOrAfter = 0;
        _rulesetConfigurations[0].duration = 0;
        _rulesetConfigurations[0].weight = _weight;
        _rulesetConfigurations[0].weightCutPercent = 0;
        _rulesetConfigurations[0].approvalHook = IJBRulesetApprovalHook(address(0));
        _rulesetConfigurations[0].metadata = _metadata;
        _rulesetConfigurations[0].splitGroups = new JBSplitGroup[](0);
        _rulesetConfigurations[0].fundAccessLimitGroups = _fundAccessLimitGroup;

        JBTerminalConfig[] memory _terminalConfigurations = new JBTerminalConfig[](1);
        JBAccountingContext[] memory _tokensToAccept = new JBAccountingContext[](1);
        _tokensToAccept[0] = JBAccountingContext({
            token: JBConstants.NATIVE_TOKEN,
            decimals: 18,
            currency: uint32(uint160(JBConstants.NATIVE_TOKEN))
        });
        _terminalConfigurations[0] =
            JBTerminalConfig({terminal: _terminal, accountingContextsToAccept: _tokensToAccept});

        // Create the platform project
        _controller.launchProjectFor({
            owner: _projectOwner, // Random.
            projectUri: "whatever",
            rulesetConfigurations: _rulesetConfigurations, // Use the same ruleset configurations.
            terminalConfigurations: _terminalConfigurations, // Set terminals to receive fees.
            memo: ""
        });
    }

    function test_PlatformProjectSelfMintOnAllowanceUsage() external {
        // should not be feeless
        // same terminal config so no second term
        // _nativeCurrencySurplusAllowance is configured as uint224.max in setup
        uint256 _nativePayAmount = 1000 ether;
        uint256 _usdcPayAmount = 10_000e6; // 10_000
        address payable _stash = payable(makeAddr("stash"));

        // Give some user funds to pay in
        vm.deal(_user, _nativePayAmount);
        deal(address(_usdcToken), _user, _usdcPayAmount);

        // Pay in
        vm.prank(_user);
        uint256 userBalance = _terminal.pay{value: _nativePayAmount}(
            _projectId, JBConstants.NATIVE_TOKEN, _nativePayAmount, _user, 0, "", ""
        );

        // User now holds the total supply of tokens
        uint256 ogTotalSupply = _tokens.totalSupplyOf(_projectId);
        assertEq(userBalance, ogTotalSupply);

        // Project owner calls to use the allowance.
        vm.prank(_projectOwner);
        _terminal.useAllowanceOf(
            _projectId,
            JBConstants.NATIVE_TOKEN,
            _nativePayAmount,
            uint32(uint160(JBConstants.NATIVE_TOKEN)),
            0,
            payable(_stash),
            payable(_beneficiary),
            ""
        );

        // Nothinge is lost balance-wise.
        assertEq((address(_terminal).balance + _stash.balance), _nativePayAmount);

        // get token/credit balances
        uint256 totalTokenBalance =
            _tokens.totalBalanceOf(_beneficiary, _projectId) + _tokens.totalBalanceOf(_user, _projectId);

        // Total supply and platform token balances have increased.
        assertGt(totalTokenBalance, ogTotalSupply);
        assertGt(_tokens.totalSupplyOf(_projectId), ogTotalSupply); // supply now higher than after original payment
        assertEq(totalTokenBalance, _tokens.totalSupplyOf(_projectId));

        // Platform project should have the fee amount that was "paid" (but really, *refunded* to platform project) as a
        // result of using allowance.
        // that is only a small amount, but the key is that the feeBeneficiary has received platform project tokens.
        uint256 platformProjectBalance =
            jbTerminalStore().balanceOf(address(_terminal), _projectId, JBConstants.NATIVE_TOKEN);
        assertEq(_nativePayAmount - _stash.balance, platformProjectBalance);

        // Rinse and repeat since a high surplus allowance value is set.
        uint256 stashBalanceNow = _stash.balance;
        vm.prank(_stash);
        _terminal.pay{value: stashBalanceNow}(_projectId, JBConstants.NATIVE_TOKEN, _nativePayAmount, _user, 0, "", "");

        // use the allowance again, continuing to mint tokens.
        vm.prank(_projectOwner);
        _terminal.useAllowanceOf(
            _projectId,
            JBConstants.NATIVE_TOKEN,
            stashBalanceNow,
            uint32(uint160(JBConstants.NATIVE_TOKEN)),
            0,
            payable(_beneficiary),
            _stash,
            ""
        );
    }
}
