/// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {IJBDirectory, IJBPermissions, IJBPriceFeed, IJBPrices, IJBProjects, JBPermissionIds, JBPermissioned, JBPrices, Ownable, mulDiv} from 'src/JBPrices.sol';
import {Ownable} from 'lib/openzeppelin-contracts/contracts/access/Ownable.sol';
import {JBPermissioned} from 'src/abstract/JBPermissioned.sol';
import {mulDiv} from 'lib/prb-math/src/Common.sol';
import {IJBPriceFeed} from 'src/interfaces/IJBPriceFeed.sol';
import {IJBProjects} from 'src/interfaces/IJBProjects.sol';
import {IJBPermissions} from 'src/interfaces/IJBPermissions.sol';
import {IJBPrices} from 'src/interfaces/IJBPrices.sol';
import {IJBDirectory} from 'src/interfaces/IJBDirectory.sol';
import {JBPermissionIds} from 'src/libraries/JBPermissionIds.sol';

contract MockJBPrices is JBPrices, Test {

  constructor(IJBPermissions permissions, IJBProjects projects, address owner) JBPrices(permissions, projects, owner) {}
  /// Mocked State Variables
  function set_priceFeedFor(uint256 _key0, uint256 _key1, uint256 _key2, IJBPriceFeed _value) public {
    priceFeedFor[_key0][_key1][_key2] = _value;
  }
  
  function mock_call_priceFeedFor(uint256 _key0, uint256 _key1, uint256 _key2, IJBPriceFeed _value) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("priceFeedFor(uint256,uint256,uint256)", _key0, _key1, _key2),
      abi.encode(_value)
    );
  }
  
  /// Mocked External Functions
  function mock_call_pricePerUnitOf(uint256 projectId, uint256 pricingCurrency, uint256 unitCurrency, uint256 decimals, uint256 _return0) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("pricePerUnitOf(uint256,uint256,uint256,uint256)", projectId, pricingCurrency, unitCurrency, decimals),
      abi.encode(_return0)
    );
  }
  
  function mock_call_addPriceFeedFor(uint256 projectId, uint256 pricingCurrency, uint256 unitCurrency, IJBPriceFeed feed) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("addPriceFeedFor(uint256,uint256,uint256,IJBPriceFeed)", projectId, pricingCurrency, unitCurrency, feed),
      abi.encode()
    );
  }
  
  /// Mocked Internal Functions

}
