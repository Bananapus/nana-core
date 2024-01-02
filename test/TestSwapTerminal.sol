// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import /* {*} from */ "./helpers/TestBaseWorkflow.sol";

import {JBSwapTerminal} from "../src/JBSwapTerminal.sol";
import {IWETH9} from "../src/interfaces/external/IWETH9.sol";

/// @notice Swap terminal test on a mainnet fork
contract TestSwapTerminal_Fork is TestBaseWorkflow {
    JBSwapTerminal internal _swapTerminal;
    JBMultiTerminal internal _projectTerminal;
    JBTokens internal _tokens;

    IJBProjects internal _projects;
    IJBPermissions internal _permissions;
    IJBDirectory internal _directory;
    IPermit2 internal _permit2;
    IJBController internal _controller;
    JBTerminalStore internal _terminalStore;
    address internal _owner;
    IWETH9 internal _weth;

    uint256 internal _projectId;
    address internal _projectOwner;
    address internal _terminalOwner;
    address internal _beneficiary;

    address DAI = address(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    IWETH9 WETH = IWETH9(0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14);

    function setUp() public override {
        vm.createSelectFork("https://rpc.ankr.com/eth_sepolia",5009568);

    // TODO: find a new way to parse broadcast json
        // _controller = IJBController(stdJson.readAddress(
        //         vm.readFile("broadcast/Deploy.s.sol/11155420/run-latest.json"), ".address"
        //     ));

        _controller = IJBController(0xAe3a940A8f16f2B7DC8E3CFffDB97714275a7B7E);

        _projects = IJBProjects(0x22CdC4938B9b11df0767ba612C6f1ecc5c323C51);

        _permissions = IJBPermissions(0x0D8dE90B514B5FE019968db73cF76E2E4957f093);

        _directory = IJBDirectory(0x9cf2aBf95f14bE5cDe265A2EF100971d023f9B65);

        _permit2 = IPermit2(0x000000000022D473030F116dDEE9F6B43aC78BA3);

        _tokens = JBTokens(0x289989C0bd96A616B06c7AAc99894A54E947a68D);

        _terminalStore = JBTerminalStore(0x3F2389068dC5FA6cfE0187D9DA6cA81124250225);

        _projectTerminal = JBMultiTerminal(0x4BF5655C7d36D3Ce3D4D769C274f1b6fCDDdF4e8);

        _owner = makeAddr("owner");

        _swapTerminal = new JBSwapTerminal(
            _projects,
            _permissions,
            _directory,
            _permit2,
            _owner,
            _weth
        );
    }
    
    /// @notice Test paying a swap terminal in XXX to contribute to JuiceboxDAO project (in the eth terminal), using metadata
    /// @dev    Quote at the forked block: . Max slippage suggested (uni sdk): 
    function testPayDaiSwapEthPayEth(
        uint256 _amountIn
    )
        external
    {   
        uint256 _quote;
        uint256 _weight;

        // Craft the metadata including the pool and quote

        // Make a payment.
        _swapTerminal.pay{value: _amountIn}({
            _projectId: _projectId,
            _amount: _amountIn,
            _token: JBConstants.NATIVE_TOKEN, // Unused.
            _beneficiary: _beneficiary,
            _minReturnedTokens: 0,
            _memo: "Take my money!",
            _metadata: new bytes(0)
        });

        // // Make sure the beneficiary has a balance of project tokens.
        // uint256 _beneficiaryTokenBalance =
        //     UD60x18unwrap(UD60x18mul(UD60x18wrap(_amountIn * _quote), UD60x18wrap(_weight)));
        // assertEq(_tokens.totalBalanceOf(_beneficiary, _projectId), _beneficiaryTokenBalance);

        // // Make sure the native token balance in terminal is up to date.
        // uint256 _terminalBalance = _amountIn * _quote;
        // assertEq(
        //     jbTerminalStore().balanceOf(address(_projectTerminal), _projectId, JBConstants.NATIVE_TOKEN), _terminalBalance
        // );

    }

    function _reconfigure() internal {
        JBRulesetMetadata memory _metadata = JBRulesetMetadata({
            reservedRate: 0,
            redemptionRate: 0,
            baseCurrency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
            pausePay: false,
            pauseCreditTransfers: false,
            allowOwnerMinting: false,
            allowTerminalMigration: false,
            allowSetTerminals: true,
            allowControllerMigration: false,
            allowSetController: false,
            holdFees: false,
            useTotalSurplusForRedemptions: false,
            useDataHookForPay: false,
            useDataHookForRedeem: false,
            dataHook: address(0),
            metadata: 0
        });

        JBRuleset memory _ruleset = jbRulesets().currentOf(_projectId);

        // Package a ruleset configuration.
        JBRulesetConfig[] memory _rulesetConfig = new JBRulesetConfig[](1);
        _rulesetConfig[0].mustStartAtOrAfter = 0;
        _rulesetConfig[0].duration = _ruleset.duration;
        _rulesetConfig[0].weight = 0;
        _rulesetConfig[0].decayRate = 0;
        _rulesetConfig[0].approvalHook = IJBRulesetApprovalHook(address(0));
        _rulesetConfig[0].metadata = _metadata;
        _rulesetConfig[0].splitGroups = new JBSplitGroup[](0);
        _rulesetConfig[0].fundAccessLimitGroups = new JBFundAccessLimitGroup[](0);

        vm.prank(multisig());
        _controller.queueRulesetsOf(_projectId, _rulesetConfig, "");

        vm.warp(block.timestamp + _ruleset.duration);

        // Set a new primary terminal for DAI
        _directory.setPrimaryTerminalOf(_projectId, DAI, _swapTerminal);
    }
}
