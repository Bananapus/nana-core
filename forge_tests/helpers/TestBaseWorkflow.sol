// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "forge-std/Test.sol";

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Metadata} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC165, IERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {JBController} from "@juicebox/JBController.sol";
import {JBDirectory} from "@juicebox/JBDirectory.sol";
import {JBTerminalStore} from "@juicebox/JBTerminalStore.sol";
import {JBFundAccessLimits} from "@juicebox/JBFundAccessLimits.sol";
import {JBRulesets} from "@juicebox/JBRulesets.sol";
import {JBPermissions} from "@juicebox/JBPermissions.sol";
import {JBPrices} from "@juicebox/JBPrices.sol";
import {JBProjects} from "@juicebox/JBProjects.sol";
import {JBSplits} from "@juicebox/JBSplits.sol";
import {JBERC20} from "@juicebox/JBERC20.sol";
import {JBTokens} from "@juicebox/JBTokens.sol";
import {JBDeadline} from "@juicebox/JBDeadline.sol";
import {JBApprovalStatus} from "@juicebox/enums/JBApprovalStatus.sol";
import {JBMultiTerminal} from "@juicebox/JBMultiTerminal.sol";
import {JBCurrencyAmount} from "@juicebox/structs/JBCurrencyAmount.sol";
import {JBAccountingContextConfig} from "@juicebox/structs/JBAccountingContextConfig.sol";
import {JBDidPayData} from "@juicebox/structs/JBDidPayData.sol";
import {JBDidRedeemData} from "@juicebox/structs/JBDidRedeemData.sol";
import {JBFee} from "@juicebox/structs/JBFee.sol";
import {JBFees} from "@juicebox/libraries/JBFees.sol";
import {JBFundAccessLimitGroup} from "@juicebox/structs/JBFundAccessLimitGroup.sol";
import {JBRuleset} from "@juicebox/structs/JBRuleset.sol";
import {JBRulesetData} from "@juicebox/structs/JBRulesetData.sol";
import {JBRulesetMetadata} from "@juicebox/structs/JBRulesetMetadata.sol";
import {JBRulesetConfig} from "@juicebox/structs/JBRulesetConfig.sol";
import {JBSplitGroup} from "@juicebox/structs/JBSplitGroup.sol";
import {JBPermissionsData} from "@juicebox/structs/JBPermissionsData.sol";
import {JBPayParamsData} from "@juicebox/structs/JBPayParamsData.sol";
import {JBRedeemParamsData} from "@juicebox/structs/JBRedeemParamsData.sol";
import {JBSplit} from "@juicebox/structs/JBSplit.sol";
import {JBTerminalConfig} from "@juicebox/structs/JBTerminalConfig.sol";
import {JBPayHookPayload} from "@juicebox/structs/JBPayHookPayload.sol";
import {JBRedeemHookPayload} from "@juicebox/structs/JBRedeemHookPayload.sol";
import {JBTokenAmount} from "@juicebox/structs/JBTokenAmount.sol";
import {JBSplitHookPayload} from "@juicebox/structs/JBSplitHookPayload.sol";
import {IJBToken} from "@juicebox/interfaces/IJBToken.sol";
import {JBSingleAllowanceData} from "@juicebox/structs/JBSingleAllowanceData.sol";
import {IJBController} from "@juicebox/interfaces/IJBController.sol";
import {IJBMigratable} from "@juicebox/interfaces/IJBMigratable.sol";
import {IJBPermissions} from "@juicebox/interfaces/IJBPermissions.sol";
import {IJBTerminalStore} from "@juicebox/interfaces/IJBTerminalStore.sol";
import {IJBProjects} from "@juicebox/interfaces/IJBProjects.sol";
import {IJBRulesetApprovalHook} from "@juicebox/interfaces/IJBRulesetApprovalHook.sol";
import {IJBDirectory} from "@juicebox/interfaces/IJBDirectory.sol";
import {IJBRulesets} from "@juicebox/interfaces/IJBRulesets.sol";
import {IJBSplits} from "@juicebox/interfaces/IJBSplits.sol";
import {IJBTokens} from "@juicebox/interfaces/IJBTokens.sol";
import {IJBSplitHook} from "@juicebox/interfaces/IJBSplitHook.sol";
import {IJBPayHook} from "@juicebox/interfaces/IJBPayHook.sol";
import {IJBRulesetDataHook} from "@juicebox/interfaces/IJBRulesetDataHook.sol";
import {IJBRedeemHook} from "@juicebox/interfaces/IJBRedeemHook.sol";
import {IJBRulesetDataHook} from "@juicebox/interfaces/IJBRulesetDataHook.sol";
import {IJBMultiTerminal} from "@juicebox/interfaces/terminal/IJBMultiTerminal.sol";
import {IJBRedeemTerminal} from "@juicebox/interfaces/terminal/IJBRedeemTerminal.sol";
import {IJBPayoutTerminal} from "@juicebox/interfaces/terminal/IJBPayoutTerminal.sol";
import {IJBPermitTerminal} from "@juicebox/interfaces/terminal/IJBPermitTerminal.sol";
import {IJBFeeTerminal} from "@juicebox/interfaces/terminal/IJBFeeTerminal.sol";
import {IJBTerminal} from "@juicebox/interfaces/terminal/IJBTerminal.sol";
import {IJBPriceFeed} from "@juicebox/interfaces/IJBPriceFeed.sol";
import {IJBPermissioned} from "@juicebox/interfaces/IJBPermissioned.sol";
import {IJBRulesetApprovalHook} from "@juicebox/interfaces/IJBRulesetApprovalHook.sol";
import {IJBPrices} from "@juicebox/interfaces/IJBPrices.sol";

import {JBConstants} from "@juicebox/libraries/JBConstants.sol";
import {JBCurrencyIds} from "@juicebox/libraries/JBCurrencyIds.sol";
import {JBTokenStandards} from "@juicebox/libraries/JBTokenStandards.sol";
import {JBRulesetMetadataResolver} from "@juicebox/libraries/JBRulesetMetadataResolver.sol";
import {JBSplitGroupIds} from "@juicebox/libraries/JBSplitGroupIds.sol";
import {JBPermissionIds} from "@juicebox/libraries/JBPermissionIds.sol";
import {JBPermissionIds} from "@juicebox/libraries/JBPermissionIds.sol";

import {IPermit2, IAllowanceTransfer} from "@permit2/src/src/interfaces/IPermit2.sol";
import {DeployPermit2} from "@permit2/src/test/utils/DeployPermit2.sol";

import {MetadataResolverHelper} from "./MetadataResolverHelper.sol";

import {MockERC20} from "./../mock/MockERC20.sol";

import "@paulrberg/contracts/math/PRBMath.sol";
import "@paulrberg/contracts/math/PRBMathUD60x18.sol";

// Base contract for Juicebox system tests.
// Provides common functionality, such as deploying contracts on test setup.
contract TestBaseWorkflow is Test, DeployPermit2 {
    // Multisig address used for testing.
    address private _multisig = address(123);
    address private _beneficiary = address(69_420);
    address private _trustedForwarder = address(123_456);
    MockERC20 private _usdcToken;
    address private _permit2;
    JBPermissions private _jbPermissions;
    JBProjects private _jbProjects;
    JBPrices private _jbPrices;
    JBDirectory private _jbDirectory;
    JBRulesets private _jbRulesets;
    JBTokens private _jbTokens;
    JBSplits private _jbSplits;
    JBController private _jbController;
    JBFundAccessLimits private _jbFundAccessLimits;
    JBTerminalStore private _jbTerminalStore;
    JBMultiTerminal private _jbMultiTerminal;
    MetadataResolverHelper private _metadataHelper;
    JBMultiTerminal private _jbMultiTerminal2;

    function multisig() internal view returns (address) {
        return _multisig;
    }

    function beneficiary() internal view returns (address) {
        return _beneficiary;
    }

    function usdcToken() internal view returns (MockERC20) {
        return _usdcToken;
    }

    function permit2() internal view returns (IPermit2) {
        return IPermit2(_permit2);
    }

    function jbPermissions() internal view returns (JBPermissions) {
        return _jbPermissions;
    }

    function jbProjects() internal view returns (JBProjects) {
        return _jbProjects;
    }

    function jbPrices() internal view returns (JBPrices) {
        return _jbPrices;
    }

    function jbDirectory() internal view returns (JBDirectory) {
        return _jbDirectory;
    }

    function jbRulesets() internal view returns (JBRulesets) {
        return _jbRulesets;
    }

    function jbTokens() internal view returns (JBTokens) {
        return _jbTokens;
    }

    function jbSplits() internal view returns (JBSplits) {
        return _jbSplits;
    }

    function jbController() internal view returns (JBController) {
        return _jbController;
    }

    function jbAccessConstraintStore() internal view returns (JBFundAccessLimits) {
        return _jbFundAccessLimits;
    }

    function jbTerminalStore() internal view returns (JBTerminalStore) {
        return _jbTerminalStore;
    }

    function jbMultiTerminal() internal view returns (JBMultiTerminal) {
        return _jbMultiTerminal;
    }

    function jbMultiTerminal2() internal view returns (JBMultiTerminal) {
        return _jbMultiTerminal2;
    }

    function metadataHelper() internal view returns (MetadataResolverHelper) {
        return _metadataHelper;
    }

    //*********************************************************************//
    // --------------------------- test setup ---------------------------- //
    //*********************************************************************//

    // Deploys and initializes contracts for testing.
    function setUp() public virtual {
        _jbPermissions = new JBPermissions();
        _jbProjects = new JBProjects(_multisig);
        _jbPrices = new JBPrices(_jbPermissions, _jbProjects, _multisig);
        _jbDirectory = new JBDirectory(_jbPermissions, _jbProjects, _multisig);
        _jbTokens = new JBTokens(_jbDirectory);
        _jbRulesets = new JBRulesets(_jbDirectory);
        _jbSplits = new JBSplits(_jbDirectory);
        _jbFundAccessLimits = new JBFundAccessLimits(_jbDirectory);

        _usdcToken = new MockERC20("USDC", "USDC");

        _jbController = new JBController(
            _jbPermissions,
            _jbProjects,
            _jbDirectory,
            _jbRulesets,
            _jbTokens,
            _jbSplits,
            _jbFundAccessLimits,
            _trustedForwarder
        );

        _metadataHelper = new MetadataResolverHelper();

        vm.prank(_multisig);
        _jbDirectory.setIsAllowedToSetFirstController(address(_jbController), true);

        _jbTerminalStore = new JBTerminalStore(_jbDirectory, _jbRulesets, _jbPrices);

        vm.prank(_multisig);
        _permit2 = deployPermit2();

        _jbMultiTerminal = new JBMultiTerminal(
            _jbPermissions,
            _jbProjects,
            _jbDirectory,
            _jbSplits,
            _jbTerminalStore,
            IPermit2(_permit2),
            _trustedForwarder,
            _multisig
        );
        _jbMultiTerminal2 = new JBMultiTerminal(
            _jbPermissions,
            _jbProjects,
            _jbDirectory,
            _jbSplits,
            _jbTerminalStore,
            IPermit2(_permit2),
            _trustedForwarder,
            _multisig
        );

        vm.label(_multisig, "projectOwner");
        vm.label(_beneficiary, "beneficiary");
        vm.label(address(_jbPrices), "JBPrices");
        vm.label(address(_jbProjects), "JBProjects");
        vm.label(address(_jbRulesets), "JBRulesets");
        vm.label(address(_jbDirectory), "JBDirectory");
        vm.label(address(_usdcToken), "ERC20");
        vm.label(address(_jbPermissions), "JBPermissions");
        vm.label(address(_jbTokens), "JBTokens");
        vm.label(address(_jbFundAccessLimits), "JBFundAccessLimits");
        vm.label(address(_jbSplits), "JBSplits");
        vm.label(address(_jbController), "JBController");
        vm.label(address(_jbTerminalStore), "JBTerminalStore");
        vm.label(address(_jbMultiTerminal2), "JBMultiTerminal2");
        vm.label(address(_jbMultiTerminal), "JBMultiTerminal");
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

    function strEqual(string memory a, string memory b) internal pure returns (bool) {
        return keccak256(abi.encode(a)) == keccak256(abi.encode(b));
    }
}
