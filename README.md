# Treza Token (TREZA)

## Overview

Treza Token is an ERC20-compliant cryptocurrency designed with manual transfer fees, structured initial token allocations, and timelock mechanisms. This smart contract provides a full tokenomics suite with built-in two-treasury routing, decentralized governance, and liquidity lock capabilities — all managed through secure and configurable parameters.

---

## 🔑 Key Features

### 📊 Fixed Supply and Allocations

The total token supply is fixed at **100 million TREZA**. Upon deployment, the contract allocates:

- **35%** to initial liquidity  
- **20%** to the team  
- **20%** to treasury
- **10%** to partnerships & grants  
- **5%** to R&D  
- **10%** to marketing & operations

---

### 💸 Manual Transfer Fees

Treza uses a **manually adjustable fee model**:

- **4%** initial fee on all transfers  
- Can be adjusted manually by governance/owner (0-10% range)
- Provides flexibility for fee optimization based on market conditions

**Fee Split Breakdown:**

- **Treasury Wallet 1:** 50% of total fee  
- **Treasury Wallet 2:** 50% of total fee

> Exempt addresses (e.g., treasury wallets, timelock contracts) do not incur transfer fees.

---

### 🏛️ Treasury and Fee Management

The contract owner or governance authority (via TimelockController) can:

- Update **both treasury wallets**
- Exempt or include addresses from fee logic
- **Manually adjust the transfer fee percentage** (0-10% range)
- View the **current fee percentage**

**Note:**  
Both treasury wallets must be **non-zero** and **distinct**.

---

### 🏛️ Decentralized Governance

Treza integrates with **OpenZeppelin’s TimelockController**:

- TimelockController is **deployed automatically**
- Contract **ownership is transferred** to the TimelockController
- Governance actions are **queued and delayed** based on configuration
- Requires **proposer** and **executor** roles
- Enables full **on-chain decentralized control**

---

### ⏳ Liquidity Locking

- **Liquidity Locking:** LP tokens can be locked using OpenZeppelin's `TokenTimelock`
  - Locked contracts are exempt from transfer fees

---

### 🔒 Security and Best Practices

- Built on **OpenZeppelin’s audited libraries**
- Uses **SafeERC20** for safe token transfers
- Prevents **zero address** errors on all sensitive functions
- Validates that **treasury addresses are unique**
- Emits logs for all **fee exemption** and **wallet updates**
- Stack-optimized constructor for compatibility with Remix and hardhat
- Modular design for readability and **gas efficiency**

---

## ⚙️ Contract Architecture

### Core Components

- **TrezaToken:** Main ERC20 contract with manual fees  
- **TimelockController:** On-chain governance delay mechanism  
- **TokenTimelock:** LP token locking mechanism  

---

## 🔁 Fee Distribution Flow

1. Transfer is triggered between two non-exempt addresses  
2. Contract uses the **manually set fee percentage** (0-10%)  
3. Fee is split as:
   - 50% → Treasury Wallet 1  
   - 50% → Treasury Wallet 2  
4. **Remaining amount** is transferred to the recipient  
5. If any party is **fee-exempt**, the full amount is transferred with no fee deduction

   ---

## 🚀 Deployment Parameters

The contract constructor requires the following inputs:

- 🧾 **Initial allocation wallet addresses**:  
  - Initial Liquidity  
  - Team  
  - Treasury
  - Partnerships & Grants  
  - R&D  
  - Marketing & Operations
 
  - 💰 **Two unique treasury wallet addresses** for dynamic fee collection

- No time-based fee parameters required (manual adjustment system)



  - 🏛️ **Governance parameters**:  
  - Array of proposer addresses  
  - Array of executor addresses  
  - Timelock delay (in seconds)

---

## ⛽ Gas Optimization

The Treza contract includes several gas-saving techniques:

- 🧱 **Struct-based parameter passing** to avoid stack depth issues during deployment
- ♻️ **Modular internal functions** for code reuse and maintainability
- 🛑 **Early returns** in transfer logic when fees are not applicable
- ⚖️ **Optimized fee splitting** with clean remainder handling (to prevent rounding errors)

  ---








