// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBTokensSetup} from "./JBTokensSetup.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

contract TestDeployERC20ForUnits_Local is JBTokensSetup {
    uint256 _projectId = 1;
    string _name = "Juice";
    string _symbol = "JBX";
    IJBToken _token = IJBToken(makeAddr("JBX"));

    function setUp() public {
        super.tokensSetup();
    }

    modifier whenCallerIsController() {
        // mock call to JBDirectory controllerOf
        mockExpect(
            address(directory), abi.encodeCall(IJBDirectory.controllerOf, (_projectId)), abi.encode(address(this))
        );

        _;
    }

    function test_WhenNameLengthEQZero() external whenCallerIsController {
        // it will revert EMPTY_NAME

        vm.expectRevert(JBTokens.JBTokens_EmptyName.selector);
        _tokens.deployERC20For({projectId: _projectId, name: "", symbol: _symbol, salt: bytes32(0)});
    }

    function test_WhenSymbolLengthEQZero() external whenCallerIsController {
        // it will revert EMPTY_SYMBOL

        vm.expectRevert(JBTokens.JBTokens_EmptySymbol.selector);
        _tokens.deployERC20For({projectId: _projectId, name: _name, symbol: "", salt: bytes32(0)});
    }

    function test_WhenProjectAlreadyHasAConfiguredToken() external whenCallerIsController {
        // it will revert PROJECT_ALREADY_HAS_TOKEN

        // Find the storage slot to set credit balance
        bytes32 tokenOfSlot = keccak256(abi.encode(_projectId, uint256(2)));

        // Set storage
        vm.store(address(_tokens), tokenOfSlot, bytes32(uint256(uint160(address(_token)))));

        // Ensure it's set
        IJBToken _storedToken = _tokens.tokenOf(_projectId);
        assertEq(address(_storedToken), address(_token));

        vm.expectRevert(JBTokens.JBTokens_ProjectAlreadyHasToken.selector);
        _tokens.deployERC20For({projectId: _projectId, name: _name, symbol: _symbol, salt: bytes32(0)});
    }

    modifier whenHappyPath() {
        _;
    }

    function test_GivenASaltIsProvided() external whenHappyPath whenCallerIsController {
        // it will create and initialize a deterministic clone based on the msgsender and salt

        bytes32 salt = bytes32(uint256(1));
        bytes32 hashedSalt = keccak256(abi.encode(address(this), salt));
        address deployer = address(_tokens);
        address token = address(jbToken);

        address predicted = Clones.predictDeterministicAddress(token, hashedSalt, deployer);

        vm.expectEmit();
        emit IJBTokens.DeployERC20(_projectId, IJBToken(predicted), _name, _symbol, salt, address(this));

        IJBToken deployedToken =
            _tokens.deployERC20For({projectId: _projectId, name: _name, symbol: _symbol, salt: salt});

        assertEq(predicted, address(deployedToken));
    }

    function test_GivenASaltIsNotProvided() external whenHappyPath whenCallerIsController {
        // it will clone and initialize a indeterministically generated clone

        IJBToken deployedToken =
            _tokens.deployERC20For({projectId: _projectId, name: _name, symbol: _symbol, salt: bytes32(0)});

        if (address(deployedToken) == address(0)) revert();
    }
}
