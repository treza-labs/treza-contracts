# TREZA Token Deployment Guide

##  Quick Deploy Commands

### Local Testing
```bash
npx hardhat compile                    # Compile contracts
npx hardhat test                       # Run all tests
```

### Deploy to Sepolia
```bash
# 1. Set up environment
cp .env.example .env                   # Copy environment template
# Edit .env with your RPC URL and private key

# 2. Update wallet addresses in scripts/deploy.ts
# Replace all placeholder addresses with your actual wallets

# 3. Deploy with anti-sniping protection
npx hardhat run scripts/deploy.ts --network sepolia

# 4. Verify contract on Etherscan
npx hardhat run scripts/verify.ts --network sepolia
```

---

##  Anti-Sniping Protection

Your TREZA token deploys with **comprehensive anti-sniping protection**:

### Initial State (SAFE DEPLOYMENT)
-  **Trading DISABLED** (must be enabled manually)
-  **Whitelist-only mode** (only approved addresses can trade)

-  **Transfer cooldown** (1 second between transactions)
-  **All allocation wallets pre-whitelisted**

### Protection Features
-  **Whitelist-only trading periods**
 
-  **Transfer cooldown protection**
- « **Emergency blacklist capability**
-  **3-block anti-bot protection** after trading enabled
-  **Complete launch control**

---

## ‹ Required Wallet Addresses

You need **8 different wallet addresses**:

### Token Allocations (receive tokens on deployment)
| Wallet | Allocation | Amount |
|--------|------------|---------|
| **Team** | 65% | 65M TREZA |
| **Initial Liquidity** | 10% | 10M TREZA |
| **Marketing & Operations** | 10% | 10M TREZA |
| **R&D** | 5% | 5M TREZA |
| **Seed Investors** | 5% | 5M TREZA |
| **CEX Listing** | 5% | 5M TREZA |

### Fee Collection (earn from transactions)
- **Treasury Wallet 1:** 50% of all transfer fees
- **Treasury Wallet 2:** 50% of all transfer fees

### Contract Owner
- **Contract Owner:** You own the contract directly (can transfer ownership later)

---

##  Fair Launch Sequence

### Phase 1: Pre-Launch Setup
```bash
# After deployment, add trusted addresses to whitelist
# (DEX routers, team wallets, early supporters)
```

### Phase 2: Liquidity Setup
```bash
# Add initial liquidity using whitelisted addresses only
# This prevents bots from front-running liquidity
```

### Phase 3: Enable Trading
```bash
# Enable trading when ready
# Anti-bot protection activates for 3 blocks
```

### Phase 4: Public Launch
```bash
# Disable whitelist mode when ready for public
# Optionally remove transaction limits after stabilization
```

---

##  Launch Management Functions

### Trading Control (Owner Only - Instant Changes)
- `setTradingEnabled(true/false)` - Master trading switch
- `setWhitelistMode(true/false)` - Whitelist-only mode

### Whitelist Management (Owner Only - Instant Changes)
- `setWhitelist([addresses], true)` - Add to whitelist
- `setWhitelist([addresses], false)` - Remove from whitelist

### Emergency Controls (Owner Only - Instant Changes)
- `setBlacklist([addresses], true)` - Emergency blacklist
- `setAntiSniperConfig(blocks, cooldown)` - Adjust protection

### Fee Management (Owner Only - Instant Changes)
- `setFeePercentage(newFee)` - Adjust fees (0-10%)
- `setFeeWallets(wallet1, wallet2)` - Update fee recipients
- `setFeeExemption(address, bool)` - Exempt from fees

---

##  Contract Features

###  Core Tokenomics
- **Fixed Supply:** 100M TREZA tokens
- **Transfer Fees:** 5% initial (adjustable 0-10%)
- **Dual Treasury:** 50/50 fee split
- **Ownership:** Direct ownership (governance can be added later)

###  Anti-Sniping Features
- **Whitelist Control:** Complete trading access control
- **Transaction Limits:** Prevent whale manipulation
- **Cooldown Protection:** Prevent spam/bot trading
- **Launch Management:** Controlled trading activation
- **Emergency Controls:** Blacklist malicious addresses

###  View Functions
```solidity
// Launch Status
getLaunchStatus()                    // Get all launch parameters
canTrade(address)                   // Check if address can trade

// Core Info
getCurrentFee()                     // Current fee percentage  
balanceOf(address)                  // Token balance
isFeeExempt(address)               // Check fee exemption
isWhitelisted(address)             // Check whitelist status
isBlacklisted(address)             // Check blacklist status
```

---

##  Security Setup

### Required Environment Variables
```env
SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/YOUR_KEY
PRIVATE_KEY=your_private_key_here
ETHERSCAN_API_KEY=your_etherscan_api_key
```

### Sepolia ETH Faucets
- **Alchemy:** https://sepoliafaucet.com  
- **Chainlink:** https://faucets.chain.link/sepolia
- **QuickNode:** https://faucet.quicknode.com/ethereum/sepolia
- **Infura:** https://www.infura.io/faucet/sepolia

### RPC Providers
- **Alchemy:** https://alchemy.com (Recommended)
- **Infura:** https://infura.io
- **QuickNode:** https://quicknode.com

---

##  Post-Deployment Checklist

### 1. Verify Contract 
```bash
npx hardhat run scripts/verify.ts --network sepolia
```

### 2. Configure Launch Settings 
- [ ] Add DEX addresses to whitelist
- [ ] Add team/community addresses to whitelist  
- [ ] Test small transactions
- [ ] Verify anti-sniping features work

### 3. Execute Launch Sequence 
- [ ] Add initial liquidity (whitelisted only)
- [ ] Enable trading
- [ ] Monitor for 3-block anti-bot period
- [ ] Announce to community
- [ ] Disable whitelist when ready for public
- [ ] Remove limits after stabilization

### 4. Documentation 
- [ ] Update README with contract address
- [ ] Share contract address with stakeholders
- [ ] Provide ANTI_SNIPE_GUIDE.md to team

---

##  Security Warnings

 **CRITICAL SECURITY NOTES:**
- **NEVER commit private keys to git**
- **Always test on Sepolia before mainnet**
- **Verify contract on Etherscan after deployment**
- **Keep owner private key secure (you control everything)**
- **Test all anti-sniping features before launch**
- **Have emergency procedures ready**
- **Consider transferring to multisig after launch for shared control**

---

##  Additional Resources

- **Anti-Sniping Guide:** See `ANTI_SNIPE_GUIDE.md` for complete launch management
- **Hardhat Docs:** https://hardhat.org/docs
- **OpenZeppelin:** https://docs.openzeppelin.com  
- **Etherscan:** https://sepolia.etherscan.io

---

##  Congratulations!

Your TREZA token now has **comprehensive anti-sniping protection** and is ready for a **fair launch**! 

Your token is ready for a secure deployment and launch. 

**Happy deploying!** 