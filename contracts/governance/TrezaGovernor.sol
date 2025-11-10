// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/governance/Governor.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol";

/// @title TrezaGovernor
/// @author Treza Labs
/// @notice Governor contract for Treza token DAO governance
/// @dev Full DAO governance with token voting, quorum, and timelock integration
contract TrezaGovernor is 
    Governor,
    GovernorSettings,
    GovernorCountingSimple,
    GovernorVotes,
    GovernorVotesQuorumFraction,
    GovernorTimelockControl 
{
    /// @notice Deploy the governor with specified parameters
    /// @param _token The voting token (must implement IVotes - requires token upgrade)
    /// @param _timelock The timelock controller for delayed execution
    constructor(
        IVotes _token,
        TimelockController _timelock
    )
        Governor("TrezaGovernor")
        GovernorSettings(
            1,      // 1 block voting delay (prevents flash loan attacks)
            50400,  // ~1 week voting period (assuming 12s blocks)
            0       // 0 proposal threshold (anyone can propose)
        )
        GovernorVotes(_token)
        GovernorVotesQuorumFraction(4) // 4% quorum required
        GovernorTimelockControl(_timelock)
    {
        // Constructor automatically sets up all extensions
    }

    // =========================================================================
    // REQUIRED OVERRIDES
    // =========================================================================

    function votingDelay()
        public
        view
        override(IGovernor, GovernorSettings)
        returns (uint256)
    {
        return super.votingDelay();
    }

    function votingPeriod()
        public
        view
        override(IGovernor, GovernorSettings)
        returns (uint256)
    {
        return super.votingPeriod();
    }

    function quorum(uint256 blockNumber)
        public
        view
        override(IGovernor, GovernorVotesQuorumFraction)
        returns (uint256)
    {
        return super.quorum(blockNumber);
    }

    function proposalThreshold()
        public
        view
        override(Governor, GovernorSettings)
        returns (uint256)
    {
        return super.proposalThreshold();
    }

    function _execute(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) {
        super._execute(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint256) {
        return super._cancel(targets, values, calldatas, descriptionHash);
    }

    function _executor()
        internal
        view
        override(Governor, GovernorTimelockControl)
        returns (address)
    {
        return super._executor();
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(Governor, GovernorTimelockControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    // =========================================================================
    // GOVERNANCE SETTINGS
    // =========================================================================

    /// @notice Update voting delay (only through governance)
    /// @param newVotingDelay New voting delay in blocks
    function setVotingDelay(uint256 newVotingDelay) external override onlyGovernance {
        _setVotingDelay(newVotingDelay);
    }

    /// @notice Update voting period (only through governance)
    /// @param newVotingPeriod New voting period in blocks
    function setVotingPeriod(uint256 newVotingPeriod) external override onlyGovernance {
        _setVotingPeriod(newVotingPeriod);
    }

    /// @notice Update proposal threshold (only through governance)
    /// @param newProposalThreshold New proposal threshold in tokens
    function setProposalThreshold(uint256 newProposalThreshold) external override onlyGovernance {
        _setProposalThreshold(newProposalThreshold);
    }

    // =========================================================================
    // VIEW FUNCTIONS
    // =========================================================================

    /// @notice Get current governance settings
    /// @return delay Voting delay in blocks
    /// @return period Voting period in blocks  
    /// @return threshold Proposal threshold in tokens
    /// @return quorumPct Quorum percentage (basis points)
    function getGovernanceSettings() external view returns (
        uint256 delay,
        uint256 period,
        uint256 threshold,
        uint256 quorumPct
    ) {
        return (
            votingDelay(),
            votingPeriod(),
            proposalThreshold(),
            quorumNumerator()
        );
    }

    /// @notice Check if an account can propose
    /// @param account Address to check
    /// @return True if account can propose
    function canPropose(address account) external view returns (bool) {
        return getVotes(account, block.number - 1) >= proposalThreshold();
    }
}
