// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";

/* 
Contract that deploys a target contract with other mock contracts to satisfy the constructor.
Tests relative to this contract will be dependent on mock calls/emits and stdStorage.
*/
contract JBTokensSetup is JBTest {
    // Mocks
    IJBDirectory public directory = IJBDirectory(makeAddr("directory"));
    IJBToken public jbToken = IJBToken(makeAddr("juicayy"));

    // Target Contract
    IJBTokens public _tokens;

    function tokensSetup() public virtual {
        // Instantiate the contract being tested
        _tokens = new JBTokens(directory, jbToken);
    }
}
