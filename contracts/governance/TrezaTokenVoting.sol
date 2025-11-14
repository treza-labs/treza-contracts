// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title TrezaTokenVoting
 * @dev Voting-enabled version of Treza token for DAO governance
 * 
 * This is a separate token contract that includes voting functionality.
 * Use this for testing DAO governance or as a governance token.
 * 
 * Features:
 * - ERC20Votes for governance participation
 * - Checkpoint system for historical voting power
 * - Delegation support
 * - Same tokenomics as main Treza token
 */
contract TrezaTokenVoting is ERC20, ERC20Votes, Ownable {
    
    // Same constants as main Treza token
    uint256 public constant TOTAL_SUPPLY = 1_000_000_000 * 10**18; // 1 billion tokens
    
    // Treasury addresses
    address public treasury1;
    address public treasury2;
    
    constructor(
        address _treasury1,
        address _treasury2,
        address _initialHolder
    ) 
        ERC20("Treza Governance Token", "TREZAGOV") 
        ERC20Votes()
        Ownable(_initialHolder)
    {
        require(_treasury1 != address(0), "Invalid treasury1 address");
        require(_treasury2 != address(0), "Invalid treasury2 address");
        require(_initialHolder != address(0), "Invalid initial holder address");
        
        treasury1 = _treasury1;
        treasury2 = _treasury2;
        
        // Mint total supply to initial holder
        // In practice, you'd distribute this appropriately
        _mint(_initialHolder, TOTAL_SUPPLY);
        
        // Delegate voting power to self initially
        _delegate(_initialHolder, _initialHolder);
    }
    
    /**
     * @dev Update treasury addresses (governance controlled)
     */
    function updateTreasuryAddresses(address _treasury1, address _treasury2) external onlyOwner {
        require(_treasury1 != address(0), "Invalid treasury1 address");
        require(_treasury2 != address(0), "Invalid treasury2 address");
        
        treasury1 = _treasury1;
        treasury2 = _treasury2;
    }
    
    // The following functions are overrides required by Solidity.
    
    function _update(address from, address to, uint256 value)
        internal
        override(ERC20, ERC20Votes)
    {
        super._update(from, to, value);
    }

    function nonces(address owner)
        public
        view
        override(ERC20Votes, Nonces)
        returns (uint256)
    {
        return super.nonces(owner);
    }
}
