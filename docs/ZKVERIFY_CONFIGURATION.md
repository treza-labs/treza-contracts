# zkVerify Configuration Guide

This guide explains how to obtain the required configuration values for zkVerify integration.

## Required Environment Variables

```bash
ZKVERIFY_CONTRACT_ADDRESS=0x...     # zkVerify's aggregation contract
VERIFICATION_KEY_HASH=0x...         # Your registered VK hash
ZKVERIFY_RELAYER_API_KEY=...       # Relayer API key
```

---

## 1. `ZKVERIFY_RELAYER_API_KEY`

### What It Is
API key for accessing the Horizen Relayer service.

### How to Get It

**Testnet:**
1. Visit: https://relayer-testnet.horizenlabs.io
2. Create an account
3. Generate an API key
4. Copy the key

**Mainnet:**
1. Visit: https://relayer.horizenlabs.io
2. Create an account
3. Generate an API key
4. Copy the key

### Add to `.env`
```bash
ZKVERIFY_RELAYER_API_KEY=your_actual_api_key_here
```

---

## 2. `ZKVERIFY_CONTRACT_ADDRESS`

### What It Is
The address of zkVerify's **IVerifyProofAggregation** contract deployed on your target chain. This contract is deployed and maintained by Horizen Labs, not by you.

### How to Find It

#### **Option 1: Check zkVerify Documentation**

1. Visit: https://docs.zkverify.io
2. Look for "Deployed Contracts" or "Contract Addresses" section
3. Find the address for your target network:
   - **Sepolia Testnet**: Look for testnet addresses
   - **Ethereum Mainnet**: Look for mainnet addresses
   - **Arbitrum/Optimism**: Check if supported

#### **Option 2: Contact Horizen Labs**

If not documented:
1. Join Horizen Discord: https://discord.gg/horizen
2. Ask in the developer channel: "What is the IVerifyProofAggregation contract address for [network]?"
3. Or email: support@horizenlabs.io

#### **Option 3: Check Block Explorer**

Once you know the network, you can verify the contract on the block explorer:
- **Sepolia**: https://sepolia.etherscan.io
- **Mainnet**: https://etherscan.io

Look for "IVerifyProofAggregation" or "ProofAggregation" contracts deployed by Horizen Labs.

#### **Option 4: Check Relayer Response**

When you submit a proof with aggregation, the response includes references:

```typescript
const response = await fetch('/api/zkverify/job-status/{jobId}');
const data = await response.json();

// The aggregation details may reference the contract
console.log(data.jobStatus.aggregationDetails);
```

### Example Addresses

```bash
# These are EXAMPLES - verify with Horizen Labs for real addresses
# Sepolia Testnet
ZKVERIFY_CONTRACT_ADDRESS=0x1234567890123456789012345678901234567890

# Ethereum Mainnet (check docs)
ZKVERIFY_CONTRACT_ADDRESS=0xABCDEF0123456789ABCDEF0123456789ABCDEF01
```

###  Important Notes

- **DO NOT** use placeholder addresses in production
- **VERIFY** the address with official zkVerify documentation
- **TEST** on testnet first before using mainnet
- The contract address is **different for each network**

---

## 3. `VERIFICATION_KEY_HASH`

### What It Is
A `bytes32` hash of your circuit's verification key, returned when you register the VK with zkVerify.

### How to Get It

#### **Step 1: Prepare Your Verification Key**

Your verification key should be in this format (Groth16 example):

```json
{
  "protocol": "groth16",
  "curve": "bn128",
  "nPublic": 2,
  "vk_alpha_1": [
    "...",
    "..."
  ],
  "vk_beta_2": [
    ["...", "..."],
    ["...", "..."]
  ],
  "vk_gamma_2": [
    ["...", "..."],
    ["...", "..."]
  ],
  "vk_delta_2": [
    ["...", "..."],
    ["...", "..."]
  ],
  "vk_alphabeta_12": [...],
  "IC": [
    ["...", "..."],
    ["...", "..."]
  ]
}
```

#### **Step 2: Run Setup Script**

Use our automated setup script:

```bash
cd treza-contracts

# Make sure you have your VK file in one of these locations:
# - ./verification_key.json
# - ./vkey.json
# - ./circuit_vkey.json

# Run the setup script
npx ts-node scripts/setup-zkverify-config.ts
```

The script will:
1. Find your verification key file
2. Register it with zkVerify via Relayer API
3. Extract the `vkHash`
4. Save it to your `.env` file

#### **Step 3: Manual Registration (Alternative)**

If you prefer to do it manually:

```bash
curl -X POST https://relayer-api-testnet.horizenlabs.io/api/v1/register-vk/YOUR_API_KEY \
  -H "Content-Type: application/json" \
  -d '{
    "proofType": "groth16",
    "proofOptions": {
      "library": "snarkjs",
      "curve": "bn128"
    },
    "vk": {
      // Your VK JSON here
    }
  }'
```

**Response:**
```json
{
  "success": true,
  "vkHash": "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef",
  "meta": {
    "registered": true
  }
}
```

Copy the `vkHash` value!

#### **Step 4: Save to `.env`**

```bash
VERIFICATION_KEY_HASH=0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef
```

###  Important Notes

- The VK hash is **unique to your circuit**
- If you change your circuit, you need a **new VK hash**
- The same VK hash works across **all networks** (it's just a hash)
- **Save this value** - you'll need it for every deployment

---

## Complete Setup Workflow

### Quick Setup (Automated)

```bash
# 1. Install dependencies
cd treza-contracts
npm install

# 2. Get Relayer API key
# Visit: https://relayer-testnet.horizenlabs.io

# 3. Add to .env
echo "ZKVERIFY_RELAYER_API_KEY=your_key" >> .env

# 4. Run setup script (registers VK and saves config)
npx ts-node scripts/setup-zkverify-config.ts

# 5. Manually add zkVerify contract address (from docs)
# Edit .env and update ZKVERIFY_CONTRACT_ADDRESS

# 6. Deploy
npx hardhat run scripts/deploy-aggregation-verifier.ts --network sepolia
```

### Manual Setup

```bash
# 1. Get Relayer API key
echo "ZKVERIFY_RELAYER_API_KEY=your_key" >> .env

# 2. Find zkVerify contract address
# Check: https://docs.zkverify.io
echo "ZKVERIFY_CONTRACT_ADDRESS=0x..." >> .env

# 3. Register VK manually
curl -X POST ... # (see above)

# 4. Save VK hash
echo "VERIFICATION_KEY_HASH=0x..." >> .env

# 5. Deploy
npx hardhat run scripts/deploy-aggregation-verifier.ts --network sepolia
```

---

## Verification

After setting up, verify your configuration:

```bash
# Check all required vars are set
cat .env | grep ZKVERIFY

# Should see:
# ZKVERIFY_RELAYER_API_KEY=...
# ZKVERIFY_CONTRACT_ADDRESS=0x...
# VERIFICATION_KEY_HASH=0x...
```

Test the configuration:

```typescript
import { ethers } from 'ethers';

// Test zkVerify contract address is valid
const provider = new ethers.JsonRpcProvider(RPC_URL);
const code = await provider.getCode(ZKVERIFY_CONTRACT_ADDRESS);

if (code === '0x') {
  console.error(' Invalid contract address - no code at address');
} else {
  console.log(' zkVerify contract found');
}

// Test VK hash format
if (!/^0x[a-fA-F0-9]{64}$/.test(VERIFICATION_KEY_HASH)) {
  console.error(' Invalid VK hash format');
} else {
  console.log(' VK hash format valid');
}
```

---

## Troubleshooting

### "Contract address has no code"

**Problem:** The zkVerify contract address is incorrect or not deployed on this network.

**Solution:**
1. Verify you're using the correct network (testnet vs mainnet)
2. Check zkVerify documentation for the correct address
3. Contact Horizen Labs if address is not documented

### "Invalid verification key"

**Problem:** VK registration failed.

**Solution:**
1. Check VK file format matches expected structure
2. Ensure `proofType` matches your circuit type (groth16, etc.)
3. Verify Relayer API key is valid
4. Check network connectivity to Relayer API

### "VK already registered"

**Problem:** Trying to register the same VK again.

**Solution:** This is actually fine! The error response should include the existing `vkHash`. Just use that value.

---

## Security Notes

### DO NOT Commit

Never commit these values to git:
-  `.env` is in `.gitignore`
-  Use `.env.example` with placeholders
-  Share setup instructions, not values

### Production Security

For production deployments:
1. Use secrets management (AWS Secrets Manager, HashiCorp Vault)
2. Rotate Relayer API keys periodically
3. Use different API keys for different environments
4. Verify contract addresses on block explorer

---

## Resources

- **zkVerify Docs**: https://docs.zkverify.io
- **Relayer API (Testnet)**: https://relayer-testnet.horizenlabs.io
- **Relayer API (Mainnet)**: https://relayer.horizenlabs.io
- **Swagger Docs (Testnet)**: https://relayer-api-testnet.horizenlabs.io/docs
- **Swagger Docs (Mainnet)**: https://relayer-api-mainnet.horizenlabs.io/docs
- **Horizen Discord**: https://discord.gg/horizen

## Support

Need help?
- Check zkVerify documentation
- Ask in Horizen Discord
- Email: support@horizenlabs.io
- Create an issue on GitHub

