// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBControllerSetup} from "./JBControllerSetup.sol";

contract TestLaunchProjectFor_Local is JBControllerSetup {
    using JBRulesetMetadataResolver for JBRulesetMetadata;

    address payable _splitsBeneficiary = payable(makeAddr("someone"));
    string _metadata = "JUICAY_DATA";
    string _memo = "JUICAY_MEMO";

    function setUp() public {
        super.controllerSetup();
    }

    modifier whenCalledDefault() {
        // we must mock calls to Projects, Directory, Rulesets, possibly Splits, and possibly a second call to directory

        bytes memory projectsCall = abi.encodeCall(IJBProjects.createFor, (address(this)));
        bytes memory projectsReturn = abi.encode(1);
        mockExpect(address(projects), projectsCall, projectsReturn);

        bytes memory setControllerCall =
            abi.encodeCall(IJBDirectory.setControllerOf, (1, IERC165(address(_controller))));
        bytes memory setControllerReturn = "";
        mockExpect(address(directory), setControllerCall, setControllerReturn);
        _;
    }

    function test_GivenMetadataIsProvided() external whenCalledDefault {
        // it will set metadata

        JBRulesetConfig[] memory _rulesets = new JBRulesetConfig[](0);
        JBTerminalConfig[] memory _terminals = new JBTerminalConfig[](0);

        vm.expectEmit();
        emit IJBController.LaunchProject(0, 1, _metadata, "", address(this));

        _controller.launchProjectFor(address(this), _metadata, _rulesets, _terminals, "");
    }

    function test_GivenRulesetHasInvalidReservedPercent() external whenCalledDefault {
        // it will revert INVALID_RESERVED_PERCENT()

        JBRulesetMetadata memory _rulesMetadata = JBRulesetMetadata({
            reservedPercent: JBConstants.MAX_RESERVED_PERCENT + 1, // invalid
            redemptionRate: JBConstants.MAX_REDEMPTION_RATE / 2, //50%
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
            useTotalSurplusForRedemptions: true,
            useDataHookForPay: false,
            useDataHookForRedeem: false,
            dataHook: address(0),
            metadata: 0
        });

        JBFundAccessLimitGroup[] memory _fundAccessLimitGroup = new JBFundAccessLimitGroup[](0);
        JBTerminalConfig[] memory _terminals = new JBTerminalConfig[](0);

        // Package up the ruleset configuration.
        JBRulesetConfig[] memory _rulesetConfigurations = new JBRulesetConfig[](1);
        _rulesetConfigurations[0].mustStartAtOrAfter = 0;
        _rulesetConfigurations[0].duration = 0;
        _rulesetConfigurations[0].weight = 1e18;
        _rulesetConfigurations[0].decayPercent = 0;
        _rulesetConfigurations[0].approvalHook = IJBRulesetApprovalHook(address(0));
        _rulesetConfigurations[0].metadata = _rulesMetadata;
        _rulesetConfigurations[0].splitGroups = new JBSplitGroup[](0);
        _rulesetConfigurations[0].fundAccessLimitGroups = _fundAccessLimitGroup;

        vm.expectRevert(JBController.JBController_InvalidReservedPercent.selector);
        _controller.launchProjectFor(address(this), _metadata, _rulesetConfigurations, _terminals, _memo);
    }

    function test_GivenRulesetHasInvalidRedemptionRate() external whenCalledDefault {
        // it will revert INVALID_REDEMPTION_RATE()

        JBRulesetMetadata memory _rulesMetadata = JBRulesetMetadata({
            reservedPercent: JBConstants.MAX_RESERVED_PERCENT / 2,
            redemptionRate: JBConstants.MAX_REDEMPTION_RATE + 1, // invalid
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
            useTotalSurplusForRedemptions: true,
            useDataHookForPay: false,
            useDataHookForRedeem: false,
            dataHook: address(0),
            metadata: 0
        });

        JBFundAccessLimitGroup[] memory _fundAccessLimitGroup = new JBFundAccessLimitGroup[](0);
        JBTerminalConfig[] memory _terminals = new JBTerminalConfig[](0);

        // Package up the ruleset configuration.
        JBRulesetConfig[] memory _rulesetConfigurations = new JBRulesetConfig[](1);
        _rulesetConfigurations[0].mustStartAtOrAfter = 0;
        _rulesetConfigurations[0].duration = 0;
        _rulesetConfigurations[0].weight = 1e18;
        _rulesetConfigurations[0].decayPercent = 0;
        _rulesetConfigurations[0].approvalHook = IJBRulesetApprovalHook(address(0));
        _rulesetConfigurations[0].metadata = _rulesMetadata;
        _rulesetConfigurations[0].splitGroups = new JBSplitGroup[](0);
        _rulesetConfigurations[0].fundAccessLimitGroups = _fundAccessLimitGroup;

        vm.expectRevert(JBController.JBController_InvalidRedemptionRate.selector);
        _controller.launchProjectFor(address(this), _metadata, _rulesetConfigurations, _terminals, _memo);
    }

    function test_GivenSplitsRulesetsAndFundAccessConstraintsAreConfigured() external whenCalledDefault {
        // it will set split groups, ruleset, fundAccessConstraints

        JBRulesetMetadata memory _rulesMetadata = JBRulesetMetadata({
            reservedPercent: JBConstants.MAX_RESERVED_PERCENT / 2,
            redemptionRate: JBConstants.MAX_REDEMPTION_RATE / 2,
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
            useTotalSurplusForRedemptions: true,
            useDataHookForPay: false,
            useDataHookForRedeem: false,
            dataHook: address(0),
            metadata: 0
        });

        uint256 _packed = _rulesMetadata.packRulesetMetadata();

        JBFundAccessLimitGroup[] memory _fundAccessLimitGroup = new JBFundAccessLimitGroup[](0);
        JBTerminalConfig[] memory _terminals = new JBTerminalConfig[](0);

        // splits
        JBSplitGroup[] memory _splitsGroup = new JBSplitGroup[](1);
        JBSplit[] memory _splits = new JBSplit[](1);

        _splits[0] = JBSplit({
            preferAddToBalance: false,
            percent: JBConstants.SPLITS_TOTAL_PERCENT,
            projectId: 1,
            beneficiary: _splitsBeneficiary,
            lockedUntil: 0,
            hook: IJBSplitHook(address(0))
        });

        _splitsGroup[0] = JBSplitGroup({groupId: uint32(uint160(JBConstants.NATIVE_TOKEN)), splits: _splits});

        // Package up the ruleset configuration.
        JBRulesetConfig[] memory _rulesetConfigurations = new JBRulesetConfig[](1);
        _rulesetConfigurations[0].mustStartAtOrAfter = 0;
        _rulesetConfigurations[0].duration = 0;
        _rulesetConfigurations[0].weight = 1e18;
        _rulesetConfigurations[0].decayPercent = 0;
        _rulesetConfigurations[0].approvalHook = IJBRulesetApprovalHook(address(0));
        _rulesetConfigurations[0].metadata = _rulesMetadata;
        _rulesetConfigurations[0].splitGroups = _splitsGroup;
        _rulesetConfigurations[0].fundAccessLimitGroups = _fundAccessLimitGroup;

        // JBRulesets calldata
        JBRuleset memory returnedRuleset = JBRuleset({
            cycleNumber: uint48(block.timestamp),
            id: uint48(block.timestamp),
            basedOnId: 0,
            start: uint48(block.timestamp),
            duration: _rulesetConfigurations[0].duration,
            weight: _rulesetConfigurations[0].weight,
            decayPercent: _rulesetConfigurations[0].decayPercent,
            approvalHook: _rulesetConfigurations[0].approvalHook,
            metadata: _packed
        });
        bytes memory rulesetsCall = abi.encodeCall(
            IJBRulesets.queueFor,
            (
                1,
                _rulesetConfigurations[0].duration,
                _rulesetConfigurations[0].weight,
                _rulesetConfigurations[0].decayPercent,
                _rulesetConfigurations[0].approvalHook,
                _packed,
                _rulesetConfigurations[0].mustStartAtOrAfter
            )
        );
        bytes memory rulesetsReturned = abi.encode(returnedRuleset);

        // JBRulesets call
        mockExpect(address(rulesets), rulesetsCall, rulesetsReturned);

        // JBSplits call
        bytes memory splitsCall = abi.encodeCall(IJBSplits.setSplitGroupsOf, (1, block.timestamp, _splitsGroup));
        bytes memory splitsReturned = "";
        mockExpect(address(splits), splitsCall, splitsReturned);

        // JBFundAccess call
        bytes memory fundsCall =
            abi.encodeCall(IJBFundAccessLimits.setFundAccessLimitsFor, (1, block.timestamp, _fundAccessLimitGroup));
        bytes memory fundsReturned = "";
        mockExpect(address(fundAccessLimits), fundsCall, fundsReturned);

        _controller.launchProjectFor(address(this), _metadata, _rulesetConfigurations, _terminals, _memo);
    }

    function test_GivenTerminalsAreProvided() external whenCalledDefault {
        // it will set terminals
        IJBTerminal _terminal = IJBTerminal(makeAddr("terminal"));
        address _token = makeAddr("token");

        JBRulesetConfig[] memory _rulesets = new JBRulesetConfig[](0);
        JBTerminalConfig[] memory _terminals = new JBTerminalConfig[](1);
        JBAccountingContext[] memory _tokensToAccept = new JBAccountingContext[](1);
        _tokensToAccept[0] = JBAccountingContext({
            token: JBConstants.NATIVE_TOKEN,
            decimals: 18,
            currency: uint32(uint160(JBConstants.NATIVE_TOKEN))
        });

        _terminals[0] = JBTerminalConfig({terminal: _terminal, accountingContextsToAccept: _tokensToAccept});

        // mock call return data
        JBAccountingContext memory _returnedContext =
            JBAccountingContext({token: _token, decimals: 18, currency: uint32(uint160(JBConstants.NATIVE_TOKEN))});

        // mock call to the terminal addAccountingContextsFor()
        bytes memory addCall = abi.encodeCall(IJBTerminal.addAccountingContextsFor, (1, _tokensToAccept));
        bytes memory addReturned = abi.encode(_returnedContext);

        mockExpect(address(_terminal), addCall, addReturned);

        vm.expectEmit();
        emit IJBController.LaunchProject(0, 1, _metadata, _memo, address(this));

        _controller.launchProjectFor(address(this), _metadata, _rulesets, _terminals, _memo);
    }

    function test_GivenMemoIsProvided() external whenCalledDefault {
        // it will be included in the emit

        JBRulesetConfig[] memory _rulesets = new JBRulesetConfig[](0);
        JBTerminalConfig[] memory _terminals = new JBTerminalConfig[](0);

        vm.expectEmit();
        emit IJBController.LaunchProject(0, 1, _metadata, _memo, address(this));

        _controller.launchProjectFor(address(this), _metadata, _rulesets, _terminals, _memo);
    }
}
