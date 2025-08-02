# TREZA Token

## Overview

TREZA Token is an ERC20 token with anti-sniping protection, dynamic fee collection, and launch management capabilities. The contract includes whitelist controls, transaction limits, and governance features designed for fair token launches.

---

## 🔥 Key Features

### 🛡️ Anti-Sniping Protection

**Bot Protection Features:**
- **Whitelist-only trading periods** - Only approved addresses can trade initially
- **Anti-whale transaction limits** - Maximum 0.1% of supply per transaction
- **Anti-whale wallet limits** - Maximum 0.2% of supply per wallet
- **Transfer cooldown protection** - 1-second minimum between transactions
- **3-block anti-bot protection** - Enhanced protection after trading enabled
- **Emergency blacklist capability** - Block malicious addresses instantly
- **Complete launch control** - Master trading enable/disable

### 💰 Tokenomics

**Fixed Supply & Allocations:**
- **Total Supply:** 100 million TREZA tokens (fixed)
- **Initial Liquidity:** 35% (35M TREZA)
- **Team:** 20% (20M TREZA)  
- **Treasury:** 20% (20M TREZA)
- **Partnerships & Grants:** 10% (10M TREZA)
- **R&D:** 5% (5M TREZA)
- **Marketing & Operations:** 10% (10M TREZA)

**Dynamic Fee System:**
- **Initial Fee:** 4% on all transfers
- **Adjustable Range:** 0-10% (governance controlled)
- **Dual Treasury:** 50/50 split between two treasury wallets
- **Fee Exemptions:** Treasury wallets and whitelisted addresses exempt

### 🏛️ Decentralized Governance

**TimelockController Integration:**
- **Automatic deployment** of OpenZeppelin TimelockController
- **Ownership transfer** to timelock for decentralized control
- **Proposal and execution** roles for governance actions
- **Time delays** for all critical changes
- **On-chain governance** with full transparency

---

## 🚀 Launch Management System

### Phase 1: Pre-Launch (Safe Deployment)
- ❌ **Trading disabled** by default
- ✅ **Whitelist-only mode** active

- ✅ **All allocation wallets pre-whitelisted**

### Phase 2: Controlled Launch
- 📝 **Add trusted addresses** to whitelist (DEX, team, early supporters)
- 🏊 **Add initial liquidity** (only whitelisted addresses can participate)
- 🚀 **Enable trading** when ready (anti-bot protection activates)

### Phase 3: Public Launch
- 🌍 **Disable whitelist mode** for public access
- 📊 **Monitor and adjust** as needed


---

## 🔧 Management Functions

### Launch Control
```solidity
setTradingEnabled(bool)              // Master trading switch
setWhitelistMode(bool)               // Whitelist-only mode

```

### Whitelist Management
```solidity
setWhitelist(address[], bool)        // Manage whitelist
isWhitelisted(address)               // Check whitelist status
```



### Emergency Controls
```solidity
setBlacklist(address[], bool)        // Emergency blacklist
setAntiSniperConfig(uint256, uint256) // Adjust protection parameters
```

### Fee Management
```solidity
setFeePercentage(uint256)            // Adjust fees (0-10%)
setFeeWallets(address, address)      // Update treasury wallets
setFeeExemption(address, bool)       // Manage fee exemptions
getCurrentFee()                      // View current fee
```

### Status Checking
```solidity
getLaunchStatus()                    // Get all launch parameters
canTrade(address)                    // Check if address can trade
```

---

## 🎯 Anti-Bot Protection Details

### Whitelist System
- **Pre-approved trading** during launch phase
- **Prevents bot sniping** at token launch
- **Controlled access** for fair distribution

### Transaction Limits
- **Max transaction:** 0.1% of total supply (100,000 TREZA)
- **Max wallet:** 0.2% of total supply (200,000 TREZA)  
- **Prevents whale manipulation** during early trading

### Cooldown Protection
- **1-second minimum** between transactions per address
- **Prevents spam trading** and bot attacks
- **Whitelisted addresses exempt** from cooldown

### Anti-Bot Blocks
- **3-block protection** after trading enabled
- **Additional protection** during initial trading activation
- **Only whitelisted addresses** can trade during this period

### Emergency Controls
- **Instant blacklisting** of malicious addresses
- **Configurable protection parameters**
- **Emergency pause capabilities**

---

## 💸 Fee Distribution Flow

1. **Transfer initiated** between addresses
2. **Check exemptions** (treasury wallets, whitelisted addresses)
3. **Apply current fee** (4% initial, 0-10% range)
4. **Split fees 50/50** between treasury wallets
5. **Transfer remaining** amount to recipient

**Fee Exemptions:**
- Treasury wallets (automatic)
- Whitelisted addresses (configurable)
- Contract-to-contract transfers (when appropriate)

---

## 🔒 Security & Best Practices

### Built-in Security
- **OpenZeppelin libraries** (audited and tested)
- **SafeERC20** for secure token transfers
- **Address validation** prevents zero-address errors
- **Unique treasury validation** ensures distinct wallets
- **Comprehensive event logging** for transparency

### Gas Optimization
- **Struct-based parameters** avoid stack depth issues
- **Modular internal functions** for code reuse
- **Early returns** when fees don't apply
- **Optimized fee calculations** with proper remainder handling

### Governance Security
- **TimelockController** prevents rushed decisions
- **Multi-signature capable** through proposer/executor roles
- **Time delays** for all critical changes
- **Transparent on-chain execution**

---

## 📊 Technical Specifications

### Contract Architecture
- **TrezaToken:** Main ERC20 contract with anti-sniping features
- **TimelockController:** Governance and ownership management
- **Modular design** for maintainability and upgrades

### Default Configuration
- **Trading:** Disabled (manual activation required)
- **Whitelist Mode:** Enabled (public trading disabled)
- **Max Transaction:** 100,000 TREZA (0.1% of supply)
- **Max Wallet:** 200,000 TREZA (0.2% of supply)
- **Transfer Cooldown:** 1 second
- **Anti-Bot Protection:** 3 blocks
- **Initial Fee:** 4%

---

## 🚀 Deployment

### Quick Deploy
```bash
# 1. Update addresses in scripts/deploy.ts
# 2. Deploy with anti-sniping protection
npx hardhat run scripts/deploy.ts --network sepolia

# 3. Verify on Etherscan  
npx hardhat run scripts/verify.ts --network sepolia
```

### Requirements
- **8 unique wallet addresses** for allocations and governance
- **Sepolia ETH** for deployment gas
- **RPC provider** (Alchemy, Infura, QuickNode)
- **Etherscan API key** for verification

---

## 📚 Documentation

- **`DEPLOYMENT_GUIDE.md`** - Complete deployment instructions
- **`ANTI_SNIPE_GUIDE.md`** - Detailed anti-sniping management guide
- **Smart Contract Comments** - Inline documentation in Solidity code

---

## Key Differences

### Compared to Standard ERC20 Tokens
- ❌ **Standard:** Vulnerable to bot sniping
- ✅ **TREZA:** Anti-sniping protection included

### Compared to Basic Fee Tokens  
- ❌ **Basic:** Simple percentage fees
- ✅ **TREZA:** Dynamic fees + dual treasury + governance

### Compared to Manual Launch Tokens
- ❌ **Manual:** Prone to human error and rushed launches
- ✅ **TREZA:** Systematic launch management with safety controls

---

## Summary

TREZA Token provides:
- 🛡️ **Comprehensive bot protection**
- 💰 **Flexible tokenomics**
- 🚀 **Controlled launch capabilities** 
- 🏛️ **Decentralized governance**
- 🔒 **Security features**

Ready for deployment and launch.

---

## 📞 Documentation

- **Hardhat Documentation:** https://hardhat.org/docs
- **OpenZeppelin Contracts:** https://docs.openzeppelin.com
- **Etherscan:** https://sepolia.etherscan.io
- **Treza Labs** https://docs.trezalabs.com

**Built with ❤️ by Treza Labs**