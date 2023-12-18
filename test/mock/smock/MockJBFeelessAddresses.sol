/// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {ERC165, IERC165, IJBFeelessAddresses, JBFeelessAddresses, Ownable} from 'src/JBFeelessAddresses.sol';
import {Ownable} from 'lib/openzeppelin-contracts/contracts/access/Ownable.sol';
import {ERC165} from 'lib/openzeppelin-contracts/contracts/utils/introspection/ERC165.sol';
import {IERC165} from 'lib/openzeppelin-contracts/contracts/utils/introspection/IERC165.sol';
import {IJBFeelessAddresses} from 'src/interfaces/IJBFeelessAddresses.sol';

contract MockJBFeelessAddresses is JBFeelessAddresses, Test {

  constructor(address owner) JBFeelessAddresses(owner) {}
  /// Mocked State Variables
  function set_isFeeless(address _key0, bool _value) public {
    isFeeless[_key0] = _value;
  }
  
  function mock_call_isFeeless(address _key0, bool _value) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("isFeeless(address)", _key0),
      abi.encode(_value)
    );
  }
  
  /// Mocked External Functions
  function mock_call_supportsInterface(bytes4 interfaceId, bool _return0) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("supportsInterface(bytes4)", interfaceId),
      abi.encode(_return0)
    );
  }
  
  function mock_call_setFeelessAddress(address addr, bool flag) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("setFeelessAddress(address,bool)", addr, flag),
      abi.encode()
    );
  }
  
  /// Mocked Internal Functions

}
