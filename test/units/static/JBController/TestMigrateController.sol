// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBControllerSetup} from "./JBControllerSetup.sol";

contract TestMigrateController_Local is JBTest, JBControllerSetup {
    using stdStorage for StdStorage;

    function setUp() public {
        super.controllerSetup();
    }

    modifier whenCallerHas_MIGRATE_CONTROLLER_Permission() {
        // mock ownerOf call
        bytes memory _ownerOfCall = abi.encodeCall(IERC721.ownerOf, (1));
        bytes memory _ownerData = abi.encode(address(this));

        mockExpect(address(projects), _ownerOfCall, _ownerData);
        _;
    }

    modifier migrationIsAllowedByRuleset() {
        JBRulesetMetadata memory _metadata = JBRulesetMetadata({
            reservedRate: JBConstants.MAX_RESERVED_RATE / 2, //50%
            redemptionRate: JBConstants.MAX_REDEMPTION_RATE / 2, //50%
            baseCurrency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
            pausePay: false,
            pauseCreditTransfers: false,
            allowOwnerMinting: false,
            allowTerminalMigration: false,
            allowSetTerminals: false,
            allowControllerMigration: true,
            allowSetController: false,
            holdFees: false,
            useTotalSurplusForRedemptions: true,
            useDataHookForPay: false,
            useDataHookForRedeem: false,
            dataHook: address(0),
            metadata: 0
        });

        uint256 _packedMetadata = JBRulesetMetadataResolver.packRulesetMetadata(_metadata);

        // setup: return data
        JBRuleset memory data = JBRuleset({
            cycleNumber: 1,
            id: block.timestamp,
            basedOnId: 0,
            start: block.timestamp,
            duration: 0,
            weight: 0,
            decayRate: 0,
            approvalHook: IJBRulesetApprovalHook(address(0)),
            metadata: _packedMetadata
        });

        // mock currentOf call
        bytes memory _currentOfCall = abi.encodeCall(IJBRulesets.currentOf, (1));
        bytes memory _returned = abi.encode(data);

        mockExpect(address(rulesets), _currentOfCall, _returned);
        _;
    }

    /* function test_Revert_When_CallerDoesNotHave_MIGRATE_CONTROLLER_Permission() external {
        // it should revert
    }

    function test_Revert_Given_MigrationIsNotAllowedByRuleset() external whenCallerHas_MIGRATE_CONTROLLER_Permission {
        // it should revert
    } */

    function test_GivenReservedTokenBalanceIsPending()
        external
        whenCallerHas_MIGRATE_CONTROLLER_Permission
        migrationIsAllowedByRuleset
    {
        // it should send reserved tokens to splits
        // set storage since we can't mock internal calls
        stdstore.target(address(_controller)).sig("pendingReservedTokenBalanceOf(uint256)").with_key(uint256(1))
            .checked_write(uint256(100));

        // receive migration call mock
        bytes memory _encodedCall =
            abi.encodeCall(IJBMigratable.receiveMigrationFrom, (IERC165(address(_controller)), 1));
        bytes memory _willReturn = abi.encode();

        mockExpect(address(this), _encodedCall, _willReturn);

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

        // event as expected
        vm.expectEmit();
        emit IJBController.SendReservedTokensToSplit(1, block.timestamp, 1, splitsArray[0], 50, address(this));

        _controller.migrateController(1, IJBMigratable(address(this)));
    }

    /* function test_GivenNoReservedTokenBalanceIsPending()
        external
        whenCallerHas_MIGRATE_CONTROLLER_Permission
        migrationIsAllowedByRuleset
    {
        // it should prepare new controller for migration
        // it should emit MigrateController event
    } */
}
