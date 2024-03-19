// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {stdJson} from "forge-std/Script.sol";
import {Vm} from "forge-std/Vm.sol";

import {JBPermissions} from "../../src/JBPermissions.sol";
import {JBProjects} from "../../src/JBProjects.sol";
import {JBPrices} from "../../src/JBPrices.sol";
import {JBRulesets} from "../../src/JBRulesets.sol";
import {JBDirectory} from "../../src/JBDirectory.sol";
import {JBTokens} from "../../src/JBTokens.sol";
import {JBSplits} from "../../src/JBSplits.sol";
import {JBFeelessAddresses} from "../../src/JBFeelessAddresses.sol";
import {JBFundAccessLimits} from "../../src/JBFundAccessLimits.sol";
import {JBController} from "../../src/JBController.sol";
import {JBTerminalStore} from "../../src/JBTerminalStore.sol";
import {JBMultiTerminal} from "../../src/JBMultiTerminal.sol";

import {SphinxConstants, NetworkInfo} from "@sphinx-labs/contracts/SphinxConstants.sol";

struct CoreDeployment {
    JBPermissions permissions;
    JBProjects projects;
    JBDirectory directory;
    JBSplits splits;
    JBRulesets rulesets;
    JBController controller;
    JBMultiTerminal terminal;
    JBTerminalStore terminalStore;
    JBPrices prices;
    JBFeelessAddresses feeless;
    JBFundAccessLimits fundAccess;
    JBTokens tokens;
}

library CoreDeploymentLib {
    // Cheat code address, 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D.
    address internal constant VM_ADDRESS = address(uint160(uint256(keccak256("hevm cheat code"))));
    Vm internal constant vm = Vm(VM_ADDRESS);

    function getDeployment(string memory path) internal returns (CoreDeployment memory deployment) {
        // get chainId for which we need to get the deployment.
        uint256 chainId = block.chainid;

        // Deploy to get the constants.
        // TODO: get constants without deploy.
        SphinxConstants sphinxConstants = new SphinxConstants();
        NetworkInfo[] memory networks = sphinxConstants.getNetworkInfoArray();

        for (uint256 _i; _i < networks.length; _i++) {
            if (networks[_i].chainId == chainId) {
                return getDeployment(path, networks[_i].name);
            }
        }

        revert("ChainID is not (currently) supported by Sphinx.");
    }

    function getDeployment(
        string memory path,
        string memory network_name
    )
        internal
        view
        returns (CoreDeployment memory deployment)
    {
        deployment.permissions = JBPermissions(_getDeploymentAddress(path, "nana-core", network_name, "JBPermissions"));

        deployment.projects = JBProjects(_getDeploymentAddress(path, "nana-core", network_name, "JBProjects"));

        deployment.directory = JBDirectory(_getDeploymentAddress(path, "nana-core", network_name, "JBDirectory"));

        deployment.splits = JBSplits(_getDeploymentAddress(path, "nana-core", network_name, "JBSplits"));

        deployment.rulesets = JBRulesets(_getDeploymentAddress(path, "nana-core", network_name, "JBRulesets"));

        deployment.controller = JBController(_getDeploymentAddress(path, "nana-core", network_name, "JBController"));

        deployment.terminal = JBMultiTerminal(_getDeploymentAddress(path, "nana-core", network_name, "JBMultiTerminal"));

        deployment.terminalStore =
            JBTerminalStore(_getDeploymentAddress(path, "nana-core", network_name, "JBTerminalStore"));

        deployment.prices = JBPrices(_getDeploymentAddress(path, "nana-core", network_name, "JBPrices"));

        deployment.feeless =
            JBFeelessAddresses(_getDeploymentAddress(path, "nana-core", network_name, "JBFeelessAddresses"));

        deployment.fundAccess =
            JBFundAccessLimits(_getDeploymentAddress(path, "nana-core", network_name, "JBFundAccessLimits"));

        deployment.tokens = JBTokens(_getDeploymentAddress(path, "nana-core", network_name, "JBTokens"));
    }

    /// @notice Get the address of a contract that was deployed by the Deploy script.
    /// @dev Reverts if the contract was not found.
    /// @param path The path to the deployment file.
    /// @param contractName The name of the contract to get the address of.
    /// @return The address of the contract.
    function _getDeploymentAddress(
        string memory path,
        string memory project_name,
        string memory network_name,
        string memory contractName
    )
        internal
        view
        returns (address)
    {
        string memory deploymentJson =
            vm.readFile(string.concat(path, project_name, "/", network_name, "/", contractName, ".json"));
        return stdJson.readAddress(deploymentJson, ".address");
    }
}
