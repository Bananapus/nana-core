// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import /* {*} from */ "./helpers/TestBaseWorkflow.sol";

// Projects can be launched.
contract TestLaunchProject_Local is TestBaseWorkflow {
    IJBController private _controller;
    JBRulesetMetadata private _metadata;
    IJBTerminal private _terminal;
    IJBRulesets private _rulesets;

    address private _projectOwner;

    function setUp() public override {
        super.setUp();

        _projectOwner = multisig();
        _terminal = jbMultiTerminal();
        _controller = jbController();
        _rulesets = jbRulesets();

        _metadata = JBRulesetMetadata({
            reservedPercent: 0,
            cashOutTaxRate: 0,
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
            allowAddPriceFeed: false,
            holdFees: false,
            useTotalSurplusForCashOuts: false,
            useDataHookForPay: false,
            useDataHookForCashOut: false,
            dataHook: address(0),
            metadata: 0
        });
    }

    function equals(JBRuleset memory queued, JBRuleset memory stored) internal pure returns (bool) {
        // Just compare the output of hashing all fields packed.
        return (
            keccak256(
                abi.encodePacked(
                    queued.cycleNumber,
                    queued.id,
                    queued.basedOnId,
                    queued.start,
                    queued.duration,
                    queued.weight,
                    queued.weightCutPercent,
                    queued.approvalHook,
                    queued.metadata
                )
            )
                == keccak256(
                    abi.encodePacked(
                        stored.cycleNumber,
                        stored.id,
                        stored.basedOnId,
                        stored.start,
                        stored.duration,
                        stored.weight,
                        stored.weightCutPercent,
                        stored.approvalHook,
                        stored.metadata
                    )
                )
        );
    }

    function testLaunchProject() public {
        // Package up ruleset configuration.
        JBRulesetConfig[] memory _rulesetConfig = new JBRulesetConfig[](1);
        _rulesetConfig[0].mustStartAtOrAfter = 0;
        _rulesetConfig[0].duration = 0;
        _rulesetConfig[0].weight = 0;
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

        uint256 projectId = _controller.launchProjectFor({
            owner: _projectOwner,
            projectUri: "myIPFSHash",
            rulesetConfigurations: _rulesetConfig,
            terminalConfigurations: _terminalConfigurations,
            memo: ""
        });

        // Get a reference to the first ruleset.
        JBRuleset memory ruleset = _rulesets.currentOf(projectId);

        // Reference queued attributes for sake of comparison.
        JBRuleset memory queued = JBRuleset({
            cycleNumber: 1,
            id: uint48(block.timestamp),
            basedOnId: 0,
            start: uint48(block.timestamp),
            duration: 0,
            weight: 0,
            weightCutPercent: 0,
            approvalHook: IJBRulesetApprovalHook(address(0)),
            metadata: ruleset.metadata
        });

        bool same = equals(queued, ruleset);

        assertEq(same, true);
    }

    function testLaunchProjectFuzzWeight(uint112 _weight) public {
        uint256 _projectId;

        // Package up ruleset configuration.
        JBRulesetConfig[] memory _rulesetConfig = new JBRulesetConfig[](1);
        _rulesetConfig[0].mustStartAtOrAfter = 0;
        _rulesetConfig[0].duration = 14;
        _rulesetConfig[0].weight = _weight;
        _rulesetConfig[0].weightCutPercent = 450_000_000;
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
            owner: _projectOwner,
            projectUri: "myIPFSHash",
            rulesetConfigurations: _rulesetConfig,
            terminalConfigurations: _terminalConfigurations,
            memo: ""
        });

        JBRuleset memory ruleset = _rulesets.currentOf(_projectId);

        // Reference queued attributes for sake of comparison.
        JBRuleset memory queued = JBRuleset({
            cycleNumber: 1,
            id: uint48(block.timestamp),
            basedOnId: 0,
            start: uint48(block.timestamp),
            duration: _rulesetConfig[0].duration,
            weight: _weight,
            weightCutPercent: _rulesetConfig[0].weightCutPercent,
            approvalHook: _rulesetConfig[0].approvalHook,
            metadata: ruleset.metadata
        });

        bool same = equals(queued, ruleset);

        assertEq(same, true);
    }
}
