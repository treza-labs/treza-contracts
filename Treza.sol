// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/TokenTimelock.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";

/// @title TrezaToken
/// @author Treza Labs 
/// @notice ERC20 token with manual fees, split to two treasury wallets, initial category allocations, and LP timelock helper.
/// @dev Inherits from OpenZeppelin ERC20 and Ownable. Uses SafeERC20 for safe transfers. Integrates TimelockController for upgradeability.
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


    /// @dev Emitted when fee wallets are updated
    /// @param old1 Previous first treasury wallet
    /// @param old2 Previous second treasury wallet
    /// @param new1 New first treasury wallet
    /// @param new2 New second treasury wallet
    event FeeWalletsUpdated(
        address indexed old1,
        address indexed old2,
        address new1,
        address new2
    );


    /// @dev Emitted when an account's fee exemption status is toggled
    /// @param account The account affected
    /// @param isExempt Whether the account is now exempt
    event FeeExemptionUpdated(address indexed account, bool isExempt);

    /// @dev Emitted when the fee percentage is updated
    /// @param oldFee Previous fee percentage
    /// @param newFee New fee percentage
    event FeePercentageUpdated(uint256 oldFee, uint256 newFee);

    /// @dev Emitted when timelock controller is deployed and ownership transferred
    /// @param timelock Address of the deployed timelock controller
    event TimelockControllerSet(address indexed timelock);

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
        
        // Initialize fee percentage to 4%
        currentFeePercentage = 4;
        
        _mintInitialAllocations(params);
        _setupTreasuryWallets(params.treasury1, params.treasury2);
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

    /// @notice Exempt or include an account from transfer fees
    /// @dev Owner-only control
    /// @param account Address to update
    /// @param exempt True to exempt, false to remove exemption
    function setFeeExemption(address account, bool exempt) external onlyOwner {
        isFeeExempt[account] = exempt;
        emit FeeExemptionUpdated(account, exempt);
    }

    /// @notice Change the treasury fee recipient addresses
    /// @dev Automatically updates fee exemptions for old and new wallets
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
    /// @return Fee percentage (0–10)
    function getCurrentFee() public view returns (uint256) {
        return currentFeePercentage;
    }

    /// @notice Update the transfer fee percentage
    /// @dev Owner-only control, cannot exceed MAX_FEE_PERCENTAGE
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

    /// @dev Internal transfer function that applies dynamic fees and exemptions
    /// @param sender Address sending tokens
    /// @param recipient Address receiving tokens
    /// @param amount Amount of tokens to transfer
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

    /// @notice Transfer tokens, applying dynamic fees
    /// @param to Recipient address
    /// @param amount Amount to transfer
    /// @return True if the operation succeeds
    function transfer(address to, uint256 amount)
        public virtual override returns (bool)
    {
        _transferWithPossibleFee(_msgSender(), to, amount);
        return true;
    }

    /// @notice Transfer tokens on behalf of another address, applying dynamic fees
    /// @param from Sender address
    /// @param to Recipient address
    /// @param amount Amount to transfer
    /// @return True if the operation succeeds
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        _transferWithPossibleFee(from, to, amount);

        uint256 currentAllowance = allowance(from, _msgSender());
        require(currentAllowance >= amount, "Treza: allowance exceeded");
        _approve(from, _msgSender(), currentAllowance - amount);
        return true;
    }

    /// @notice Lock any ERC20 LP tokens until a specified time
    /// @dev Deploys an OpenZeppelin TokenTimelock and exempts it from fees
    /// @param lpToken ERC20 token to lock
    /// @param beneficiary Address that will receive tokens after releaseTime
    /// @param releaseTime UNIX timestamp when tokens become releasable
    /// @return Address of the deployed TokenTimelock contract
    function lockLPTokens(
        IERC20 lpToken,
        address beneficiary,
        uint256 releaseTime
    ) external onlyOwner returns (address) {
        TokenTimelock timelock = new TokenTimelock(lpToken, beneficiary, releaseTime);
        isFeeExempt[address(timelock)] = true;
        emit FeeExemptionUpdated(address(timelock), true);
        return address(timelock);
    }
}


