// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/governance/TimelockController.sol";

/**
 * @title TrezaTimelock
 * @dev TimelockController for Treza governance with configurable delays
 * 
 * This contract acts as a timelock for governance proposals, ensuring that
 * all changes have a delay period for community review and response.
 */
contract TrezaTimelock is TimelockController {
    
    /**
     * @dev Constructor for TrezaTimelock
     * @param minDelay Minimum delay for operations (in seconds)
     * @param proposers List of addresses that can propose operations
     * @param executors List of addresses that can execute operations (empty array = anyone can execute)
     * @param admin Optional admin address (use zero address for no admin)
     */
    constructor(
        uint256 minDelay,
        address[] memory proposers,
        address[] memory executors,
        address admin
    ) TimelockController(minDelay, proposers, executors, admin) {
        // TimelockController handles all the logic
        // This contract just provides a named deployment
    }
}
