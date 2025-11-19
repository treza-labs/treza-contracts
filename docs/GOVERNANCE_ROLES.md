# Governance Roles: Proposers and Executors

## Overview

**Note: This document describes governance roles for when you're ready to add governance to your TREZA token.**

Your TREZA token currently uses simple ownership for fast launch iteration. When you're ready to decentralize, you can deploy separate governance contracts that use OpenZeppelin's `TimelockController` with distinct roles for proposing and executing governance actions.

**Current State:** Direct ownership (you control the token immediately)
**Future State:** Governance with proposers/executors (described in this document)

See `GOVERNANCE_MIGRATION_GUIDE.md` for step-by-step migration instructions.

## Understanding the Roles

### Proposers 

**Proposers** are addresses that have the authority to queue operations in the timelock system.

**What they can do:**
- Submit governance proposals for timelock execution
- Queue operations that will be executed after the delay period
- Propose changes to contract parameters, upgrades, treasury operations
- Schedule any function calls that need governance approval

**What they cannot do:**
- Execute operations immediately (must wait for timelock delay)
- Execute operations at all (that's the executor's role)
- Bypass the timelock delay mechanism

### Executors 

**Executors** are addresses that have the authority to execute operations that have been queued and whose timelock delay has expired.

**What they can do:**
- Execute queued operations after the delay period has passed
- Carry out approved governance decisions
- Trigger the final transaction that implements the proposal

**What they cannot do:**
- Queue new operations (that's the proposer's role)
- Execute operations before the delay period expires
- Execute operations that weren't properly queued by proposers

## Security Model

The timelock system provides security through:

1. **Separation of Concerns**: Different roles for proposing vs executing
2. **Time Delay**: 24-hour window for community to review and react
3. **Transparency**: All operations are queued publicly before execution
4. **Controlled Access**: Only authorized addresses can propose operations

## Recommended Configuration

### Proposers Setup

**Recommended: 1-3 proposer addresses**

```typescript
const proposers = [
  "0x742d35Cc6532C4532532C4532C4532C4532C4540", // Main governance contract
  "0x742d35Cc6532C4532532C4532C4532C4532C4541", // Backup multisig (optional)
];
```

**Should include:**
- Your main Governor contract address
- Trusted multisig addresses for emergency proposals (optional)
- Core team addresses with governance authority

**Security considerations:**
- Keep the number limited to maintain control
- Only include addresses you have strict control over
- Ensure you have backup access (don't rely on a single proposer)

### Executors Setup

**Option 1: Open Execution (Recommended)**
```typescript
const executors = [
  "0x0000000000000000000000000000000000000000" // Anyone can execute
];
```

**Option 2: Restricted Execution**
```typescript
const executors = [
  "0x742d35Cc6532C4532532C4532C4532C4532C4542", // Main governance contract
  "0x742d35Cc6532C4532532C4532C4532C4532C4543", // Trusted executor 1
  "0x742d35Cc6532C4532532C4532C4532C4532C4544", // Trusted executor 2
];
```

**Why open execution is often preferred:**
- Anyone can execute approved proposals (more decentralized)
- Execution is safe since proposals must be pre-approved and delayed
- Prevents execution bottlenecks
- Community members can execute proposals on behalf of the DAO

## Validation Requirements

When you deploy a separate timelock contract, it will enforce these requirements:

```solidity
// TimelockController validation (in separate governance contract)
require(proposers.length > 0, "TimelockController: no proposers provided");
require(executors.length > 0, "TimelockController: no executors provided");

// No zero addresses allowed in proposers or executors arrays
// (except for the special case of zero address meaning "anyone" for executors)
```

**Note:** These validations are NOT in your current Treza token contract - they'll be in the separate governance contracts you deploy later.

## Example Configurations

**When you're ready to add governance**, you'll deploy separate contracts with these configurations:

### Configuration 1: Simple Timelock with Open Execution
```typescript
// Deploy separate timelock contract
const TrezaTimelock = await ethers.getContractFactory("TrezaTimelock");

const proposers = [
  "0xYourTeamMultisig",     // Team can propose
  "0xYourBackupMultisig",  // Backup proposer
];

const executors = [
  "0x0000000000000000000000000000000000000000" // Anyone can execute
];

const minDelay = 86400; // 24 hours

const timelock = await TrezaTimelock.deploy(minDelay, proposers, executors);

// Then transfer your token ownership to the timelock
await trezaToken.transferOwnership(await timelock.getAddress());
```

### Configuration 2: Full DAO Governance
```typescript
// Deploy governor + timelock contracts
const proposers = []; // Governor contract will be the proposer
const executors = []; // Governor contract will be the executor

const timelock = await TrezaTimelock.deploy(minDelay, proposers, executors);
const governor = await TrezaGovernor.deploy(trezaTokenAddress, timelockAddress);

// Setup roles and transfer ownership
// (See GOVERNANCE_MIGRATION_GUIDE.md for full details)
```

## Workflow Example

**Current Workflow (Direct Ownership):**
```typescript
// You can change anything immediately
await trezaToken.setFeePercentage(3); // Instant change
```

**Future Workflow (With Governance):**

1. **Proposal Phase**: Proposer submits a governance proposal
   ```typescript
   // Example: Propose fee change to 3%
   const target = trezaTokenAddress;
   const data = trezaToken.interface.encodeFunctionData("setFeePercentage", [3]);
   
   // Proposer queues the operation
   await timelock.schedule(target, 0, data, ethers.ZeroHash, salt, 86400);
   ```

2. **Delay Phase**: Community has 24 hours to review
   - Proposal is public and transparent
   - Community can prepare to react if needed
   - No execution possible during this period

3. **Execution Phase**: After delay expires, executor can execute
   ```typescript
   // Executor (or anyone if open execution) executes
   await timelock.execute(target, 0, data, ethers.ZeroHash, salt);
   ```

## Best Practices

### For Proposers
-  Use hardware wallets or secure multisigs
-  Have multiple proposers for redundancy
-  Regularly rotate keys if needed
-  Don't use a single point of failure
-  Don't share proposer keys

### For Executors
-  Consider using open execution (zero address) for decentralization
-  If using restricted execution, have multiple executors
-  Include the governance contract as an executor
-  Don't create execution bottlenecks
-  Don't rely on single executor

### General Security
-  Test governance flow on testnet first
-  Document all governance addresses
-  Have emergency procedures ready
-  Regular security audits
-  Don't rush governance decisions
-  Don't skip the delay period

## Emergency Considerations

### Lost Proposer Access
- Have multiple proposers configured
- Keep secure backups of proposer credentials
- Document recovery procedures

### Lost Executor Access
- If using open execution: No problem, anyone can execute
- If using restricted execution: Ensure multiple executors
- Have emergency governance procedures

### Malicious Proposals
- 24-hour delay allows community response time
- Monitor governance proposals actively
- Have community alert systems in place

## Migration Checklist

**Current State (No Action Needed):**
- [x] Token deployed with simple ownership
- [x] You have full control over all functions
- [x] No governance delays during launch

**When Ready to Add Governance:**
- [ ] Decide on governance model (simple timelock vs full DAO)
- [ ] Deploy separate governance contracts
- [ ] Configure proposer addresses (controlled by your team)
- [ ] Configure executor setup (open vs restricted)
- [ ] Test governance flow on testnet
- [ ] Transfer token ownership to governance contract
- [ ] Document new governance procedures
- [ ] Train team on governance workflow
- [ ] Set up community monitoring and alerts

## Summary

**Current State:**
-  **Simple ownership** - you control the token directly
-  **Fast iteration** - change parameters instantly
-  **Launch ready** - no governance complexity

**Future Governance (When Ready):**
The proposer/executor model provides a secure, transparent governance system where:

- **Proposers** (1-3 addresses) control what gets proposed
- **Executors** (open or restricted) control final execution  
- **Time delay** (24 hours) provides security buffer
- **Community** has time to react to proposals

This system protects against rushed decisions while maintaining operational flexibility for legitimate governance actions.

**Migration Path:**
1. **Launch** with direct ownership (current)
2. **Add governance** when community is ready
3. **Transfer ownership** to governance contracts
4. **Maintain flexibility** with documented procedures

See `GOVERNANCE_MIGRATION_GUIDE.md` for detailed implementation steps.