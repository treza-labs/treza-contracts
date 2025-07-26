// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/TokenTimelock.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";

/// @title TrezaToken
/// @author Brandon Torres and Treza Labs
/// @notice ERC20 token with dynamic fees, split to three treasury wallets, initial category allocations, vesting, and LP timelock helper.
/// @dev Inherits from OpenZeppelin ERC20 and Ownable. Uses SafeERC20 for safe transfers. Integrates TimelockController for upgradeability.
contract TrezaToken is ERC20, Ownable {
    using SafeERC20 for IERC20;

    /// @notice Total fixed supply of TREZA (100 million tokens)
    uint256 public constant TOTAL_SUPPLY = 100_000_000 * 1e18;

    /// @notice Allocation percentages for initial minting
    uint256 public constant PCT_COMMUNITY = 40;  // 40%
    uint256 public constant PCT_ECOSYSTEM = 25;  // 25%
    uint256 public constant PCT_TEAM      = 20;  // 20%
    uint256 public constant PCT_ADVISOR   = 15;  // 15%

    /// @notice Fee split: 2.0%, 1.6%, 0.4% respectively (summing to 4%)
    uint256 public constant FEE1_PCT = 50;   // 2.0% of total fee (50/100*4%)
    uint256 public constant FEE2_PCT = 40;   // 1.6% of total fee (40/100*4%)
    uint256 public constant FEE3_PCT = 10;   // 0.4% of total fee (10/100*4%)
    uint256 public constant FEE_SPLIT_TOTAL = 100; // 100 parts in total

    /// @notice Primary fee recipients
    address public treasuryWallet1;
    address public treasuryWallet2;
    address public treasuryWallet3;

    /// @notice Mapping of addresses exempted from transfer fees
    mapping(address => bool) public isFeeExempt;

    /// @notice Timestamp when fee drops from initial to mid level
    uint256 public immutable milestone1;
    /// @notice Timestamp when fee drops from mid level to zero
    uint256 public immutable milestone2;

    /// @notice Initial fee percentage (before milestone1)
    uint256 public constant FEE_INITIAL = 4;  // 4%
    /// @notice Mid fee percentage (between milestone1 and milestone2)
    uint256 public constant FEE_MID     = 2;  // 2%
    /// @notice Final fee percentage (after milestone2)
    uint256 public constant FEE_FINAL   = 0;  // 0%

    /// @notice Address of the deployed vesting contract for advisors
    address public advisorVestingContract;

    /// @notice Timelock controller for decentralized ownership
    TimelockController public timelockController;

    /// @dev Struct to hold constructor parameters to avoid stack too deep
    struct ConstructorParams {
        address communityWallet;
        address ecosystemWallet;
        address teamWallet;
        address advisor;
        address treasury1;
        address treasury2;
        address treasury3;
        uint256 dur1;
        uint256 dur2;
        uint256 vestCliff;
        uint256 vestDuration;
        uint256 timelockDelay;
    }


    /// @dev Emitted when fee wallets are updated
    /// @param old1 Previous first treasury wallet
    /// @param old2 Previous second treasury wallet
    /// @param old3 Previous third treasury wallet
    /// @param new1 New first treasury wallet
    /// @param new2 New second treasury wallet
    /// @param new3 New third treasury wallet
    event FeeWalletsUpdated(
        address indexed old1,
        address indexed old2,
        address indexed old3,
        address new1,
        address new2,
        address new3
    );


    /// @dev Emitted when an account's fee exemption status is toggled
    /// @param account The account affected
    /// @param isExempt Whether the account is now exempt
    event FeeExemptionUpdated(address indexed account, bool isExempt);

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
        _validateTreasuryWallets(params.treasury1, params.treasury2, params.treasury3);
        
        // Initialize milestones first to avoid stack issues
        milestone1 = block.timestamp + params.dur1;
        milestone2 = block.timestamp + params.dur2;
        
        _mintInitialAllocations(params);
        _setupVesting(params);
        _setupTreasuryWallets(params.treasury1, params.treasury2, params.treasury3);
        _setupTimelock(proposers, executors, params.timelockDelay);
    }

    /// @dev Validates that all required addresses are not zero
    function _validateAddresses(ConstructorParams memory params) private pure {
        require(
            params.communityWallet != address(0) &&
            params.ecosystemWallet != address(0) &&
            params.teamWallet != address(0) &&
            params.advisor != address(0) &&
            params.treasury1 != address(0) &&
            params.treasury2 != address(0) &&
            params.treasury3 != address(0),
            "Treza: zero address"
        );
    }
    

    /// @dev Validates that treasury wallets are unique
    function _validateTreasuryWallets(address t1, address t2, address t3) private pure {
        require(
            t1 != t2 && t1 != t3 && t2 != t3,
            "Treza: treasury wallets must be unique"
        );
    }

    /// @dev Mints initial token allocations
    function _mintInitialAllocations(ConstructorParams memory params) private {
        _mint(params.communityWallet, (TOTAL_SUPPLY * PCT_COMMUNITY) / 100);
        _mint(params.ecosystemWallet, (TOTAL_SUPPLY * PCT_ECOSYSTEM) / 100);
        _mint(params.teamWallet, (TOTAL_SUPPLY * PCT_TEAM) / 100);
    }

    /// @dev Sets up vesting contract for advisor
    function _setupVesting(ConstructorParams memory params) private {
        TokenVesting vest = new TokenVesting(
            IERC20(this),
            params.advisor,
            block.timestamp,
            params.vestCliff,
            params.vestDuration
        );
        advisorVestingContract = address(vest);
        _mint(advisorVestingContract, (TOTAL_SUPPLY * PCT_ADVISOR) / 100);
        isFeeExempt[advisorVestingContract] = true;
        emit FeeExemptionUpdated(advisorVestingContract, true);
    }

    /// @dev Sets up treasury wallets and exemptions
    function _setupTreasuryWallets(address t1, address t2, address t3) private {
        treasuryWallet1 = t1;
        treasuryWallet2 = t2;
        treasuryWallet3 = t3;
        
        isFeeExempt[t1] = true;
        isFeeExempt[t2] = true;
        isFeeExempt[t3] = true;
        
        emit FeeExemptionUpdated(t1, true);
        emit FeeExemptionUpdated(t2, true);
        emit FeeExemptionUpdated(t3, true);
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
    /// @param new3 New third treasury wallet
    function setFeeWallets(address new1, address new2, address new3) external onlyOwner {
        require(
            new1 != address(0) && new2 != address(0) && new3 != address(0),
            "Treza: zero address"
        );
        require(
            new1 != new2 && new1 != new3 && new2 != new3,
            "Treza: treasury wallets must be unique"
        );
        
        address old1 = treasuryWallet1;
        address old2 = treasuryWallet2;
        address old3 = treasuryWallet3;

        // Remove exemptions for old wallets
        isFeeExempt[old1] = false;
        isFeeExempt[old2] = false;
        isFeeExempt[old3] = false;
        emit FeeExemptionUpdated(old1, false);
        emit FeeExemptionUpdated(old2, false);
        emit FeeExemptionUpdated(old3, false);

        // Assign new wallets and exempt them
        treasuryWallet1 = new1;
        treasuryWallet2 = new2;
        treasuryWallet3 = new3;
        isFeeExempt[new1] = true;
        isFeeExempt[new2] = true;
        isFeeExempt[new3] = true;
        emit FeeExemptionUpdated(new1, true);
        emit FeeExemptionUpdated(new2, true);
        emit FeeExemptionUpdated(new3, true);

        emit FeeWalletsUpdated(old1, old2, old3, new1, new2, new3);
    }

    /// @notice Returns the current transfer fee percentage
    /// @return Fee percentage (0–4)
    function getCurrentFee() public view returns (uint256) {
        if (block.timestamp >= milestone2) {
            return FEE_FINAL;
        } else if (block.timestamp >= milestone1) {
            return FEE_MID;
        } else {
            return FEE_INITIAL;
        }
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

    /// @dev Distributes fees to treasury wallets
    function _distributeFees(address sender, uint256 fee) private {
        uint256 fee1 = (fee * FEE1_PCT) / FEE_SPLIT_TOTAL;
        uint256 fee2 = (fee * FEE2_PCT) / FEE_SPLIT_TOTAL;
        uint256 fee3 = fee - fee1 - fee2; // Ensure all fee is distributed

        super._transfer(sender, treasuryWallet1, fee1);
        super._transfer(sender, treasuryWallet2, fee2);
        super._transfer(sender, treasuryWallet3, fee3);
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

/// @title TokenVesting
/// @notice Linear vesting contract with cliff for advisor allocations
/// @dev Uses SafeERC20 to release without incurring transfer fees
contract TokenVesting {
    using SafeERC20 for IERC20;

    /// @notice ERC20 token being vested
    IERC20 public immutable token;
    /// @notice Address entitled to vested tokens
    address public immutable beneficiary;
    /// @notice Timestamp when vesting starts
    uint256 public immutable start;
    /// @notice Timestamp before which no tokens vest
    uint256 public immutable cliff;
    /// @notice Total duration for full vesting
    uint256 public immutable duration;
    /// @notice Amount already released
    uint256 public released;

    /// @param _token The ERC20 token to vest
    /// @param _beneficiary The address receiving vested tokens
    /// @param _start When vesting begins
    /// @param _cliffDuration Seconds until tokens begin vesting
    /// @param _duration Total seconds over which tokens fully vest
    constructor(
        IERC20 _token,
        address _beneficiary,
        uint256 _start,
        uint256 _cliffDuration,
        uint256 _duration
    ) {
        require(
            address(_token) != address(0) &&
            _beneficiary != address(0) &&
            _cliffDuration <= _duration,
            "Vesting: invalid params"
        );
        token = _token;
        beneficiary = _beneficiary;
        start = _start;
        cliff = _start + _cliffDuration;
        duration = _duration;
    }

    /// @notice Release vested tokens to the beneficiary without fees
    /// @dev Calculates vested amount, tracks released amount, and transfers tokens
    function release() external {
        require(block.timestamp >= cliff, "Vesting: cliff not reached");
        uint256 totalBalance = token.balanceOf(address(this)) + released;
        uint256 vested = block.timestamp >= start + duration
            ? totalBalance
            : (totalBalance * (block.timestamp - start)) / duration;
        uint256 unreleased = vested - released;
        require(unreleased > 0, "Vesting: none");

        released += unreleased;
        token.safeTransfer(beneficiary, unreleased);
    }

    /// @notice View the amount of tokens vested so far
    /// @return The vested token amount (including released)
    function vestedAmount() public view returns (uint256) {
        uint256 totalBalance = token.balanceOf(address(this)) + released;
        if (block.timestamp < cliff) {
            return 0;
        } else if (block.timestamp >= start + duration) {
            return totalBalance;
        } else {
            return (totalBalance * (block.timestamp - start)) / duration;
        }
    }
}
