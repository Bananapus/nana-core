// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBMultiTerminalSetup} from "./JBMultiTerminalSetup.sol";

contract TestSendPayoutsOf_Local is JBMultiTerminalSetup {
    uint256 _projectId = 1;
    uint256 _defaultAmount = 1e18;

    function setUp() public {
        super.multiTerminalSetup();
    }

    function test_WhenAmountPaidOutLtMinTokensPaidOut() external {
        // it will revert UNDER_MIN_TOKENS_PAID_OUT

        // needed for terminal store mock call
        JBRuleset memory returnedRuleset = JBRuleset({
            cycleNumber: 1,
            id: 1,
            basedOnId: 0,
            start: 0,
            duration: 0,
            weight: 0,
            decayPercent: 0,
            approvalHook: IJBRulesetApprovalHook(address(0)),
            metadata: 0
        });

        JBAccountingContext memory mockTokenContext = JBAccountingContext({token: address(0), decimals: 0, currency: 0});

        // record payout mock call
        mockExpect(
            address(store),
            abi.encodeCall(IJBTerminalStore.recordPayoutFor, (_projectId, mockTokenContext, 0, 0)),
            abi.encode(returnedRuleset, 0)
        );

        // projects owner of
        mockExpect(address(projects), abi.encodeCall(IERC721.ownerOf, (_projectId)), abi.encode(address(this)));

        // needed for splits return call
        JBSplit[] memory returnedSplits = new JBSplit[](0);

        // mock splits of call
        mockExpect(
            address(splits),
            abi.encodeCall(IJBSplits.splitsOf, (_projectId, returnedRuleset.id, 0)),
            abi.encode(returnedSplits)
        );

        // mock directory call for fee processing
        mockExpect(
            address(directory),
            abi.encodeCall(IJBDirectory.primaryTerminalOf, (1, address(0))),
            abi.encode(address(_terminal))
        );

        vm.expectRevert(abi.encodeWithSelector(JBMultiTerminal.JBMultiTerminal_UnderMinTokensPaidOut.selector, 0, 1));
        _terminal.sendPayoutsOf(_projectId, address(0), 0, 0, 1);
    }

    function test_WhenOwnerMustSendPayoutsButCallerDNEQOwner() external {
        // it will check permissions

        // needed for terminal store mock call
        JBRuleset memory returnedRuleset = generateUnfriendlyRuleset();

        JBAccountingContext memory mockTokenContext = JBAccountingContext({token: address(0), decimals: 0, currency: 0});

        // record payout mock call
        mockExpect(
            address(store),
            abi.encodeCall(IJBTerminalStore.recordPayoutFor, (_projectId, mockTokenContext, 0, 0)),
            abi.encode(returnedRuleset, 0)
        );

        address owner = makeAddr("owner");

        // projects owner of
        mockExpect(address(projects), abi.encodeCall(IERC721.ownerOf, (_projectId)), abi.encode(owner));

        // mock permissions call
        bytes memory _permCall = abi.encodeCall(
            IJBPermissions.hasPermission, (address(this), owner, _projectId, JBPermissionIds.SEND_PAYOUTS, true, true)
        );
        mockExpect(address(permissions), _permCall, abi.encode(false));

        vm.expectRevert(
            abi.encodeWithSelector(
                JBPermissioned.JBPermissioned_Unauthorized.selector,
                owner,
                address(this),
                _projectId,
                JBPermissionIds.SEND_PAYOUTS
            )
        );
        _terminal.sendPayoutsOf(_projectId, address(0), 0, 0, 1);
    }

    function test_WhenExecutePayoutFails() external {
        // it will revert PayoutReverted

        // needed for terminal store mock call
        JBRuleset memory returnedRuleset = JBRuleset({
            cycleNumber: 1,
            id: 1,
            basedOnId: 0,
            start: 0,
            duration: 0,
            weight: 0,
            decayPercent: 0,
            approvalHook: IJBRulesetApprovalHook(address(0)),
            metadata: 0
        });

        JBAccountingContext memory mockTokenContext = JBAccountingContext({token: address(0), decimals: 0, currency: 0});

        // record payout mock call
        mockExpect(
            address(store),
            abi.encodeCall(IJBTerminalStore.recordPayoutFor, (_projectId, mockTokenContext, 0, 0)),
            abi.encode(returnedRuleset, 0)
        );

        // projects owner of
        mockExpect(address(projects), abi.encodeCall(IERC721.ownerOf, (_projectId)), abi.encode(address(this)));

        // needed for splits return call
        // invalid data to ensure revert
        JBSplit[] memory returnedSplits = new JBSplit[](1);
        returnedSplits[0] = JBSplit({
            preferAddToBalance: false,
            percent: 0,
            projectId: 0,
            beneficiary: payable(address(this)),
            lockedUntil: uint48(block.timestamp + 1),
            lockId: 0,
            hook: IJBSplitHook(address(0))
        });

        // mock splits of call
        mockExpect(
            address(splits),
            abi.encodeCall(IJBSplits.splitsOf, (_projectId, returnedRuleset.id, 0)),
            abi.encode(returnedSplits)
        );

        // mock directory call for fee processing
        mockExpect(
            address(directory),
            abi.encodeCall(IJBDirectory.primaryTerminalOf, (1, address(0))),
            abi.encode(address(_terminal))
        );

        // mock call to feelessAddresses
        mockExpect(
            address(feelessAddresses), abi.encodeCall(IJBFeelessAddresses.isFeeless, (address(this))), abi.encode(true)
        );

        vm.expectEmit(true, true, true, false);
        emit IJBPayoutTerminal.PayoutReverted(
            _projectId,
            returnedSplits[0],
            0,
            bytes("0x9996b3150000000000000000000000000000000000000000000000000000000000000000"),
            address(this)
        );

        _terminal.sendPayoutsOf(_projectId, address(0), 0, 0, 0);
    }
}
