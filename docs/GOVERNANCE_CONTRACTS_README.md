# Treza Governance Contracts

## Overview

This directory contains governance contracts and scripts for decentralizing your Treza token. These contracts are **ready to deploy** when you want to transition from direct ownership to community governance.

##  Contract Architecture

### Current State: Direct Ownership
```
You (Owner)  TrezaToken
     
Direct control over all functions
```

### Future State: Governance Control
```
Proposers  TimelockController  TrezaToken
              
         24-hour delay
         
OR

Token Holders  Governor  TimelockController  TrezaToken
                                               
   Vote      Count votes   Enforce delay    Execute changes
```

##  Files Structure

```
contracts/governance/
 TrezaTimelock.sol          # TimelockController for delayed execution
 TrezaGovernor.sol          # Full DAO governor with token voting
 TrezaTokenVoting.sol       # Voting-enabled token (for DAO)

scripts/governance/
 deploy-timelock.ts         # Deploy simple timelock governance
 deploy-full-dao.ts         # Deploy complete DAO system
 transfer-ownership.ts      # Transfer token to governance
 examples/
     propose-fee-change.ts  # Example governance proposal
     execute-proposal.ts    # Example proposal execution
```

##  Quick Start

### Option 1: Simple Timelock Governance (Recommended First)

**1. Deploy Timelock:**
```bash
npx hardhat run scripts/governance/deploy-timelock.ts --network sepolia
```

**2. Update addresses in the script:**
```typescript
const proposers = [
    "0xYourTeamMultisig",     // Can propose changes
    "0xYourBackupMultisig",  // Backup proposer
];
```

**3. Transfer token ownership:**
```bash
# Update addresses in transfer-ownership.ts first
npx hardhat run scripts/governance/transfer-ownership.ts --network sepolia
```

**4. Make governance proposals:**
```bash
# Update addresses in propose-fee-change.ts first
npx hardhat run scripts/governance/examples/propose-fee-change.ts --network sepolia
```

### Option 2: Full DAO Governance (Advanced)

**1. Deploy complete DAO:**
```bash
npx hardhat run scripts/governance/deploy-full-dao.ts --network sepolia
```

**2. Community votes on proposals through token holdings**

##  Governance Options

### Simple Timelock Governance

**Best for:** Teams that want decentralization with time delays but don't need token voting.

**Features:**
-  24-hour delay on all changes
-  Transparent proposals
-  Multiple proposers supported
-  Anyone can execute approved proposals
-  No token voting required

**Workflow:**
1. Proposer schedules operation
2. 24-hour delay for community review
3. Anyone can execute after delay

### Full DAO Governance

**Best for:** Projects that want complete community control through token voting.

**Features:**
-  Token holder voting
-  Quorum requirements (4% default)
-  1-week voting periods
-  24-hour execution delays
-  Fully decentralized

**Workflow:**
1. Token holder creates proposal
2. 1-week voting period
3. If passed, 24-hour delay
4. Anyone can execute

## ‹ Configuration Options

### Timelock Settings

```typescript
const minDelay = 86400; // 24 hours (recommended)

const proposers = [
    "0xYourTeamMultisig",     // Primary proposer
    "0xYourBackupMultisig",  // Backup proposer (optional)
];

const executors = [
    "0x0000000000000000000000000000000000000000" // Anyone can execute (recommended)
    // OR specific addresses for restricted execution
];
```

### Governor Settings

```typescript
const votingDelay = 1;      // 1 block (prevents flash loans)
const votingPeriod = 50400; // ~1 week
const proposalThreshold = 0; // Anyone can propose
const quorumPercentage = 4;  // 4% quorum required
```

##  Usage Examples

### Propose Fee Change

```typescript
// 1. Encode function call
const data = trezaToken.interface.encodeFunctionData("setFeePercentage", [3]);

// 2. Schedule proposal
await timelock.schedule(
    trezaTokenAddress,  // target
    0,                  // value
    data,              // calldata
    ethers.ZeroHash,   // predecessor
    salt,              // unique salt
    86400              // 24 hour delay
);

// 3. Wait 24 hours...

// 4. Execute proposal
await timelock.execute(
    trezaTokenAddress,
    0,
    data,
    ethers.ZeroHash,
    salt
);
```

### DAO Proposal

```typescript
// 1. Create proposal
await governor.propose(
    [trezaTokenAddress],                    // targets
    [0],                                    // values
    [encodedFunctionCall],                  // calldatas
    "Reduce fee to 3% for better adoption"  // description
);

// 2. Token holders vote
await governor.castVote(proposalId, 1); // 1 = For

// 3. If passed, queue in timelock
await governor.queue(/* proposal details */);

// 4. Execute after delay
await governor.execute(/* proposal details */);
```

##  Security Features

### Timelock Protection
-  **24-hour delays** prevent rushed decisions
-  **Public proposals** allow community review
-  **Transparent execution** - all changes are visible
-  **Emergency response time** for community

### Access Control
-  **Proposer roles** limit who can submit proposals
-  **Executor roles** control who can execute (or open to all)
-  **Admin renunciation** for full decentralization
-  **Role-based permissions** prevent unauthorized access

### DAO Protection
-  **Voting delays** prevent flash loan attacks
-  **Quorum requirements** ensure sufficient participation
-  **Token-based voting** aligns incentives
-  **Proposal thresholds** prevent spam

##  Governance Functions

All these functions become governance-controlled after ownership transfer:

```solidity
// Trading Control
setTradingEnabled(bool)
setWhitelistMode(bool)
setWhitelist(address[], bool)

// Fee Management  
setFeePercentage(uint256)
setFeeWallets(address, address)
setFeeExemption(address, bool)

// Anti-Sniping
setBlacklist(address[], bool)
setAntiSniperConfig(uint256, uint256)
setTimeBasedAntiSniper(bool)
setAntiSniperPhases(TimeFeePhase[4])

// Emergency
startPublicTradingTimer()
```

## ª Testing

### Before Mainnet Deployment

1. **Deploy on testnet** with test addresses
2. **Test proposal workflow** end-to-end
3. **Verify time delays** work correctly
4. **Test emergency scenarios**
5. **Validate all governance functions**

### Test Scripts

```bash
# Deploy governance on testnet
npx hardhat run scripts/governance/deploy-timelock.ts --network sepolia

# Test proposal workflow
npx hardhat run scripts/governance/examples/propose-fee-change.ts --network sepolia

# Test execution (after delay)
npx hardhat run scripts/governance/examples/execute-proposal.ts --network sepolia
```

##  Important Warnings

### Before Transfer
-  **Test thoroughly** on testnet first
-  **Verify governance contracts** are working
-  **Ensure you have proposer access**
-  **Document all procedures**

### After Transfer
-  **Ownership transfer is irreversible**
-  **All changes require governance**
-  **Time delays apply to everything**
-  **Emergency procedures needed**

##  Migration Timeline

### Phase 1: Launch (Current)
-  Direct ownership for fast iteration
-  Deploy and test governance contracts
-  Prepare migration procedures

### Phase 2: Simple Governance (Month 1-3)
-  Deploy timelock governance
-  Transfer ownership to timelock
-  Test governance workflow

### Phase 3: Full DAO (Month 6+)
-  Deploy DAO governance
-  Migrate to token voting
-  Full community control

##  Additional Resources

- **OpenZeppelin Governance:** https://docs.openzeppelin.com/contracts/governance
- **Timelock Documentation:** https://docs.openzeppelin.com/contracts/api/governance#TimelockController
- **Governor Documentation:** https://docs.openzeppelin.com/contracts/api/governance#governor
- **Governance Best Practices:** https://blog.openzeppelin.com/governor-smart-contract/

## ‰ Ready to Decentralize?

Your governance contracts are ready! When you're prepared to transition from direct ownership to community governance, these contracts provide a secure, tested path forward.

**Remember:** Start simple with timelock governance, then evolve to full DAO when your community is ready. 
