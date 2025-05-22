// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit, Nonces} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";

import {IJBToken} from "./interfaces/IJBToken.sol";
import {JBVestingSchedule} from "./structs/JBVestingSchedule.sol";

/// @notice An ERC-20 token that can be used by a project in `JBTokens` and `JBController`.
/// @dev By default, a project uses "credits" to track balances. Once a project sets their `IJBToken` using
/// `JBController.deployERC20For(...)` or `JBController.setTokenFor(...)`, credits can be redeemed to claim tokens.
/// @dev `JBController.deployERC20For(...)` deploys a `JBERC20` contract and sets it as the project's token.
contract JBVestedERC20 is ERC20Votes, ERC20Permit, Ownable, IJBToken {

    //*********************************************************************//
    // --------------------------- custom errors ------------------------- //
    //*********************************************************************//

    error JBVestedERC20_TransferExceedsVestedAmount(uint256 amount, uint256 vestedAmount);

    //*********************************************************************//
    // ---------------- public immutable stored properties --------------- //
    //*********************************************************************//

    /// @notice The number of seconds to wait before the tokens start to unlock.
    uint256 public immutable override CLIFF;

    /// @notice The number of seconds it takes to unlock the full amount of tokens.
    uint256 public immutable override UNLOCK_DURATION;

    /// @notice The project ID.
    uint256 public immutable override PROJECT_ID;

    /// @notice The JBTokens contract.
    IJBTokens public immutable override TOKENS;

    //*********************************************************************//
    // --------------------- internal stored properties ------------------ //
    //*********************************************************************//

    /// @notice The token's name.
    // slither-disable-next-line shadowing-state
    string private _name;

    /// @notice The token's symbol.
    // slither-disable-next-line shadowing-state
    string private _symbol;

    mapping(address => VestingSchedule[]) private _vestingSchedules;

    /// @notice Mapping of addresses exempt from vesting restrictions.
    mapping(address => bool) public isExemptFromVesting;

    /// @notice The admin address for managing vesting exemptions.
    address public vestingAdmin;

    //*********************************************************************//
    // -------------------------- events -------------------------------- //
    //*********************************************************************//
    event ExemptAddressAdded(address indexed account);
    event ExemptAddressRemoved(address indexed account);

    //*********************************************************************//
    // -------------------------- modifiers ----------------------------- //
    //*********************************************************************//
    modifier onlyVestingAdmin() {
        require(msg.sender == vestingAdmin, "NOT_ADMIN");
        _;
    }

    //*********************************************************************//
    // -------------------------- constructor ---------------------------- //
    //*********************************************************************//

    /// @param tokens A contract that manages token minting and burning.
    constructor(IJBTokens tokens) Ownable(address(this)) ERC20("invalid", "invalid") ERC20Permit("JBToken") {
        TOKENS = tokens;
    }

    //*********************************************************************//
    // -------------------------- public views --------------------------- //
    //*********************************************************************//

    /// @notice The balance of the given address.
    /// @dev Returns only the vested (available) amount, not the total tokens owned.
    /// @param account The account to get the balance of.
    /// @return The number of vested (available) tokens owned by the `account`, as a fixed point number with 18 decimals.
    function balanceOf(address account) public view override(ERC20, IJBToken) returns (uint256) {
        if (isExemptFromVesting[account]) {
            return super.balanceOf(account);
        }
        return super.balanceOf(account) - _vestingAmount(account);
    }

    /// @notice This token can only be added to a project when its created by the `JBTokens` contract.
    function canBeAddedTo(uint256 projectId) external pure override returns (bool) {
        return projectId == PROJECT_ID;
    }

    /// @notice The number of decimals used for this token's fixed point accounting.
    /// @return The number of decimals.
    function decimals() public view override(ERC20, IJBToken) returns (uint8) {
        return super.decimals();
    }

    /// @notice The token's name.
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /// @notice The token's symbol.
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /// @notice The total supply of this ERC20 i.e. the total number of tokens in existence.
    /// @return The total supply of this ERC20, as a fixed point number.
    function totalSupply() public view override(ERC20, IJBToken) returns (uint256) {
        return super.totalSupply();
    }

    /// @notice The total amount still vesting for an account.
    /// @param account The address to get the vesting amount for.
    /// @return The total amount still vesting for the `account`.
    function vestingAmount(address account) public view returns (uint256) {
        return _vestingAmount(account);
    } 

    /// @notice The total amount vested for an account.
    /// @param account The address to get the vested amount for.
    /// @return The total amount vested for the `account`.
    function vestedAmount(address account) public view returns (uint256) {
        return balanceOf(account) - _vestingAmount(account);
    } 

    //*********************************************************************//
    // ---------------------- external transactions ---------------------- //
    //*********************************************************************//

    /// @notice Burn some outstanding tokens.
    /// @dev Can only be called by this contract's owner.
    /// @param account The address to burn tokens from.
    /// @param amount The amount of tokens to burn, as a fixed point number with 18 decimals.
    function burn(address account, uint256 amount) external override onlyOwner {
        return _burn(account, amount);
    }

    /// @notice Mints more of this token with a new vesting schedule.
    /// @dev Can only be called by this contract's owner.
    /// @param account The address to mint the new tokens to.
    /// @param amount The amount of tokens to mint, as a fixed point number with 18 decimals.
    function mint(address account, uint256 amount) external override onlyOwner {
        _mint(account, amount);

        // Add a new vesting schedule for the minted tokens
        _vestingSchedules[account].push(VestingSchedule({
            totalAmount: amount,
            startTime: block.timestamp
        }));
    }

    //*********************************************************************//
    // ----------------------- public transactions ----------------------- //
    //*********************************************************************//

    /// @notice Initializes the token.
    /// @param name_ The token's name.
    /// @param symbol_ The token's symbol.
    /// @param owner The token contract's owner.
    /// @param projectId The project ID.
    /// @param cliff The number of seconds to wait before the tokens start to unlock.
    /// @param unlockDuration The number of seconds it takes to unlock the full amount of tokens.
    /// @param vestingAdmin_ The admin address for managing vesting exemptions.
    function initialize(string memory name_, string memory symbol_, address owner, uint256 projectId, uint256 cliff, uint256 unlockDuration, address vestingAdmin_) public override {
        // Prevent re-initialization by reverting if a name is already set or if the provided name is empty.
        if (bytes(_name).length != 0 || bytes(name_).length == 0) revert();

        _name = name_;
        _symbol = symbol_;
        PROJECT_ID = projectId;
        CLIFF = cliff;
        UNLOCK_DURATION = unlockDuration;
        vestingAdmin = vestingAdmin_;

        // Transfer ownership to the owner.
        _transferOwnership(owner);
    }

    /// @notice Required override.
    function nonces(address owner) public view virtual override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }

    //*********************************************************************//
    // ------------------------ internal functions ----------------------- //
    //*********************************************************************//

    /// @notice Required override.
    function _update(address from, address to, uint256 value) internal virtual override(ERC20, ERC20Votes) {
        super._update(from, to, value);
    }

    /// @notice Override to enforce vesting schedule and clean up fully vested schedules.
    /// @param from The address to transfer from.
    /// @param to The address to transfer to.
    /// @param amount The amount to transfer.
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);

        if (from != address(0)) { // Not a minting operation

            // Skip vesting checks for exempt addresses
            if (isExemptFromVesting[from]) {
                return;
            }

            // Keep track of the amount still vesting for the sender.
            uint256 vestingAmount = _vestingAmountFor(from);

            // Make sure there is sufficient vested balance to transfer.
            if(balanceOf(from) - vestingAmount < amount) revert JBVestedERC20_TransferExceedsVestedAmount(amount, vestingAmount);

            // Clean up fully vested schedules
            VestingSchedule[] storage schedules = _vestingSchedules[from];
            uint256 len = schedules.length;
            uint256 cutoff = 0;
            for (uint256 i = 0; i < len; i++) {
                VestingSchedule storage schedule = schedules[i];
                if (block.timestamp >= schedule.startTime + CLIFF + UNLOCK_DURATION) {
                    cutoff = i + 1;
                } else {
                    break;
                }
            }
            if (cutoff > 0) {
                // Remove all fully vested schedules at the start of the array
                for (uint256 i = cutoff; i < len; i++) {
                    schedules[i - cutoff] = schedules[i];
                }
                for (uint256 i = 0; i < cutoff; i++) {
                    schedules.pop();
                }
            }
        }
    }

    /// @notice Calculate the total amount still vesting for an account.
    /// @param account The address to get the vesting amount for.
    /// @return stillVesting The total amount still vesting for the `account`.
    function _vestingAmountFor(address account) internal view returns (uint256 stillVesting) {
        // Iterate over the vesting schedules for the account.
        VestingSchedule[] storage schedules = _vestingSchedules[account];
        for (uint256 i = schedules.length; i > 0; i--) {

            // Get the vesting schedule for the account.
            VestingSchedule storage schedule = schedules[i - 1];

            // Calculate the elapsed time since the vesting schedule started.
            uint256 elapsedTime = block.timestamp - schedule.startTime;

            // If the cliff period hasn't passed, the entire amount is still vesting.
            if (elapsedTime < CLIFF) {
                // If the cliff period hasn't passed, the entire amount is still vesting
                stillVesting += schedule.totalAmount;
            // If the cliff period has passed, calculate the amount still vesting.
            } else if (elapsedTime < CLIFF + UNLOCK_DURATION) {
                uint256 vested = (schedule.totalAmount * elapsedTime) / UNLOCK_DURATION;
                stillVesting += schedule.totalAmount - vested;
            // If the schedule is fully vested, no need to add anything else since all other schedules must also be fully vested.
            } else {
                return stillVesting;
            }
        }
    }

    //*********************************************************************//
    // ---------------------- external admin functions ------------------ //
    //*********************************************************************//

    /// @notice Add an address to the vesting exemption list.
    /// @dev Only callable by the vesting admin.
    function addExemptAddress(address account) external onlyVestingAdmin {
        isExemptFromVesting[account] = true;
        emit ExemptAddressAdded(account);
    }

    /// @notice Remove an address from the vesting exemption list.
    /// @dev Only callable by the vesting admin.
    function removeExemptAddress(address account) external onlyVestingAdmin {
        isExemptFromVesting[account] = false;
        emit ExemptAddressRemoved(account);
    }

    /// @notice Allows the owner to change the admin address.
    function setVestingAdmin(address newVestingAdmin) external onlyVestingAdmin {
        vestingAdmin = newVestingAdmin;
    }
}
