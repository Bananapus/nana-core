// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBControllerSetup} from "./JBControllerSetup.sol";

contract TestMintTokensOfUnits_Local is JBControllerSetup {
    uint256 _projectId = 1;

    function setUp() public {
        super.controllerSetup();
    }

    function test_WhenNoRulesetIsActive() external {
        // it should be able to mint
    }

    function test_MintNotAllowedSenderNotHookTerminalNorRulesetAllowsMint() external {
        // mock call to JBProjects ownerOf which will give permission
        bytes memory _projectsCall = abi.encodeCall(IERC721.ownerOf, (_projectId));
        bytes memory _projectsCallReturn = abi.encode(address(this));
        mockExpect(address(projects), _projectsCall, _projectsCallReturn);

        // setup: return data
        JBRulesetMetadata memory _metadata = JBRulesetMetadata({
            reservedPercent: JBConstants.MAX_RESERVED_PERCENT / 2, //50%
            cashOutTaxRate: JBConstants.MAX_CASH_OUT_TAX_RATE / 2, //50%
            weightCurrency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
            pausePay: false,
            pauseCreditTransfers: false,
            allowOwnerMinting: false,
            allowSetCustomToken: false,
            allowTerminalMigration: false,
            allowSetTerminals: false,
            ownerMustSendPayouts: false,
            allowSetController: false,
            allowAddAccountingContext: true,
            allowAddPriceFeed: false,
            holdFees: false,
            useTotalSurplusForCashOuts: true,
            useDataHookForPay: false,
            useDataHookForCashOut: false,
            dataHook: address(0),
            metadata: 0
        });

        uint256 _packedMetadata = JBRulesetMetadataResolver.packRulesetMetadata(_metadata);

        JBRuleset memory data = JBRuleset({
            cycleNumber: 1,
            id: uint48(block.timestamp),
            basedOnId: 0,
            start: uint48(block.timestamp),
            duration: 8000,
            weight: 5000,
            weightCutPercent: 0,
            approvalHook: IJBRulesetApprovalHook(address(0x1234567890123456789012345678901234567890)),
            metadata: _packedMetadata
        });

        // mock call to rulesets
        mockExpect(address(rulesets), abi.encodeCall(IJBRulesets.currentOf, (_projectId)), abi.encode(data));

        // mock call to isTerminalOf
        mockExpect(
            address(directory),
            abi.encodeCall(IJBDirectory.isTerminalOf, (_projectId, IJBTerminal(address(this)))),
            abi.encode(false)
        );

        vm.expectRevert(JBController.JBController_MintNotAllowedAndNotTerminalOrHook.selector);

        _controller.mintTokensOf({
            projectId: _projectId,
            tokenCount: 1,
            beneficiary: address(this),
            memo: "",
            useReservedPercent: true
        });
    }

    function test_RevertWhen_MintingIsDisabledInTheFundingCycleRuleset() external {
        // it should revert
    }

    modifier whenMintingIsEnabledInTheFundingCycleRuleset() {
        _;
    }

    function test_GivenThatThereAreTokensAvailableToMint() external whenMintingIsEnabledInTheFundingCycleRuleset {
        // it should be possible to mint
    }

    function test_GivenThatADataSourceIsConfigured() external whenMintingIsEnabledInTheFundingCycleRuleset {
        // it should be able to mint
    }

    function test_GivenThatADataSourceHasPermissionedAnotherContractToMint()
        external
        whenMintingIsEnabledInTheFundingCycleRuleset
    {
        // it should be able to mint
    }
}
