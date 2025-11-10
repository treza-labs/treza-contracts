// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/governance/TimelockController.sol";

/// @title TrezaTimelock
/// @author Treza Labs
/// @notice TimelockController for Treza token governance
/// @dev Provides time-delayed execution of governance proposals
contract TrezaTimelock is TimelockController {
    /// @notice Deploy the timelock with specified parameters
    /// @param minDelay Minimum delay in seconds before execution (recommended: 86400 = 24 hours)
    /// @param proposers Array of addresses that can propose operations
    /// @param executors Array of addresses that can execute operations (use 0x0 for anyone)
    /// @param admin Initial admin address (will be renounced after setup)
    constructor(
        uint256 minDelay,
        address[] memory proposers,
        address[] memory executors,
        address admin
    ) TimelockController(minDelay, proposers, executors, admin) {
        // Constructor automatically sets up roles via parent contract
        // Admin should renounce TIMELOCK_ADMIN_ROLE after setup for full decentralization
    }

    /// @notice Get the minimum delay for operations
    /// @return The minimum delay in seconds
    function getMinDelay() external view returns (uint256) {
        return getMinDelay();
    }

    /// @notice Check if an operation is ready for execution
    /// @param id The operation identifier
    /// @return True if the operation is ready
    function isOperationReady(bytes32 id) external view returns (bool) {
        return isOperationReady(id);
    }

    /// @notice Check if an operation is pending
    /// @param id The operation identifier  
    /// @return True if the operation is pending
    function isOperationPending(bytes32 id) external view returns (bool) {
        return isOperationPending(id);
    }

    /// @notice Get the timestamp when an operation becomes ready
    /// @param id The operation identifier
    /// @return The timestamp when ready for execution
    function getTimestamp(bytes32 id) external view returns (uint256) {
        return getTimestamp(id);
    }
}
