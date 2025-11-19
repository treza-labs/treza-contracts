# Smart Contract Verification with zkVerify

This guide explains how to use zkVerify's trustless aggregation-based verification for TREZA compliance, as an alternative to the oracle-based approach.

## Overview

TREZA now supports **two verification methods**:

### 1. **Oracle-Based Verification** (Already Implemented)
-  Fast (30-60 seconds)
-  Works for single proofs
-  Requires trust in oracle nodes
-  Higher gas cost (~150k gas per verification)
-  Requires backend infrastructure

### 2. **Smart Contract Verification** (New - This Guide)
-  **Trustless** - No oracle trust required
-  Lower gas cost (~50k gas per verification)  
-  No backend infrastructure needed
-  Censorship resistant
-  Slower (5-10 minutes for aggregation)
-  Only works with aggregated proofs

## Architecture

```
User  DeFi App  TREZA SDK  Relayer API  zkVerify Chain
                                                    
                                            Proof Aggregated
                                                    
                                    Aggregation Published to Ethereum
                                                    
        DeFi App calls ZKVerifyAggregationVerifier Contract
                                
                    Direct cryptographic verification
                        (No oracle needed!)
```

## Smart Contract: `ZKVerifyAggregationVerifier.sol`

### Key Features

```solidity
contract ZKVerifyAggregationVerifier {
    // Calls zkVerify's aggregation contract directly
    function verifyComplianceWithAggregation(
        address user,
        uint256 publicInputHash,
        uint256 aggregationId,
        uint256 domainId,
        bytes32[] calldata merklePath,
        uint256 leafCount,
        uint256 leafIndex,
        string calldata verificationLevel
    ) external;
    
    // Check compliance status
    function isCompliant(address user) external view returns (bool);
}
```

### How It Works

1. **Proof Aggregation**: Multiple proofs are batched into one Merkle tree on zkVerify
2. **On-Chain Publication**: zkVerify publishes the aggregation root to Ethereum
3. **Merkle Verification**: Your contract verifies individual proofs using Merkle proofs
4. **No Trust Required**: Cryptographic verification against zkVerify's contract

## Deployment

### Prerequisites

1. zkVerify aggregation contract deployed on your target chain
2. Verification key hash from zkVerify

### Step 1: Set Environment Variables

```bash
# In treza-contracts/.env
ZKVERIFY_CONTRACT_ADDRESS=0x...  # zkVerify's aggregation contract
VERIFICATION_KEY_HASH=0x...      # Your VK hash from zkVerify
```

### Step 2: Deploy Contract

```bash
cd treza-contracts

# Deploy to testnet (Sepolia)
npx hardhat run scripts/deploy-aggregation-verifier.ts --network sepolia

# Deploy to mainnet
npx hardhat run scripts/deploy-aggregation-verifier.ts --network mainnet
```

### Step 3: Verify on Block Explorer

```bash
npx hardhat verify --network sepolia \
  <VERIFIER_ADDRESS> \
  <ZKVERIFY_CONTRACT_ADDRESS> \
  <VERIFICATION_KEY_HASH>
```

## Integration with SDK

### Initialize with Aggregation Support

```typescript
import { ZKVerifyBridge } from '@treza/core';

const bridge = new ZKVerifyBridge('https://yourdomain.com/api');
```

### Method 1: Oracle-Based (Fast)

```typescript
// For low-value operations or when speed is critical
const result = await bridge.processComplianceVerification(
  zkPassportProof,
  userAddress,
  true // Submit to oracle
);

// Takes 30-60 seconds
// Gas cost: ~150k gas
// Requires trust in your oracle nodes
```

### Method 2: Smart Contract (Trustless)

```typescript
// For high-value operations or when trustlessness is critical
const result = await bridge.processComplianceWithAggregation(
  zkPassportProof,
  userAddress,
  11155111 // Sepolia chain ID
);

// Takes 5-10 minutes (waiting for aggregation)
// Gas cost: ~50k gas
// No trust required!
```

### Submit to Smart Contract

```typescript
import { ethers } from 'ethers';

// After aggregation completes
const verifier = new ethers.Contract(
  AGGREGATION_VERIFIER_ADDRESS,
  AGGREGATION_VERIFIER_ABI,
  signer
);

// Submit verification using aggregation data
await verifier.verifyComplianceWithAggregation(
  userAddress,
  result.aggregationData.publicInputHash,
  result.aggregationData.aggregationId,
  result.aggregationData.domainId,
  result.aggregationData.merkleProof,
  result.aggregationData.leafCount,
  result.aggregationData.leafIndex,
  'enhanced' // verification level
);

// User is now compliant on-chain (trustlessly!)
```

## Hybrid Approach: Best of Both Worlds

```typescript
async function verifyCompliance(userAddress, amount, zkPassportProof) {
  // High-value: Use trustless smart contract verification
  if (amount > 10000) {
    console.log('High-value trade: Using trustless verification');
    const result = await bridge.processComplianceWithAggregation(
      zkPassportProof,
      userAddress,
      11155111
    );
    
    // Submit to aggregation verifier contract
    await submitToAggregationVerifier(result);
    
  // Low-value: Use fast oracle verification
  } else {
    console.log('Low-value trade: Using fast oracle verification');
    const result = await bridge.processComplianceVerification(
      zkPassportProof,
      userAddress,
      true
    );
  }
}
```

## Cost Comparison

### Single Proof

| Method | Time | Gas Cost (50 gwei) | Trust Required |
|--------|------|-------------------|----------------|
| Oracle | 30-60s | ~150k gas (~$7.50) | Yes (oracle nodes) |
| Smart Contract | 5-10 min | ~50k gas (~$2.50) | No (trustless) |

### 100 Proofs

| Method | Time | Total Gas Cost | Trust Required |
|--------|------|----------------|----------------|
| Oracle | 30-60s each | 15M gas (~$750) | Yes |
| Smart Contract | 5-10 min (batched) | 5M gas (~$250) | No |

**Savings: 66% cheaper + trustless!**

## API Endpoints

### Get Aggregation Data

```typescript
// GET /api/zkverify/aggregation/{aggregationId}
const aggregation = await fetch('/api/zkverify/aggregation/12345');

// Returns:
{
  aggregationId: 12345,
  domainId: 1,
  root: "0x...",
  leafCount: 100,
  merkleProof: ["0x...", "0x..."],
  leafIndex: 42,
  ...
}
```

### Get Aggregation for Job

```typescript
// GET /api/zkverify/aggregation/job/{jobId}
const aggregation = await fetch('/api/zkverify/aggregation/job/uuid');

// Returns aggregation data when job is aggregated
```

## Security Considerations

### Trustless Verification

 **No Oracle Trust**: Verification happens cryptographically on-chain
 **No Single Point of Failure**: zkVerify publishes aggregations
 **Censorship Resistant**: Can't be blocked by oracle operators
 **Auditable**: All verifications are on-chain

### Best Practices

1. **Use for High-Value**: Apply to transactions above threshold
2. **Validate Aggregation**: Check aggregation data before submission
3. **Monitor Gas Costs**: Aggregation reduces costs at scale
4. **Set Timeouts**: Handle aggregation delays in UX

## Testing

### Test on Sepolia

```bash
# 1. Deploy contract
npx hardhat run scripts/deploy-aggregation-verifier.ts --network sepolia

# 2. Run integration test
npx hardhat test test/compliance/ZKVerifyAggregationVerifier.test.ts --network sepolia
```

### Manual Test Flow

```typescript
// 1. Submit proof with aggregation
const result = await bridge.processComplianceWithAggregation(
  zkPassportProof,
  userAddress,
  11155111
);

// 2. Wait for aggregation (5-10 minutes)
console.log('Waiting for aggregation...');

// 3. Get aggregation data
const aggregation = result.aggregationData;

// 4. Submit to contract
await verifier.verifyComplianceWithAggregation(
  userAddress,
  aggregation.publicInputHash,
  aggregation.aggregationId,
  aggregation.domainId,
  aggregation.merkleProof,
  aggregation.leafCount,
  aggregation.leafIndex,
  'enhanced'
);

// 5. Verify on-chain
const isCompliant = await verifier.isCompliant(userAddress);
console.log('Compliant:', isCompliant); // Should be true
```

## Troubleshooting

### "Job not yet aggregated"

Aggregation takes 5-10 minutes. Check job status:

```typescript
const status = await fetch(`/api/zkverify/job-status/${jobId}`);
// Wait for status: "Aggregated" or "AggregationPublished"
```

### "Invalid Merkle proof"

Ensure you're using the correct aggregation data:
- Correct `aggregationId`
- Correct `leafIndex`
- Full `merklePath` array
- Matching `publicInputHash`

### "zkVerify contract not found"

Update `ZKVERIFY_CONTRACT_ADDRESS` in your deployment script to point to the correct zkVerify aggregation contract for your network.

## Production Checklist

- [ ] Deploy `ZKVerifyAggregationVerifier` to mainnet
- [ ] Verify contract on block explorer
- [ ] Update SDK with contract address
- [ ] Test aggregation flow end-to-end
- [ ] Set up monitoring for aggregation delays
- [ ] Implement hybrid verification strategy
- [ ] Update UI to show verification method
- [ ] Document for users (why 5-10 min wait)

## Resources

- [zkVerify Smart Contract Docs](https://docs.zkverify.io/overview/getting-started/smart-contract)
- [IVerifyProofAggregation Interface](../contracts/compliance/interfaces/IVerifyProofAggregation.sol)
- [ZKVerifyAggregationVerifier Contract](../contracts/compliance/ZKVerifyAggregationVerifier.sol)
- [Integration Example](../../treza-example-defi-app/lib/smart-contract-verification.ts)

## Support

For questions or issues:
- GitHub Issues
- Discord Community
- Email: support@treza.io

