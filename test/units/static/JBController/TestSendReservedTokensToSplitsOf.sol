// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBControllerSetup} from "./JBControllerSetup.sol";

contract TestSendReservedTokensToSplitsOf_Local is JBControllerSetup {
    using stdStorage for StdStorage;
    using JBRulesetMetadataResolver for JBRulesetMetadata;

    uint64 _projectId = 1;
    uint256 _tokenCount = 1e18;
    uint8 _decimals = 18;
    string _memo = "JUICAY";
    address _beneficiary = makeAddr("bene");
    IJBSplitHook _hook = IJBSplitHook(makeAddr("hook"));
    IJBToken _token = IJBToken(makeAddr("token"));

    function setUp() public {
        super.controllerSetup();
        vm.label(_beneficiary, "client");
        vm.label(address(_controller), "controller");
    }

    function test_WhenTheProjectHasNoReservedTokens() external {
        // it will revert NO_RESERVED_TOKENS

        JBRulesetMetadata memory _rulesMetadata = JBRulesetMetadata({
            reservedPercent: JBConstants.MAX_RESERVED_PERCENT / 2,
            cashOutTaxRate: JBConstants.MAX_CASH_OUT_TAX_RATE / 2,
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
            useTotalSurplusForCashOuts: true,
            useDataHookForPay: false,
            useDataHookForCashOut: false,
            dataHook: address(0),
            metadata: 0
        });

        JBFundAccessLimitGroup[] memory _fundAccessLimitGroup = new JBFundAccessLimitGroup[](0);

        // splits
        JBSplitGroup[] memory _splitsGroup = new JBSplitGroup[](0);

        // Package up the ruleset configuration.
        JBRulesetConfig[] memory _rulesetConfigurations = new JBRulesetConfig[](1);
        _rulesetConfigurations[0].mustStartAtOrAfter = 0;
        _rulesetConfigurations[0].duration = 0;
        _rulesetConfigurations[0].weight = 1e18;
        _rulesetConfigurations[0].weightCutPercent = 0;
        _rulesetConfigurations[0].approvalHook = IJBRulesetApprovalHook(address(0));
        _rulesetConfigurations[0].metadata = _rulesMetadata;
        _rulesetConfigurations[0].splitGroups = _splitsGroup;
        _rulesetConfigurations[0].fundAccessLimitGroups = _fundAccessLimitGroup;

        vm.expectRevert(JBController.JBController_NoReservedTokens.selector);
        _controller.sendReservedTokensToSplitsOf(_projectId);
    }

    modifier whenTheProjectHasReservedTokensGtZero() {
        // Set some pending reserved token balance
        stdstore.target(address(_controller)).sig("pendingReservedTokenBalanceOf(uint256)").with_key(_projectId).depth(
            0
        ).checked_write(1e18);

        _;
    }

    function test_GivenAHookIsConfigured() external whenTheProjectHasReservedTokensGtZero {
        // it will mint to hook and call its processSplitWith function

        JBRulesetMetadata memory _rulesMetadata = JBRulesetMetadata({
            reservedPercent: JBConstants.MAX_RESERVED_PERCENT / 2,
            cashOutTaxRate: JBConstants.MAX_CASH_OUT_TAX_RATE / 2,
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
            useTotalSurplusForCashOuts: true,
            useDataHookForPay: false,
            useDataHookForCashOut: false,
            dataHook: address(0),
            metadata: 0
        });

        uint256 _packed = _rulesMetadata.packRulesetMetadata();

        JBFundAccessLimitGroup[] memory _fundAccessLimitGroup = new JBFundAccessLimitGroup[](0);

        // splits
        JBSplitGroup[] memory _splitsGroup = new JBSplitGroup[](1);
        JBSplit[] memory _splits = new JBSplit[](1);

        _splits[0] = JBSplit({
            preferAddToBalance: false,
            percent: JBConstants.SPLITS_TOTAL_PERCENT,
            projectId: _projectId,
            beneficiary: payable(address(0)),
            lockedUntil: 0,
            hook: _hook
        });

        _splitsGroup[0] = JBSplitGroup({groupId: uint32(uint160(JBConstants.NATIVE_TOKEN)), splits: _splits});

        // Package up the ruleset configuration.
        JBRulesetConfig[] memory _rulesetConfigurations = new JBRulesetConfig[](1);
        _rulesetConfigurations[0].mustStartAtOrAfter = 0;
        _rulesetConfigurations[0].duration = 0;
        _rulesetConfigurations[0].weight = 1e18;
        _rulesetConfigurations[0].weightCutPercent = 0;
        _rulesetConfigurations[0].approvalHook = IJBRulesetApprovalHook(address(0));
        _rulesetConfigurations[0].metadata = _rulesMetadata;
        _rulesetConfigurations[0].splitGroups = _splitsGroup;
        _rulesetConfigurations[0].fundAccessLimitGroups = _fundAccessLimitGroup;

        // JBRulesets calldata
        JBRuleset memory _returnedRuleset = JBRuleset({
            cycleNumber: uint48(block.timestamp),
            id: uint48(block.timestamp),
            basedOnId: 0,
            start: uint48(block.timestamp),
            duration: _rulesetConfigurations[0].duration,
            weight: _rulesetConfigurations[0].weight,
            weightCutPercent: _rulesetConfigurations[0].weightCutPercent,
            approvalHook: _rulesetConfigurations[0].approvalHook,
            metadata: _packed
        });

        // mock call to JBRulesets currentOf
        bytes memory _rulesetsCall = abi.encodeCall(IJBRulesets.currentOf, (_projectId));
        bytes memory _rulesetsCallReturn = abi.encode(_returnedRuleset);
        mockExpect(address(rulesets), _rulesetsCall, _rulesetsCallReturn);

        // mock call to JBProjects ownerOf
        bytes memory _projectsCall = abi.encodeCall(IERC721.ownerOf, (_projectId));
        bytes memory _projectsCallReturn = abi.encode(address(this));
        mockExpect(address(projects), _projectsCall, _projectsCallReturn);

        //mock call to JBSplits splitsOf
        bytes memory _splitsCall = abi.encodeCall(IJBSplits.splitsOf, (_projectId, block.timestamp, 1));
        bytes memory _splitsCallReturn = abi.encode(_splits);
        mockExpect(address(splits), _splitsCall, _splitsCallReturn);

        // mock call to JBTokens mintFor
        bytes memory _tokensMintCall =
            abi.encodeCall(IJBTokens.mintFor, (address(_controller), _projectId, _tokenCount));
        mockExpect(address(tokens), _tokensMintCall, abi.encode(_token));

        // Mock send after minting to controller.
        mockExpect(address(_token), abi.encodeCall(IERC20.transfer, (address(_hook), _tokenCount)), abi.encode(true));

        // split hook data
        JBSplitHookContext memory _context = JBSplitHookContext({
            token: address(_token),
            amount: _tokenCount,
            decimals: _decimals,
            projectId: _projectId,
            groupId: 1,
            split: _splits[0]
        });

        // mock call to split hook processSplitWith
        bytes memory _hookCall = abi.encodeCall(IJBSplitHook.processSplitWith, (_context));
        mockExpect(address(_hook), _hookCall, "");

        vm.expectEmit();
        emit IJBController.SendReservedTokensToSplits(
            block.timestamp, block.timestamp, _projectId, address(this), _tokenCount, 0, address(this)
        );
        _controller.sendReservedTokensToSplitsOf(_projectId);
    }

    function test_GivenABeneficiaryIsConfiguredAndProjectIsZero() external whenTheProjectHasReservedTokensGtZero {
        // it will mint for the beneficiary

        JBRulesetMetadata memory _rulesMetadata = JBRulesetMetadata({
            reservedPercent: JBConstants.MAX_RESERVED_PERCENT / 2,
            cashOutTaxRate: JBConstants.MAX_CASH_OUT_TAX_RATE / 2,
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
            useTotalSurplusForCashOuts: true,
            useDataHookForPay: false,
            useDataHookForCashOut: false,
            dataHook: address(0),
            metadata: 0
        });

        uint256 _packed = _rulesMetadata.packRulesetMetadata();

        JBFundAccessLimitGroup[] memory _fundAccessLimitGroup = new JBFundAccessLimitGroup[](0);

        // splits
        JBSplitGroup[] memory _splitsGroup = new JBSplitGroup[](1);
        JBSplit[] memory _splits = new JBSplit[](1);

        _splits[0] = JBSplit({
            preferAddToBalance: false,
            percent: JBConstants.SPLITS_TOTAL_PERCENT,
            projectId: 0,
            beneficiary: payable(_beneficiary),
            lockedUntil: 0,
            hook: IJBSplitHook(address(0))
        });

        _splitsGroup[0] = JBSplitGroup({groupId: uint32(uint160(JBConstants.NATIVE_TOKEN)), splits: _splits});

        // Package up the ruleset configuration.
        JBRulesetConfig[] memory _rulesetConfigurations = new JBRulesetConfig[](1);
        _rulesetConfigurations[0].mustStartAtOrAfter = 0;
        _rulesetConfigurations[0].duration = 0;
        _rulesetConfigurations[0].weight = 1e18;
        _rulesetConfigurations[0].weightCutPercent = 0;
        _rulesetConfigurations[0].approvalHook = IJBRulesetApprovalHook(address(0));
        _rulesetConfigurations[0].metadata = _rulesMetadata;
        _rulesetConfigurations[0].splitGroups = _splitsGroup;
        _rulesetConfigurations[0].fundAccessLimitGroups = _fundAccessLimitGroup;

        // JBRulesets calldata
        JBRuleset memory _returnedRuleset = JBRuleset({
            cycleNumber: uint48(block.timestamp),
            id: uint48(block.timestamp),
            basedOnId: 0,
            start: uint48(block.timestamp),
            duration: _rulesetConfigurations[0].duration,
            weight: _rulesetConfigurations[0].weight,
            weightCutPercent: _rulesetConfigurations[0].weightCutPercent,
            approvalHook: _rulesetConfigurations[0].approvalHook,
            metadata: _packed
        });

        // mock call to JBRulesets currentOf
        bytes memory _rulesetsCall = abi.encodeCall(IJBRulesets.currentOf, (_projectId));
        bytes memory _rulesetsCallReturn = abi.encode(_returnedRuleset);
        mockExpect(address(rulesets), _rulesetsCall, _rulesetsCallReturn);

        // mock call to JBProjects ownerOf
        bytes memory _projectsCall = abi.encodeCall(IERC721.ownerOf, (_projectId));
        bytes memory _projectsCallReturn = abi.encode(address(this));
        mockExpect(address(projects), _projectsCall, _projectsCallReturn);

        //mock call to JBSplits splitsOf
        bytes memory _splitsCall = abi.encodeCall(IJBSplits.splitsOf, (_projectId, block.timestamp, 1));
        bytes memory _splitsCallReturn = abi.encode(_splits);
        mockExpect(address(splits), _splitsCall, _splitsCallReturn);

        // Mock send after minting to controller.
        mockExpect(address(_token), abi.encodeCall(IERC20.transfer, (_beneficiary, _tokenCount)), abi.encode(true));

        // mock call to JBTokens mintFor
        bytes memory _tokensMintCall =
            abi.encodeCall(IJBTokens.mintFor, (address(_controller), _projectId, _tokenCount));
        mockExpect(address(tokens), _tokensMintCall, abi.encode(_token));

        vm.expectEmit();
        emit IJBController.SendReservedTokensToSplit(
            _projectId, block.timestamp, 1, _splits[0], _tokenCount, address(this)
        );
        _controller.sendReservedTokensToSplitsOf(_projectId);
    }

    function test_GivenADeadAddressBeneficiary() external whenTheProjectHasReservedTokensGtZero {
        JBRulesetMetadata memory _rulesMetadata = JBRulesetMetadata({
            reservedPercent: JBConstants.MAX_RESERVED_PERCENT / 2,
            cashOutTaxRate: JBConstants.MAX_CASH_OUT_TAX_RATE / 2,
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
            useTotalSurplusForCashOuts: true,
            useDataHookForPay: false,
            useDataHookForCashOut: false,
            dataHook: address(0),
            metadata: 0
        });

        uint256 _packed = _rulesMetadata.packRulesetMetadata();

        JBFundAccessLimitGroup[] memory _fundAccessLimitGroup = new JBFundAccessLimitGroup[](0);

        // splits
        JBSplitGroup[] memory _splitsGroup = new JBSplitGroup[](1);
        JBSplit[] memory _splits = new JBSplit[](1);

        _splits[0] = JBSplit({
            preferAddToBalance: false,
            percent: JBConstants.SPLITS_TOTAL_PERCENT,
            projectId: 0,
            beneficiary: payable(address(0xdead)),
            lockedUntil: 0,
            hook: IJBSplitHook(address(0))
        });

        _splitsGroup[0] = JBSplitGroup({groupId: uint32(uint160(JBConstants.NATIVE_TOKEN)), splits: _splits});

        // Package up the ruleset configuration.
        JBRulesetConfig[] memory _rulesetConfigurations = new JBRulesetConfig[](1);
        _rulesetConfigurations[0].mustStartAtOrAfter = 0;
        _rulesetConfigurations[0].duration = 0;
        _rulesetConfigurations[0].weight = 1e18;
        _rulesetConfigurations[0].weightCutPercent = 0;
        _rulesetConfigurations[0].approvalHook = IJBRulesetApprovalHook(address(0));
        _rulesetConfigurations[0].metadata = _rulesMetadata;
        _rulesetConfigurations[0].splitGroups = _splitsGroup;
        _rulesetConfigurations[0].fundAccessLimitGroups = _fundAccessLimitGroup;

        // JBRulesets calldata
        JBRuleset memory _returnedRuleset = JBRuleset({
            cycleNumber: uint48(block.timestamp),
            id: uint48(block.timestamp),
            basedOnId: 0,
            start: uint48(block.timestamp),
            duration: _rulesetConfigurations[0].duration,
            weight: _rulesetConfigurations[0].weight,
            weightCutPercent: _rulesetConfigurations[0].weightCutPercent,
            approvalHook: _rulesetConfigurations[0].approvalHook,
            metadata: _packed
        });

        // mock call to JBRulesets currentOf
        bytes memory _rulesetsCall = abi.encodeCall(IJBRulesets.currentOf, (_projectId));
        bytes memory _rulesetsCallReturn = abi.encode(_returnedRuleset);
        mockExpect(address(rulesets), _rulesetsCall, _rulesetsCallReturn);

        // mock call to JBProjects ownerOf
        bytes memory _projectsCall = abi.encodeCall(IERC721.ownerOf, (_projectId));
        bytes memory _projectsCallReturn = abi.encode(address(this));
        mockExpect(address(projects), _projectsCall, _projectsCallReturn);

        //mock call to JBSplits splitsOf
        bytes memory _splitsCall = abi.encodeCall(IJBSplits.splitsOf, (_projectId, block.timestamp, 1));
        bytes memory _splitsCallReturn = abi.encode(_splits);
        mockExpect(address(splits), _splitsCall, _splitsCallReturn);

        // mock call to JBTokens mintFor
        bytes memory _tokensMintCall =
            abi.encodeCall(IJBTokens.mintFor, (address(_controller), _projectId, _tokenCount));
        mockExpect(address(tokens), _tokensMintCall, abi.encode(_token));

        mockExpect(address(tokens), abi.encodeCall(IJBTokens.burnFrom, (address(_controller), 1, _tokenCount)), "");

        vm.expectEmit();
        emit IJBController.SendReservedTokensToSplit(
            _projectId, block.timestamp, 1, _splits[0], _tokenCount, address(this)
        );

        _controller.sendReservedTokensToSplitsOf(_projectId);
    }

    function test_GivenSplitIsPayableToAProjectWhichAcceptsTheToken() external whenTheProjectHasReservedTokensGtZero {
        // it will mint to the project

        JBRulesetMetadata memory _rulesMetadata = JBRulesetMetadata({
            reservedPercent: JBConstants.MAX_RESERVED_PERCENT / 2,
            cashOutTaxRate: JBConstants.MAX_CASH_OUT_TAX_RATE / 2,
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
            useTotalSurplusForCashOuts: true,
            useDataHookForPay: false,
            useDataHookForCashOut: false,
            dataHook: address(0),
            metadata: 0
        });

        uint256 _packed = _rulesMetadata.packRulesetMetadata();

        JBFundAccessLimitGroup[] memory _fundAccessLimitGroup = new JBFundAccessLimitGroup[](0);

        // splits
        JBSplitGroup[] memory _splitsGroup = new JBSplitGroup[](1);
        JBSplit[] memory _splits = new JBSplit[](1);

        _splits[0] = JBSplit({
            preferAddToBalance: false,
            percent: JBConstants.SPLITS_TOTAL_PERCENT,
            projectId: 1, // non-zero to execute rest of the function
            beneficiary: payable(address(0xdead)),
            lockedUntil: 0,
            hook: IJBSplitHook(address(0))
        });

        _splitsGroup[0] = JBSplitGroup({groupId: uint32(uint160(JBConstants.NATIVE_TOKEN)), splits: _splits});

        // Package up the ruleset configuration.
        JBRulesetConfig[] memory _rulesetConfigurations = new JBRulesetConfig[](1);
        _rulesetConfigurations[0].mustStartAtOrAfter = 0;
        _rulesetConfigurations[0].duration = 0;
        _rulesetConfigurations[0].weight = 1e18;
        _rulesetConfigurations[0].weightCutPercent = 0;
        _rulesetConfigurations[0].approvalHook = IJBRulesetApprovalHook(address(0));
        _rulesetConfigurations[0].metadata = _rulesMetadata;
        _rulesetConfigurations[0].splitGroups = _splitsGroup;
        _rulesetConfigurations[0].fundAccessLimitGroups = _fundAccessLimitGroup;

        // JBRulesets calldata
        JBRuleset memory _returnedRuleset = JBRuleset({
            cycleNumber: uint48(block.timestamp),
            id: uint48(block.timestamp),
            basedOnId: 0,
            start: uint48(block.timestamp),
            duration: _rulesetConfigurations[0].duration,
            weight: _rulesetConfigurations[0].weight,
            weightCutPercent: _rulesetConfigurations[0].weightCutPercent,
            approvalHook: _rulesetConfigurations[0].approvalHook,
            metadata: _packed
        });

        // mock call to JBRulesets currentOf
        bytes memory _rulesetsCall = abi.encodeCall(IJBRulesets.currentOf, (_projectId));
        bytes memory _rulesetsCallReturn = abi.encode(_returnedRuleset);
        mockExpect(address(rulesets), _rulesetsCall, _rulesetsCallReturn);

        // mock call to JBProjects ownerOf
        bytes memory _projectsCall = abi.encodeCall(IERC721.ownerOf, (_projectId));
        bytes memory _projectsCallReturn = abi.encode(address(this));
        mockExpect(address(projects), _projectsCall, _projectsCallReturn);

        //mock call to JBSplits splitsOf
        bytes memory _splitsCall = abi.encodeCall(IJBSplits.splitsOf, (_projectId, block.timestamp, 1));
        bytes memory _splitsCallReturn = abi.encode(_splits);
        mockExpect(address(splits), _splitsCall, _splitsCallReturn);

        // mock to JBDirectory primaryTerminalOf
        address terminal = makeAddr("terminal");
        mockExpect(
            address(directory),
            abi.encodeCall(IJBDirectory.primaryTerminalOf, (1, address(_token))),
            abi.encode(terminal)
        );

        // mock to JBTokens mintFor
        mockExpect(
            address(tokens),
            abi.encodeCall(IJBTokens.mintFor, (address(_controller), 1, _tokenCount)),
            abi.encode(address(_token))
        );

        // mock token approval
        mockExpect(address(_token), abi.encodeCall(IERC20.approve, (terminal, 1e18)), "");

        vm.expectEmit();
        emit IJBController.SendReservedTokensToSplit(
            _projectId, block.timestamp, 1, _splits[0], _tokenCount, address(this)
        );
        _controller.sendReservedTokensToSplitsOf(_projectId);
    }

    function test_GivenSplitIsPayableToAProjectWhichAcceptsTheTokenButTokenIsInvalid()
        external
        whenTheProjectHasReservedTokensGtZero
    {
        // it will revert via OZ Address
        JBRulesetMetadata memory _rulesMetadata = JBRulesetMetadata({
            reservedPercent: JBConstants.MAX_RESERVED_PERCENT / 2,
            cashOutTaxRate: JBConstants.MAX_CASH_OUT_TAX_RATE / 2,
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
            useTotalSurplusForCashOuts: true,
            useDataHookForPay: false,
            useDataHookForCashOut: false,
            dataHook: address(0),
            metadata: 0
        });

        uint256 _packed = _rulesMetadata.packRulesetMetadata();

        JBFundAccessLimitGroup[] memory _fundAccessLimitGroup = new JBFundAccessLimitGroup[](0);

        // splits
        JBSplitGroup[] memory _splitsGroup = new JBSplitGroup[](1);
        JBSplit[] memory _splits = new JBSplit[](1);

        _splits[0] = JBSplit({
            preferAddToBalance: false,
            percent: JBConstants.SPLITS_TOTAL_PERCENT,
            projectId: 1, // non-zero to execute rest of the function
            beneficiary: payable(address(0)),
            lockedUntil: 0,
            hook: IJBSplitHook(address(0))
        });

        _splitsGroup[0] = JBSplitGroup({groupId: uint32(uint160(JBConstants.NATIVE_TOKEN)), splits: _splits});

        // Package up the ruleset configuration.
        JBRulesetConfig[] memory _rulesetConfigurations = new JBRulesetConfig[](1);
        _rulesetConfigurations[0].mustStartAtOrAfter = 0;
        _rulesetConfigurations[0].duration = 0;
        _rulesetConfigurations[0].weight = 1e18;
        _rulesetConfigurations[0].weightCutPercent = 0;
        _rulesetConfigurations[0].approvalHook = IJBRulesetApprovalHook(address(0));
        _rulesetConfigurations[0].metadata = _rulesMetadata;
        _rulesetConfigurations[0].splitGroups = _splitsGroup;
        _rulesetConfigurations[0].fundAccessLimitGroups = _fundAccessLimitGroup;

        // JBRulesets calldata
        JBRuleset memory _returnedRuleset = JBRuleset({
            cycleNumber: uint48(block.timestamp),
            id: uint48(block.timestamp),
            basedOnId: 0,
            start: uint48(block.timestamp),
            duration: _rulesetConfigurations[0].duration,
            weight: _rulesetConfigurations[0].weight,
            weightCutPercent: _rulesetConfigurations[0].weightCutPercent,
            approvalHook: _rulesetConfigurations[0].approvalHook,
            metadata: _packed
        });

        // mock call to JBRulesets currentOf
        bytes memory _rulesetsCall = abi.encodeCall(IJBRulesets.currentOf, (_projectId));
        bytes memory _rulesetsCallReturn = abi.encode(_returnedRuleset);
        mockExpect(address(rulesets), _rulesetsCall, _rulesetsCallReturn);

        // mock call to JBProjects ownerOf
        bytes memory _projectsCall = abi.encodeCall(IERC721.ownerOf, (_projectId));
        bytes memory _projectsCallReturn = abi.encode(address(this));
        mockExpect(address(projects), _projectsCall, _projectsCallReturn);

        //mock call to JBSplits splitsOf
        bytes memory _splitsCall = abi.encodeCall(IJBSplits.splitsOf, (_projectId, block.timestamp, 1));
        bytes memory _splitsCallReturn = abi.encode(_splits);
        mockExpect(address(splits), _splitsCall, _splitsCallReturn);

        // mock to JBDirectory primaryTerminalOf
        address terminal = makeAddr("terminal");
        mockExpect(
            address(directory),
            abi.encodeCall(IJBDirectory.primaryTerminalOf, (1, address(_token))),
            abi.encode(terminal)
        );

        // mock to JBTokens mintFor
        mockExpect(
            address(tokens),
            abi.encodeCall(IJBTokens.mintFor, (address(_controller), 1, _tokenCount)),
            abi.encode(address(_token))
        );

        vm.expectRevert(abi.encodeWithSignature(("SafeERC20FailedOperation(address)"), address(_token)));
        _controller.sendReservedTokensToSplitsOf(_projectId);
    }
}
