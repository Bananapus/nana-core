// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "lib/forge-std/src/Script.sol";
import {IPermit2} from "lib/permit2/src/interfaces/IPermit2.sol";
import {JBPermissions} from "../src/JBPermissions.sol";
import {JBProjects} from "../src/JBProjects.sol";
import {JBPrices} from "../src/JBPrices.sol";
import {JBRulesets} from "../src/JBRulesets.sol";
import {JBDirectory} from "../src/JBDirectory.sol";
import {JBTokens} from "../src/JBTokens.sol";
import {JBSplits} from "../src/JBSplits.sol";
import {JBFeelessAddresses} from "../src/JBFeelessAddresses.sol";
import {JBFundAccessLimits} from "../src/JBFundAccessLimits.sol";
import {JBController} from "../src/JBController.sol";
import {JBTerminalStore} from "../src/JBTerminalStore.sol";
import {JBMultiTerminal} from "../src/JBMultiTerminal.sol";

abstract contract Deploy is Script {
    /// @notice The universal PERMIT2 address.
    IPermit2 private constant _PERMIT2 = IPermit2(0x000000000022D473030F116dDEE9F6B43aC78BA3);

    function _trustedForwarder() internal virtual returns (address);

    function _manager() internal virtual returns (address);

    function run() public {
        vm.startBroadcast();
        _deployJBProtocol(_manager(), _trustedForwarder());
        vm.stopBroadcast();
    }

    /// @notice Deploys the protocol.
    /// @param manager The address that will manage the few privileged functions of the protocol.
    /// @param trustedForwarder The address that is allowed to forward calls to the terminal and controller on a payer's
    /// behalf.
    function _deployJBProtocol(address manager, address trustedForwarder) private {
        JBPermissions permissions = new JBPermissions();
        JBProjects projects = new JBProjects(manager);
        JBDirectory directory = new JBDirectory(permissions, projects, msg.sender);
        JBSplits splits = new JBSplits(directory);
        JBRulesets rulesets = new JBRulesets(directory);
        directory.setIsAllowedToSetFirstController(
            address(
                new JBController({
                    permissions: permissions,
                    projects: projects,
                    directory: directory,
                    rulesets: rulesets,
                    tokens: new JBTokens(directory),
                    splits: splits,
                    fundAccessLimits: new JBFundAccessLimits(directory),
                    trustedForwarder: trustedForwarder
                })
            ),
            true
        );
        directory.transferOwnership(manager);
        new JBMultiTerminal({
            permissions: permissions,
            projects: projects,
            directory: directory,
            splits: splits,
            store: new JBTerminalStore({
                directory: directory,
                rulesets: rulesets,
                prices: new JBPrices(permissions, projects, manager)
            }),
            feelessAddresses: new JBFeelessAddresses(manager),
            permit2: _PERMIT2,
            trustedForwarder: trustedForwarder
        });
    }
}

// Ethereum

contract DeployEthereumMainnet is Deploy {
    function _trustedForwarder() internal virtual override returns (address) {
        return 0xB2b5841DBeF766d4b521221732F9B618fCf34A87;
    }

    function _manager() internal virtual override returns (address) {
        return 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
    }
}

contract DeployEthereumGoerli is Deploy {
    function _trustedForwarder() internal virtual override returns (address) {
        return 0xB2b5841DBeF766d4b521221732F9B618fCf34A87;
    }

    function _manager() internal virtual override returns (address) {
        return 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
    }
}

contract DeployEthereumSepolia is Deploy {
    function _trustedForwarder() internal virtual override returns (address) {
        return 0xB2b5841DBeF766d4b521221732F9B618fCf34A87;
    }

    function _manager() internal virtual override returns (address) {
        return 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
    }
}

// Optimism

contract DeployOptimismMainnet is Deploy {
    function _trustedForwarder() internal virtual override returns (address) {
        return 0xB2b5841DBeF766d4b521221732F9B618fCf34A87;
    }

    function _manager() internal virtual override returns (address) {
        return 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
    }
}

contract DeployOptimismTestnet is Deploy {
    function _trustedForwarder() internal virtual override returns (address) {
        return 0xB2b5841DBeF766d4b521221732F9B618fCf34A87;
    }

    function _manager() internal virtual override returns (address) {
        return 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
    }
}

// Polygon

contract DeployPolygonMainnet is Deploy {
    function _trustedForwarder() internal virtual override returns (address) {
        return 0xB2b5841DBeF766d4b521221732F9B618fCf34A87;
    }

    function _manager() internal virtual override returns (address) {
        return 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
    }
}

contract DeployPolygonMumbai is Deploy {
    function _trustedForwarder() internal virtual override returns (address) {
        return 0xB2b5841DBeF766d4b521221732F9B618fCf34A87;
    }

    function _manager() internal virtual override returns (address) {
        return 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;
    }
}
