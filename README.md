# Treza Token (TREZA)

## Overview

Treza Token is an ERC20-compliant cryptocurrency designed with dynamic transfer fees, structured initial token allocations, and robust vesting and timelock mechanisms. This smart contract provides a full tokenomics suite with built-in three-treasury routing, advisor vesting, decentralized governance, and liquidity lock capabilities — all managed through secure and configurable parameters.

---

## 🔑 Key Features

### 📊 Fixed Supply and Allocations

The total token supply is fixed at **100 million TREZA**. Upon deployment, the contract allocates:

- **40%** to community incentives  
- **25%** to ecosystem and grants  
- **20%** to the team  
- **15%** to advisors (via vesting)

> Advisor tokens are released through an integrated linear vesting contract with a configurable cliff and total vesting duration.

---

### 💸 Dynamic Transfer Fees

Treza uses a **time-based fee model**:

- **4%** initial fee on all transfers  
- Reduces to **2%** after `milestone1`  
- Drops to **0%** after `milestone2`

**Fee Split Breakdown:**

- **Treasury Wallet 1:** 2.0% (50% of total fee)  
- **Treasury Wallet 2:** 1.6% (40% of total fee)  
- **Treasury Wallet 3:** 0.4% (10% of total fee)

> Exempt addresses (e.g., treasury wallets, vesting contracts, timelock contracts) do not incur transfer fees.

---

### 🏛️ Treasury and Fee Management

The contract owner or governance authority (via TimelockController) can:

- Update **all three treasury wallets**
- Exempt or include addresses from fee logic
- View the **current fee percentage** based on time since deployment

**Note:**  
All three treasury wallets must be **non-zero** and **distinct**.

---

### 🏛️ Decentralized Governance

Treza integrates with **OpenZeppelin’s TimelockController**:

- TimelockController is **deployed automatically**
- Contract **ownership is transferred** to the TimelockController
- Governance actions are **queued and delayed** based on configuration
- Requires **proposer** and **executor** roles
- Enables full **on-chain decentralized control**

---

### ⏳ Vesting and Timelocks

- **Advisor Allocation:** Released linearly with a **configurable cliff**
- **Liquidity Locking:** LP tokens can be locked using OpenZeppelin’s `TokenTimelock`
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

- **TrezaToken:** Main ERC20 contract with dynamic fees  
- **TokenVesting:** Linear vesting logic for advisors  
- **TimelockController:** On-chain governance delay mechanism  
- **TokenTimelock:** LP token locking mechanism  

---

## 🔁 Fee Distribution Flow

1. Transfer is triggered between two non-exempt addresses  
2. Contract calculates the **current fee** (4%, 2%, or 0%)  
3. Fee is split as:
   - 50% → Treasury Wallet 1  
   - 40% → Treasury Wallet 2  
   - 10% → Treasury Wallet 3  
4. **Remaining amount** is transferred to the recipient  
5. If any party is **fee-exempt**, the full amount is transferred with no fee deduction

   ---

## 🚀 Deployment Parameters

The contract constructor requires the following inputs:

- 🧾 **Initial allocation wallet addresses**:  
  - Community  
  - Ecosystem  
  - Team  
  - Advisor
 
  - 💰 **Three unique treasury wallet addresses** for dynamic fee collection

- ⏱️ **Fee milestone durations**:  
  - `dur1`: Time until fee drops from 4% → 2%  
  - `dur2`: Time until fee drops from 2% → 0%

- 📈 **Vesting parameters**:  
  - Cliff duration  
  - Total vesting duration

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







