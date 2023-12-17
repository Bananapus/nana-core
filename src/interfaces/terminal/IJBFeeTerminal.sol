// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IJBTerminal} from "./IJBTerminal.sol";
import {IJBFeelessAddresses} from "../IJBFeelessAddresses.sol";
import {JBFee} from "../../structs/JBFee.sol";

/// @notice A terminal that can process and hold fees.
interface IJBFeeTerminal is IJBTerminal {
    event HoldFee(
        uint256 indexed projectId,
        address indexed token,
        uint256 indexed amount,
        uint256 fee,
        address beneficiary,
        address caller
    );

    event ProcessFee(
        uint256 indexed projectId,
        address indexed token,
        uint256 indexed amount,
        bool wasHeld,
        address beneficiary,
        address caller
    );

    event ReturnHeldFees(
        uint256 indexed projectId,
        address indexed token,
        uint256 indexed amount,
        uint256 returnedFees,
        uint256 leftoverAmount,
        address caller
    );

    event FeeReverted(
        uint256 indexed projectId,
        address indexed token,
        uint256 indexed feeProjectId,
        uint256 amount,
        bytes reason,
        address caller
    );

    function FEE() external view returns (uint256);

    function FEELESS_ADDRESSES() external view returns (IJBFeelessAddresses);

    function heldFeesOf(uint256 projectId, address token) external view returns (JBFee[] memory);

    function processHeldFeesOf(uint256 projectId, address token) external;
}
