#  TREZA Anti-Sniping Protection Guide

##  **Overview**

Your enhanced TREZA token includes comprehensive anti-sniping protection to ensure a fair launch and prevent bot attacks. This guide explains all the protection mechanisms including the **TIME-BASED ANTI-SNIPER SYSTEM** with dynamic fees and max wallet limits.

## ¥ **Anti-Sniping Features**

###  **Time-Based Anti-Sniper Launch Mechanism**
- **Private Period (Whitelist Only):** 0% fee, no max wallet limits
- **Phase 1 (0-1 min):** 40% fee, 0.10% max wallet
- **Phase 2 (1-5 min):** 30% fee, 0.15% max wallet  
- **Phase 3 (5-8 min):** 20% fee, 0.20% max wallet
- **Phase 4 (8-15 min):** 10% fee, 0.30% max wallet
- **After 15 min:** Normal 5% fee, no max wallet limit
- **Purpose:** Free trading for trusted users, extreme deterrent for snipers

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



### 3. **Transfer Cooldown**
- **What it does:** Minimum 1 second between transactions per address
- **Purpose:** Prevent spam/rapid bot trading
- **Control:** `setAntiSniperConfig(uint256 blocks, uint256 cooldown)`

### 4. **Anti-Bot Block Protection**
- **What it does:** Extra protection for 3 blocks after trading enabled
- **Purpose:** Prevent immediate bot sniping when trading starts
- **Only whitelisted addresses can trade during this period**

### 5. **Emergency Blacklist**
- **What it does:** Manually block suspicious addresses
- **Purpose:** Emergency response to detected bots/bad actors
- **Control:** `setBlacklist(address[], bool)` (owner only)

##  **Fair Launch Sequence**

### **Phase 1: Pre-Launch Setup** ™
```solidity
// 1. Deploy contract (trading disabled, whitelist-only)
// 2. Add team/DEX addresses to whitelist
setWhitelist([dexRouter, liquidityWallet, teamWallet], true);

// 3. Add community whitelist (presale participants, etc.)
setWhitelist([user1, user2, user3], true);
```

### **Phase 2: Liquidity Addition** 
```solidity
// 4. Add initial liquidity (only whitelisted addresses can do this)
// Your DEX addresses should be whitelisted
// This prevents bots from front-running liquidity
```

### **Phase 3: Private Trading** 
```solidity
// 5. Enable trading (whitelisted addresses only)
setTradingEnabled(true);
//  PRIVATE PERIOD FEATURES:
// - 0% fees for all transactions
// - No max wallet limits
// - Only whitelisted addresses can trade

// 6. Community whitelist trading period
// Monitor for any suspicious activity
```

### **Phase 4: Public Launch** 
```solidity
// 7. Disable whitelist mode (starts time-based anti-sniper protection)
setWhitelistMode(false);
//  TIME-BASED PROTECTION ACTIVATED:
// - First minute: 40% fee, 0.10% max wallet
// - Minutes 1-5: 30% fee, 0.15% max wallet  
// - Minutes 5-8: 20% fee, 0.20% max wallet
// - Minutes 8-15: 10% fee, 0.30% max wallet
// - After 15 min: Normal 5% fee, no max wallet

// 8. Monitor and adjust as needed
```

##  **Management Functions**

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
// Enable/disable all trading (activates time-based anti-sniper)
setTradingEnabled(true/false);

// Enable/disable whitelist-only mode
setWhitelistMode(true/false);

// Enable/disable time-based anti-sniper mechanism
setTimeBasedAntiSniper(true/false);
```

### **Time-Based Anti-Sniper Management**
```solidity
// Get current anti-sniper status
getAntiSniperStatus() // Returns phase, fee, max wallet, time remaining

// Get current dynamic fee (time-based or manual)
getCurrentFee() // Returns current applicable fee percentage

// Get current max wallet limit
getCurrentMaxWallet() // Returns max wallet in tokens
getCurrentMaxWalletBasisPoints() // Returns max wallet in basis points

// Update anti-sniper phase configuration (owner only)
setAntiSniperPhases(phases) // Array of 4 TimeFeePhase structs

// Get specific phase configuration
getAntiSniperPhase(phaseIndex) // Returns phase details

// Manually start public trading timer
startPublicTradingTimer() // Start anti-sniper countdown manually
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

##  **Default Configuration**

| Feature | Default Value | Purpose |
|---------|---------------|---------|
| Trading Enabled | `false` | Launch control |
| Whitelist Mode | `true` | Bot prevention |
| Time-Based Anti-Sniper | `true` | Dynamic protection |
| Transfer Cooldown | 1 second | Anti-spam |
| Anti-Bot Blocks | 3 blocks | Launch protection |
| **Normal Fee Percentage** | **5%** | Revenue generation |

###  **Complete Fee Structure**

| Phase | Condition | Fee % | Max Wallet % | Max Wallet Tokens |
|-------|-----------|-------|--------------|-------------------|
| **Private** | Whitelist Mode ON | **0%** | No limit | No limit |
| **Phase 1** | 0-1 min public | **40%** | 0.10% | 100,000 TREZA |
| **Phase 2** | 1-5 min public | **30%** | 0.15% | 150,000 TREZA |
| **Phase 3** | 5-8 min public | **20%** | 0.20% | 200,000 TREZA |
| **Phase 4** | 8-15 min public | **10%** | 0.30% | 300,000 TREZA |
| **Normal** | 15+ min public | **5%** | No limit | No limit |

##  **Pre-Whitelisted Addresses**

These addresses are automatically whitelisted during deployment:
-  Team Wallet (65% allocation)
-  Initial Liquidity Wallet (10% allocation)
-  Marketing & Operations Wallet (10% allocation)
-  R&D Wallet (5% allocation)
-  Seed Investors Wallet (5% allocation)
-  CEX Listing Wallet (5% allocation)
-  Treasury Wallet 1 (50% of fees)
-  Treasury Wallet 2 (50% of fees)
-  Contract Deployer

##  **Common Anti-Sniping Scenarios**

### **Scenario 1: Trusted user during private period**
-  **Result:** 0% fees, no max wallet limits
-  **Protection:** Whitelist-only access for fair early trading

### **Scenario 2: Bot tries to buy at public launch (0-1 minute)**
-  **Result:** 40% fee + max 100K tokens
-  **Protection:** Extreme fees + max wallet limits

### **Scenario 3: Sniper tries large buy in Phase 2 (1-5 minutes)**
-  **Result:** 30% fee taken + limited to 150K tokens max wallet
-  **Protection:** Time-based fees + max wallet limits

### **Scenario 4: Whale tries to accumulate in Phase 3 (5-8 minutes)**
-  **Result:** 20% fee + max 200K tokens per wallet
-  **Protection:** Dynamic max wallet enforcement

### **Scenario 5: Bot tries rapid transactions**
-  **Result:** Subsequent transactions fail (cooldown active)
-  **Protection:** Transfer cooldown

### **Scenario 6: Multiple wallets try to bypass max wallet**
-  **Result:** Each wallet still limited by current phase max
-  **Protection:** Per-wallet max enforcement

### **Scenario 7: Bot detected after launch**
-  **Result:** Address blacklisted, cannot trade
-  **Protection:** Emergency blacklist function

### **Scenario 8: Normal user after 15 minutes**
-  **Result:** Normal 5% fee, no max wallet limit
-  **Protection:** Fair trading for legitimate users

##  **Best Practices**

### **For Launch Teams:**
1. • **Plan whitelist carefully** - Include all necessary addresses
2. ª **Test with small amounts** first
3.  **Monitor transactions** during early launch
4.  **Be ready to use emergency functions** if needed
5. ¢ **Communicate launch phases** to community

### **For Communities:**
1.  **Get whitelisted early** for best access
2.  **Respect transaction limits** during launch
3.  **Wait for cooldown** between transactions
4. ˆ **Understand that limits protect everyone** from manipulation

##  **Monitoring & Analytics**

### **Time-Based Anti-Sniper Monitoring**
```solidity
// Get complete anti-sniper status
getAntiSniperStatus() 
// Returns: enabled, currentPhase, currentFee, currentMaxWallet, timeRemaining

// Monitor current fees and limits
getCurrentFee()                    // Current fee percentage
getCurrentMaxWallet()              // Current max wallet in tokens  
getCurrentMaxWalletBasisPoints()   // Current max wallet in basis points

// Check specific phase configuration
getAntiSniperPhase(0)             // Phase 1 config
getAntiSniperPhase(1)             // Phase 2 config
// etc.
```

### **Traditional Monitoring**
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

### **Frontend Integration Example**
```javascript
// Real-time anti-sniper status for UI
const status = await contract.getAntiSniperStatus();
console.log(`Phase ${status._currentPhase}: ${status._currentFee}% fee, ${status._timeRemainingInPhase}s remaining`);

// Check if user can buy amount
const maxWallet = await contract.getCurrentMaxWallet();
const userBalance = await contract.balanceOf(userAddress);
const canBuy = userBalance + purchaseAmount <= maxWallet;
```

##  **Why This Matters**

**Without Anti-Sniping Protection:**
-  Bots buy tokens instantly at launch
- ˆ Price manipulated by large early purchases  
- ž Community gets worse prices
-  Unfair launch experience

** With TIME-BASED Anti-Sniping Protection:**
-  **Free trading for trusted users** (0% fees during private period)
-  **Extreme deterrent for bots** (40% fees at public launch)
-  **Graduated fee reduction** rewards patience
-  **Max wallet limits** prevent whale accumulation
-  **Fair access for whitelisted community**
-  **Controlled launch sequence** with automatic progression
-  **Protection against manipulation** across all phases
-  **Emergency controls available** throughout
-  **Normal trading** after 15 minutes for regular users
- ‰ **Most comprehensive fair launch system available!**

---

##  **Ready to Launch?**

Your TREZA token now has comprehensive anti-sniping protection! 

**Next Steps:**
1. Deploy the enhanced contract
2. Set up your whitelist
3. Execute the launch sequence
4. Monitor and manage as needed

