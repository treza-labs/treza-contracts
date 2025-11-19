# Environment Variables Setup

Copy this to your `.env` file and fill in the values following the guide below.

```bash
# =============================================================================
# Network Configuration
# =============================================================================
SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/your-key
MAINNET_RPC_URL=https://eth-mainnet.g.alchemy.com/v2/your-key
PRIVATE_KEY=0x...

# =============================================================================
# zkVerify Relayer API Configuration
# =============================================================================
# Get your API key from: https://relayer-testnet.horizenlabs.io (testnet)
#                    or: https://relayer.horizenlabs.io (mainnet)
ZKVERIFY_RELAYER_API_KEY=your_api_key_here

# =============================================================================
# zkVerify Smart Contract Address
# =============================================================================
# This is zkVerify's IVerifyProofAggregation contract (deployed by Horizen Labs)
# 
# How to find it:
# 1. Check zkVerify docs: https://docs.zkverify.io
# 2. Join Horizen Discord and ask: https://discord.gg/horizen
# 3. Email Horizen Labs: support@horizenlabs.io
#
# IMPORTANT: This is different for each network (Sepolia/Mainnet/etc)
# DO NOT use the placeholder value in production!
ZKVERIFY_CONTRACT_ADDRESS=0x0000000000000000000000000000000000000000

# =============================================================================
# Verification Key Hash
# =============================================================================
# This is the hash of your circuit's verification key
# 
# How to get it:
# Option 1 (Automated):
#   Run: npx ts-node scripts/setup-zkverify-config.ts
#   This will register your VK and save the hash
#
# Option 2 (Manual):
#   1. Register your VK with the Relayer API
#   2. Copy the returned vkHash
#   3. Paste it here
#
# Format: 0x followed by 64 hex characters (32 bytes)
VERIFICATION_KEY_HASH=0x0000000000000000000000000000000000000000000000000000000000000000

# =============================================================================
# Block Explorer API Keys (Optional, for verification)
# =============================================================================
ETHERSCAN_API_KEY=your_etherscan_key
```

## Quick Setup

```bash
# 1. Copy example
cp ENV_SETUP.md .env

# 2. Get Relayer API key
# Visit: https://relayer-testnet.horizenlabs.io

# 3. Run automated setup
npx ts-node scripts/setup-zkverify-config.ts

# 4. Manually add zkVerify contract address
# Check: https://docs.zkverify.io or contact Horizen Labs

# 5. Deploy!
npx hardhat run scripts/deploy-aggregation-verifier.ts --network sepolia
```

For detailed instructions, see: [docs/ZKVERIFY_CONFIGURATION.md](docs/ZKVERIFY_CONFIGURATION.md)

