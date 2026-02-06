# Solana Token Deployment - Developer Handoff

## Overview

This is the Treza Token implementation for Solana using Token-2022 with:
- **5% transfer fee** (native Token-2022 TransferFeeConfig extension)
- **50/50 treasury split** (custom Anchor program)
- **On-chain metadata** (name, symbol, URI via MetadataPointer extension)
- **100M fixed supply** with same allocations as EVM contract

## What's Already Done

- [x] Token-2022 deployment script with transfer fee + metadata extensions
- [x] Anchor program for 50/50 fee splitting to two treasury wallets
- [x] Fee collection script (harvests withheld fees from token accounts)
- [x] Fee splitting script (distributes to treasuries)
- [x] Token metadata JSON (`treza-xyz/public/tokens/treza-metadata.json`)
- [x] Token logo (`treza-xyz/public/tokens/treza-logo.png`)
- [x] Configuration template with all required fields
- [x] Comprehensive README documentation

## What You Need To Do

### Step 1: Install Prerequisites

```bash
# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source $HOME/.cargo/env

# Install Solana CLI (v1.18.17)
sh -c "$(curl -sSfL https://release.solana.com/v1.18.17/install)"
export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"

# Install Anchor via AVM
cargo install --git https://github.com/coral-xyz/anchor avm --locked --force
avm install 0.30.1
avm use 0.30.1

# Verify installations
solana --version
anchor --version
```

### Step 2: Setup Project

```bash
cd treza-contracts/solana
npm install
```

### Step 3: Create Wallets

You need public keys for 8 wallets. Create or collect these:

```bash
# Create authority keypair (KEEP THIS SECURE - controls the token)
solana-keygen new -o ~/.config/solana/treza-authority.json
solana-keygen pubkey ~/.config/solana/treza-authority.json

# You'll also need public keys for:
# - Treasury Wallet 1 (receives 50% of fees)
# - Treasury Wallet 2 (receives 50% of fees)
# - Team Wallet (65% allocation)
# - Initial Liquidity Wallet (10% allocation)
# - Marketing/Ops Wallet (10% allocation)
# - R&D Wallet (5% allocation)
# - Seed Investors Wallet (5% allocation)
# - CEX Listing Wallet (5% allocation)
```

### Step 4: Create Config File

```bash
# Copy the example config
cp config/devnet.example.json config/devnet.json

# Edit with your actual wallet addresses
# IMPORTANT: Never commit config/devnet.json - it's gitignored
```

Fill in all `REPLACE_WITH_*` fields with actual Solana public keys (base58 format).

### Step 5: Build the Fee Splitter Program

```bash
# Build the Anchor program
anchor build

# Get the generated program ID
solana-keygen pubkey target/deploy/treza_fee_splitter-keypair.json
# Example output: TRZAxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

**IMPORTANT**: Update the program ID in two places:
1. `Anchor.toml` - update `[programs.devnet]` and `[programs.mainnet]`
2. `programs/treza-fee-splitter/src/lib.rs` - update `declare_id!("...")`

Then rebuild:
```bash
anchor build
```

### Step 6: Deploy to Devnet (Testing)

```bash
# Configure Solana CLI for devnet
solana config set --url devnet

# Fund your authority wallet (devnet only - free SOL)
solana airdrop 2 ~/.config/solana/treza-authority.json --url devnet

# Check balance
solana balance ~/.config/solana/treza-authority.json --url devnet

# Deploy the fee splitter program
anchor deploy --provider.cluster devnet

# Deploy the token (creates mint, mints allocations, initializes splitter)
npm run deploy:devnet
```

### Step 7: Verify Deployment

1. Check Solana Explorer: https://explorer.solana.com/?cluster=devnet
2. Search for your mint address (printed after deployment)
3. Verify token metadata, supply, and allocations

### Step 8: Test Fee Collection

After some transfers have occurred:

```bash
# Collect withheld fees from all token accounts
npm run collect-fees -- --network=devnet

# Split collected fees 50/50 to treasury wallets
npm run split-fees -- --network=devnet
```

### Step 9: Mainnet Deployment (When Ready)

```bash
# Create mainnet config
cp config/devnet.example.json config/mainnet-beta.json
# Edit with mainnet wallet addresses

# Configure for mainnet
solana config set --url mainnet-beta

# Fund authority wallet with real SOL (~0.5 SOL needed)
# Transfer SOL to your authority wallet address

# Deploy program
anchor deploy --provider.cluster mainnet-beta

# Deploy token
npm run deploy:mainnet
```

## Important Files

| File | Description |
|------|-------------|
| `README.md` | Full documentation |
| `config/devnet.example.json` | Config template - copy to `devnet.json` |
| `programs/treza-fee-splitter/src/lib.rs` | Anchor program source code |
| `scripts/deploy-token.ts` | Main deployment script |
| `scripts/collect-fees.ts` | Fee harvesting script |
| `scripts/split-fees.ts` | Fee distribution script |

## Token Metadata

The token metadata is hosted at:
- **Metadata JSON**: `https://trezalabs.com/tokens/treza-metadata.json`
- **Logo**: `https://trezalabs.com/tokens/treza-logo.png`

These files are in `treza-xyz/public/tokens/` and will be live once deployed.

## Architecture Notes

### How Fees Work on Solana (Different from EVM!)

```
1. Alice transfers 100 TREZA to Bob
   └─> Bob receives 100 TREZA, but 5 TREZA is "withheld" in his account

2. Authority calls collect-fees script
   └─> Withheld fees are harvested to mint, then to collection account

3. Anyone calls split-fees script (permissionless)
   └─> Collection account balance split 50/50 to treasury wallets
```

### Key Differences from EVM Treza.sol

| Feature | EVM | Solana |
|---------|-----|--------|
| Fee deduction | Immediate on transfer | Withheld, then collected |
| Fee exemptions | `isFeeExempt` mapping | Not supported |
| Anti-sniping | Built-in phases | Not implemented |
| Max wallet limit | Built-in | Not implemented |
| Whitelist/Blacklist | Built-in | Not implemented |

This is a **simplified version** - just the core 5% fee and treasury split.

## Troubleshooting

### "Insufficient funds"
```bash
# Devnet: request airdrop
solana airdrop 2 --url devnet

# Mainnet: transfer real SOL to your wallet
```

### "Program not found"
Make sure you deployed the Anchor program before running deploy-token:
```bash
anchor deploy --provider.cluster devnet
```

### "Invalid program ID"
You forgot to update the program ID after `anchor build`. Check both:
- `Anchor.toml`
- `programs/treza-fee-splitter/src/lib.rs`

### Build errors
```bash
# Make sure you have correct Anchor version
avm use 0.30.1

# Clean and rebuild
anchor clean
anchor build
```

## Questions?

Refer to:
- `README.md` in this directory
- Solana docs: https://docs.solana.com
- Token-2022 docs: https://spl.solana.com/token-2022
- Anchor docs: https://www.anchor-lang.com
