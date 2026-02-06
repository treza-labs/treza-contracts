# Treza Token - Solana

Treza Token implementation on Solana using Token-2022 with a 5% transfer fee and 50/50 treasury split.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     Token-2022 Mint (TREZA)                     │
│  • Fixed supply: 100,000,000 tokens                             │
│  • Decimals: 9                                                  │
│  • Transfer fee: 5% (500 basis points)                          │
│  • On-chain metadata (name, symbol, URI)                        │
│  • Fees withheld in recipient accounts                          │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                   Fee Collection Flow                           │
│                                                                 │
│  1. Transfer happens → 5% withheld in recipient account         │
│  2. Authority harvests → Fees move to mint                      │
│  3. Authority withdraws → Fees move to collection account       │
│  4. Anyone calls split_fees → 50/50 to treasuries               │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Treza Fee Splitter Program                   │
│                                                                 │
│  • Stores treasury wallet addresses                             │
│  • Splits fees 50/50 to two treasuries                          │
│  • Permissionless splitting (anyone can trigger)                │
│  • Authority can update treasury wallets                        │
└─────────────────────────────────────────────────────────────────┘
```

## Prerequisites

1. **Rust & Cargo**
   ```bash
   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
   ```

2. **Solana CLI**
   ```bash
   sh -c "$(curl -sSfL https://release.solana.com/v1.18.17/install)"
   ```

3. **Anchor**
   ```bash
   cargo install --git https://github.com/coral-xyz/anchor avm --locked
   avm install 0.30.1
   avm use 0.30.1
   ```

4. **Node.js** (v18+)

## Setup

1. **Install dependencies**
   ```bash
   cd solana
   npm install
   ```

2. **Create deployment keypair**
   ```bash
   # Generate a new keypair for deployment authority
   solana-keygen new -o ~/.config/solana/treza-authority.json
   
   # View the public key
   solana-keygen pubkey ~/.config/solana/treza-authority.json
   ```

3. **Configure network**
   ```bash
   # For devnet
   solana config set --url devnet
   
   # For mainnet
   solana config set --url mainnet-beta
   ```

4. **Fund the keypair** (devnet)
   ```bash
   solana airdrop 2 ~/.config/solana/treza-authority.json
   ```

5. **Create config file**
   ```bash
   # Copy example config
   cp config/devnet.example.json config/devnet.json
   
   # Edit with your wallet addresses
   nano config/devnet.json
   ```

## Configuration

Edit `config/devnet.json` (or `mainnet-beta.json` for mainnet):

```json
{
  "authorityKeypairPath": "~/.config/solana/treza-authority.json",
  "treasuryWallet1": "YOUR_TREASURY_1_PUBKEY",
  "treasuryWallet2": "YOUR_TREASURY_2_PUBKEY",
  "tokenName": "Treza",
  "tokenSymbol": "TREZA",
  "tokenUri": "https://trezalabs.com/tokens/treza-metadata.json",
  "tokenDecimals": 9,
  "totalSupply": "100000000",
  "transferFeeBasisPoints": 500,
  "maxTransferFee": "1000000000000",
  "allocations": {
    "team": { "wallet": "TEAM_WALLET", "percentage": 65 },
    "initialLiquidity": { "wallet": "LIQUIDITY_WALLET", "percentage": 10 },
    "marketingOps": { "wallet": "MARKETING_WALLET", "percentage": 10 },
    "rnd": { "wallet": "RND_WALLET", "percentage": 5 },
    "seedInvestors": { "wallet": "SEED_WALLET", "percentage": 5 },
    "cexListing": { "wallet": "CEX_WALLET", "percentage": 5 }
  }
}
```

### Token Metadata Fields

| Field | Description |
|-------|-------------|
| `tokenName` | Full token name (e.g., "Treza") |
| `tokenSymbol` | Token ticker symbol (e.g., "TREZA") |
| `tokenUri` | URL to off-chain JSON metadata (logo, description, etc.) |

The `tokenUri` should point to a JSON file following the [Token Metadata Standard](https://docs.metaplex.com/programs/token-metadata/token-standard):

```json
{
  "name": "Treza",
  "symbol": "TREZA",
  "description": "Privacy infrastructure for crypto and finance.",
  "image": "https://trezalabs.com/tokens/treza-logo.png",
  "external_url": "https://trezalabs.com"
}
```

The metadata file is hosted at `https://trezalabs.com/tokens/treza-metadata.json`.

## Build & Deploy

### 1. Build the Fee Splitter Program

```bash
anchor build
```

This generates:
- `target/deploy/treza_fee_splitter.so` - The program binary
- `target/idl/treza_fee_splitter.json` - The IDL for clients

### 2. Deploy the Fee Splitter Program

```bash
# Get program ID
solana-keygen pubkey target/deploy/treza_fee_splitter-keypair.json

# Update Anchor.toml and lib.rs with the actual program ID

# Deploy to devnet
anchor deploy --provider.cluster devnet

# Deploy to mainnet
anchor deploy --provider.cluster mainnet-beta
```

### 3. Deploy the Token

```bash
# Deploy to devnet
npm run deploy:devnet

# Deploy to mainnet
npm run deploy:mainnet
```

This will:
1. Create the Token-2022 mint with 5% transfer fee
2. Mint initial allocations to configured wallets
3. Initialize the fee splitter config
4. Create the fee collection account
5. Save deployment info to `deployments/treza-{network}.json`

## Fee Collection & Distribution

### Automated (Recommended)

Set up a cron job to periodically collect and split fees:

```bash
# Add to crontab (runs every 6 hours)
0 */6 * * * cd /path/to/treza-contracts/solana && npm run collect-fees && npm run split-fees
```

### Manual

```bash
# Step 1: Collect withheld fees from all token accounts
npm run collect-fees

# Step 2: Split collected fees 50/50 to treasuries
npm run split-fees
```

## Scripts Reference

| Script | Description |
|--------|-------------|
| `npm run build` | Build the Anchor program |
| `npm run test` | Run tests |
| `npm run deploy:devnet` | Deploy token to devnet |
| `npm run deploy:mainnet` | Deploy token to mainnet |
| `npm run collect-fees` | Harvest withheld fees to collection account |
| `npm run split-fees` | Split fees 50/50 to treasury wallets |

## Program Instructions

### `initialize`
Set up the fee splitter with treasury wallets.

```typescript
await program.methods
  .initialize(treasuryWallet1, treasuryWallet2)
  .accounts({ authority, config, mint, systemProgram })
  .rpc();
```

### `split_fees`
Split fees from collection account to treasuries (permissionless).

```typescript
await program.methods
  .splitFees()
  .accounts({
    payer,
    config,
    mint,
    feeCollectionAccount,
    treasuryAccount1,
    treasuryAccount2,
    tokenProgram,
  })
  .rpc();
```

### `update_treasury_wallets`
Update treasury wallet addresses (authority only).

```typescript
await program.methods
  .updateTreasuryWallets(newWallet1, newWallet2)
  .accounts({ authority, config })
  .rpc();
```

### `transfer_authority`
Transfer program authority to new address.

```typescript
await program.methods
  .transferAuthority(newAuthority)
  .accounts({ authority, config })
  .rpc();
```

## Key Differences from EVM Version

| Feature | EVM (Treza.sol) | Solana |
|---------|-----------------|--------|
| Fee deduction | Automatic on transfer | Withheld, then collected |
| Fee distribution | Immediate 50/50 | Batched collection + split |
| Fee exemptions | `isFeeExempt` mapping | Not supported (all pay) |
| Anti-sniping | Built-in | Not implemented |
| Whitelist/Blacklist | Built-in | Not implemented |
| Max wallet limit | Built-in | Not implemented |

## Security Considerations

1. **Authority Key Security**
   - Store keypair securely (hardware wallet for mainnet)
   - Consider multisig for authority

2. **Fee Collection**
   - Anyone can call `split_fees` (permissionless cranking)
   - Only authority can withdraw from mint

3. **Program Upgrades**
   - Program is immutable by default
   - Keep upgrade authority if future changes needed

## Deployment Checklist

- [ ] Generate fresh deployment keypair
- [ ] Fund keypair with SOL
- [ ] Create and verify config file
- [ ] Build and deploy fee splitter program
- [ ] Update program ID in Anchor.toml and lib.rs
- [ ] Deploy token with correct allocations
- [ ] Verify all allocations on Solana Explorer
- [ ] Create treasury token accounts
- [ ] Test fee collection and splitting
- [ ] Set up automated fee collection cron job
- [ ] (Optional) Revoke mint authority
- [ ] (Optional) Transfer authority to multisig

## Testnet Deployments

| Network | Mint | Fee Splitter |
|---------|------|--------------|
| Devnet | TBD | TBD |
| Mainnet | TBD | TBD |

## Resources

- [Token-2022 Documentation](https://spl.solana.com/token-2022)
- [Anchor Framework](https://www.anchor-lang.com/)
- [Solana Explorer](https://explorer.solana.com/)
