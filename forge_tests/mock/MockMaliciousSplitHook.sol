// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import /* {*} from */ "../helpers/TestBaseWorkflow.sol";

import {ERC165, IERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";

contract MockMaliciousSplitHook is ERC165, IJBSplitHook {
    error NopeNotGonnaDoIt();

    uint256 revertMode;

    function process(JBSplitHookPayload calldata _data) external payable override {
        _data;
        if (revertMode == 0) {
            revert();
        } else if (revertMode == 1) {
            revert NopeNotGonnaDoIt();
        } else if (revertMode == 2) {
            require(false, "thanks no thanks");
        } else {
            uint256 a = 3;
            uint256 b = 6;
            uint256 c = a - b;
            c;
        }
    }

    function setRevertMode(uint256 _newMode) external {
        revertMode = _newMode;
    }

    function supportsInterface(bytes4 _interfaceId)
        public
        view
        override(IERC165, ERC165)
        returns (bool)
    {
        return
            _interfaceId == type(IJBSplitHook).interfaceId || super.supportsInterface(_interfaceId);
    }
}

contract GasGussler {
    fallback() external payable {
        while (true) {}
    }
}
