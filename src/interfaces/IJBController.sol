// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {JBApprovalStatus} from "./../enums/JBApprovalStatus.sol";
import {JBRuleset} from "./../structs/JBRuleset.sol";
import {JBRulesetConfig} from "./../structs/JBRulesetConfig.sol";
import {JBRulesetMetadata} from "./../structs/JBRulesetMetadata.sol";
import {JBTerminalConfig} from "./../structs/JBTerminalConfig.sol";
import {JBSplit} from "./../structs/JBSplit.sol";
import {JBSplitGroup} from "./../structs/JBSplitGroup.sol";
import {IJBDirectory} from "./IJBDirectory.sol";
import {IJBDirectoryAccessControl} from "./IJBDirectoryAccessControl.sol";
import {IJBFundAccessLimits} from "./IJBFundAccessLimits.sol";
import {IJBRulesets} from "./IJBRulesets.sol";
import {IJBMigratable} from "./IJBMigratable.sol";
import {IJBProjectMetadataRegistry} from "./IJBProjectMetadataRegistry.sol";
import {IJBProjects} from "./IJBProjects.sol";
import {IJBSplits} from "./IJBSplits.sol";
import {IJBToken} from "./IJBToken.sol";
import {IJBTokens} from "./IJBTokens.sol";

interface IJBController is IERC165, IJBProjectMetadataRegistry, IJBDirectoryAccessControl {
    event LaunchProject(uint256 rulesetId, uint32 projectId, string metadata, string memo, address caller);

    event LaunchRulesets(uint256 rulesetId, uint32 projectId, string memo, address caller);

    event QueueRulesets(uint256 rulesetId, uint32 projectId, string memo, address caller);

    event SendReservedTokensToSplits(
        uint256 indexed rulesetId,
        uint256 indexed rulesetCycleNumber,
        uint32 indexed projectId,
        address beneficiary,
        uint256 tokenCount,
        uint256 beneficiaryTokenCount,
        string memo,
        address caller
    );

    event SendReservedTokensToSplit(
        uint32 indexed projectId,
        uint256 indexed domain,
        uint256 indexed group,
        JBSplit split,
        uint256 tokenCount,
        address caller
    );

    event MintTokens(
        address indexed beneficiary,
        uint32 indexed projectId,
        uint256 tokenCount,
        uint256 beneficiaryTokenCount,
        string memo,
        uint256 reservedRate,
        address caller
    );

    event BurnTokens(address indexed holder, uint32 indexed projectId, uint256 tokenCount, string memo, address caller);

    event MigrateController(uint32 indexed projectId, IJBMigratable to, address caller);

    event PrepMigration(uint32 indexed projectId, address from, address caller);

    event SetMetadata(uint32 indexed projectId, string metadata, address caller);

    function PROJECTS() external view returns (IJBProjects);

    function DIRECTORY() external view returns (IJBDirectory);

    function RULESETS() external view returns (IJBRulesets);

    function TOKENS() external view returns (IJBTokens);

    function SPLITS() external view returns (IJBSplits);

    function FUND_ACCESS_LIMITS() external view returns (IJBFundAccessLimits);

    function pendingReservedTokenBalanceOf(uint32 projectId) external view returns (uint256);

    function totalTokenSupplyWithReservedTokensOf(uint32 projectId) external view returns (uint256);

    function getRulesetOf(
        uint32 projectId,
        uint256 rulesetId
    )
        external
        view
        returns (JBRuleset memory ruleset, JBRulesetMetadata memory metadata);

    function latestQueuedRulesetOf(uint32 projectId)
        external
        view
        returns (JBRuleset memory, JBRulesetMetadata memory metadata, JBApprovalStatus);

    function currentRulesetOf(uint32 projectId)
        external
        view
        returns (JBRuleset memory ruleset, JBRulesetMetadata memory metadata);

    function queuedRulesetOf(uint32 projectId)
        external
        view
        returns (JBRuleset memory ruleset, JBRulesetMetadata memory metadata);

    function launchProjectFor(
        address owner,
        string calldata projectMetadata,
        JBRulesetConfig[] calldata rulesetConfigurations,
        JBTerminalConfig[] memory terminalConfigurations,
        string calldata memo
    )
        external
        returns (uint32 projectId);

    function launchRulesetsFor(
        uint32 projectId,
        JBRulesetConfig[] calldata rulesetConfigurations,
        JBTerminalConfig[] memory terminalConfigurations,
        string calldata memo
    )
        external
        returns (uint256 rulesetId);

    function queueRulesetsOf(
        uint32 projectId,
        JBRulesetConfig[] calldata rulesetConfigurations,
        string calldata memo
    )
        external
        returns (uint256 rulesetId);

    function mintTokensOf(
        uint32 projectId,
        uint256 tokenCount,
        address beneficiary,
        string calldata memo,
        bool useReservedRate
    )
        external
        returns (uint256 beneficiaryTokenCount);

    function burnTokensOf(address holder, uint32 projectId, uint256 tokenCount, string calldata memo) external;

    function sendReservedTokensToSplitsOf(uint32 projectId, string memory memo) external returns (uint256);

    function migrateController(uint32 projectId, IJBMigratable to) external;

    function setSplitGroupsOf(uint32 projectId, uint256 domain, JBSplitGroup[] calldata splitGroup) external;

    function deployERC20For(
        uint32 projectId,
        string calldata name,
        string calldata symbol
    )
        external
        returns (IJBToken token);

    function setTokenFor(uint32 _projectId, IJBToken _token) external;

    function claimTokensFor(address holder, uint32 projectId, uint256 amount, address beneficiary) external;

    function transferCreditsFrom(address holder, uint32 projectId, address recipient, uint256 amount) external;
}
