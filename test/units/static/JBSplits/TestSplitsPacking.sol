// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "src/JBSplits.sol";
import "forge-std/Test.sol";

contract TestSplitsPacking_Local is JBSplits, Test {
    constructor() JBSplits(IJBDirectory(address(0))) {}

    function test_SplitsPacking(JBSplit calldata _split) external {
        // Ensure the split percentage is within bounds.
        vm.assume(_split.percent != 0 && _split.percent <= JBConstants.SPLITS_TOTAL_PERCENT);

        JBSplit[] memory _splits = new JBSplit[](1);
        _splits[0] = _split;

        _setSplitsOf(1, 1, 1, _splits);
        JBSplit memory _unpackedSplit = _getStructsFor(1, 1, 1)[0];

        assertEq(_split.percent, _unpackedSplit.percent, "Percent packing is lossy");
        assertEq(_split.projectId, _unpackedSplit.projectId, "Project ID packing is lossy");
        assertEq(_split.beneficiary, _unpackedSplit.beneficiary, "Beneficiary packing is lossy");
        assertEq(_split.preferAddToBalance, _unpackedSplit.preferAddToBalance, "preferAddToBalance packing is lossy");
        assertEq(_split.lockedUntil, _unpackedSplit.lockedUntil, "lockedUntil packing is lossy");
        assertEq(address(_split.hook), address(_unpackedSplit.hook), "hook packing is lossy");

        assertEq(
            keccak256(abi.encode(_split)),
            keccak256(abi.encode(_unpackedSplit)),
            "Packing and unpacking of a split is lossy"
        );
    }
}
