// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "lib/forge-std/src/Script.sol";

import {IPermit2} from "lib/permit2/src/interfaces/IPermit2.sol";
import "../src/JBProtocolDeployer.sol";

abstract contract Deploy is Script {
    function _trustedForwarder() internal virtual returns (address);
    function _manager() internal virtual returns (address);

    function _run() internal {
        vm.broadcast();
        JBProtocolDeployer deployer = new JBProtocolDeployer();
        vm.broadcast();
        deployer.deployJBProtocol(_manager(), _trustedForwarder());
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
