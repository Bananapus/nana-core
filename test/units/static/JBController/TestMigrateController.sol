// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBControllerSetup} from "./JBControllerSetup.sol";

contract TestMigrateController_Local is JBControllerSetup {
    using stdStorage for StdStorage;

    function setUp() public {
        super.controllerSetup();
    }

    modifier whenCallerHasPermission() {
        // mock ownerOf call
        bytes memory _ownerOfCall = abi.encodeCall(IERC721.ownerOf, (1));
        bytes memory _ownerData = abi.encode(address(this));

        mockExpect(address(projects), _ownerOfCall, _ownerData);
        _;
    }

    modifier migrationIsAllowedByRuleset() {
        JBRulesetMetadata memory _metadata = JBRulesetMetadata({
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
            allowSetController: true,
            allowAddAccountingContext: true,
            allowAddPriceFeed: false,
            holdFees: false,
            useTotalSurplusForCashOuts: true,
            useDataHookForPay: false,
            useDataHookForCashOut: false,
            dataHook: address(0),
            metadata: 0
        });

        uint256 _packedMetadata = JBRulesetMetadataResolver.packRulesetMetadata(_metadata);

        // setup: return data
        JBRuleset memory data = JBRuleset({
            cycleNumber: 1,
            id: uint48(block.timestamp),
            basedOnId: 0,
            start: uint48(block.timestamp),
            duration: 0,
            weight: 0,
            weightCutPercent: 0,
            approvalHook: IJBRulesetApprovalHook(address(0)),
            metadata: _packedMetadata
        });

        // mock currentOf call
        bytes memory _currentOfCall = abi.encodeCall(IJBRulesets.currentOf, (1));
        bytes memory _returned = abi.encode(data);

        mockExpect(address(rulesets), _currentOfCall, _returned);
        _;
    }

    modifier migrationIsNotAllowedByRuleset() {
        JBRulesetMetadata memory _metadata = JBRulesetMetadata({
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
            allowSetController: true,
            allowAddAccountingContext: true,
            allowAddPriceFeed: false,
            holdFees: false,
            useTotalSurplusForCashOuts: true,
            useDataHookForPay: false,
            useDataHookForCashOut: false,
            dataHook: address(0),
            metadata: 0
        });

        uint256 _packedMetadata = JBRulesetMetadataResolver.packRulesetMetadata(_metadata);

        // setup: return data
        JBRuleset memory data = JBRuleset({
            cycleNumber: 1,
            id: uint48(block.timestamp),
            basedOnId: 0,
            start: uint48(block.timestamp),
            duration: 0,
            weight: 0,
            weightCutPercent: 0,
            approvalHook: IJBRulesetApprovalHook(address(0)),
            metadata: _packedMetadata
        });

        // mock currentOf call
        bytes memory _currentOfCall = abi.encodeCall(IJBRulesets.currentOf, (1));
        bytes memory _returned = abi.encode(data);

        mockExpect(address(rulesets), _currentOfCall, _returned);
        _;
    }

    function test_Revert_When_Caller_Is_Not_Directory() external {
        // it should revert

        vm.expectRevert(
            abi.encodeWithSelector(
                JBController.JBController_OnlyDirectory.selector, address(this), _controller.DIRECTORY()
            )
        );
        IJBMigratable(address(_controller)).migrate(1, IJBMigratable(address(this)));
    }

    // Ruleset check happens in JBDirectory now and examples can be found in those units.
    /* function test_Revert_Given_MigrationIsNotAllowedByRuleset()
        external
    {   
        // it should revert
        vm.expectRevert(abi.encodeWithSignature("CONTROLLER_MIGRATION_NOT_ALLOWED()"));

        vm.prank(address(directory));
        IJBMigratable(address(_controller)).migrate(1, IJBMigratable(address(this)));
    } */

    function test_GivenReservedTokenBalanceIsPending() external migrationIsAllowedByRuleset whenCallerHasPermission {
        // it should send reserved tokens to splits
        // set storage since we can't mock internal calls
        stdstore.target(address(IJBMigratable(address(_controller)))).sig("pendingReservedTokenBalanceOf(uint256)")
            .with_key(uint256(1)).checked_write(uint256(100));

        // receive migration call mock
        bytes memory _encodedCall = abi.encodeCall(IJBMigratable.beforeReceiveMigrationFrom, (IERC165(_controller), 1));
        bytes memory _willReturn = "";

        mockExpect(address(this), _encodedCall, _willReturn);

        // mock supports interface call
        mockExpect(
            address(this),
            abi.encodeCall(IERC165.supportsInterface, (type(IJBMigratable).interfaceId)),
            abi.encode(true)
        );

        // mock splitsOf call
        JBSplit[] memory splitsArray = new JBSplit[](1);

        splitsArray[0] = JBSplit({
            preferAddToBalance: false,
            percent: JBConstants.SPLITS_TOTAL_PERCENT / 2,
            projectId: 1,
            beneficiary: payable(address(this)),
            lockedUntil: 0,
            hook: IJBSplitHook(address(0))
        });

        bytes memory _encodedCallSplits = abi.encodeCall(IJBSplits.splitsOf, (1, block.timestamp, 1));
        bytes memory _willReturnSplits = abi.encode(splitsArray);

        mockExpect(address(splits), _encodedCallSplits, _willReturnSplits);

        // mock mint call
        bytes memory _mintCall = abi.encodeCall(IJBTokens.mintFor, (address(this), 1, 50));
        bytes memory _mintReturn = abi.encode(splitsArray);

        mockExpect(address(tokens), _mintCall, _mintReturn);

        // mock tokenOf call
        mockExpect(address(tokens), abi.encodeCall(IJBTokens.tokenOf, (1)), abi.encode(address(0)));

        // event as expected
        vm.expectEmit();
        emit IJBController.SendReservedTokensToSplit(1, block.timestamp, 1, splitsArray[0], 50, address(directory));

        vm.prank(address(directory));
        IJBMigratable(address(_controller)).migrate(1, IJBMigratable(address(this)));
    }

    function test_GivenNoReservedTokenBalanceIsPending() external {
        // it should prepare new controller for migration
        // it should emit MigrateController event

        // receive migration call mock
        bytes memory _encodedCall =
            abi.encodeCall(IJBMigratable.beforeReceiveMigrationFrom, (IERC165(address(_controller)), 1));
        bytes memory _willReturn = "";

        mockExpect(address(this), _encodedCall, _willReturn);

        // mock supports interface call
        mockExpect(
            address(this),
            abi.encodeCall(IERC165.supportsInterface, (type(IJBMigratable).interfaceId)),
            abi.encode(true)
        );

        // event as expected
        vm.expectEmit();
        emit IJBMigratable.Migrate(1, IJBMigratable(address(this)), address(directory));

        vm.prank(address(directory));
        IJBMigratable(address(_controller)).migrate(1, IJBMigratable(address(this)));
    }
}
