# Governance Migration Guide

## Overview

This guide explains how to migrate your Treza token from direct ownership to decentralized governance using a TimelockController or full DAO system. Your token was deployed with simple ownership for fast launch iteration, but can be upgraded to full governance when your community is ready.

## Current State: Direct Ownership

Your Treza token currently uses simple `Ownable` pattern:

```solidity
// Current setup - you own the contract directly
contract TrezaToken is ERC20, Ownable {
    // All onlyOwner functions can be called immediately by owner
    function setTradingEnabled(bool _enabled) external onlyOwner { ... }
    function setFeePercentage(uint256 newFee) external onlyOwner { ... }
    // ... other management functions
}
```

**Benefits of current setup:**
- ✅ Fast decision making during launch
- ✅ No timelock delays for critical fixes
- ✅ Simple and gas efficient
- ✅ Easy to test and debug

## Migration Options

### Option 1: Simple Multisig Governance (Recommended First Step)

**When to use:** When you want shared control but still need fast decisions.

**Implementation:**
```typescript
// Deploy a multisig wallet (like Gnosis Safe)
const multisigAddress = "0xYourMultisigWalletAddress";

// Transfer ownership to multisig
await trezaToken.transferOwnership(multisigAddress);
```

**Benefits:**
- ✅ Shared control among team members
- ✅ Still fast execution (no timelock delays)
- ✅ More decentralized than single owner
- ✅ Easy to implement

**Governance Process:**
1. Team member proposes change in multisig
2. Required signatures approve
3. Transaction executes immediately

---

### Option 2: TimelockController Governance

**When to use:** When you want time delays for community protection but don't need token voting.

**Step 1: Deploy TimelockController**

```solidity
// contracts/TrezaTimelock.sol
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/governance/TimelockController.sol";

contract TrezaTimelock is TimelockController {
    constructor(
        uint256 minDelay,           // 24 hours = 86400 seconds
        address[] memory proposers, // Who can propose
        address[] memory executors  // Who can execute (use 0x0 for anyone)
    ) TimelockController(minDelay, proposers, executors, msg.sender) {}
}
```

**Step 2: Deploy the Timelock**

```typescript
// scripts/deploy-timelock.ts
import { ethers } from "hardhat";

async function main() {
    const [deployer] = await ethers.getSigners();
    
    const proposers = [
        "0xYourTeamMultisig",     // Team can propose
        "0xYourBackupMultisig",  // Backup proposer
    ];
    
    const executors = [
        "0x0000000000000000000000000000000000000000" // Anyone can execute
    ];
    
    const minDelay = 86400; // 24 hours
    
    const TrezaTimelock = await ethers.getContractFactory("TrezaTimelock");
    const timelock = await TrezaTimelock.deploy(minDelay, proposers, executors);
    
    await timelock.waitForDeployment();
    console.log("Timelock deployed to:", await timelock.getAddress());
}
```

**Step 3: Transfer Token Ownership**

```typescript
// Transfer Treza ownership to timelock
const timelockAddress = "0xYourDeployedTimelockAddress";
await trezaToken.transferOwnership(timelockAddress);
```

**Step 4: Governance Process**

```typescript
// Example: Propose fee change to 3%
const target = trezaTokenAddress;
const value = 0;
const data = trezaToken.interface.encodeFunctionData("setFeePercentage", [3]);
const predecessor = ethers.ZeroHash;
const salt = ethers.keccak256(ethers.toUtf8Bytes("fee-change-proposal-1"));
const delay = 86400; // 24 hours

// Step 1: Proposer schedules the operation
await timelock.schedule(target, value, data, predecessor, salt, delay);

// Step 2: Wait 24 hours for community review

// Step 3: Anyone can execute after delay
await timelock.execute(target, value, data, predecessor, salt);
```

---

### Option 3: Full DAO Governance with Token Voting

**When to use:** When you want full community governance with token holder voting.

**Step 1: Make Token Voting-Compatible**

Your token needs voting functionality. Create a new version:

```solidity
// contracts/TrezaTokenVoting.sol
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TrezaTokenVoting is ERC20Votes, Ownable {
    // Copy all your existing Treza functionality
    // Add voting capabilities
    
    constructor() 
        ERC20("Treza Token", "TREZA")
        ERC20Permit("Treza Token")
        Ownable(msg.sender)
    {
        // Your existing constructor logic
    }
    
    // Override required functions for voting
    function _update(address from, address to, uint256 value)
        internal
        override(ERC20, ERC20Votes)
    {
        super._update(from, to, value);
    }

    function nonces(address owner)
        public
        view
        override(ERC20Permit, Nonces)
        returns (uint256)
    {
        return super.nonces(owner);
    }
}
```

**Step 2: Deploy Governor Contract**

```solidity
// contracts/TrezaGovernor.sol
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/governance/Governor.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol";

contract TrezaGovernor is 
    Governor,
    GovernorSettings,
    GovernorCountingSimple,
    GovernorVotes,
    GovernorVotesQuorumFraction,
    GovernorTimelockControl 
{
    constructor(
        IVotes _token,
        TimelockController _timelock
    )
        Governor("TrezaGovernor")
        GovernorSettings(1, 50400, 0) // 1 block delay, ~1 week voting, 0 proposal threshold
        GovernorVotes(_token)
        GovernorVotesQuorumFraction(4) // 4% quorum required
        GovernorTimelockControl(_timelock)
    {}

    // Required overrides
    function votingDelay()
        public
        view
        override(IGovernor, GovernorSettings)
        returns (uint256)
    {
        return super.votingDelay();
    }

    function votingPeriod()
        public
        view
        override(IGovernor, GovernorSettings)
        returns (uint256)
    {
        return super.votingPeriod();
    }

    function quorum(uint256 blockNumber)
        public
        view
        override(IGovernor, GovernorVotesQuorumFraction)
        returns (uint256)
    {
        return super.quorum(blockNumber);
    }

    function proposalThreshold()
        public
        view
        override(Governor, GovernorSettings)
        returns (uint256)
    {
        return super.proposalThreshold();
    }

    function _execute(uint256 proposalId, address[] memory targets, uint256[] memory values, bytes[] memory calldatas, bytes32 descriptionHash)
        internal
        override(Governor, GovernorTimelockControl)
    {
        super._execute(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _cancel(address[] memory targets, uint256[] memory values, bytes[] memory calldatas, bytes32 descriptionHash)
        internal
        override(Governor, GovernorTimelockControl)
        returns (uint256)
    {
        return super._cancel(targets, values, calldatas, descriptionHash);
    }

    function _executor()
        internal
        view
        override(Governor, GovernorTimelockControl)
        returns (address)
    {
        return super._executor();
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(Governor, GovernorTimelockControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
```

**Step 3: Full DAO Deployment**

```typescript
// scripts/deploy-dao.ts
async function deployFullDAO() {
    // 1. Deploy voting-enabled token (or upgrade existing)
    const TrezaTokenVoting = await ethers.getContractFactory("TrezaTokenVoting");
    const votingToken = await TrezaTokenVoting.deploy();
    
    // 2. Deploy timelock
    const timelock = await TrezaTimelock.deploy(
        86400, // 24 hour delay
        [], // No direct proposers (governor will propose)
        [], // No direct executors (governor will execute)
    );
    
    // 3. Deploy governor
    const TrezaGovernor = await ethers.getContractFactory("TrezaGovernor");
    const governor = await TrezaGovernor.deploy(
        await votingToken.getAddress(),
        await timelock.getAddress()
    );
    
    // 4. Setup roles
    const PROPOSER_ROLE = await timelock.PROPOSER_ROLE();
    const EXECUTOR_ROLE = await timelock.EXECUTOR_ROLE();
    const TIMELOCK_ADMIN_ROLE = await timelock.TIMELOCK_ADMIN_ROLE();
    
    await timelock.grantRole(PROPOSER_ROLE, await governor.getAddress());
    await timelock.grantRole(EXECUTOR_ROLE, ethers.ZeroAddress); // Anyone can execute
    await timelock.revokeRole(TIMELOCK_ADMIN_ROLE, deployer.address); // Renounce admin
    
    // 5. Transfer token ownership to timelock
    await votingToken.transferOwnership(await timelock.getAddress());
    
    console.log("DAO deployed successfully!");
    console.log("Token:", await votingToken.getAddress());
    console.log("Governor:", await governor.getAddress());
    console.log("Timelock:", await timelock.getAddress());
}
```

**Step 4: DAO Governance Process**

```typescript
// Example: Community proposes fee change
async function proposeAndVote() {
    // 1. Create proposal
    const targets = [trezaTokenAddress];
    const values = [0];
    const calldatas = [trezaToken.interface.encodeFunctionData("setFeePercentage", [3])];
    const description = "Reduce fee to 3% for better adoption";
    
    const proposeTx = await governor.propose(targets, values, calldatas, description);
    const proposeReceipt = await proposeTx.wait();
    const proposalId = proposeReceipt.logs[0].args.proposalId;
    
    // 2. Wait for voting delay (1 block)
    await ethers.provider.send("evm_mine");
    
    // 3. Token holders vote
    await governor.castVote(proposalId, 1); // 1 = For, 0 = Against, 2 = Abstain
    
    // 4. Wait for voting period (~1 week)
    // ... voting happens ...
    
    // 5. Queue proposal (if passed)
    await governor.queue(targets, values, calldatas, ethers.keccak256(ethers.toUtf8Bytes(description)));
    
    // 6. Wait for timelock delay (24 hours)
    // ... community review period ...
    
    // 7. Execute proposal
    await governor.execute(targets, values, calldatas, ethers.keccak256(ethers.toUtf8Bytes(description)));
}
```

## Migration Timeline Recommendation

### Phase 1: Launch (Current)
- ✅ **Direct ownership** for fast iteration
- ✅ **Quick response** to issues
- ✅ **Simple deployment**

### Phase 2: Team Governance (Month 1-3)
- 🔄 **Transfer to multisig** for shared team control
- ✅ **Still fast execution** for critical fixes
- ✅ **More decentralized** than single owner

### Phase 3: Timelock Governance (Month 3-6)
- 🔄 **Deploy TimelockController**
- 🔄 **24-hour delays** for community protection
- ✅ **Transparent governance** with public proposals

### Phase 4: Full DAO (Month 6+)
- 🔄 **Deploy Governor contract**
- 🔄 **Token holder voting** on all proposals
- ✅ **Fully decentralized** governance

## Security Considerations

### Before Migration
- ✅ **Audit governance contracts** thoroughly
- ✅ **Test on testnet** extensively
- ✅ **Have emergency procedures** ready
- ✅ **Document all processes** clearly

### During Migration
- ⚠️ **Use timelock delays** appropriately (24 hours minimum)
- ⚠️ **Set up monitoring** for governance proposals
- ⚠️ **Have community alerts** for important votes
- ⚠️ **Keep emergency contacts** updated

### After Migration
- 🔍 **Monitor governance activity** regularly
- 🔍 **Engage with community** on proposals
- 🔍 **Maintain documentation** and guides
- 🔍 **Regular security reviews** of governance

## Emergency Procedures

### Lost Access Recovery
If you lose access to governance:

1. **Multisig Recovery**: Use backup signers
2. **Timelock Recovery**: Wait for proposals to expire, use executor role
3. **DAO Recovery**: Community can vote on recovery proposals

### Malicious Proposals
If malicious proposals are submitted:

1. **Timelock Period**: 24-hour window to alert community
2. **Community Response**: Organize opposition or emergency response
3. **Emergency Pause**: If implemented, use emergency pause functions

### Governance Attacks
Protection against governance attacks:

1. **Quorum Requirements**: Ensure sufficient participation
2. **Proposal Thresholds**: Require minimum tokens to propose
3. **Voting Delays**: Prevent flash loan attacks
4. **Community Monitoring**: Active community oversight

## Tools and Resources

### Governance Interfaces
- **Tally**: https://tally.xyz (DAO governance interface)
- **Snapshot**: https://snapshot.org (Off-chain voting)
- **Gnosis Safe**: https://safe.global (Multisig management)

### Monitoring Tools
- **OpenZeppelin Defender**: Automated monitoring and alerts
- **Tenderly**: Transaction monitoring and simulation
- **Etherscan**: On-chain governance tracking

### Documentation
- **OpenZeppelin Governance**: https://docs.openzeppelin.com/contracts/governance
- **Compound Governance**: https://compound.finance/governance
- **Uniswap Governance**: https://gov.uniswap.org

## Conclusion

Your Treza token is designed for easy governance migration. Start simple with direct ownership, then gradually decentralize as your community grows and matures. Each phase builds on the previous one, allowing for smooth transitions without disrupting your token's functionality.

The key is timing - migrate to more complex governance only when your community is ready and you have the infrastructure to support it properly.

Remember: **Governance is a journey, not a destination.** Start simple, learn from your community, and evolve your governance system as your project grows.
