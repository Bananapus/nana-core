// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import /* {*} from */ "./helpers/TestBaseWorkflow.sol";

// Launch project, issue token or set the token, mint token, burn token.
contract TestTokenFlow_Local is TestBaseWorkflow {
    IJBController private _controller;
    IJBTokens private _tokens;
    JBRulesetMetadata _metadata;
    IJBTerminal private _terminal;
    uint256 private _projectId;
    address private _projectOwner;
    address private _beneficiary;

    function setUp() public override {
        super.setUp();

        _projectOwner = multisig();
        _beneficiary = beneficiary();
        _controller = jbController();
        _tokens = jbTokens();
        _terminal = jbMultiTerminal();
        _metadata = JBRulesetMetadata({
            reservedPercent: JBConstants.MAX_RESERVED_PERCENT / 2,
            redemptionRate: 0,
            baseCurrency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
            pausePay: false,
            pauseCreditTransfers: false,
            allowOwnerMinting: true,
            allowSetCustomToken: true,
            allowTerminalMigration: false,
            allowSetTerminals: false,
            ownerMustSendPayouts: false,
            allowSetController: false,
            allowAddAccountingContext: true,
            allowAddPriceFeed: false,
            holdFees: false,
            useTotalSurplusForRedemptions: false,
            useDataHookForPay: false,
            useDataHookForRedeem: false,
            dataHook: address(0),
            metadata: 0
        });

        // Package up ruleset configuration.
        JBRulesetConfig[] memory _rulesetConfig = new JBRulesetConfig[](1);
        _rulesetConfig[0].mustStartAtOrAfter = 0;
        _rulesetConfig[0].duration = 0;
        _rulesetConfig[0].weight = 1000 * 10 ** 18;
        _rulesetConfig[0].weightCutPercent = 0;
        _rulesetConfig[0].approvalHook = IJBRulesetApprovalHook(address(0));
        _rulesetConfig[0].metadata = _metadata;
        _rulesetConfig[0].splitGroups = new JBSplitGroup[](0);
        _rulesetConfig[0].fundAccessLimitGroups = new JBFundAccessLimitGroup[](0);

        // Package up terminal configuration.
        JBTerminalConfig[] memory _terminalConfigurations = new JBTerminalConfig[](1);
        JBAccountingContext[] memory _tokensToAccept = new JBAccountingContext[](1);
        _tokensToAccept[0] = JBAccountingContext({
            token: JBConstants.NATIVE_TOKEN,
            decimals: 18,
            currency: uint32(uint160(JBConstants.NATIVE_TOKEN))
        });
        _terminalConfigurations[0] =
            JBTerminalConfig({terminal: _terminal, accountingContextsToAccept: _tokensToAccept});

        _projectId = _controller.launchProjectFor({
            owner: address(_projectOwner),
            projectUri: "myIPFSHash",
            rulesetConfigurations: _rulesetConfig,
            terminalConfigurations: _terminalConfigurations,
            memo: ""
        });
    }

    function testFuzzTokenFlow(uint208 _mintAmount, uint256 _burnAmount, bool _issueToken) public {
        vm.startPrank(_projectOwner);

        if (_issueToken) {
            // Issue an ERC-20 token for project.
            _controller.deployERC20For({projectId: _projectId, name: "TestName", symbol: "TestSymbol", salt: bytes32(0)});
        } else {
            // Create a new `IJBToken` and change it's owner to the `JBTokens` contract.
            IJBToken _newToken = IJBToken(Clones.clone(address(new JBERC20())));
            _newToken.initialize({name: "NewTestName", symbol: "NewTestSymbol", owner: address(_tokens)});

            // Set the projects token to `_newToken`.
            _controller.setTokenFor(_projectId, _newToken);

            // Make sure the project's new `JBToken` is set.
            assertEq(address(_tokens.tokenOf(_projectId)), address(_newToken));
        }

        // Expect revert if there are no tokens being minted.
        if (_mintAmount == 0) vm.expectRevert(JBController.JBController_ZeroTokensToMint.selector);

        // Mint tokens to beneficiary.
        _controller.mintTokensOf({
            projectId: _projectId,
            tokenCount: _mintAmount,
            beneficiary: _beneficiary,
            memo: "Mint memo",
            useReservedPercent: true
        });

        uint256 _expectedTokenBalance = mulDiv(_mintAmount, _metadata.reservedPercent, JBConstants.MAX_RESERVED_PERCENT);

        // Make sure the beneficiary has the correct amount of tokens.
        assertEq(_tokens.totalBalanceOf(_beneficiary, _projectId), _expectedTokenBalance);

        if (_burnAmount == 0) {
            vm.expectRevert(JBController.JBController_ZeroTokensToBurn.selector);
        } else if (_burnAmount > _expectedTokenBalance) {
            vm.expectRevert(
                abi.encodeWithSelector(
                    JBTokens.JBTokens_InsufficientTokensToBurn.selector, _burnAmount, _expectedTokenBalance
                )
            );
        } else {
            _expectedTokenBalance -= _burnAmount;
        }

        // Burn tokens from beneficiary.
        vm.stopPrank();
        vm.prank(_beneficiary);
        _controller.burnTokensOf({
            holder: _beneficiary,
            projectId: _projectId,
            tokenCount: _burnAmount,
            memo: "Burn memo"
        });

        // Make sure the total balance of tokens is updated.
        assertEq(_tokens.totalBalanceOf(_beneficiary, _projectId), _expectedTokenBalance);
    }

    function testMintCreditsAtLimit() public {
        // Pay the project such that the `_beneficiary` receives 1000 project token credits.
        vm.deal(_beneficiary, 1 ether);
        uint256 beneficiaryTokenCount = _terminal.pay{value: 1 ether}({
            projectId: _projectId,
            amount: 1 ether,
            token: JBConstants.NATIVE_TOKEN,
            beneficiary: _beneficiary,
            minReturnedTokens: 0,
            memo: "",
            metadata: new bytes(0)
        });

        // Calls will originate from project.
        vm.startPrank(_projectOwner);

        // Issue an ERC-20 token for project.
        _controller.deployERC20For({projectId: _projectId, name: "TestName", symbol: "TestSymbol", salt: bytes32(0)});

        // Mint claimed tokens to beneficiary: since this is 1,000 over `uint(208)` it will revert.
        vm.expectRevert(
            abi.encodeWithSelector(
                JBTokens.JBTokens_OverflowAlert.selector, type(uint208).max + beneficiaryTokenCount, type(uint208).max
            )
        );

        _controller.mintTokensOf({
            projectId: _projectId,
            tokenCount: type(uint208).max,
            beneficiary: _beneficiary,
            memo: "Mint memo",
            useReservedPercent: false
        });
    }
}
