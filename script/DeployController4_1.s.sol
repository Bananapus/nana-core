// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "@sphinx-labs/contracts/SphinxPlugin.sol";
import {Script, stdJson, VmSafe} from "forge-std/Script.sol";
import {CoreDeployment, CoreDeploymentLib} from "./helpers/CoreDeploymentLib.sol";

import {JBController4_1} from "src/JBController4_1.sol";

contract DeployPeriphery is Script, Sphinx {
    /// @notice tracks the deployment of the core contracts for the chain we are deploying to.
    CoreDeployment core;

    uint256 CORE_DEPLOYMENT_NONCE = 1;
    address OMNICHAIN_RULESET_OPERATOR = address(0xa7E0cbCFB2C6dF7db07cC4cA05df681f1307CeDD);

    function configureSphinx() public override {
        sphinxConfig.projectName = "nana-core";
        sphinxConfig.mainnets = ["ethereum", "optimism", "base", "arbitrum"];
        sphinxConfig.testnets = ["ethereum_sepolia", "optimism_sepolia", "base_sepolia", "arbitrum_sepolia"];
    }

    /// @notice Deploys the protocol.
    function run() public {
        // Get the deployment addresses for the nana CORE for this chain.
        // We want to do this outside of the `sphinx` modifier.
        core = CoreDeploymentLib.getDeployment(vm.envOr("NANA_CORE_DEPLOYMENT_PATH", string("deployments/")));

        // Deploy the protocol.
        deploy();
    }

    function deploy() public sphinx {
        if (OMNICHAIN_RULESET_OPERATOR == address(0)) {
            revert("OMNICHAIN_RULESET_OPERATOR must be set before deploying the controller.");
        }

        JBController4_1 controller = new JBController4_1{salt: keccak256(abi.encode(CORE_DEPLOYMENT_NONCE))}({
            directory: core.directory,
            fundAccessLimits: core.fundAccess,
            permissions: core.permissions,
            prices: core.prices,
            projects: core.projects,
            rulesets: core.rulesets,
            splits: core.splits,
            tokens: core.tokens,
            omnichainRulesetOperator: OMNICHAIN_RULESET_OPERATOR,
            trustedForwarder: core.trustedForwarder
        });

        // Allow the controller to set itself as the first controller.
        core.directory.setIsAllowedToSetFirstController(address(controller), true);
    }
}
