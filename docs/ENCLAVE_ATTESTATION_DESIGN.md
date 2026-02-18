# Enclave Attestation: On-Chain Verification of TEE Code

## Status: Proposal / Design Phase

## Problem

Treza's Nitro Enclave platform can run arbitrary Docker workloads inside hardware-isolated Trusted Execution Environments (TEEs). Each enclave produces **PCR values** -- cryptographic hashes proving exactly what code is running inside the hardware.

To close the trust loop, smart contracts need to:
1. Know which PCR values correspond to approved, audited code
2. Gate on-chain actions (USDC transfers, governance execution, data access) on valid attestation
3. Do this **without relying on a single trusted party** to decide what's "approved"

## Background: What PCR Values Are

When a Nitro Enclave boots, the hardware measures the loaded image and produces three PCR (Platform Configuration Register) values:

| PCR | What it measures | Significance |
|-----|-----------------|--------------|
| PCR0 | Enclave image (EIF) hash | **The code itself** -- changes if any byte of the binary changes |
| PCR1 | Linux kernel + boot ramfs | The enclave OS layer |
| PCR2 | Application layer | User application within the enclave |

PCR0 is the most important: it uniquely identifies the exact binary running inside the enclave. If someone modifies a single instruction, PCR0 changes.

## The Core Question: What Does "Approved Code" Mean?

When a smart contract checks `isApproved(pcr0)`, someone had to set that PCR0 as approved. **Who, and why should anyone trust them?**

This is the fundamental design problem. Centralized approaches (single admin, multisig, naive token voting on opaque hashes) don't solve it -- they just move the trust to a different party. The two approaches worth building are **Reproducible Builds + Governance** and **Formal Verification**.

---

## Approach 1: Reproducible Builds + Governance

**The key insight**: instead of voting on opaque hashes, vote on **source code** with a **verifiable build pipeline** that links source to PCR values.

### How It Works

1. Source code is public (GitHub, IPFS, Arweave)
2. The build is **deterministic/reproducible** -- anyone can compile the same source with the same toolchain and get the same binary, which produces the same PCR hash
3. Governance votes on **source code commits**, not raw hashes
4. Multiple independent parties reproduce the build and confirm the PCR mapping on-chain
5. The smart contract records: `(source_repo, commit_hash, compiler_version) → PCR0`

### Why This Works

Voters can audit readable source code. The link between "code I can read" and "hash the enclave produces" is independently verifiable by anyone with Docker. You don't need to trust the proposer -- you can check their work.

**Why Rust helps**: The enclave proxy is a static musl binary. Given the same `Cargo.lock` and compiler version, the output is deterministic. Python environments are notoriously non-reproducible.

### Optimistic Extension

This pairs naturally with an optimistic approval model (inspired by optimistic rollups) that shifts from "everyone must verify" to "anyone *can* verify, and they're incentivized to":

1. A **proposer** submits: source repo + commit hash + build instructions + resulting PCR values + a **stake** (TREZA or USDC)
2. The proposal enters a **challenge period** (e.g., 7 days)
3. During the challenge period, anyone can:
   - Reproduce the build and confirm or dispute the PCR mapping
   - Audit the source code and raise security objections
   - Submit a **challenge** with their own stake
4. If **unchallenged** after the period expires, the PCR hash is auto-approved
5. If **challenged**:
   - A dispute resolution process runs (governance vote or arbitration)
   - If the challenge is upheld → proposer's stake is slashed, challenger is rewarded
   - If the challenge fails → challenger's stake is slashed, proposer is rewarded

You only need **one honest auditor** in the entire ecosystem to catch a malicious proposal. The economic incentive (slash the proposer) means the cost of submitting bad code is high.

---

## Approach 2: Formal Verification + Automated Approval

The ultimate goal: remove humans from the approval loop entirely.

### How It Works

1. Enclave code is written with formal specifications (e.g., "this agent never transfers more than X USDC per day to addresses not on the allowlist")
2. A proof is generated that the code satisfies these properties
3. A ZK proof of the property verification is submitted on-chain
4. The smart contract verifies the proof and auto-approves the PCR hash

No governance vote needed. The math proves the code is safe.

### What's Feasible Now vs. Later

Full formal verification of arbitrary programs is an open research problem. But specific, constrained properties are achievable near-term:

| Property | Feasibility | Example |
|----------|------------|---------|
| Spending limits | Near-term | "Never transfers > X USDC per day" |
| Address allowlists | Near-term | "Only sends to addresses in set S" |
| Rate limiting | Near-term | "Max N transactions per hour" |
| Data confinement | Medium-term | "Never writes secrets to external storage" |
| Arbitrary safety | Long-term | "This trading strategy never risks more than Y% of the portfolio" |

### Hybrid Model

The most practical path is to combine both approaches:
- **Reproducible Builds + Governance** for the overall enclave code approval
- **Formal Verification** for specific safety properties that can be proven automatically
- A verified property can reduce the challenge period or lower stake requirements, since math has already covered the critical invariants

---

## Recommended Architecture

### Phase 1: Reproducible Builds + Optimistic Approval

```solidity
interface IEnclaveAttestation {
    // Propose code with source linkage and stake
    function proposeCode(
        string calldata sourceRepo,
        string calldata commitHash,
        string calldata buildInstructions,
        bytes calldata pcr0,
        bytes calldata pcr1,
        bytes calldata pcr2
    ) external payable returns (uint256 proposalId);

    // Anyone can confirm they independently reproduced the build
    function confirmBuild(uint256 proposalId) external;

    // Challenge a proposal during the challenge period
    function challengeProposal(uint256 proposalId, string calldata reason) external payable;

    // Finalize after challenge period (auto-approves if unchallenged)
    function finalizeProposal(uint256 proposalId) external;

    // Emergency revocation via governance
    function revokeApproval(bytes calldata pcr0) external;

    // Query: is this PCR0 approved?
    function isApproved(bytes calldata pcr0) external view returns (bool);

    // Query: full attestation record
    function getAttestation(bytes calldata pcr0) external view returns (
        string memory sourceRepo,
        string memory commitHash,
        uint256 approvedAt,
        uint256 confirmations,
        bool active
    );
}
```

- Proposals require a stake and enter a challenge period
- Independent builders call `confirmBuild()` to strengthen confidence
- Unchallenged proposals auto-approve; challenges trigger governance arbitration
- Other contracts (escrow, treasury, compliance) call `isApproved(pcr0)` before trusting enclave outputs
- Emergency `revokeApproval()` path via `TrezaGovernor` for discovered vulnerabilities

### Phase 2: Formal Verification Layer

- Add `verifyProperty(uint256 proposalId, bytes calldata zkProof)` for automated safety checks
- Verified properties can reduce the challenge period or lower stake requirements
- Start with constrained properties: spending limits, address allowlists, rate limiting
- ZK proof verification on-chain for specific code invariants

---

## Use Cases Unlocked

### Verifiable AI Agent Execution
An AI agent managing a USDC treasury runs inside an attested enclave. The smart contract holding the funds checks `isApproved(agent_pcr0)` before allowing withdrawals. Token holders voted on the agent's source code; independent auditors confirmed the build.

### Agent-to-Agent Commerce
Two AI agents verify each other's enclave attestation on-chain before exchanging USDC. Neither trusts the other's operator -- they trust the hardware attestation and the decentralized approval process.

### Confidential DeFi Strategies
A trading strategy runs inside an attested enclave. Investors deposit USDC into a contract that only releases funds to wallets controlled by the attested enclave. The attestation proves the strategy code hasn't been modified by the operator.

### Compliant USDC Operations
KYC verification logic runs inside an attested enclave (ties into existing `KYCVerifier` and `TrezaComplianceIntegration` contracts). The attestation proves to regulators exactly which compliance rules are being enforced, without revealing individual user data.

### Sealed-Bid Auctions
An enclave receives encrypted bids, opens them simultaneously, and triggers USDC escrow release to the winner. The attestation proves fair selection logic.

---

## Integration Points

| Existing Contract | Integration |
|-------------------|-------------|
| `TrezaGovernor` | Proposal/voting for code approval; dispute resolution for challenges |
| `TrezaTimelock` | Delay between approval and activation (defense against governance attacks) |
| `KYCVerifier` | Attested enclave runs KYC logic; contract verifies the enclave is approved |
| `TrezaComplianceIntegration` | Compliance rules execute inside attested enclaves |
| `ITreza` (token) | Staking for proposals/challenges; governance voting weight |

## Open Questions

1. **Stake amounts**: What's the minimum stake for proposals and challenges? Should it scale with the value the enclave controls?
2. **Challenge period duration**: 7 days matches optimistic rollups, but may be too slow for rapid iteration. Should different risk tiers have different periods?
3. **PCR granularity**: Should we verify PCR0 only (enclave image) or all three PCRs? PCR1/PCR2 change with kernel updates, which creates maintenance overhead.
4. **Revocation**: How do we handle revoking a previously approved PCR (e.g., vulnerability discovered)? Emergency governance path?
5. **Versioning**: How do we manage the transition from one approved enclave version to the next without downtime?
6. **Cross-chain**: If enclaves serve multiple chains, should attestation be on one canonical chain with bridges, or replicated?

## References

- [AWS Nitro Enclaves Attestation](https://docs.aws.amazon.com/enclaves/latest/user/verify-root.html)
- [Reproducible Builds](https://reproducible-builds.org/)
- [Optimistic Rollup Dispute Resolution](https://ethereum.org/en/developers/docs/scaling/optimistic-rollups/)
- [Formal Verification of Smart Contracts](https://ethereum.org/en/developers/docs/smart-contracts/formal-verification/)
