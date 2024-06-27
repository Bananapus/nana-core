// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "./helpers/TestBaseWorkflow.sol";

import {ERC20Votes} from "../src/JBERC20.sol";

contract JBERC20Inheritance_Local is JBERC20, TestBaseWorkflow {
    /// This test is to verify that the inheritance order of JBERC20 is correct and that it calls the
    /// `ERC20Votes._update()`
    function test_votesUpdate() public {
        uint256 _max = _maxSupply();
        vm.expectRevert(abi.encodeWithSelector(ERC20Votes.ERC20ExceededSafeSupply.selector, _max + 1, _max));

        _update(address(0), address(100), _max + 1);
    }

    // This test checks that voting power gets accounted for.
    function test_votesUpdateOnTransfer() public {
        JBRulesetMetadata memory _metadata = JBRulesetMetadata({
            reservedRate: 0,
            redemptionRate: 0,
            baseCurrency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
            pausePay: false,
            pauseCreditTransfers: false,
            allowOwnerMinting: true,
            allowSetCustomToken: false,
            allowTerminalMigration: false,
            allowSetTerminals: false,
            ownerMustSendPayouts: false,
            allowSetController: false,
            allowAddAccountingContext: true,
            allowAddPriceFeed: false,
            holdFees: false,
            useTotalSurplusForRedemptions: false,
            useDataHookForPay: true,
            useDataHookForRedeem: true,
            dataHook: address(0),
            metadata: 0
        });
        address _projectOwner = multisig();
        address _recipient = address(200);
        uint256 _amount = 10 ether;

        // Package up ruleset configuration.
        JBRulesetConfig[] memory _rulesetConfig = new JBRulesetConfig[](1);
        _rulesetConfig[0].mustStartAtOrAfter = 0;
        _rulesetConfig[0].duration = 0;
        _rulesetConfig[0].weight = 0;
        _rulesetConfig[0].decayRate = 0;
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
            JBTerminalConfig({terminal: jbMultiTerminal(), accountingContextsToAccept: _tokensToAccept});

        uint256 projectId = jbController().launchProjectFor({
            owner: _projectOwner,
            projectUri: "myIPFSHash",
            rulesetConfigurations: _rulesetConfig,
            terminalConfigurations: _terminalConfigurations,
            memo: ""
        });

        // Configure a token.
        vm.prank(_projectOwner);
        IJBToken _token = jbController().deployERC20For(projectId, "TestToken", "TEST", bytes32(0));

        // Have the user delegate to themselves.
        vm.prank(_recipient);
        ERC20Votes(address(_token)).delegate(_recipient);

        // Mint tokens to the user, check that the balance is correct.
        vm.startPrank(_projectOwner);
        jbController().mintTokensOf(projectId, _amount, _recipient, "", false);
        assertEq(_token.balanceOf(_recipient), _amount);

        // Assert that the user received the voting power as expected.
        assertEq(ERC20Votes(address(_token)).getVotes(_recipient), _amount);
    }
}
