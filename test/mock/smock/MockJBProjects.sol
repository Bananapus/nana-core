/// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {EIP712, ERC721, ERC721Votes, IERC165, IJBProjects, IJBTokenUriResolver, JBProjects, Ownable} from 'src/JBProjects.sol';
import {Ownable} from 'lib/openzeppelin-contracts/contracts/access/Ownable.sol';
import {ERC721Votes} from 'lib/openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721Votes.sol';
import {ERC721} from 'lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol';
import {EIP712} from 'lib/openzeppelin-contracts/contracts/utils/cryptography/EIP712.sol';
import {IERC165} from 'lib/openzeppelin-contracts/contracts/utils/introspection/IERC165.sol';
import {IJBProjects} from 'src/interfaces/IJBProjects.sol';
import {IJBTokenUriResolver} from 'src/interfaces/IJBTokenUriResolver.sol';

contract MockJBProjects is JBProjects, Test {

  constructor(address owner) JBProjects(owner) {}
  /// Mocked State Variables
  function set_count(uint256 _count) public {
    count = _count;
  }
  
  function mock_call_count(uint256 _count) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("count()"),
      abi.encode(_count)
    );
  }
  
  function set_tokenUriResolver(IJBTokenUriResolver _tokenUriResolver) public {
    tokenUriResolver = _tokenUriResolver;
  }
  
  function mock_call_tokenUriResolver(IJBTokenUriResolver _tokenUriResolver) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("tokenUriResolver()"),
      abi.encode(_tokenUriResolver)
    );
  }
  
  /// Mocked External Functions
  function mock_call_tokenURI(uint256 projectId, string memory _return0) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("tokenURI(uint256)", projectId),
      abi.encode(_return0)
    );
  }
  
  function mock_call_supportsInterface(bytes4 interfaceId, bool _return0) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("supportsInterface(bytes4)", interfaceId),
      abi.encode(_return0)
    );
  }
  
  function mock_call_createFor(address owner, uint256 projectId) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("createFor(address)", owner),
      abi.encode(projectId)
    );
  }
  
  function mock_call_setTokenUriResolver(IJBTokenUriResolver newResolver) public {
    vm.mockCall(
      address(this),
      abi.encodeWithSignature("setTokenUriResolver(IJBTokenUriResolver)", newResolver),
      abi.encode()
    );
  }
  
  /// Mocked Internal Functions

}
