# TREZA Token

## Overview

TREZA Token is an ERC20 token with anti-sniping protection, dynamic fee collection, and launch management capabilities. The contract includes whitelist controls and governance features designed for fair token launches.

---

## 🔥 Key Features

### 🛡️ Anti-Sniping Protection

**🚀 Time-Based Anti-Sniper Launch Mechanism:**
- **Private Period:** 0% fee, no max wallet (whitelist only)
- **Phase 1 (0-1 min):** 40% fee, 0.10% max wallet (100K TREZA)
- **Phase 2 (1-5 min):** 30% fee, 0.15% max wallet (150K TREZA)
- **Phase 3 (5-8 min):** 20% fee, 0.20% max wallet (200K TREZA)
- **Phase 4 (8-15 min):** 10% fee, 0.30% max wallet (300K TREZA)
- **After 15 min:** Normal 5% fee, no max wallet limit

**Traditional Bot Protection Features:**
- **Whitelist-only trading periods** - Only approved addresses can trade initially
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
- **Private Period:** 0% on all transfers (whitelist-only trading)
- **Public Launch Fees:** 40% → 30% → 20% → 10% → 5% (first 15 minutes)
- **Normal Fee:** 5% on all transfers (after anti-sniper period)
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
setFeePercentage(uint256)            // Adjust manual fees (0-10%)
setFeeWallets(address, address)      // Update treasury wallets
setFeeExemption(address, bool)       // Manage fee exemptions
getCurrentFee()                      // View current fee (time-based or manual)
```

### Time-Based Anti-Sniper Management
```solidity
setTimeBasedAntiSniper(bool)         // Enable/disable time-based system
setAntiSniperPhases(phases)          // Update phase configurations
getAntiSniperStatus()                // Get current phase, fee, max wallet, time remaining
getCurrentMaxWallet()                // View current max wallet limit
getAntiSniperPhase(uint256)          // Get specific phase configuration
startPublicTradingTimer()            // Manually start anti-sniper countdown
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
2. **Check trading mode** (whitelist-only vs public trading)
3. **Check exemptions** (treasury wallets, whitelisted addresses)  
4. **Check max wallet limits** (if time-based anti-sniper enabled and public trading)
5. **Apply current fee:**
   - **Private Period:** 0% (whitelist-only trading)
   - **Public Trading:** 40%→30%→20%→10%→5% (time-based) OR manual fee
6. **Split fees 50/50** between treasury wallets (if fees apply)
7. **Transfer remaining** amount to recipient

**Fee Exemptions & Max Wallet Bypasses:**
- Treasury wallets (automatic exemption from fees and max wallet)
- Whitelisted addresses (configurable exemption from max wallet)
- Private period (0% fees for all transactions during whitelist mode)

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
- **Time-Based Anti-Sniper:** Enabled (dynamic fees and max wallet)
- **Transfer Cooldown:** 1 second
- **Anti-Bot Protection:** 3 blocks
- **Normal Fee:** 5% (after anti-sniper period)

### Time-Based Anti-Sniper Configuration
- **Private Period:** 0% fee, no max wallet (whitelist-only trading)
- **Phase 1 (0-1 min public):** 40% fee, 100,000 TREZA max wallet (0.10%)
- **Phase 2 (1-5 min public):** 30% fee, 150,000 TREZA max wallet (0.15%)
- **Phase 3 (5-8 min public):** 20% fee, 200,000 TREZA max wallet (0.20%)
- **Phase 4 (8-15 min public):** 10% fee, 300,000 TREZA max wallet (0.30%)
- **Normal (15+ min public):** 5% fee, no max wallet limit

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
- ✅ **TREZA:** Comprehensive anti-sniping protection with time-based deterrents

### Compared to Basic Fee Tokens  
- ❌ **Basic:** Simple percentage fees
- ✅ **TREZA:** Free private trading + time-based dynamic fees (0%→40%→5%) + dual treasury + governance

### Compared to Manual Launch Tokens
- ❌ **Manual:** Prone to human error and rushed launches
- ✅ **TREZA:** Automated 15-minute anti-sniper system with graduated protection

### Compared to Simple Anti-Bot Tokens
- ❌ **Simple:** Basic blacklist or cooldown only
- ✅ **TREZA:** Multi-layered protection: time-based fees + max wallet + whitelist + cooldown + blacklist

---

## Summary

TREZA Token provides:
- 🛡️ **Most comprehensive bot protection available** with time-based anti-sniper system
- 🆓 **Free private trading** for trusted early supporters (0% fees)
- 💰 **Dynamic tokenomics** with graduated fees (0%→40%→30%→20%→10%→5%)
- 🚀 **Automated launch protection** across 4 phases over 15 minutes
- 🏛️ **Decentralized governance** with timelock controller
- 🔒 **Multi-layered security** features
- ⚖️ **Fair launch system** that rewards patience and deters manipulation

Ready for deployment with the most advanced anti-sniping protection in DeFi.

---

## 📞 Documentation

- **Hardhat Documentation:** https://hardhat.org/docs
- **OpenZeppelin Contracts:** https://docs.openzeppelin.com
- **Etherscan:** https://sepolia.etherscan.io
- **Treza Labs** https://docs.trezalabs.com
