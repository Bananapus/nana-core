// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";

import {IPermit2} from "@permit2/src/src/interfaces/IPermit2.sol";
import "../contracts/JBPermissions.sol";
import "../contracts/JBProjects.sol";
import "../contracts/JBPrices.sol";
import "../contracts/JBRulesets.sol";
import "../contracts/JBDirectory.sol";
import "../contracts/JBTokens.sol";
import "../contracts/JBSplits.sol";
import "../contracts/JBFundAccessLimits.sol";
import "../contracts/JBController.sol";
import "../contracts/JBTerminalStore.sol";
import "../contracts/JBMultiTerminal.sol";

contract Deploy is Script {
    IPermit2 internal constant _PERMIT2 = IPermit2(0x000000000022D473030F116dDEE9F6B43aC78BA3);

    JBPermissions _permissions;
    JBProjects _projects;
    JBPrices _prices;
    JBDirectory _directory;
    JBRulesets _rulesets;
    JBTokens _tokens;
    JBSplits _splits;
    JBFundAccessLimits _fundAccessLimits;
    JBController _controller;
    JBTerminalStore _terminalStore;
    JBMultiTerminal _multiTerminal;

    function _run(address _manager, address _trustedForwarder) internal {
        vm.broadcast();
        _deployContracts(_manager, _trustedForwarder);
    }

    function _deployContracts(address _manager, address _trustedForwarder) internal {
        _permissions = new JBPermissions();
        _projects = new JBProjects(_manager);
        _prices = new JBPrices(_permissions, _projects, _manager);
        _directory = new JBDirectory(_permissions, _projects, address(this));
        _tokens = new JBTokens(_directory);
        _rulesets = new JBRulesets(_directory);
        _splits = new JBSplits(_directory);
        _fundAccessLimits = new JBFundAccessLimits(_directory);
        _controller = new JBController(
            _permissions,
            _projects,
            _directory,
            _rulesets,
            _tokens,
            _splits,
            _fundAccessLimits,
            _trustedForwarder
        );
        _directory.setIsAllowedToSetFirstController(address(_controller), true);
        _directory.transferOwnership(_manager);
        _terminalStore = new JBTerminalStore(_directory, _rulesets, _prices);
        _multiTerminal = new JBMultiTerminal(
            _permissions,
            _projects,
            _directory,
            _splits,
            _terminalStore,
            _PERMIT2,
            _trustedForwarder,
            _manager
        );
    }

    //https://ethereum.stackexchange.com/questions/24248/how-to-calculate-an-ethereum-contracts-address-during-its-creation-using-the-so
    function addressFrom(address _origin, uint256 _nonce)
        internal
        pure
        returns (address _address)
    {
        bytes memory data;
        if (_nonce == 0x00) {
            data = abi.encodePacked(bytes1(0xd6), bytes1(0x94), _origin, bytes1(0x80));
        } else if (_nonce <= 0x7f) {
            data = abi.encodePacked(bytes1(0xd6), bytes1(0x94), _origin, uint8(_nonce));
        } else if (_nonce <= 0xff) {
            data =
                abi.encodePacked(bytes1(0xd7), bytes1(0x94), _origin, bytes1(0x81), uint8(_nonce));
        } else if (_nonce <= 0xffff) {
            data =
                abi.encodePacked(bytes1(0xd8), bytes1(0x94), _origin, bytes1(0x82), uint16(_nonce));
        } else if (_nonce <= 0xffffff) {
            data =
                abi.encodePacked(bytes1(0xd9), bytes1(0x94), _origin, bytes1(0x83), uint24(_nonce));
        } else {
            data =
                abi.encodePacked(bytes1(0xda), bytes1(0x94), _origin, bytes1(0x84), uint32(_nonce));
        }
        bytes32 hash = keccak256(data);
        assembly {
            mstore(0, hash)
            _address := mload(0)
        }
    }
}

// Ethereum
contract DeployEthereumMainnet is Deploy {
    address _trustedForwarder = 0xB2b5841DBeF766d4b521221732F9B618fCf34A87;

    address _manager = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;

    function setUp() public {}

    function run() public {
        _run(_manager, _trustedForwarder);
    }
}

contract DeployEthereumGoerli is Deploy {
    address _trustedForwarder = 0xB2b5841DBeF766d4b521221732F9B618fCf34A87;

    address _manager = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;

    function setUp() public {}

    function run() public {
        _run(_manager, _trustedForwarder);
    }
}

contract DeployEthereumSepolia is Deploy {
    address _trustedForwarder = 0xB2b5841DBeF766d4b521221732F9B618fCf34A87;

    address _manager = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;

    function setUp() public {}

    function run() public {
        _run(_manager, _trustedForwarder);
    }
}

// Optimism

contract DeployOptimismMainnet is Deploy {
    address _trustedForwarder = 0xB2b5841DBeF766d4b521221732F9B618fCf34A87;

    address _manager = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;

    function setUp() public {}

    function run() public {
        _run(_manager, _trustedForwarder);
    }
}

contract DeployOptimismTestnet is Deploy {
    address _trustedForwarder = 0xB2b5841DBeF766d4b521221732F9B618fCf34A87;

    address _manager = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;

    function setUp() public {}

    function run() public {
        _run(_manager, _trustedForwarder);
    }
}

// Polygon

contract DeployPolygonMainnet is Deploy {
    address _trustedForwarder = 0xB2b5841DBeF766d4b521221732F9B618fCf34A87;

    address _manager = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;

    function setUp() public {}

    function run() public {
        _run(_manager, _trustedForwarder);
    }
}

contract DeployPolygonMumbai is Deploy {
    address _trustedForwarder = 0xB2b5841DBeF766d4b521221732F9B618fCf34A87;

    address _manager = 0x823b92d6a4b2AED4b15675c7917c9f922ea8ADAD;

    function setUp() public {}

    function run() public {
        _run(_manager, _trustedForwarder);
    }
}
