// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {JBFundingCycleData} from './JBFundingCycleData.sol';
import {JBFundingCycleMetadata3_2} from './JBFundingCycleMetadata3_2.sol';
import {JBGroupedSplits} from './JBGroupedSplits.sol';
import {JBFundAccessConstraints} from './JBFundAccessConstraints.sol';

/// @custom:member mustStartAtOrAfter The time before which the configured funding cycle cannot start.
/// @custom:member data Data that defines the project's funding cycle. These properties will remain fixed for the duration of the funding cycle.
/// @custom:member metadata Metadata specifying the controller specific params that a funding cycle can have. These properties will remain fixed for the duration of the funding cycle.
/// @custom:member groupedSplits An array of splits to set for any number of groups while the funding cycle configuration is active.
/// @custom:member fundAccessConstraints An array containing amounts that a project can use from its treasury for each payment terminal while the funding cycle configuration is active. Amounts are fixed point numbers using the same number of decimals as the accompanying terminal. The `_distributionLimit` and `_overflowAllowance` parameters must fit in a `uint232`.
struct JBFundingCycleConfiguration {
  uint256 mustStartAtOrAfter;
  JBFundingCycleData data;
  JBFundingCycleMetadata3_2 metadata;
  JBGroupedSplits[] groupedSplits;
  JBFundAccessConstraints[] fundAccessConstraints;
}
