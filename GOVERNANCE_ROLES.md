# Governance Roles: Proposers and Executors

## Overview

The TREZA token governance system uses OpenZeppelin's `TimelockController` which implements a two-step governance process with distinct roles for proposing and executing governance actions. This document explains the **Proposers** and **Executors** roles and how to configure them properly.

## Understanding the Roles

### Proposers 🏛️

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

### Executors ⚡

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

Your timelock contract enforces these requirements:

```solidity
// From your contract validation
require(proposers.length > 0, "Treza: no proposers provided");
require(executors.length > 0, "Treza: no executors provided");

// No zero addresses allowed in proposers or executors arrays
// (except for the special case of zero address meaning "anyone" for executors)
```

## Example Configurations

### Configuration 1: DAO with Open Execution
```typescript
const constructorParams = {
  // ... other params
  timelockDelay: 86400 // 24 hours
};

const proposers = [
  "0x...", // Governor contract address
  "0x...", // Emergency multisig
];

const executors = [
  "0x0000000000000000000000000000000000000000" // Anyone can execute
];
```

### Configuration 2: Restricted Governance
```typescript
const proposers = [
  "0x...", // Main governance address
];

const executors = [
  "0x...", // Governor contract
  "0x...", // Core team multisig
  "0x...", // Community multisig
];
```

## Workflow Example

1. **Proposal Phase**: Proposer submits a governance proposal
   ```typescript
   // Proposer queues an operation
   await timelock.schedule(target, value, data, predecessor, salt, delay);
   ```

2. **Delay Phase**: Community has 24 hours to review
   - Proposal is public and transparent
   - Community can prepare to react if needed
   - No execution possible during this period

3. **Execution Phase**: After delay expires, executor can execute
   ```typescript
   // Executor (or anyone if open execution) executes
   await timelock.execute(target, value, data, predecessor, salt);
   ```

## Best Practices

### For Proposers
- ✅ Use hardware wallets or secure multisigs
- ✅ Have multiple proposers for redundancy
- ✅ Regularly rotate keys if needed
- ❌ Don't use a single point of failure
- ❌ Don't share proposer keys

### For Executors
- ✅ Consider using open execution (zero address) for decentralization
- ✅ If using restricted execution, have multiple executors
- ✅ Include the governance contract as an executor
- ❌ Don't create execution bottlenecks
- ❌ Don't rely on single executor

### General Security
- ✅ Test governance flow on testnet first
- ✅ Document all governance addresses
- ✅ Have emergency procedures ready
- ✅ Regular security audits
- ❌ Don't rush governance decisions
- ❌ Don't skip the delay period

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

## Deployment Checklist

Before deploying your governance system:

- [ ] Proposer addresses are controlled by your team
- [ ] Executor configuration matches your security model
- [ ] All addresses are validated (no zero addresses except for open execution)
- [ ] Timelock delay is appropriate (24 hours recommended)
- [ ] Backup governance procedures are documented
- [ ] Team understands the governance workflow

## Summary

The proposer/executor model provides a secure, transparent governance system where:

- **Proposers** (1-3 addresses) control what gets proposed
- **Executors** (open or restricted) control final execution
- **Time delay** (24 hours) provides security buffer
- **Community** has time to react to proposals

This system protects against rushed decisions while maintaining operational flexibility for legitimate governance actions.