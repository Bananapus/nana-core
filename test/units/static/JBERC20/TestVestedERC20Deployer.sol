// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {JBVestedERC20} from "../../../../src/JBVestedERC20.sol";
import {JBVestedERC20Deployer} from "../../../../src/JBVestedERC20Deployer.sol";
import {IJBDirectory} from "../../../../src/interfaces/IJBDirectory.sol";
import {IJBTokens} from "../../../../src/interfaces/IJBTokens.sol";
import {IJBController} from "../../../../src/interfaces/IJBController.sol";
import {IJBToken} from "../../../../src/interfaces/IJBToken.sol";

contract MockDirectory is IJBDirectory {
    address public controller;
    function controllerOf(uint256) external view override returns (address) { return controller; }
    // stub all other functions
    function PROJECTS() external pure override returns (address) { return address(0); }
    function isAllowedToSetFirstController(address) external pure override returns (bool) { return false; }
    function isTerminalOf(uint256, address) external pure override returns (bool) { return false; }
    function primaryTerminalOf(uint256, address) external pure override returns (address) { return address(0); }
    function terminalsOf(uint256) external pure override returns (address[] memory) { address[] memory a; return a; }
    function setControllerOf(uint256, address) external pure override {}
    function setIsAllowedToSetFirstController(address, bool) external pure override {}
    function setPrimaryTerminalOf(uint256, address, address) external pure override {}
    function setTerminalsOf(uint256, address[] calldata) external pure override {}
}

contract MockTokens is IJBTokens {
    // stub all functions
}

contract MockController is IJBController {
    address public lastSetToken;
    uint256 public lastSetProjectId;
    function setTokenFor(uint256 projectId, IJBToken token) external override {
        lastSetProjectId = projectId;
        lastSetToken = address(token);
    }
    // stub all other functions
}

contract TestVestedERC20Deployer is JBTest {
    function test_DeployerDeploysAndInitializesVestedERC20() public {
        // Deploy implementation
        JBVestedERC20 implementation = new JBVestedERC20();
        // Deploy mocks
        MockDirectory directory = new MockDirectory();
        MockTokens tokens = new MockTokens();
        MockController controller = new MockController();
        directory.controller = address(controller);
        // Deploy deployer
        JBVestedERC20Deployer deployer = new JBVestedERC20Deployer(
            IJBDirectory(address(directory)),
            IJBTokens(address(tokens)),
            address(implementation)
        );
        // Deploy a new vested token via the deployer
        string memory name = "VestedToken";
        string memory symbol = "VST";
        address owner = address(0x123);
        address admin = address(0x456);
        uint256 projectId = 42;
        uint256 cliff = 1 days;
        uint256 duration = 3 days;
        bytes32 salt = bytes32(0);
        IJBToken token = deployer.deployVestedERC20ForProject(
            projectId, name, symbol, owner, cliff, duration, salt
        );
        // Check initialization
        JBVestedERC20 vested = JBVestedERC20(address(token));
        assertEq(vested.name(), name);
        assertEq(vested.symbol(), symbol);
        assertEq(vested.owner(), owner);
        assertEq(vested.admin(), admin);
        assertEq(vested.CLIFF(), cliff);
        assertEq(vested.UNLOCK_DURATION(), duration);
        assertEq(vested.PROJECT_ID(), projectId);
        // Check controller was set
        assertEq(controller.lastSetProjectId, projectId);
        assertEq(controller.lastSetToken, address(token));
    }
} 