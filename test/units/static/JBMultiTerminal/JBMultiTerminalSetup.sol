// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";

/* 
Contract that deploys a target contract with other mock contracts to satisfy the constructor.
Tests relative to this contract will be dependent on mock calls/emits and stdStorage.
*/
contract JBMultiTerminalSetup is JBTest {
    // Target Contract
    IJBMultiTerminal public _terminal;

    // Mocks
    IJBPermissions public permissions = IJBPermissions(makeAddr("permissions"));
    IJBProjects public projects = IJBProjects(makeAddr("projects"));
    IJBDirectory public directory = IJBDirectory(makeAddr("directory"));
    IJBSplits public splits = IJBSplits(makeAddr("splits"));
    IJBTerminalStore public store = IJBTerminalStore(makeAddr("store"));
    IJBFeelessAddresses public feelessAddresses = IJBFeelessAddresses(makeAddr("feeless"));
    IPermit2 public permit2 = IPermit2(makeAddr("permit2"));
    address trustedForwarder = makeAddr("forwarder");

    function multiTerminalSetup() public virtual {
        // Instantiate the contract being tested
        _terminal = new JBMultiTerminal(
            permissions, projects, directory, splits, store, feelessAddresses, permit2, trustedForwarder
        );
    }
}
