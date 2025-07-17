# 🪙 Treza Token (TREZA)

## Overview

Treza Token is an ERC20-compliant cryptocurrency designed with dynamic transfer fees, structured initial token allocations, and robust vesting and timelock mechanisms. This smart contract provides a full tokenomics suite with built-in treasury routing, advisor vesting, and liquidity lock capabilities, all managed through secure and configurable parameters.

---

## Key Features

### 📊 Fixed Supply and Allocations
The total token supply is fixed at 100 million TREZA. Upon deployment, the contract allocates:
- 40% to community incentives,
- 25% to ecosystem and grants,
- 20% to the team,
- 15% to advisors, with vesting.

Advisors receive their allocation through an integrated linear vesting contract with a configurable cliff and full vesting duration.

---

### 💸 Dynamic Transfer Fees
Treza implements a time-based fee model:
- Initially, a 4% fee is applied to all transfers.
- After a specified period, the fee reduces to 2%.
- Eventually, the fee drops to 0% permanently.

Fees are automatically split between two treasury wallets and exempt addresses (e.g., treasury, vesting contract, timelock contracts) do not incur fees.

---

### 🏛️ Treasury and Fee Management
The owner can:
- Update the treasury wallets that receive split fees.
- Exempt or include addresses from the transfer fee mechanism.
- View the current active fee percentage depending on time since deployment.

---

### ⏳ Vesting and Timelocks
The advisor allocation is subject to linear vesting with a configurable cliff, ensuring long-term alignment. Additionally, the contract provides the ability to deploy LP token timelocks via OpenZeppelin's `TokenTimelock`, which can be used to lock liquidity for a specified duration and exempt those contracts from transfer fees.

---

## 🔒 Security and Best Practices
- Built on top of OpenZeppelin’s audited libraries.
- Uses `SafeERC20` to prevent unsafe token transfers.
- Protects against zero-address errors in all critical functions.
- Provides event logs for changes to fee exemptions and treasury addresses.

---

