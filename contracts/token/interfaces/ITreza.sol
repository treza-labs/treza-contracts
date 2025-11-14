// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title ITreza
 * @dev Public interface for TREZA token functionality
 * 
 * This interface exposes only the public functions that external
 * contracts and DApps need to interact with TREZA token.
 */
interface ITreza is IERC20 {
    
    // =========================================================================
    // EVENTS
    // =========================================================================
    
    event FeeWalletsUpdated(
        address indexed old1,
        address indexed old2,
        address new1,
        address new2
    );
    
    event FeeExemptionUpdated(address indexed account, bool isExempt);
    event FeePercentageUpdated(uint256 oldFee, uint256 newFee);
    event WhitelistModeToggled(bool enabled);
    event TradingEnabledToggled(bool enabled);
    event WhitelistUpdated(address indexed account, bool isWhitelisted);
    
    // =========================================================================
    // VIEW FUNCTIONS
    // =========================================================================
    
    /**
     * @dev Returns the current transfer fee percentage
     */
    function getCurrentFee() external view returns (uint256);
    
    /**
     * @dev Returns the current max wallet limit in tokens
     */
    function getCurrentMaxWallet() external view returns (uint256);
    
    /**
     * @dev Check if address can currently trade
     */
    function canTrade(address account) external view returns (bool);
    
    /**
     * @dev Check if address is whitelisted
     */
    function isWhitelisted(address account) external view returns (bool);
    
    /**
     * @dev Check if address is fee exempt
     */
    function isFeeExempt(address account) external view returns (bool);
    
    /**
     * @dev Get launch status information
     */
    function getLaunchStatus() external view returns (
        bool tradingEnabled,
        bool whitelistMode,
        uint256 antiBotBlocksRemaining
    );
    
    /**
     * @dev Get current anti-sniper status and timeline
     */
    function getAntiSniperStatus() external view returns (
        bool timeBasedEnabled,
        uint256 currentPhase,
        uint256 currentFee,
        uint256 currentMaxWallet,
        uint256 timeRemainingInPhase
    );
    
    // =========================================================================
    // COMPLIANCE INTEGRATION (if supported)
    // =========================================================================
    
    /**
     * @dev Check if user can participate in governance with compliance
     */
    function checkGovernanceEligibility(
        address user,
        uint256 proposalId
    ) external returns (bool canParticipate, uint256 votingWeight);
    
    /**
     * @dev Check if user is compliant (if compliance is enabled)
     */
    function isUserCompliant(address user) external view returns (bool compliant);
}

