// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "forge-std/Test.sol";

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Metadata} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC165, IERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {JBPermissionIds} from "@bananapus/permission-ids/src/JBPermissionIds.sol";
import {JBControlled} from "../../src/abstract/JBControlled.sol";
import {JBPermissioned} from "../../src/abstract/JBPermissioned.sol";
import {JBController} from "../../src/JBController.sol";
import {JBDirectory} from "../../src/JBDirectory.sol";
import {JBTerminalStore} from "../../src/JBTerminalStore.sol";
import {JBFeelessAddresses} from "../../src/JBFeelessAddresses.sol";
import {JBFundAccessLimits} from "../../src/JBFundAccessLimits.sol";
import {JBRulesets} from "../../src/JBRulesets.sol";
import {JBPermissions} from "../../src/JBPermissions.sol";
import {JBPrices} from "../../src/JBPrices.sol";
import {JBProjects} from "../../src/JBProjects.sol";
import {JBSplits} from "../../src/JBSplits.sol";
import {JBERC20} from "../../src/JBERC20.sol";
import {JBTokens} from "../../src/JBTokens.sol";
import {JBDeadline} from "../../src/JBDeadline.sol";
import {JBApprovalStatus} from "../../src/enums/JBApprovalStatus.sol";
import {JBMultiTerminal} from "../../src/JBMultiTerminal.sol";
import {JBAccountingContext} from "../../src/structs/JBAccountingContext.sol";
import {JBCurrencyAmount} from "../../src/structs/JBCurrencyAmount.sol";
import {JBAfterPayRecordedContext} from "../../src/structs/JBAfterPayRecordedContext.sol";
import {JBAfterCashOutRecordedContext} from "../../src/structs/JBAfterCashOutRecordedContext.sol";
import {JBFee} from "../../src/structs/JBFee.sol";
import {JBFees} from "../../src/libraries/JBFees.sol";
import {JBMetadataResolver} from "../../src/libraries/JBMetadataResolver.sol";
import {JBCashOuts} from "../../src/libraries/JBCashOuts.sol";
import {JBFundAccessLimitGroup} from "../../src/structs/JBFundAccessLimitGroup.sol";
import {JBRuleset} from "../../src/structs/JBRuleset.sol";
import {JBRulesetWithMetadata} from "../../src/structs/JBRulesetWithMetadata.sol";
import {JBRulesetMetadata} from "../../src/structs/JBRulesetMetadata.sol";
import {JBRulesetConfig} from "../../src/structs/JBRulesetConfig.sol";
import {JBSplitGroup} from "../../src/structs/JBSplitGroup.sol";
import {JBPermissionsData} from "../../src/structs/JBPermissionsData.sol";
import {JBBeforePayRecordedContext} from "../../src/structs/JBBeforePayRecordedContext.sol";
import {JBBeforeCashOutRecordedContext} from "../../src/structs/JBBeforeCashOutRecordedContext.sol";
import {JBSplit} from "../../src/structs/JBSplit.sol";
import {JBTerminalConfig} from "../../src/structs/JBTerminalConfig.sol";
import {JBPayHookSpecification} from "../../src/structs/JBPayHookSpecification.sol";
import {JBCashOutHookSpecification} from "../../src/structs/JBCashOutHookSpecification.sol";
import {JBTokenAmount} from "../../src/structs/JBTokenAmount.sol";
import {JBSplitHookContext} from "../../src/structs/JBSplitHookContext.sol";
import {IJBToken} from "../../src/interfaces/IJBToken.sol";
import {JBSingleAllowance} from "../../src/structs/JBSingleAllowance.sol";
import {IJBController} from "../../src/interfaces/IJBController.sol";
import {IJBFeelessAddresses} from "../../src/interfaces/IJBFeelessAddresses.sol";
import {IJBFundAccessLimits} from "../../src/interfaces/IJBFundAccessLimits.sol";
import {IJBMigratable} from "../../src/interfaces/IJBMigratable.sol";
import {IJBPermissions} from "../../src/interfaces/IJBPermissions.sol";
import {IJBDirectoryAccessControl} from "../../src/interfaces/IJBDirectoryAccessControl.sol";
import {IJBTerminalStore} from "../../src/interfaces/IJBTerminalStore.sol";
import {IJBProjects} from "../../src/interfaces/IJBProjects.sol";
import {IJBRulesetApprovalHook} from "../../src/interfaces/IJBRulesetApprovalHook.sol";
import {IJBDirectory} from "../../src/interfaces/IJBDirectory.sol";
import {IJBRulesets} from "../../src/interfaces/IJBRulesets.sol";
import {IJBSplits} from "../../src/interfaces/IJBSplits.sol";
import {IJBTokenUriResolver} from "../../src/interfaces/IJBTokenUriResolver.sol";
import {IJBTokens} from "../../src/interfaces/IJBTokens.sol";
import {IJBSplitHook} from "../../src/interfaces/IJBSplitHook.sol";
import {IJBPayHook} from "../../src/interfaces/IJBPayHook.sol";
import {IJBRulesetDataHook} from "../../src/interfaces/IJBRulesetDataHook.sol";
import {IJBCashOutHook} from "../../src/interfaces/IJBCashOutHook.sol";
import {IJBRulesetDataHook} from "../../src/interfaces/IJBRulesetDataHook.sol";
import {IJBMultiTerminal} from "../../src/interfaces/IJBMultiTerminal.sol";
import {IJBCashOutTerminal} from "../../src/interfaces/IJBCashOutTerminal.sol";
import {IJBPayoutTerminal} from "../../src/interfaces/IJBPayoutTerminal.sol";
import {IJBPermitTerminal} from "../../src/interfaces/IJBPermitTerminal.sol";
import {IJBFeeTerminal} from "../../src/interfaces/IJBFeeTerminal.sol";
import {IJBTerminal} from "../../src/interfaces/IJBTerminal.sol";
import {IJBPriceFeed} from "../../src/interfaces/IJBPriceFeed.sol";
import {IJBPermissioned} from "../../src/interfaces/IJBPermissioned.sol";
import {IJBProjectUriRegistry} from "../../src/interfaces/IJBProjectUriRegistry.sol";
import {IJBRulesetApprovalHook} from "../../src/interfaces/IJBRulesetApprovalHook.sol";
import {IJBPrices} from "../../src/interfaces/IJBPrices.sol";

import {JBConstants} from "../../src/libraries/JBConstants.sol";
import {JBCurrencyIds} from "../../src/libraries/JBCurrencyIds.sol";
import {JBRulesetMetadataResolver} from "../../src/libraries/JBRulesetMetadataResolver.sol";
import {JBSplitGroupIds} from "../../src/libraries/JBSplitGroupIds.sol";

import {IPermit2, IAllowanceTransfer} from "@uniswap/permit2/src/interfaces/IPermit2.sol";
import {DeployPermit2} from "@uniswap/permit2/test/utils/DeployPermit2.sol";

import {JBTest} from "./JBTest.sol";
import {MetadataResolverHelper} from "./MetadataResolverHelper.sol";

import {MockERC20} from "./../mock/MockERC20.sol";

import {mulDiv} from "@prb/math/src/Common.sol";
import {mul as UD60x18mul, wrap as UD60x18wrap, unwrap as UD60x18unwrap} from "@prb/math/src/UD60x18.sol";

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
    JBERC20 private _jbErc20;
    JBTokens private _jbTokens;
    JBSplits private _jbSplits;
    JBController private _jbController;
    JBFeelessAddresses private _jbFeelessAddresses;
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

    function jbErc20() internal view returns (JBERC20) {
        return _jbErc20;
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

    function jbFeelessAddresses() internal view returns (JBFeelessAddresses) {
        return _jbFeelessAddresses;
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
        _jbProjects = new JBProjects(_multisig, address(0));
        _jbDirectory = new JBDirectory(_jbPermissions, _jbProjects, _multisig);
        _jbErc20 = new JBERC20();
        _jbTokens = new JBTokens(_jbDirectory, _jbErc20);
        _jbRulesets = new JBRulesets(_jbDirectory);
        _jbPrices = new JBPrices(_jbDirectory, _jbPermissions, _jbProjects, _multisig);
        _jbSplits = new JBSplits(_jbDirectory);
        _jbFundAccessLimits = new JBFundAccessLimits(_jbDirectory);
        _jbFeelessAddresses = new JBFeelessAddresses(_multisig);

        _usdcToken = new MockERC20("USDC", "USDC");

        _jbController = new JBController(
            _jbDirectory,
            _jbFundAccessLimits,
            _jbPermissions,
            _jbPrices,
            _jbProjects,
            _jbRulesets,
            _jbSplits,
            _jbTokens,
            _trustedForwarder
        );

        _metadataHelper = new MetadataResolverHelper();

        vm.prank(_multisig);
        _jbDirectory.setIsAllowedToSetFirstController(address(_jbController), true);

        _jbTerminalStore = new JBTerminalStore(_jbDirectory, _jbPrices, _jbRulesets);

        vm.prank(_multisig);
        _permit2 = deployPermit2();

        _jbMultiTerminal = new JBMultiTerminal(
            _jbFeelessAddresses,
            _jbPermissions,
            _jbProjects,
            _jbSplits,
            _jbTerminalStore,
            _jbTokens,
            IPermit2(_permit2),
            _trustedForwarder
        );

        _jbMultiTerminal2 = new JBMultiTerminal(
            _jbFeelessAddresses,
            _jbPermissions,
            _jbProjects,
            _jbSplits,
            _jbTerminalStore,
            _jbTokens,
            IPermit2(_permit2),
            _trustedForwarder
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
        vm.label(address(_jbFeelessAddresses), "JBFeelessAddresses");
        vm.label(address(_jbFundAccessLimits), "JBFundAccessLimits");
        vm.label(address(_jbSplits), "JBSplits");
        vm.label(address(_jbController), "JBController");
        vm.label(address(_jbTerminalStore), "JBTerminalStore");
        vm.label(address(_jbMultiTerminal2), "JBMultiTerminal2");
        vm.label(address(_jbMultiTerminal), "JBMultiTerminal");
    }

    //https://ethereum.stackexchange.com/questions/24248/how-to-calculate-an-ethereum-contracts-address-during-its-creation-using-the-so
    function addressFrom(address _origin, uint256 _nonce) internal pure returns (address _address) {
        bytes memory data;
        if (_nonce == 0x00) {
            data = abi.encodePacked(bytes1(0xd6), bytes1(0x94), _origin, bytes1(0x80));
        } else if (_nonce <= 0x7f) {
            data = abi.encodePacked(bytes1(0xd6), bytes1(0x94), _origin, uint8(_nonce));
        } else if (_nonce <= 0xff) {
            data = abi.encodePacked(bytes1(0xd7), bytes1(0x94), _origin, bytes1(0x81), uint8(_nonce));
        } else if (_nonce <= 0xffff) {
            data = abi.encodePacked(bytes1(0xd8), bytes1(0x94), _origin, bytes1(0x82), uint16(_nonce));
        } else if (_nonce <= 0xffffff) {
            data = abi.encodePacked(bytes1(0xd9), bytes1(0x94), _origin, bytes1(0x83), uint24(_nonce));
        } else {
            data = abi.encodePacked(bytes1(0xda), bytes1(0x94), _origin, bytes1(0x84), uint32(_nonce));
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
