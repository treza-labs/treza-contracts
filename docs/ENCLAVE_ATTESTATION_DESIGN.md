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

This is the fundamental design problem. Below is the full spectrum of approaches, from most centralized to most decentralized.

---

## Trust Spectrum

### Level 0: Single Admin

An owner address calls `approveCode(pcr0)`.

- **Pros**: Simple, fast iteration
- **Cons**: Single point of failure. Defeats the purpose of using enclaves for trustlessness. The admin could approve malicious code, or be coerced.
- **Use case**: Internal testing only

### Level 1: Multisig

A k-of-n multisig approves PCR hashes.

- **Pros**: No single point of failure
- **Cons**: Still a small trusted committee. Collusion risk remains. No transparency into what the PCR hash represents.
- **Use case**: Early production with known, trusted operators

### Level 2: Token-Weighted Governance

TREZA token holders vote to approve PCR hashes (via `TrezaGovernor`).

- **Pros**: Decentralized authority. Transparent on-chain record of approvals.
- **Cons**: **The voter competency problem** -- can token holders actually verify what a PCR hash represents? A proposal says "approve PCR0 = abc123 for the treasury agent." Without reading source code, compiling it, and verifying the hash, voters are trusting the proposer on reputation alone. This is effectively Level 0 with a popularity contest.
- **Use case**: Non-critical governance decisions where social trust is acceptable

### Level 3: Reproducible Builds + Governance

This is where meaningful decentralization begins.

**The key insight**: instead of voting on opaque hashes, vote on **source code** with a **verifiable build pipeline** that links source to PCR values.

The process:
1. Source code is public (GitHub, IPFS, Arweave)
2. The build is **deterministic/reproducible** -- anyone can compile the same source with the same toolchain and get the same binary, which produces the same PCR hash
3. Governance votes on **source code commits**, not raw hashes
4. Multiple independent parties reproduce the build and confirm the PCR mapping on-chain
5. The smart contract records: `(source_repo, commit_hash, compiler_version) → PCR0`

**Why this works**: Voters can now audit readable source code. The link between "code I can read" and "hash the enclave produces" is independently verifiable by anyone with Docker. You don't need to trust the proposer -- you can check their work.

**Why Rust helps**: The enclave proxy is a static musl binary. Given the same `Cargo.lock` and compiler version, the output is deterministic. Python environments are notoriously non-reproducible.

- **Pros**: Meaningful verifiability. Voters can audit source. Independent verification is possible.
- **Cons**: Requires reproducible build infrastructure. Still depends on voter engagement.
- **Use case**: Production systems managing real value

### Level 4: Optimistic Approval with Challenge Period

Inspired by optimistic rollups. Shifts the model from "everyone must verify" to "anyone *can* verify, and they're incentivized to."

The process:
1. A **proposer** submits: source repo + commit hash + build instructions + resulting PCR values + a **stake** (TREZA or USDC)
2. The proposal enters a **challenge period** (e.g., 7 days)
3. During the challenge period, anyone can:
   - Reproduce the build and confirm or dispute the PCR mapping
   - Audit the source code and raise security objections
   - Submit a **challenge** with their own stake
4. If **unchallenged** after the period expires, the PCR hash is auto-approved
5. If **challenged**:
   - A dispute resolution process runs (governance vote, or designated auditor committee)
   - If the challenge is upheld → proposer's stake is slashed, challenger is rewarded
   - If the challenge fails → challenger's stake is slashed, proposer is rewarded

**Why this is powerful**: You only need **one honest auditor** in the entire ecosystem to catch a malicious proposal. The economic incentive (slash the proposer) means the cost of submitting bad code is high.

- **Pros**: Highly decentralized. Economic security model. Doesn't require all voters to be technical.
- **Cons**: 7-day delay for new code approval. Requires meaningful stake amounts.
- **Use case**: High-value systems (treasury agents, USDC custody, DeFi strategies)

### Level 5: Formal Verification + Automated Approval (Theoretical)

The ultimate goal: remove humans from the approval loop entirely.

1. Enclave code is written with formal specifications (e.g., "this agent never transfers more than X USDC per day to addresses not on the allowlist")
2. A proof is generated that the code satisfies these properties
3. A ZK proof of the property verification is submitted on-chain
4. The smart contract verifies the proof and auto-approves the PCR hash

No governance vote needed. The math proves the code is safe.

- **Pros**: Fully automated, no human trust required, instant approval
- **Cons**: Formal verification of real programs is hard. Only feasible for constrained behaviors.
- **Use case**: Future -- but specific sub-properties (spending limits, allowlists) are achievable near-term

---

## Recommended Architecture

### Phase 1: Level 2 + Reproducible Builds (Ship First)

```solidity
// Simplified interface
interface IEnclaveAttestation {
    // Governance proposes and approves code
    function proposeCode(
        string calldata sourceRepo,
        string calldata commitHash,
        bytes calldata pcr0,
        bytes calldata pcr1,
        bytes calldata pcr2
    ) external returns (uint256 proposalId);

    // Anyone can confirm they reproduced the build
    function confirmBuild(uint256 proposalId) external;

    // Query: is this PCR0 approved?
    function isApproved(bytes calldata pcr0) external view returns (bool);

    // Query: get full attestation record
    function getAttestation(bytes calldata pcr0) external view returns (
        string memory sourceRepo,
        string memory commitHash,
        uint256 approvedAt,
        uint256 confirmations
    );
}
```

- Proposals submitted by anyone, approved by `TrezaGovernor`
- Independent builders can call `confirmBuild()` to record on-chain that they reproduced the PCR mapping
- Other contracts (escrow, treasury, compliance) call `isApproved(pcr0)` before trusting enclave outputs

### Phase 2: Optimistic Approval (Scale)

Add the challenge/stake mechanism:
- `proposeCode()` requires a stake deposit
- Challenge period (configurable, default 7 days)
- `challengeProposal()` with counter-stake
- Dispute resolution via `TrezaGovernor`
- Auto-approval after unchallenged period

### Phase 3: Formal Verification (Long-term)

- ZK proof verification for specific code properties
- Automated approval for code that proves safety invariants
- Human governance only for novel or complex changes

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
