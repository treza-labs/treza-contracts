// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";

/// @title TrezaToken with Anti-Sniping Protection
/// @author Brandon Torres and Treza Labs
/// @notice ERC20 token with manual fees, anti-sniping whitelist, and launch controls
/// @dev Enhanced with comprehensive anti-bot protection for fair launches
contract TrezaToken is ERC20, Ownable {
    using SafeERC20 for IERC20;

    /// @notice Total fixed supply of TREZA (100 million tokens)
    uint256 public constant TOTAL_SUPPLY = 100_000_000 * 1e18;

    /// @notice Allocation percentages for initial minting
    uint256 public constant PCT_INITIAL_LIQUIDITY    = 35;  // 35%
    uint256 public constant PCT_TEAM                 = 20;  // 20%
    uint256 public constant PCT_TREASURY             = 20;  // 20%
    uint256 public constant PCT_PARTNERSHIPS_GRANTS  = 10;  // 10%
    uint256 public constant PCT_RND                  = 5;   // 5%
    uint256 public constant PCT_MARKETING_OPS        = 10;  // 10%

    /// @notice Fee split: 50% each to two treasury wallets
    uint256 public constant FEE1_PCT = 50;   // 50% of total fee
    uint256 public constant FEE2_PCT = 50;   // 50% of total fee
    uint256 public constant FEE_SPLIT_TOTAL = 100; // 100 parts in total

    /// @notice Primary fee recipients
    address public treasuryWallet1;
    address public treasuryWallet2;

    /// @notice Mapping of addresses exempted from transfer fees
    mapping(address => bool) public isFeeExempt;

    /// @notice Current transfer fee percentage (can be manually adjusted)
    uint256 public currentFeePercentage;

    /// @notice Maximum allowed fee percentage
    uint256 public constant MAX_FEE_PERCENTAGE = 10;  // 10%

    /// @notice Timelock controller for decentralized ownership
    TimelockController public timelockController;

    // =========================================================================
    // ANTI-SNIPING & LAUNCH CONTROL VARIABLES
    // =========================================================================

    /// @notice Whether the token is in whitelist-only mode
    bool public whitelistMode = true;

    /// @notice Whether trading is enabled (override for complete trading halt)
    bool public tradingEnabled = false;

    /// @notice Mapping of whitelisted addresses during launch
    mapping(address => bool) public isWhitelisted;



    /// @notice Block number when trading was enabled
    uint256 public tradingEnabledBlock;

    /// @notice Timestamp when trading was enabled (for time-based anti-sniper)
    uint256 public tradingEnabledTimestamp;

    /// @notice Number of blocks with enhanced anti-bot protection
    uint256 public antiBotBlockCount = 3;

    // =========================================================================
    // TIME-BASED ANTI-SNIPER MECHANISM
    // =========================================================================

    /// @notice Whether time-based anti-sniper mechanism is enabled
    bool public timeBasedAntiSniperEnabled = true;

    /// @notice Time-based fee structure (in seconds from launch)
    struct TimeFeePhase {
        uint256 duration;       // Duration in seconds
        uint256 feePercentage;  // Fee percentage for this phase
        uint256 maxWalletPct;   // Max wallet as percentage of total supply (in basis points, 10000 = 1%)
    }

    /// @notice Anti-sniper fee phases
    TimeFeePhase[4] public antiSniperPhases;

    /// @notice Minimum time between transactions for the same address (anti-spam)
    uint256 public transferCooldown = 1; // 1 second

    /// @notice Last transaction timestamp for each address
    mapping(address => uint256) public lastTransferTime;

    /// @notice Addresses flagged as potential bots (manual or automatic)
    mapping(address => bool) public isBlacklisted;

    /// @dev Struct to hold constructor parameters to avoid stack too deep
    struct ConstructorParams {
        address initialLiquidityWallet;
        address teamWallet;
        address treasuryWallet;
        address partnershipsGrantsWallet;
        address rndWallet;
        address marketingOpsWallet;
        address treasury1;
        address treasury2;
        uint256 timelockDelay;
    }

    // =========================================================================
    // EVENTS
    // =========================================================================

    /// @dev Emitted when fee wallets are updated
    event FeeWalletsUpdated(
        address indexed old1,
        address indexed old2,
        address new1,
        address new2
    );

    /// @dev Emitted when an account's fee exemption status is toggled
    event FeeExemptionUpdated(address indexed account, bool isExempt);

    /// @dev Emitted when the fee percentage is updated
    event FeePercentageUpdated(uint256 oldFee, uint256 newFee);

    /// @dev Emitted when timelock controller is deployed and ownership transferred
    event TimelockControllerSet(address indexed timelock);

    // Anti-sniping events
    event WhitelistModeToggled(bool enabled);
    event TradingEnabledToggled(bool enabled);
    event WhitelistUpdated(address indexed account, bool isWhitelisted);

    event AddressBlacklisted(address indexed account, bool isBlacklisted);
    event AntiSniperConfigUpdated(uint256 blocksCount, uint256 cooldownSeconds);
    event TimeBasedAntiSniperToggled(bool enabled);
    event AntiSniperPhasesUpdated();

    /// @param params Struct containing all constructor parameters
    /// @param proposers Array of addresses that can propose timelock operations
    /// @param executors Array of addresses that can execute timelock operations
    constructor(
        ConstructorParams memory params,
        address[] memory proposers,
        address[] memory executors
    )
        ERC20("Treza Token", "TREZA")
        Ownable(msg.sender)
    {
        _validateAddresses(params);
        _validateTreasuryWallets(params.treasury1, params.treasury2);
        
        // Initialize fee percentage to 5%
        currentFeePercentage = 5;
        

        
        _mintInitialAllocations(params);
        _setupTreasuryWallets(params.treasury1, params.treasury2);
        _setupInitialWhitelist(params);
        _setupAntiSniperPhases();
        _setupTimelock(proposers, executors, params.timelockDelay);
    }

    /// @dev Validates that all required addresses are not zero
    function _validateAddresses(ConstructorParams memory params) private pure {
        require(
            params.initialLiquidityWallet != address(0) &&
            params.teamWallet != address(0) &&
            params.treasuryWallet != address(0) &&
            params.partnershipsGrantsWallet != address(0) &&
            params.rndWallet != address(0) &&
            params.marketingOpsWallet != address(0) &&
            params.treasury1 != address(0) &&
            params.treasury2 != address(0),
            "Treza: zero address"
        );
    }

    /// @dev Validates that treasury wallets are unique
    function _validateTreasuryWallets(address t1, address t2) private pure {
        require(
            t1 != t2,
            "Treza: treasury wallets must be unique"
        );
    }

    /// @dev Mints initial token allocations
    function _mintInitialAllocations(ConstructorParams memory params) private {
        _mint(params.initialLiquidityWallet, (TOTAL_SUPPLY * PCT_INITIAL_LIQUIDITY) / 100);
        _mint(params.teamWallet, (TOTAL_SUPPLY * PCT_TEAM) / 100);
        _mint(params.treasuryWallet, (TOTAL_SUPPLY * PCT_TREASURY) / 100);
        _mint(params.partnershipsGrantsWallet, (TOTAL_SUPPLY * PCT_PARTNERSHIPS_GRANTS) / 100);
        _mint(params.rndWallet, (TOTAL_SUPPLY * PCT_RND) / 100);
        _mint(params.marketingOpsWallet, (TOTAL_SUPPLY * PCT_MARKETING_OPS) / 100);
    }

    /// @dev Sets up treasury wallets and exemptions
    function _setupTreasuryWallets(address t1, address t2) private {
        treasuryWallet1 = t1;
        treasuryWallet2 = t2;
        
        isFeeExempt[t1] = true;
        isFeeExempt[t2] = true;
        
        emit FeeExemptionUpdated(t1, true);
        emit FeeExemptionUpdated(t2, true);
    }

    /// @dev Sets up initial whitelist with all allocation wallets
    function _setupInitialWhitelist(ConstructorParams memory params) private {
        // Automatically whitelist all initial allocation wallets
        isWhitelisted[params.initialLiquidityWallet] = true;
        isWhitelisted[params.teamWallet] = true;
        isWhitelisted[params.treasuryWallet] = true;
        isWhitelisted[params.partnershipsGrantsWallet] = true;
        isWhitelisted[params.rndWallet] = true;
        isWhitelisted[params.marketingOpsWallet] = true;
        isWhitelisted[params.treasury1] = true;
        isWhitelisted[params.treasury2] = true;
        
        // Whitelist the contract deployer
        isWhitelisted[msg.sender] = true;
        
        emit WhitelistUpdated(params.initialLiquidityWallet, true);
        emit WhitelistUpdated(params.teamWallet, true);
        emit WhitelistUpdated(params.treasuryWallet, true);
        emit WhitelistUpdated(params.partnershipsGrantsWallet, true);
        emit WhitelistUpdated(params.rndWallet, true);
        emit WhitelistUpdated(params.marketingOpsWallet, true);
        emit WhitelistUpdated(params.treasury1, true);
        emit WhitelistUpdated(params.treasury2, true);
        emit WhitelistUpdated(msg.sender, true);
    }

    /// @dev Sets up anti-sniper phases with specified fee and wallet limits
    function _setupAntiSniperPhases() private {
        // Phase 1: First 1 minute - 40% fee, 0.10% max wallet
        antiSniperPhases[0] = TimeFeePhase({
            duration: 60,        // 1 minute
            feePercentage: 40,   // 40% fee
            maxWalletPct: 10     // 0.10% of total supply (10 basis points)
        });
        
        // Phase 2: 2-5 minutes - 30% fee, 0.15% max wallet  
        antiSniperPhases[1] = TimeFeePhase({
            duration: 240,       // 4 minutes (total 5 minutes from start)
            feePercentage: 30,   // 30% fee
            maxWalletPct: 15     // 0.15% of total supply (15 basis points)
        });
        
        // Phase 3: 6-8 minutes - 20% fee, 0.20% max wallet
        antiSniperPhases[2] = TimeFeePhase({
            duration: 180,       // 3 minutes (total 8 minutes from start)
            feePercentage: 20,   // 20% fee
            maxWalletPct: 20     // 0.20% of total supply (20 basis points)
        });
        
        // Phase 4: 9-15 minutes - 10% fee, 0.30% max wallet
        antiSniperPhases[3] = TimeFeePhase({
            duration: 420,       // 7 minutes (total 15 minutes from start)
            feePercentage: 10,   // 10% fee
            maxWalletPct: 30     // 0.30% of total supply (30 basis points)
        });
    }

    /// @dev Sets up timelock controller
    function _setupTimelock(
        address[] memory proposers, 
        address[] memory executors, 
        uint256 delay
    ) private {
        TimelockController timelock = new TimelockController(delay, proposers, executors, msg.sender);
        timelockController = timelock;
        _transferOwnership(address(timelock));
        emit TimelockControllerSet(address(timelock));
    }

    // =========================================================================
    // LAUNCH CONTROL FUNCTIONS (OWNER ONLY)
    // =========================================================================

    /// @notice Enable/disable trading completely
    /// @param _enabled True to enable trading, false to disable
    function setTradingEnabled(bool _enabled) external onlyOwner {
        tradingEnabled = _enabled;
        if (_enabled && tradingEnabledBlock == 0) {
            tradingEnabledBlock = block.number;
            tradingEnabledTimestamp = block.timestamp;
        }
        emit TradingEnabledToggled(_enabled);
    }

    /// @notice Enable/disable whitelist-only mode
    /// @param _enabled True for whitelist-only, false for public trading
    function setWhitelistMode(bool _enabled) external onlyOwner {
        whitelistMode = _enabled;
        emit WhitelistModeToggled(_enabled);
    }

    /// @notice Add or remove addresses from whitelist
    /// @param accounts Array of addresses to update
    /// @param whitelisted Whether these addresses should be whitelisted
    function setWhitelist(address[] calldata accounts, bool whitelisted) external onlyOwner {
        for (uint256 i = 0; i < accounts.length; i++) {
            isWhitelisted[accounts[i]] = whitelisted;
            emit WhitelistUpdated(accounts[i], whitelisted);
        }
    }



    /// @notice Blacklist suspicious addresses (emergency function)
    /// @param accounts Array of addresses to blacklist/unblacklist
    /// @param blacklisted Whether these addresses should be blacklisted
    function setBlacklist(address[] calldata accounts, bool blacklisted) external onlyOwner {
        for (uint256 i = 0; i < accounts.length; i++) {
            isBlacklisted[accounts[i]] = blacklisted;
            emit AddressBlacklisted(accounts[i], blacklisted);
        }
    }

    /// @notice Configure anti-sniper protection parameters
    /// @param _blocks Number of blocks with enhanced protection after trading enabled
    /// @param _cooldownSeconds Minimum seconds between transactions
    function setAntiSniperConfig(uint256 _blocks, uint256 _cooldownSeconds) external onlyOwner {
        antiBotBlockCount = _blocks;
        transferCooldown = _cooldownSeconds;
        emit AntiSniperConfigUpdated(_blocks, _cooldownSeconds);
    }

    /// @notice Enable/disable time-based anti-sniper mechanism
    /// @param _enabled True to enable time-based fees and max wallet limits
    function setTimeBasedAntiSniper(bool _enabled) external onlyOwner {
        timeBasedAntiSniperEnabled = _enabled;
        emit TimeBasedAntiSniperToggled(_enabled);
    }

    /// @notice Update anti-sniper phases configuration
    /// @param phases Array of 4 TimeFeePhase structs defining the anti-sniper timeline
    function setAntiSniperPhases(TimeFeePhase[4] calldata phases) external onlyOwner {
        for (uint256 i = 0; i < 4; i++) {
            require(phases[i].feePercentage <= 50, "Treza: fee too high");
            require(phases[i].maxWalletPct <= 10000, "Treza: max wallet too high"); // Max 100%
            antiSniperPhases[i] = phases[i];
        }
        emit AntiSniperPhasesUpdated();
    }

    // =========================================================================
    // EXISTING FEE FUNCTIONS
    // =========================================================================

    /// @notice Exempt or include an account from transfer fees
    /// @param account Address to update
    /// @param exempt True to exempt, false to remove exemption
    function setFeeExemption(address account, bool exempt) external onlyOwner {
        isFeeExempt[account] = exempt;
        emit FeeExemptionUpdated(account, exempt);
    }

    /// @notice Change the treasury fee recipient addresses
    /// @param new1 New first treasury wallet
    /// @param new2 New second treasury wallet
    function setFeeWallets(address new1, address new2) external onlyOwner {
        require(
            new1 != address(0) && new2 != address(0),
            "Treza: zero address"
        );
        require(
            new1 != new2,
            "Treza: treasury wallets must be unique"
        );
        
        address old1 = treasuryWallet1;
        address old2 = treasuryWallet2;

        // Remove exemptions for old wallets
        isFeeExempt[old1] = false;
        isFeeExempt[old2] = false;
        emit FeeExemptionUpdated(old1, false);
        emit FeeExemptionUpdated(old2, false);

        // Assign new wallets and exempt them
        treasuryWallet1 = new1;
        treasuryWallet2 = new2;
        isFeeExempt[new1] = true;
        isFeeExempt[new2] = true;
        emit FeeExemptionUpdated(new1, true);
        emit FeeExemptionUpdated(new2, true);

        emit FeeWalletsUpdated(old1, old2, new1, new2);
    }

    /// @notice Returns the current transfer fee percentage
    function getCurrentFee() public view returns (uint256) {
        // If time-based anti-sniper is disabled, use manual fee
        if (!timeBasedAntiSniperEnabled || tradingEnabledTimestamp == 0) {
            return currentFeePercentage;
        }

        uint256 timeSinceLaunch = block.timestamp - tradingEnabledTimestamp;
        uint256 cumulativeTime = 0;

        // Check each phase to determine current fee
        for (uint256 i = 0; i < antiSniperPhases.length; i++) {
            cumulativeTime += antiSniperPhases[i].duration;
            if (timeSinceLaunch <= cumulativeTime) {
                return antiSniperPhases[i].feePercentage;
            }
        }

        // After all anti-sniper phases, use manual fee
        return currentFeePercentage;
    }

    /// @notice Returns the current max wallet limit as percentage of total supply (in basis points)
    function getCurrentMaxWalletBasisPoints() public view returns (uint256) {
        // If time-based anti-sniper is disabled, no max wallet limit
        if (!timeBasedAntiSniperEnabled || tradingEnabledTimestamp == 0) {
            return 10000; // 100% - no limit
        }

        uint256 timeSinceLaunch = block.timestamp - tradingEnabledTimestamp;
        uint256 cumulativeTime = 0;

        // Check each phase to determine current max wallet
        for (uint256 i = 0; i < antiSniperPhases.length; i++) {
            cumulativeTime += antiSniperPhases[i].duration;
            if (timeSinceLaunch <= cumulativeTime) {
                return antiSniperPhases[i].maxWalletPct;
            }
        }

        // After all anti-sniper phases, no max wallet limit
        return 10000; // 100% - no limit
    }

    /// @notice Returns the current max wallet limit in tokens
    function getCurrentMaxWallet() public view returns (uint256) {
        uint256 basisPoints = getCurrentMaxWalletBasisPoints();
        return (TOTAL_SUPPLY * basisPoints) / 10000;
    }

    /// @notice Update the transfer fee percentage
    /// @param newFeePercentage New fee percentage (0-10)
    function setFeePercentage(uint256 newFeePercentage) external onlyOwner {
        require(
            newFeePercentage <= MAX_FEE_PERCENTAGE,
            "Treza: fee exceeds maximum"
        );
        
        uint256 oldFee = currentFeePercentage;
        currentFeePercentage = newFeePercentage;
        emit FeePercentageUpdated(oldFee, newFeePercentage);
    }

    // =========================================================================
    // ENHANCED TRANSFER LOGIC WITH ANTI-SNIPING
    // =========================================================================

    /// @dev Enhanced transfer function with anti-sniping protection
    function _transferWithAntiSnipe(
        address sender,
        address recipient,
        uint256 amount
    ) internal {
        // 1. Check if trading is enabled
        require(tradingEnabled, "Treza: trading not enabled");

        // 2. Check blacklist
        require(!isBlacklisted[sender] && !isBlacklisted[recipient], "Treza: blacklisted address");

        // 3. Check whitelist mode
        if (whitelistMode) {
            require(
                isWhitelisted[sender] || isWhitelisted[recipient],
                "Treza: not whitelisted"
            );
        }

        // 4. Anti-bot protection during launch
        if (tradingEnabledBlock > 0 && block.number <= tradingEnabledBlock + antiBotBlockCount) {
            require(isWhitelisted[sender] || isWhitelisted[recipient], "Treza: anti-bot protection active");
        }

        // 5. Transfer cooldown (except for whitelisted addresses)
        if (!isWhitelisted[sender] && transferCooldown > 0) {
            require(
                block.timestamp >= lastTransferTime[sender] + transferCooldown,
                "Treza: transfer too soon"
            );
            lastTransferTime[sender] = block.timestamp;
        }

        // 6. Check max wallet limit (except for whitelisted addresses and fee wallets)
        if (!isWhitelisted[recipient] && !isFeeExempt[recipient] && timeBasedAntiSniperEnabled) {
            uint256 maxWallet = getCurrentMaxWallet();
            uint256 recipientBalance = balanceOf(recipient);
            require(
                recipientBalance + amount <= maxWallet,
                "Treza: max wallet exceeded"
            );
        }

        // 7. Apply normal fee logic
        _transferWithPossibleFee(sender, recipient, amount);
    }

    /// @dev Internal transfer function that applies dynamic fees and exemptions
    function _transferWithPossibleFee(
        address sender,
        address recipient,
        uint256 amount
    ) internal {
        if (isFeeExempt[sender] || isFeeExempt[recipient]) {
            super._transfer(sender, recipient, amount);
            return;
        }

        uint256 pct = getCurrentFee();
        if (pct == 0) {
            super._transfer(sender, recipient, amount);
            return;
        }

        uint256 fee = (amount * pct) / 100;
        uint256 net = amount - fee;

        _distributeFees(sender, fee);
        super._transfer(sender, recipient, net);
    }

    /// @dev Distributes fees to treasury wallets (50/50 split)
    function _distributeFees(address sender, uint256 fee) private {
        uint256 fee1 = fee / 2; // 50% to wallet 1
        uint256 fee2 = fee - fee1; // Remaining 50% to wallet 2 (handles odd amounts)

        super._transfer(sender, treasuryWallet1, fee1);
        super._transfer(sender, treasuryWallet2, fee2);
    }

    // =========================================================================
    // OVERRIDDEN TRANSFER FUNCTIONS
    // =========================================================================

    /// @notice Transfer tokens with anti-sniping protection
    function transfer(address to, uint256 amount)
        public virtual override returns (bool)
    {
        _transferWithAntiSnipe(_msgSender(), to, amount);
        return true;
    }

    /// @notice Transfer tokens on behalf of another address with anti-sniping protection
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        _transferWithAntiSnipe(from, to, amount);

        uint256 currentAllowance = allowance(from, _msgSender());
        require(currentAllowance >= amount, "Treza: allowance exceeded");
        _approve(from, _msgSender(), currentAllowance - amount);
        return true;
    }

    // =========================================================================
    // VIEW FUNCTIONS
    // =========================================================================

    /// @notice Check if address can currently trade
    function canTrade(address account) external view returns (bool) {
        if (!tradingEnabled) return false;
        if (isBlacklisted[account]) return false;
        if (whitelistMode && !isWhitelisted[account]) return false;
        
        // Check if in anti-bot period
        if (tradingEnabledBlock > 0 && block.number <= tradingEnabledBlock + antiBotBlockCount) {
            return isWhitelisted[account];
        }
        
        return true;
    }

    /// @notice Get launch status information
    function getLaunchStatus() external view returns (
        bool _tradingEnabled,
        bool _whitelistMode,
        uint256 _antiBotBlocksRemaining
    ) {
        uint256 antiBotRemaining = 0;
        if (tradingEnabledBlock > 0 && block.number <= tradingEnabledBlock + antiBotBlockCount) {
            antiBotRemaining = (tradingEnabledBlock + antiBotBlockCount) - block.number;
        }

        return (
            tradingEnabled,
            whitelistMode,
            antiBotRemaining
        );
    }

    /// @notice Get current anti-sniper status and timeline
    function getAntiSniperStatus() external view returns (
        bool _timeBasedEnabled,
        uint256 _currentPhase,
        uint256 _currentFee,
        uint256 _currentMaxWallet,
        uint256 _timeRemainingInPhase
    ) {
        if (!timeBasedAntiSniperEnabled || tradingEnabledTimestamp == 0) {
            return (false, 0, currentFeePercentage, TOTAL_SUPPLY, 0);
        }

        uint256 timeSinceLaunch = block.timestamp - tradingEnabledTimestamp;
        uint256 cumulativeTime = 0;

        for (uint256 i = 0; i < antiSniperPhases.length; i++) {
            cumulativeTime += antiSniperPhases[i].duration;
            if (timeSinceLaunch <= cumulativeTime) {
                uint256 timeRemainingInPhase = cumulativeTime - timeSinceLaunch;
                return (
                    true,
                    i + 1, // Phase 1-4
                    antiSniperPhases[i].feePercentage,
                    getCurrentMaxWallet(),
                    timeRemainingInPhase
                );
            }
        }

        // After all phases
        return (true, 5, currentFeePercentage, TOTAL_SUPPLY, 0);
    }

    /// @notice Get anti-sniper phase configuration
    function getAntiSniperPhase(uint256 phaseIndex) external view returns (TimeFeePhase memory) {
        require(phaseIndex < 4, "Treza: invalid phase index");
        return antiSniperPhases[phaseIndex];
    }
}