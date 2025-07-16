# 🪙 Treza Token (TREZA)

## Overview

Treza Token (`TREZA`) is a custom ERC20 token with built-in transfer fees and vesting functionality, designed to support sustainable treasury growth and fair contributor rewards. This implementation provides two core components:

- **TrezaToken.sol** — An ERC20 token with a dynamic transfer fee routed to a treasury wallet.
- **TokenVesting.sol** — A linear vesting contract with a 6-month cliff, allowing deferred token releases for contributors or advisors.

---

## 📦 Features

### ✅ TrezaToken (ERC20)

- **4% Transfer Fee**: Every token transfer deducts a 4% fee (default), which is sent to a designated treasury wallet.
- **Dynamic Fee Configuration**: The owner can adjust the fee percentage up to a maximum of 10%.
- **Treasury Wallet Management**: The fee collection address can be updated by the contract owner.
- **Standard ERC20 Compliance**: Compatible with wallets, exchanges, and dApps that support ERC20.

---

### 🕒 TokenVesting

- **Cliff Vesting**: Tokens are locked for an initial 6-month period.
- **Linear Release**: After the cliff, tokens vest linearly until the end of the total duration.
- **Immutable Parameters**: Vesting start time, cliff, and duration are all set at deployment and cannot be modified.
- **Secure Withdrawals**: Only the beneficiary can call `release()` to withdraw vested tokens.

---
