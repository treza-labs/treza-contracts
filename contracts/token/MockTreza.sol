// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MockTreza
 * @dev Simple mock TREZA token for testing compliance integration
 */
contract MockTreza is ERC20, Ownable {
    
    constructor() ERC20("Mock TREZA Token", "MTREZA") Ownable(msg.sender) {
        // Mint 100 million tokens to deployer
        _mint(msg.sender, 100_000_000 * 1e18);
    }
    
    /**
     * @dev Mint additional tokens (for testing)
     */
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
    
    /**
     * @dev Burn tokens (for testing)
     */
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }
}
