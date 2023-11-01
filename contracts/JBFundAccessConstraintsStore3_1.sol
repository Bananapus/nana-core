// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {ERC165} from '@openzeppelin/contracts/utils/introspection/ERC165.sol';
import {JBControllerUtility} from './abstract/JBControllerUtility.sol';
import {IJBFundAccessConstraintsStore3_1} from './interfaces/IJBFundAccessConstraintsStore3_1.sol';
import {IJBDirectory} from './interfaces/IJBDirectory.sol';
import {IJBPaymentTerminal} from './interfaces/IJBPaymentTerminal.sol';
import {JBFundAccessConstraints3_1} from './structs/JBFundAccessConstraints3_1.sol';
import {JBCurrencyAmount} from './structs/JBCurrencyAmount.sol';

/// @notice Information pertaining to how much funds can be accessed by a project from each payment terminal.
contract JBFundAccessConstraintsStore3_1 is
  JBControllerUtility,
  ERC165,
  IJBFundAccessConstraintsStore3_1
{
  //*********************************************************************//
  // --------------------------- custom errors ------------------------- //
  //*********************************************************************//

  error INVALID_DISTRIBUTION_LIMIT();
  error INVALID_DISTRIBUTION_LIMIT_CURRENCY();
  error INVALID_DISTRIBUTION_LIMIT_CURRENCY_ORDERING();
  error INVALID_OVERFLOW_ALLOWANCE();
  error INVALID_OVERFLOW_ALLOWANCE_CURRENCY();
  error INVALID_OVERFLOW_ALLOWANCE_CURRENCY_ORDERING();

  //*********************************************************************//
  // --------------------- internal stored properties ------------------ //
  //*********************************************************************//

  /// @notice Data regarding the distribution limits of a project during a configuration.
  /// @dev bits 0-231: The amount of token that a project can distribute per funding cycle.
  /// @dev bits 232-255: The currency of amount that a project can distribute.
  /// @custom:param _projectId The ID of the project to get the packed distribution limit data of.
  /// @custom:param _configuration The configuration during which the packed distribution limit data applies.
  /// @custom:param _terminal The terminal from which distributions are being limited.
  /// @custom:param _token The token for which distributions are being limited.
  mapping(uint256 => mapping(uint256 => mapping(IJBPaymentTerminal => mapping(address => uint256[]))))
    internal _packedDistributionLimitsDataOf;

  /// @notice Data regarding the overflow allowance of a project during a configuration.
  /// @dev bits 0-231: The amount of overflow that a project is allowed to tap into on-demand throughout the configuration.
  /// @dev bits 232-255: The currency of the amount of overflow that a project is allowed to tap.
  /// @custom:param _projectId The ID of the project to get the packed overflow allowance data of.
  /// @custom:param _configuration The configuration during which the packed overflow allowance data applies.
  /// @custom:param _terminal The terminal managing the overflow.
  /// @custom:param _token The token for which overflow is being allowed.
  mapping(uint256 => mapping(uint256 => mapping(IJBPaymentTerminal => mapping(address => uint256[]))))
    internal _packedOverflowAllowancesDataOf;

  //*********************************************************************//
  // ------------------------- external views -------------------------- //
  //*********************************************************************//

  /// @notice The amounts of token that a project can distribute per funding cycle, and the currencies they're in terms of.
  /// @dev The number of decimals in the returned fixed point amount is the same as that of the specified terminal.
  /// @param _projectId The ID of the project to get the distribution limit of.
  /// @param _configuration The configuration during which the distribution limit applies.
  /// @param _terminal The terminal from which distributions are being limited.
  /// @param _token The token for which the distribution limit applies.
  /// @return distributionLimits The distribution limits.
  function distributionLimitsOf(
    uint256 _projectId,
    uint256 _configuration,
    IJBPaymentTerminal _terminal,
    address _token
  ) external view override returns (JBCurrencyAmount[] memory distributionLimits) {
    // Get a reference to the packed data.
    uint256[] memory _packedDistributionLimitsData = _packedDistributionLimitsDataOf[_projectId][
      _configuration
    ][_terminal][_token];

    // Get a reference to the number of distribution limits.
    uint256 _numberOfData = _packedDistributionLimitsData.length;

    // Initialize the return value.
    distributionLimits = new JBCurrencyAmount[](_numberOfData);

    // Keep a reference to the data that'll be iterated.
    uint256 _packedDistributionLimitData;

    // Iterate through the stored packed values and format the returned value.
    for (uint256 _i; _i < _numberOfData; ) {
      // Set the data being iterated on.
      _packedDistributionLimitData = _packedDistributionLimitsData[_i];

      // The limit is in bits 0-231. The currency is in bits 232-255.
      distributionLimits[_i] = JBCurrencyAmount({
        currency: _packedDistributionLimitData >> 232,
        value: uint256(uint232(_packedDistributionLimitData))
      });

      unchecked {
        ++_i;
      }
    }
  }

  /// @notice The amounts of token that a project can distribute per funding cycle, for any currency.
  /// @dev The number of decimals in the returned fixed point amount is the same as that of the specified terminal.
  /// @param _projectId The ID of the project to get the distribution limit of.
  /// @param _configuration The configuration during which the distribution limit applies.
  /// @param _terminal The terminal from which distributions are being limited.
  /// @param _token The token for which the distribution limit applies.
  /// @param _currency The currency to get the distribution limit of.
  /// @return distributionLimit The distribution limit, as a fixed point number with the same number of decimals as the provided terminal.
  function distributionLimitOf(
    uint256 _projectId,
    uint256 _configuration,
    IJBPaymentTerminal _terminal,
    address _token,
    uint256 _currency
  ) external view override returns (uint256 distributionLimit) {
    // Get a reference to the packed data.
    uint256[] memory _data = _packedDistributionLimitsDataOf[_projectId][_configuration][_terminal][
      _token
    ];

    // Get a reference to the number of distribution limits.
    uint256 _numberOfData = _data.length;

    // Keep a reference to the data that'll be iterated.
    uint256 _packedDistributionLimitData;

    // Iterate through the stored packed values and return the value of the matching currency.
    for (uint256 _i; _i < _numberOfData; ) {
      // Set the data being iterated on.
      _packedDistributionLimitData = _data[_i];

      // If the currencies match, return the value.
      if (_currency == _packedDistributionLimitData >> 232)
        return uint256(uint232(_packedDistributionLimitData));

      unchecked {
        ++_i;
      }
    }
  }

  /// @notice The amounts of overflow that a project is allowed to tap into on-demand throughout a configuration, and the currencies they're in terms of.
  /// @dev The number of decimals in the returned fixed point amount is the same as that of the specified terminal.
  /// @param _projectId The ID of the project to get the overflow allowance of.
  /// @param _configuration The configuration of the during which the allowance applies.
  /// @param _terminal The terminal managing the overflow.
  /// @param _token The token for which the overflow allowance applies.
  /// @return overflowAllowances The overflow allowances.
  function overflowAllowancesOf(
    uint256 _projectId,
    uint256 _configuration,
    IJBPaymentTerminal _terminal,
    address _token
  ) external view override returns (JBCurrencyAmount[] memory overflowAllowances) {
    // Get a reference to the packed data.
    uint256[] memory _packedOverflowAllowancesData = _packedOverflowAllowancesDataOf[_projectId][
      _configuration
    ][_terminal][_token];

    // Get a reference to the number of overflow allowances.
    uint256 _numberOfData = _packedOverflowAllowancesData.length;

    // Initialize the return value.
    overflowAllowances = new JBCurrencyAmount[](_numberOfData);

    // Keep a reference to the data that'll be iterated.
    uint256 _packedOverflowAllowanceData;

    // Iterate through the stored packed values and format the returned value.
    for (uint256 _i; _i < _numberOfData; ) {
      // Set the data being iterated on.
      _packedOverflowAllowanceData = _packedOverflowAllowancesData[_i];

      // The limit is in bits 0-231. The currency is in bits 232-255.
      overflowAllowances[_i] = JBCurrencyAmount({
        currency: _packedOverflowAllowanceData >> 232,
        value: uint256(uint232(_packedOverflowAllowanceData))
      });

      unchecked {
        ++_i;
      }
    }
  }

  /// @notice The amounts of overflow that a project is allowed to tap into on-demand throughout a configuration, for any currency.
  /// @dev The number of decimals in the returned fixed point amount is the same as that of the specified terminal.
  /// @param _projectId The ID of the project to get the overflow allowance of.
  /// @param _configuration The configuration of the during which the allowance applies.
  /// @param _terminal The terminal managing the overflow.
  /// @param _token The token for which the overflow allowance applies.
  /// @param _currency The currency to get the overflow allowance of.
  /// @return overflowAllowance The overflow allowance, as a fixed point number with the same number of decimals as the provided terminal.
  function overflowAllowanceOf(
    uint256 _projectId,
    uint256 _configuration,
    IJBPaymentTerminal _terminal,
    address _token,
    uint256 _currency
  ) external view override returns (uint256 overflowAllowance) {
    // Get a reference to the packed data.
    uint256[] memory _data = _packedOverflowAllowancesDataOf[_projectId][_configuration][_terminal][
      _token
    ];

    // Get a reference to the number of overflow allowances.
    uint256 _numberOfData = _data.length;

    // Keep a reference to the data that'll be iterated.
    uint256 _packedOverflowAllowanceData;

    // Iterate through the stored packed values and format the returned value.
    for (uint256 _i; _i < _numberOfData; ) {
      // Set the data being iterated on.
      _packedOverflowAllowanceData = _data[_i];

      // If the currencies match, return the value.
      if (_currency == _packedOverflowAllowanceData >> 232)
        return uint256(uint232(_packedOverflowAllowanceData));

      unchecked {
        ++_i;
      }
    }
  }

  //*********************************************************************//
  // -------------------------- constructor ---------------------------- //
  //*********************************************************************//

  /// @param _directory A contract storing directories of terminals and controllers for each project.
  // solhint-disable-next-line no-empty-blocks
  constructor(IJBDirectory _directory) JBControllerUtility(_directory) {}

  //*********************************************************************//
  // --------------------- external transactions ----------------------- //
  //*********************************************************************//

  /// @notice Sets a project's constraints for accessing treasury funds.
  /// @dev Only a project's current controller can set its fund access constraints.
  /// @dev Distribution limits and overflow allowances must be specified in increasing order by currencies to prevent duplicates.
  /// @param _projectId The ID of the project whose fund access constraints are being set.
  /// @param _configuration The funding cycle configuration the constraints apply within.
  /// @param _fundAccessConstraints An array containing amounts that a project can use from its treasury for each payment terminal. Amounts are fixed point numbers using the same number of decimals as the accompanying terminal. The `_distributionLimit` and `_overflowAllowance` parameters must fit in a `uint232`.
  function setFor(
    uint256 _projectId,
    uint256 _configuration,
    JBFundAccessConstraints3_1[] calldata _fundAccessConstraints
  ) external override onlyController(_projectId) {
    // Save the number of constraints.
    uint256 _numberOfFundAccessConstraints = _fundAccessConstraints.length;

    // Keep a reference to the fund access constraint being iterated on.
    JBFundAccessConstraints3_1 memory _constraints;

    // Set distribution limits if there are any.
    for (uint256 _i; _i < _numberOfFundAccessConstraints; ) {
      // Set the constraints being iterated on.
      _constraints = _fundAccessConstraints[_i];

      // Keep a reference to the number of distribution limits.
      uint256 _numberOfDistributionLimits = _constraints.distributionLimits.length;

      // Keep a reference to the distribution limit being iterated on.
      JBCurrencyAmount memory _distributionLimit;

      // Iterate through each distribution limit to validate and store them.
      for (uint256 _j; _j < _numberOfDistributionLimits; ) {
        // Set the distribution limit being iterated on.
        _distributionLimit = _constraints.distributionLimits[_j];

        // If distribution limit value is larger than 232 bits, revert.
        if (_distributionLimit.value > type(uint232).max) revert INVALID_DISTRIBUTION_LIMIT();

        // If distribution limit currency value is larger than 24 bits, revert.
        if (_distributionLimit.currency > type(uint24).max)
          revert INVALID_DISTRIBUTION_LIMIT_CURRENCY();

        // Make sure the distribution limits are passed in increasing order of currency to prevent duplicates.
        if (
          _j != 0 && _distributionLimit.currency <= _constraints.distributionLimits[_j - 1].currency
        ) revert INVALID_DISTRIBUTION_LIMIT_CURRENCY_ORDERING();

        // Set the distribution limit if there is one.
        if (_distributionLimit.value > 0)
          _packedDistributionLimitsDataOf[_projectId][_configuration][
            _fundAccessConstraints[_i].terminal
          ][_fundAccessConstraints[_i].token].push(
              _distributionLimit.value | (_distributionLimit.currency << 232)
            );

        unchecked {
          ++_j;
        }
      }

      // Keep a reference to the number of overflow allowances.
      uint256 _numberOfOverflowAllowances = _constraints.overflowAllowances.length;

      // Keep a reference to the overflow allowances being iterated on.
      JBCurrencyAmount memory _overflowAllowance;

      // Iterate through each overflow allowance to validate and store them.
      for (uint256 _j; _j < _numberOfOverflowAllowances; ) {
        // Set the distribution limit being iterated on.
        _overflowAllowance = _constraints.overflowAllowances[_j];

        // If overflow allowance value is larger than 232 bits, revert.
        if (_overflowAllowance.value > type(uint232).max) revert INVALID_OVERFLOW_ALLOWANCE();

        // If overflow allowance currency value is larger than 24 bits, revert.
        if (_overflowAllowance.currency > type(uint24).max)
          revert INVALID_OVERFLOW_ALLOWANCE_CURRENCY();

        // Make sure the overflow allowances are passed in increasing order of currency to prevent duplicates.
        if (
          _j != 0 && _overflowAllowance.currency <= _constraints.overflowAllowances[_j - 1].currency
        ) revert INVALID_OVERFLOW_ALLOWANCE_CURRENCY_ORDERING();

        // Set the overflow allowance if there is one.
        if (_overflowAllowance.value > 0)
          _packedOverflowAllowancesDataOf[_projectId][_configuration][
            _fundAccessConstraints[_i].terminal
          ][_fundAccessConstraints[_i].token].push(
              _overflowAllowance.value | (_overflowAllowance.currency << 232)
            );

        unchecked {
          ++_j;
        }
      }

      emit SetFundAccessConstraints(_configuration, _projectId, _constraints, msg.sender);

      unchecked {
        ++_i;
      }
    }
  }
}
