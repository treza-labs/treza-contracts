// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title TrezaTokenVoting
/// @author Treza Labs
/// @notice Voting-enabled version of Treza token for DAO governance
/// @dev This is a future upgrade path - adds voting capabilities to existing token functionality
/// @dev NOTE: This would require a token migration from the current TrezaToken
contract TrezaTokenVoting is ERC20Votes, Ownable {
    /// @notice Total fixed supply of TREZA (100 million tokens)
    uint256 public constant TOTAL_SUPPLY = 100_000_000 * 1e18;

    /// @notice Current transfer fee percentage (can be manually adjusted)
    uint256 public currentFeePercentage = 5;

    /// @notice Maximum allowed fee percentage
    uint256 public constant MAX_FEE_PERCENTAGE = 10;

    /// @notice Primary fee recipients
    address public treasuryWallet1;
    address public treasuryWallet2;

    /// @notice Mapping of addresses exempted from transfer fees
    mapping(address => bool) public isFeeExempt;

    /// @notice Whether trading is enabled
    bool public tradingEnabled = true;

    // Events
    event FeePercentageUpdated(uint256 oldFee, uint256 newFee);
    event FeeWalletsUpdated(address indexed old1, address indexed old2, address new1, address new2);
    event FeeExemptionUpdated(address indexed account, bool isExempt);
    event TradingEnabledToggled(bool enabled);

    /// @notice Deploy voting-enabled Treza token
    /// @param _treasuryWallet1 First treasury wallet (50% of fees)
    /// @param _treasuryWallet2 Second treasury wallet (50% of fees)
    /// @param _initialHolder Address to receive all initial tokens
    constructor(
        address _treasuryWallet1,
        address _treasuryWallet2,
        address _initialHolder
    ) 
        ERC20("Treza Token", "TREZA")
        ERC20Permit("Treza Token")
        Ownable(msg.sender)
    {
        require(_treasuryWallet1 != address(0) && _treasuryWallet2 != address(0), "Zero address");
        require(_treasuryWallet1 != _treasuryWallet2, "Treasury wallets must be unique");
        require(_initialHolder != address(0), "Zero address");

        treasuryWallet1 = _treasuryWallet1;
        treasuryWallet2 = _treasuryWallet2;

        // Exempt treasury wallets from fees
        isFeeExempt[_treasuryWallet1] = true;
        isFeeExempt[_treasuryWallet2] = true;
        isFeeExempt[_initialHolder] = true;

        // Mint all tokens to initial holder
        _mint(_initialHolder, TOTAL_SUPPLY);
    }

    // =========================================================================
    // GOVERNANCE FUNCTIONS (OWNER ONLY)
    // =========================================================================

    /// @notice Update the transfer fee percentage
    /// @param newFeePercentage New fee percentage (0-10)
    function setFeePercentage(uint256 newFeePercentage) external onlyOwner {
        require(newFeePercentage <= MAX_FEE_PERCENTAGE, "Fee exceeds maximum");
        uint256 oldFee = currentFeePercentage;
        currentFeePercentage = newFeePercentage;
        emit FeePercentageUpdated(oldFee, newFeePercentage);
    }

    /// @notice Change the treasury fee recipient addresses
    /// @param new1 New first treasury wallet
    /// @param new2 New second treasury wallet
    function setFeeWallets(address new1, address new2) external onlyOwner {
        require(new1 != address(0) && new2 != address(0), "Zero address");
        require(new1 != new2, "Treasury wallets must be unique");
        
        address old1 = treasuryWallet1;
        address old2 = treasuryWallet2;

        // Remove exemptions for old wallets
        isFeeExempt[old1] = false;
        isFeeExempt[old2] = false;

        // Assign new wallets and exempt them
        treasuryWallet1 = new1;
        treasuryWallet2 = new2;
        isFeeExempt[new1] = true;
        isFeeExempt[new2] = true;

        emit FeeWalletsUpdated(old1, old2, new1, new2);
        emit FeeExemptionUpdated(old1, false);
        emit FeeExemptionUpdated(old2, false);
        emit FeeExemptionUpdated(new1, true);
        emit FeeExemptionUpdated(new2, true);
    }

    /// @notice Exempt or include an account from transfer fees
    /// @param account Address to update
    /// @param exempt True to exempt, false to remove exemption
    function setFeeExemption(address account, bool exempt) external onlyOwner {
        isFeeExempt[account] = exempt;
        emit FeeExemptionUpdated(account, exempt);
    }

    /// @notice Enable/disable trading
    /// @param _enabled True to enable trading, false to disable
    function setTradingEnabled(bool _enabled) external onlyOwner {
        tradingEnabled = _enabled;
        emit TradingEnabledToggled(_enabled);
    }

    // =========================================================================
    // TRANSFER LOGIC WITH FEES
    // =========================================================================

    /// @dev Override transfer to apply fees
    function _update(address from, address to, uint256 value)
        internal
        override(ERC20, ERC20Votes)
    {
        // Check if trading is enabled (except for minting/burning)
        if (from != address(0) && to != address(0)) {
            require(tradingEnabled, "Trading not enabled");
        }

        // Apply fee logic for regular transfers
        if (from != address(0) && to != address(0) && !isFeeExempt[from] && !isFeeExempt[to] && currentFeePercentage > 0) {
            uint256 fee = (value * currentFeePercentage) / 100;
            uint256 netAmount = value - fee;

            // Transfer fee to treasury wallets (50/50 split)
            if (fee > 0) {
                uint256 fee1 = fee / 2;
                uint256 fee2 = fee - fee1;
                
                super._update(from, treasuryWallet1, fee1);
                super._update(from, treasuryWallet2, fee2);
            }

            // Transfer net amount to recipient
            super._update(from, to, netAmount);
        } else {
            // No fee - direct transfer
            super._update(from, to, value);
        }
    }

    // =========================================================================
    // REQUIRED OVERRIDES
    // =========================================================================

    function nonces(address owner)
        public
        view
        override(ERC20Permit, Nonces)
        returns (uint256)
    {
        return super.nonces(owner);
    }

    // =========================================================================
    // VIEW FUNCTIONS
    // =========================================================================

    /// @notice Get current fee percentage
    /// @return Current fee percentage
    function getCurrentFee() external view returns (uint256) {
        return currentFeePercentage;
    }

    /// @notice Check if address is fee exempt
    /// @param account Address to check
    /// @return True if exempt from fees
    function isExemptFromFees(address account) external view returns (bool) {
        return isFeeExempt[account];
    }
}
