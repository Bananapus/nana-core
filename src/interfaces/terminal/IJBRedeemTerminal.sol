// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IJBTerminal} from "./IJBTerminal.sol";
import {IJBRedeemHook} from "../IJBRedeemHook.sol";
import {JBDidRedeemData} from "../../structs/JBDidRedeemData.sol";

/// @notice A terminal that can be redeemed from.
interface IJBRedeemTerminal is IJBTerminal {
    event RedeemTokens(
        uint256 indexed rulesetId,
        uint256 indexed rulesetCycleNumber,
        uint32 indexed projectId,
        address holder,
        address beneficiary,
        uint160 tokenCount,
        uint160 reclaimedAmount,
        bytes metadata,
        address caller
    );

    event HookDidRedeem(
        IJBRedeemHook indexed hook, JBDidRedeemData data, uint160 payloadAmount, uint160 fee, address caller
    );

    function redeemTokensOf(
        address holder,
        uint32 projectId,
        address token,
        uint160 count,
        uint160 minReclaimed,
        address payable beneficiary,
        bytes calldata metadata
    )
        external
        returns (uint160 reclaimAmount);
}
