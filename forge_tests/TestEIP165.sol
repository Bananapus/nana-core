// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import /* {*} from */ "./helpers/TestBaseWorkflow.sol";

contract TestEIP165_Local is TestBaseWorkflow {
    bytes4 constant notSupportedInterface = 0xffffffff;

    uint256 constant projectId = 2;
    uint256 constant splitsProjectID = 3;
    address payable constant splitsBeneficiary = payable(address(420));
    uint256 constant splitsDomain = 1;
    uint256 constant splitsGroup = 1;
    bool constant splitsPreferClaimedTokens = false;
    string constant splitsMemo = "";
    bytes constant splitsMetadata = "";
    bool constant splitsPreferAddToBalance = true;
    address constant splitsOwner = address(420);

    function testJBController() public {
        JBController controller = jbController();

        // Should support these interfaces
        assertTrue(controller.supportsInterface(type(IERC165).interfaceId));
        assertTrue(controller.supportsInterface(type(IJBMigratable).interfaceId));
        assertTrue(controller.supportsInterface(type(IJBOperatable).interfaceId));

        if (isUsingJbController3_0()) {
            assertTrue(controller.supportsInterface(type(IJBController).interfaceId));
        } else {
            assertTrue(controller.supportsInterface(type(IJBController3_1).interfaceId));
        }

        // Make sure it doesn't always return true
        assertTrue(!controller.supportsInterface(notSupportedInterface));
    }

    function testJBERC20PaymentTerminal() public {
        JBERC20PaymentTerminal terminal = jbERC20PaymentTerminal();

        // Should support these interfaces
        assertTrue(terminal.supportsInterface(type(IERC165).interfaceId));
        assertTrue(terminal.supportsInterface(type(IJBPaymentTerminal).interfaceId));
        assertTrue(terminal.supportsInterface(type(IJBRedemptionTerminal).interfaceId));
        assertTrue(terminal.supportsInterface(type(IJBSingleTokenPaymentTerminal).interfaceId));
        assertTrue(terminal.supportsInterface(type(IJBOperatable).interfaceId));

        if (isUsingJbController3_0()) {
            assertTrue(terminal.supportsInterface(type(IJBPayoutTerminal).interfaceId));
            assertTrue(terminal.supportsInterface(type(IJBAllowanceTerminal).interfaceId));
            assertTrue(terminal.supportsInterface(type(IJBPayoutRedemptionPaymentTerminal).interfaceId));
        } else {
            assertTrue(terminal.supportsInterface(type(IJBPayoutTerminal3_1).interfaceId));
            assertTrue(terminal.supportsInterface(type(IJBAllowanceTerminal3_1).interfaceId));
            assertTrue(terminal.supportsInterface(type(IJBPayoutRedemptionPaymentTerminal3_1).interfaceId));
        }

        // Make sure it doesn't always return true
        assertTrue(!terminal.supportsInterface(notSupportedInterface));
    }

    function testJBETHPaymentTerminal() public {
        JBETHPaymentTerminal terminal = jbETHPaymentTerminal();

        // Should support these interfaces
        assertTrue(terminal.supportsInterface(type(IERC165).interfaceId));
        assertTrue(terminal.supportsInterface(type(IJBPaymentTerminal).interfaceId));
        assertTrue(terminal.supportsInterface(type(IJBRedemptionTerminal).interfaceId));
        assertTrue(terminal.supportsInterface(type(IJBSingleTokenPaymentTerminal).interfaceId));
        assertTrue(terminal.supportsInterface(type(IJBOperatable).interfaceId));

        if (isUsingJbController3_0()) {
            assertTrue(terminal.supportsInterface(type(IJBPayoutTerminal).interfaceId));
            assertTrue(terminal.supportsInterface(type(IJBAllowanceTerminal).interfaceId));
            assertTrue(terminal.supportsInterface(type(IJBPayoutRedemptionPaymentTerminal).interfaceId));
        } else {
            assertTrue(terminal.supportsInterface(type(IJBPayoutTerminal3_1).interfaceId));
            assertTrue(terminal.supportsInterface(type(IJBAllowanceTerminal3_1).interfaceId));
            assertTrue(terminal.supportsInterface(type(IJBPayoutRedemptionPaymentTerminal3_1).interfaceId));
        }
        // Make sure it doesn't always return true
        assertTrue(!terminal.supportsInterface(notSupportedInterface));
    }

    function testJBProjects() public {
        JBProjects projects = jbProjects();

        // Should support these interfaces
        assertTrue(projects.supportsInterface(type(IERC165).interfaceId));
        assertTrue(projects.supportsInterface(type(IERC721).interfaceId));
        assertTrue(projects.supportsInterface(type(IERC721Metadata).interfaceId));
        assertTrue(projects.supportsInterface(type(IJBProjects).interfaceId));
        assertTrue(projects.supportsInterface(type(IJBOperatable).interfaceId));

        // Make sure it doesn't always return true
        assertTrue(!projects.supportsInterface(notSupportedInterface));
    }

    function testJBReconfigurationBufferBallot() public {
        JBReconfigurationBufferBallot ballot = new JBReconfigurationBufferBallot(3000);

        // Should support these interfaces
        assertTrue(ballot.supportsInterface(type(IERC165).interfaceId));
        // TODO: Add interface
        //assertTrue(ballot.supportsInterface(type(IJBReconfigurationBufferBallot).interfaceId));
        assertTrue(ballot.supportsInterface(type(IJBFundingCycleBallot).interfaceId));

        // Make sure it doesn't always return true
        assertTrue(!ballot.supportsInterface(notSupportedInterface));
    }

    function testJBETHERC20SplitsPayer() public {
      
        JBETHERC20SplitsPayerDeployer deployer = new JBETHERC20SplitsPayerDeployer(jbSplitsStore());

        JBETHERC20SplitsPayer splitsPayer = JBETHERC20SplitsPayer(
            payable(
                address(
                deployer.deploySplitsPayer(
                    splitsProjectID,
                    splitsDomain,
                    splitsGroup,
                    projectId,
                    splitsBeneficiary,
                    splitsPreferClaimedTokens,
                    splitsMemo,
                    splitsMetadata,
                    splitsPreferAddToBalance,
                    splitsOwner
        ))));

        // Should support these interfaces
        assertTrue(splitsPayer.supportsInterface(type(IERC165).interfaceId));
        assertTrue(splitsPayer.supportsInterface(type(IJBSplitsPayer).interfaceId));
        assertTrue(splitsPayer.supportsInterface(type(IJBProjectPayer).interfaceId));

        // Make sure it doesn't always return true
        assertTrue(!splitsPayer.supportsInterface(notSupportedInterface));
    }
}
