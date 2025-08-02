# 🛡️ TREZA Anti-Sniping Protection Guide

## 🎯 **Overview**

Your enhanced TREZA token includes comprehensive anti-sniping protection to ensure a fair launch and prevent bot attacks. This guide explains all the protection mechanisms and how to use them.

## 🔥 **Anti-Sniping Features**

### 1. **Whitelist-Only Trading Period**
- **What it does:** Only whitelisted addresses can trade initially
- **Default state:** ENABLED (public trading disabled)
- **Purpose:** Prevent bots from sniping during launch
- **Control:** `setWhitelistMode(bool)` (owner only)

### 2. **Trading Enable/Disable**
- **What it does:** Complete trading halt override
- **Default state:** DISABLED (no trading allowed)
- **Purpose:** Full control over when trading begins
- **Control:** `setTradingEnabled(bool)` (owner only)

### 3. **Anti-Whale Limits**
- **Max Transaction:** 0.1% of total supply (100,000 TREZA)
- **Max Wallet:** 0.2% of total supply (200,000 TREZA)
- **Default state:** ENABLED during launch
- **Purpose:** Prevent large purchases that manipulate price
- **Control:** `setMaxLimits(uint256, uint256)` and `setMaxLimitsActive(bool)`

### 4. **Transfer Cooldown**
- **What it does:** Minimum 1 second between transactions per address
- **Purpose:** Prevent spam/rapid bot trading
- **Control:** `setAntiSniperConfig(uint256 blocks, uint256 cooldown)`

### 5. **Anti-Bot Block Protection**
- **What it does:** Extra protection for 3 blocks after trading enabled
- **Purpose:** Prevent immediate bot sniping when trading starts
- **Only whitelisted addresses can trade during this period**

### 6. **Emergency Blacklist**
- **What it does:** Manually block suspicious addresses
- **Purpose:** Emergency response to detected bots/bad actors
- **Control:** `setBlacklist(address[], bool)` (owner only)

## 🚀 **Fair Launch Sequence**

### **Phase 1: Pre-Launch Setup** ⚙️
```solidity
// 1. Deploy contract (trading disabled, whitelist-only)
// 2. Add team/DEX addresses to whitelist
setWhitelist([dexRouter, liquidityWallet, teamWallet], true);

// 3. Add community whitelist (presale participants, etc.)
setWhitelist([user1, user2, user3], true);
```

### **Phase 2: Liquidity Addition** 🏊
```solidity
// 4. Add initial liquidity (only whitelisted addresses can do this)
// Your DEX addresses should be whitelisted
// This prevents bots from front-running liquidity
```

### **Phase 3: Launch** 🚀
```solidity
// 5. Enable trading (starts anti-bot protection)
setTradingEnabled(true);

// 6. Wait for community whitelist trading period
// Monitor for any suspicious activity

// 7. Optional: Adjust limits if needed
setMaxLimits(newMaxTx, newMaxWallet);
```

### **Phase 4: Public Launch** 🌍
```solidity
// 8. Disable whitelist mode (opens to public)
setWhitelistMode(false);

// 9. Optionally disable limits after stabilization
setMaxLimitsActive(false);
```

## 🛠️ **Management Functions**

### **Whitelist Management**
```solidity
// Add multiple addresses to whitelist
setWhitelist([addr1, addr2, addr3], true);

// Remove from whitelist
setWhitelist([addr1], false);

// Check if address is whitelisted
isWhitelisted[address] // returns bool
```

### **Launch Control**
```solidity
// Enable/disable all trading
setTradingEnabled(true/false);

// Enable/disable whitelist-only mode
setWhitelistMode(true/false);

// Set transaction and wallet limits
setMaxLimits(maxTxAmount, maxWalletAmount);

// Enable/disable limits
setMaxLimitsActive(true/false);
```

### **Emergency Functions**
```solidity
// Blacklist suspicious addresses
setBlacklist([botAddress1, botAddress2], true);

// Configure anti-bot protection
setAntiSniperConfig(blockCount, cooldownSeconds);
```

### **Status Checking**
```solidity
// Check if address can trade
canTrade(address) // returns bool

// Get full launch status
getLaunchStatus() // returns all launch parameters

// Check launch progress
tradingEnabledBlock // block when trading was enabled
```

## 📊 **Default Configuration**

| Feature | Default Value | Purpose |
|---------|---------------|---------|
| Trading Enabled | `false` | Launch control |
| Whitelist Mode | `true` | Bot prevention |
| Max Transaction | 100,000 TREZA (0.1%) | Anti-whale |
| Max Wallet | 200,000 TREZA (0.2%) | Anti-whale |
| Transfer Cooldown | 1 second | Anti-spam |
| Anti-Bot Blocks | 3 blocks | Launch protection |
| Fee Percentage | 4% | Revenue generation |

## 🎯 **Pre-Whitelisted Addresses**

These addresses are automatically whitelisted during deployment:
- ✅ Initial Liquidity Wallet
- ✅ Team Wallet  
- ✅ Treasury Wallet
- ✅ Partnerships & Grants Wallet
- ✅ R&D Wallet
- ✅ Marketing & Operations Wallet
- ✅ Treasury Wallet 1 (fees)
- ✅ Treasury Wallet 2 (fees)
- ✅ Contract Deployer

## 🚨 **Common Anti-Sniping Scenarios**

### **Scenario 1: Bot tries to buy at launch**
- ❌ **Result:** Transaction reverted (not whitelisted)
- ✅ **Protection:** Whitelist-only mode

### **Scenario 2: Whale tries to buy large amount**
- ❌ **Result:** Transaction reverted (exceeds max transaction)
- ✅ **Protection:** Max transaction limits

### **Scenario 3: Bot tries rapid transactions**
- ❌ **Result:** Subsequent transactions fail (cooldown active)
- ✅ **Protection:** Transfer cooldown

### **Scenario 4: Bot detected after launch**
- ❌ **Result:** Address blacklisted, cannot trade
- ✅ **Protection:** Emergency blacklist function

## 💡 **Best Practices**

### **For Launch Teams:**
1. 🕐 **Plan whitelist carefully** - Include all necessary addresses
2. 🧪 **Test with small amounts** first
3. 📊 **Monitor transactions** during early launch
4. ⚡ **Be ready to use emergency functions** if needed
5. 📢 **Communicate launch phases** to community

### **For Communities:**
1. ✅ **Get whitelisted early** for best access
2. 🎯 **Respect transaction limits** during launch
3. ⏰ **Wait for cooldown** between transactions
4. 📈 **Understand that limits protect everyone** from manipulation

## 🔍 **Monitoring & Analytics**

```solidity
// Check current protection status
getLaunchStatus() 

// Monitor specific address
canTrade(suspiciousAddress)
isBlacklisted[suspiciousAddress]
isWhitelisted[suspiciousAddress]

// Track anti-bot period
antiBotBlocksRemaining = (tradingEnabledBlock + antiBotBlockCount) - currentBlock
```

## 🎊 **Why This Matters**

**Without Anti-Sniping Protection:**
- 🤖 Bots buy tokens instantly at launch
- 📈 Price manipulated by large early purchases  
- 😞 Community gets worse prices
- 💔 Unfair launch experience

**With Anti-Sniping Protection:**
- ✅ Fair access for whitelisted community
- ✅ Controlled launch sequence
- ✅ Protection against manipulation
- ✅ Emergency controls available
- 🎉 **Successful fair launch!**

---

## 🚀 **Ready to Launch?**

Your TREZA token now has military-grade anti-sniping protection! 🛡️

**Next Steps:**
1. Deploy the enhanced contract
2. Set up your whitelist
3. Execute the launch sequence
4. Monitor and manage as needed

**Your community will thank you for the fair launch!** 🎉