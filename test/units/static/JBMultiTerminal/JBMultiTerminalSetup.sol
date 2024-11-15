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
    MetadataResolverHelper public _metadataHelper;

    // Mocks
    IJBPermissions public permissions = IJBPermissions(makeAddr("permissions"));
    IJBProjects public projects = IJBProjects(makeAddr("projects"));
    IJBDirectory public directory = IJBDirectory(makeAddr("directory"));
    IJBRulesets public rulesets = IJBRulesets(makeAddr("rulesets"));
    IJBTokens public tokens = IJBTokens(makeAddr("tokens"));
    IJBSplits public splits = IJBSplits(makeAddr("splits"));
    IJBTerminalStore public store = IJBTerminalStore(makeAddr("store"));
    IJBFeelessAddresses public feelessAddresses = IJBFeelessAddresses(makeAddr("feeless"));
    IPermit2 public permit2 = IPermit2(makeAddr("permit2"));
    address trustedForwarder = makeAddr("forwarder");

    function multiTerminalSetup() public virtual {
        // Constructor will call to find directory and rulesets from the terminal store
        mockExpect(address(store), abi.encodeCall(IJBTerminalStore.DIRECTORY, ()), abi.encode(address(directory)));
        mockExpect(address(store), abi.encodeCall(IJBTerminalStore.RULESETS, ()), abi.encode(address(rulesets)));

        // Instantiate the contract being tested
        _terminal = new JBMultiTerminal(
            feelessAddresses, permissions, projects, splits, store, tokens, permit2, trustedForwarder
        );

        _metadataHelper = new MetadataResolverHelper();
    }
}
