#  Pre-Deployment Security Checklist

##  CRITICAL - Complete Before Public Release

###  Security Essentials

#### Private Keys & Secrets
- [ ] **No private keys in code** - All keys in secure hardware wallets
- [ ] **No API keys committed** - All keys in environment variables  
- [ ] **No hardcoded addresses** - All placeholder addresses updated
- [ ] **Secure .env setup** - Environment variables properly configured
- [ ] **Multisig wallets ready** - Team and treasury multisigs deployed

#### Smart Contract Security  
- [ ] **Professional audit completed** - By reputable security firm
- [ ] **All tests passing** - 100% test coverage on critical functions
- [ ] **Gas optimization** - Reasonable gas costs for all operations
- [ ] **Emergency controls tested** - Pause/unpause mechanisms work
- [ ] **Access controls verified** - Only authorized addresses can call admin functions

### ‹ Configuration Updates Required

#### 1. Update All Placeholder Addresses

**In `scripts/deploy.ts`:**
```solidity
//  REPLACE THESE PLACEHOLDER ADDRESSES:
initialLiquidityWallet: "0x742d35Cc...", // UPDATE: Your liquidity wallet
teamWallet: "0x742d35Cc...",             // UPDATE: Your team multisig  
treasury1: "0x742d35Cc...",              // UPDATE: Treasury wallet 1
treasury2: "0x742d35Cc...",              // UPDATE: Treasury wallet 2
// ... (all other wallets)
```

**In `scripts/governance/deploy-timelock.ts`:**
```solidity
//  REPLACE THESE:
"0x742d35Cc...", // UPDATE: Your team multisig
"0x742d35Cc...", // UPDATE: Backup multisig
```

**In `scripts/compliance/deploy-compliance-contracts.ts`:**
```solidity
//  REPLACE THESE:
zkVerifyContract: "0x0000000000000000000000000000000000000000", // UPDATE: Real zkVerify contract
trezaTokenAddress: "0x0000000000000000000000000000000000000000", // UPDATE: Deployed TREZA token
```

#### 2. Environment Variables Setup

**Create `.env` file (NEVER commit this):**
```bash
# RPC URLs
SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/YOUR_KEY
MAINNET_RPC_URL=https://eth-mainnet.g.alchemy.com/v2/YOUR_KEY

# Private keys (use hardware wallet for production)
PRIVATE_KEY=your_private_key_here

# API keys  
ETHERSCAN_API_KEY=your_etherscan_api_key
COINMARKETCAP_API_KEY=your_coinmarketcap_api_key
```

### ª Testing Requirements

#### Testnet Deployment
- [ ] **Deploy on Sepolia** - Full deployment tested
- [ ] **All functions tested** - Manual testing of all features
- [ ] **Integration testing** - Frontend + contracts working
- [ ] **Gas cost analysis** - Acceptable costs for users
- [ ] **Edge case testing** - Boundary conditions tested

#### Security Testing
- [ ] **Reentrancy testing** - All external calls protected
- [ ] **Access control testing** - Unauthorized calls fail properly
- [ ] **Input validation testing** - Invalid inputs handled gracefully  
- [ ] **Emergency scenario testing** - Pause/unpause works correctly
- [ ] **Governance testing** - Timelock and voting mechanisms work

###  Governance Setup

#### Timelock Configuration
- [ ] **Minimum delay set** - 24+ hours for mainnet
- [ ] **Proposer addresses** - Team multisig addresses configured
- [ ] **Executor addresses** - Appropriate execution permissions
- [ ] **Admin renunciation** - Plan for decentralizing admin role

#### Multisig Wallets
- [ ] **Team multisig deployed** - 3/5 or similar threshold
- [ ] **Treasury multisig deployed** - Secure fee collection
- [ ] **Emergency multisig deployed** - For critical situations
- [ ] **Backup procedures** - Key recovery processes documented

###  Monitoring & Alerting

#### Contract Monitoring
- [ ] **Etherscan verification** - All contracts verified
- [ ] **Transaction monitoring** - Alerts for large transactions
- [ ] **Balance monitoring** - Treasury and contract balances tracked
- [ ] **Event monitoring** - Critical events tracked
- [ ] **Gas price monitoring** - Network congestion alerts

#### Security Monitoring  
- [ ] **Unusual activity alerts** - Large transfers, admin calls
- [ ] **Failed transaction monitoring** - Potential attack attempts
- [ ] **Contract interaction monitoring** - Unknown contract calls
- [ ] **Emergency contact system** - 24/7 response capability

###  Documentation

#### Public Documentation
- [ ] **README updated** - Clear setup instructions
- [ ] **Security policy published** - SECURITY.md complete
- [ ] **API documentation** - All functions documented
- [ ] **Integration guides** - Developer resources ready
- [ ] **Audit reports published** - Transparency for users

#### Internal Documentation
- [ ] **Emergency procedures** - Step-by-step incident response
- [ ] **Key management** - Secure key storage procedures  
- [ ] **Deployment procedures** - Repeatable deployment process
- [ ] **Monitoring runbooks** - Alert response procedures

###  Final Security Review

#### Code Review
- [ ] **No debug code** - All console.log and debug statements removed
- [ ] **No TODO comments** - All development notes cleaned up
- [ ] **Consistent naming** - Professional variable/function names
- [ ] **Gas optimization** - Efficient contract operations
- [ ] **Error handling** - Proper error messages and reverts

#### Deployment Review
- [ ] **Correct network** - Deploying to intended network
- [ ] **Correct addresses** - All addresses double-checked
- [ ] **Correct parameters** - All constructor parameters verified
- [ ] **Sufficient gas** - Deployment transactions have enough gas
- [ ] **Backup plan** - Rollback procedures if needed

##  Deployment Day Checklist

### Pre-Deployment (T-24 hours)
- [ ] **Final code freeze** - No more changes
- [ ] **Team coordination** - All team members ready
- [ ] **Communication plan** - Community announcements prepared
- [ ] **Emergency contacts** - All team members reachable

### Deployment (T-0)
- [ ] **Deploy contracts** - In correct order
- [ ] **Verify on Etherscan** - All contracts verified
- [ ] **Test basic functions** - Smoke testing
- [ ] **Transfer ownership** - To multisig/governance
- [ ] **Announce deployment** - Official contract addresses

### Post-Deployment (T+1 hour)
- [ ] **Monitor transactions** - Watch for unusual activity
- [ ] **Test frontend integration** - Ensure UI works with contracts
- [ ] **Community communication** - Address any questions
- [ ] **Documentation updates** - Update all docs with real addresses

---

##  STOP - Do Not Deploy If Any Item Is Unchecked

**This checklist ensures the security and reliability of the TREZA protocol. Every item must be completed before public deployment.**

**Remember: Smart contracts are immutable. Take time to get it right.**
