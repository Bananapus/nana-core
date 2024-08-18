// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {IJBProjects} from "./IJBProjects.sol";
import {IJBTerminal} from "./IJBTerminal.sol";

interface IJBDirectory {
    event AddTerminal(uint256 indexed projectId, IJBTerminal indexed terminal, address caller);
    event SetController(uint256 indexed projectId, IERC165 indexed controller, address caller);
    event SetIsAllowedToSetFirstController(address indexed addr, bool indexed flag, address caller);
    event SetPrimaryTerminal(
        uint256 indexed projectId, address indexed token, IJBTerminal indexed terminal, address caller
    );
    event SetTerminals(uint256 indexed projectId, IJBTerminal[] terminals, address caller);

    function PROJECTS() external view returns (IJBProjects);

    function controllerOf(uint256 projectId) external view returns (IERC165);
    function isAllowedToSetFirstController(address account) external view returns (bool);
    function isTerminalOf(uint256 projectId, IJBTerminal terminal) external view returns (bool);
    function primaryTerminalOf(uint256 projectId, address token) external view returns (IJBTerminal);
    function terminalsOf(uint256 projectId) external view returns (IJBTerminal[] memory);

    function setControllerOf(uint256 projectId, IERC165 controller) external;
    function setIsAllowedToSetFirstController(address account, bool flag) external;
    function setPrimaryTerminalOf(uint256 projectId, address token, IJBTerminal terminal) external;
    function setTerminalsOf(uint256 projectId, IJBTerminal[] calldata terminals) external;
}
