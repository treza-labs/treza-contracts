// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/TokenTimelock.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title TrezaToken
/// @author Brandon Torres and Treza Labs
/// @notice ERC20 token with dynamic fees, split to two treasury wallets, initial category allocations, vesting, and LP timelock helper.
/// @dev Inherits from OpenZeppelin ERC20 and Ownable. Uses SafeERC20 for safe transfers.
contract TrezaToken is ERC20, Ownable {
    using SafeERC20 for IERC20;

    /// @notice Total fixed supply of TREZA (100 million tokens)
    uint256 public constant TOTAL_SUPPLY = 100_000_000 * 1e18;

    /// @notice Allocation percentages for initial minting
    uint256 public constant PCT_COMMUNITY = 40;  // 40%
    uint256 public constant PCT_ECOSYSTEM = 25;  // 25%
    uint256 public constant PCT_TEAM      = 20;  // 20%
    uint256 public constant PCT_ADVISOR   = 15;  // 15%

    /// @notice Primary recipient of half the fee
    address public treasuryWallet1;
    /// @notice Secondary recipient of half the fee
    address public treasuryWallet2;

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

    /// @dev Emitted when fee wallets are updated
    /// @param old1 Previous first treasury wallet
    /// @param old2 Previous second treasury wallet
    /// @param new1 New first treasury wallet
    /// @param new2 New second treasury wallet
    event FeeWalletsUpdated(
        address indexed old1,
        address indexed old2,
        address indexed new1,
        address new2
    );

    /// @dev Emitted when an account's fee exemption status is toggled
    /// @param account The account affected
    /// @param isExempt Whether the account is now exempt
    event FeeExemptionUpdated(address indexed account, bool isExempt);

    /// @param communityWallet   Address receiving 40% of tokens
    /// @param ecosystemWallet   Address receiving 25% of tokens
    /// @param teamWallet        Address receiving 20% of tokens
    /// @param advisor           Address receiving vesting contract shares (15%)
    /// @param _treasury1        First treasury fee wallet
    /// @param _treasury2        Second treasury fee wallet
    /// @param dur1              Seconds until fee drops 4%→2%
    /// @param dur2              Seconds until fee drops 2%→0%
    /// @param vestCliff         Cliff duration for advisor vesting
    /// @param vestDuration      Total duration for advisor vesting
    constructor(
        address communityWallet,
        address ecosystemWallet,
        address teamWallet,
        address advisor,
        address _treasury1,
        address _treasury2,
        uint256 dur1,
        uint256 dur2,
        uint256 vestCliff,
        uint256 vestDuration
    )
        ERC20("Treza Token", "TREZA")
        Ownable(msg.sender)
    {
        require(
            communityWallet  != address(0) &&
            ecosystemWallet  != address(0) &&
            teamWallet       != address(0) &&
            advisor          != address(0) &&
            _treasury1       != address(0) &&
            _treasury2       != address(0),
            "Treza: zero address"
        );

        // Mint initial allocations
        _mint(communityWallet, (TOTAL_SUPPLY * PCT_COMMUNITY) / 100);
        _mint(ecosystemWallet, (TOTAL_SUPPLY * PCT_ECOSYSTEM) / 100);
        _mint(teamWallet,      (TOTAL_SUPPLY * PCT_TEAM)      / 100);

        // Deploy vesting for advisor and fund it
        TokenVesting vest = new TokenVesting(
            IERC20(this),
            advisor,
            block.timestamp,
            vestCliff,
            vestDuration
        );
        advisorVestingContract = address(vest);
        _mint(advisorVestingContract, (TOTAL_SUPPLY * PCT_ADVISOR) / 100);

        // Set and exempt treasury wallets
        treasuryWallet1 = _treasury1;
        treasuryWallet2 = _treasury2;
        isFeeExempt[treasuryWallet1]        = true;
        isFeeExempt[treasuryWallet2]        = true;
        isFeeExempt[advisorVestingContract] = true;
        emit FeeExemptionUpdated(treasuryWallet1, true);
        emit FeeExemptionUpdated(treasuryWallet2, true);
        emit FeeExemptionUpdated(advisorVestingContract, true);

        // Initialize fee reduction milestones
        milestone1 = block.timestamp + dur1;
        milestone2 = block.timestamp + dur2;
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
        require(new1 != address(0) && new2 != address(0), "Treza: zero address");
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
        uint256 fee = (amount * pct) / 100;
        uint256 net = amount - fee;

        if (fee > 0) {
            uint256 half  = fee / 2;
            uint256 other = fee - half;
            super._transfer(sender, treasuryWallet1, half);
            super._transfer(sender, treasuryWallet2, other);
        }
        super._transfer(sender, recipient, net);
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
            address(_token)      != address(0) &&
            _beneficiary         != address(0) &&
            _cliffDuration <= _duration,
            "Vesting: invalid params"
        );
        token       = _token;
        beneficiary = _beneficiary;
        start       = _start;
        cliff       = _start + _cliffDuration;
        duration    = _duration;
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

