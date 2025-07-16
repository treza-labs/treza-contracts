// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;


import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title TrezaToken
/// @dev ERC20 with a 4% fee on every transfer, routed to a treasury wallet.
contract TrezaToken is ERC20, Ownable {
    uint256 public feePercent = 4;               // 4% fee
    address public treasuryWallet;               // collects the fees

    /// @param _treasuryWallet the address that collects fees
    /// @param initialSupply total TREZA to mint (in whole tokens)
    constructor(address _treasuryWallet, uint256 initialSupply)
        ERC20("Treza Token", "TREZA")
        Ownable(msg.sender)
    {
        require(_treasuryWallet != address(0), "Treasury wallet zero");
        treasuryWallet = _treasuryWallet;
        _mint(msg.sender, initialSupply * 10 ** decimals());
    }

    /// @notice Change the fee percentage (max 10%)
    function setFeePercent(uint256 _pct) external onlyOwner {
        require(_pct <= 10, "Fee too high");
        feePercent = _pct;
    }

    /// @notice Update the treasury wallet
    function setTreasuryWallet(address _wallet) external onlyOwner {
        require(_wallet != address(0), "Treasury wallet zero");
        treasuryWallet = _wallet;
    }

    /// @dev Overrides ERC20.transfer to deduct feePercent.
    function transfer(address recipient, uint256 amount)
        public
        virtual
        override
        returns (bool)
    {
        uint256 fee = (amount * feePercent) / 100;
        uint256 net = amount - fee;

        // 1) send fee to treasury
        super._transfer(_msgSender(), treasuryWallet, fee);
        // 2) send remainder to recipient
        super._transfer(_msgSender(), recipient, net);
        return true;
    }

    /// @dev Overrides ERC20.transferFrom to deduct feePercent.
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        uint256 fee = (amount * feePercent) / 100;
        uint256 net = amount - fee;

        // 1) fee to treasury
        super._transfer(sender, treasuryWallet, fee);
        // 2) remainder to recipient
        super._transfer(sender, recipient, net);

        // 3) decrease allowance by full amount
        uint256 currentAllowance = allowance(sender, _msgSender());
        require(currentAllowance >= amount, "ERC20: transfer exceeds allowance");
        _approve(sender, _msgSender(), currentAllowance - amount);

        return true;
    }
}

/// @title TokenVesting
/// @dev Simple linear vesting with 6‑month cliff, then linear until end.
contract TokenVesting {
    using SafeERC20 for IERC20;

    IERC20 public immutable token;
    address public immutable beneficiary;
    uint256 public immutable start;
    uint256 public immutable cliff;
    uint256 public immutable duration;
    uint256 public released;

    /// @param _token the ERC20 token to vest
    /// @param _beneficiary the address receiving vested tokens
    /// @param _start timestamp when vesting starts
    /// @param _cliffDuration seconds after start before any tokens vest
    /// @param _duration total vesting duration (must ≥ _cliffDuration)
    constructor(
        IERC20 _token,
        address _beneficiary,
        uint256 _start,
        uint256 _cliffDuration,
        uint256 _duration
    ) {
        require(address(_token) != address(0), "Token zero");
        require(_beneficiary != address(0), "Beneficiary zero");
        require(_cliffDuration <= _duration, "Cliff > duration");

        token       = _token;
        beneficiary = _beneficiary;
        start       = _start;
        cliff       = _start + _cliffDuration;
        duration    = _duration;
    }

    /// @notice Transfers vested tokens to beneficiary
    function release() external {
        require(block.timestamp >= cliff, "Cliff not reached");
        uint256 vested     = vestedAmount();
        uint256 unreleased = vested - released;
        require(unreleased > 0, "Nothing to release");

        released += unreleased;
        token.safeTransfer(beneficiary, unreleased);
    }

    /// @return total tokens vested so far (including already released)
    function vestedAmount() public view returns (uint256) {
        uint256 total = token.balanceOf(address(this)) + released;

        if (block.timestamp < cliff) {
            return 0;
        } else if (block.timestamp >= start + duration) {
            return total;
        } else {
            return (total * (block.timestamp - start)) / duration;
        }
    }
}
