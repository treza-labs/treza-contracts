# TREZA Smart Contracts

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Solidity](https://img.shields.io/badge/Solidity-^0.8.19-blue)](https://soliditylang.org/)
[![Hardhat](https://img.shields.io/badge/Built%20with-Hardhat-yellow)](https://hardhat.org/)

Smart contracts powering the TREZA ecosystem. Privacy-preserving infrastructure with zero-knowledge compliance technology.

## Architecture

### Core Contracts

- **Token Contracts** (`contracts/token/`)
  - ERC20 token implementation with advanced features
  - Anti-sniping protection and fair launch mechanisms
  - Dynamic fee structures and treasury management

- **KYC Verification Contracts** (`contracts/kyc/`)
  - Zero-knowledge identity verification using ZKPassport mobile app
  - Privacy-preserving KYC/AML compliance on-chain
  - Role-based access control for proof verification
  - Multi-tier compliance levels: Basic, Enhanced, Institutional
  - Compliance-weighted governance and token transfer controls

- **Governance Contracts** (`contracts/governance/`)
  - Decentralized governance with timelock controls
  - Token-weighted voting with compliance integration
  - Proposal execution and treasury management

### Key Features

**Zero-Knowledge KYC Verification**
- Privacy-preserving identity verification with ZKPassport mobile app
- On-chain KYC proof storage with role-based access control
- Compliance integration with governance and token features
- Time-based proof validity and automatic expiration
- No personal data stored on-chain - only cryptographic proofs

### KYC Verification Architecture

The TREZA compliance system uses two primary contracts working in tandem:

#### 1. KYCVerifier Contract (`contracts/kyc/KYCVerifier.sol`)

The KYCVerifier is the foundational contract that stores and validates zero-knowledge proofs on-chain.

**Core Functionality:**
- **Proof Submission**: Users submit cryptographic proofs (commitment + ZK proof + public claims) via the ZKPassport mobile app
- **Role-Based Verification**: Configurable access control using OpenZeppelin's AccessControl
  - `ADMIN_ROLE`: Manages contract configuration and revokes proofs
  - `VERIFIER_ROLE`: Authorized addresses that can verify submitted proofs
- **Automatic Expiration**: Proofs have configurable validity periods (default: 30 days)
- **Replay Protection**: Prevents duplicate submissions using commitment hashes
- **Zero-Knowledge Privacy**: Only stores cryptographic proofs, never raw identity data

**Key Methods:**
```solidity
submitProof(bytes32 commitment, bytes proof, string[] publicInputs) → returns proofId
verifyProof(bytes32 proofId) → marks proof as verified
hasValidKYC(address user) → checks if user has valid, non-expired proof
```

**What Gets Stored:**
- Commitment hash (Pedersen-SHA256)
- ZK proof bytes
- Public claims (e.g., "isAdult:true", "country:US")
- Timestamps (submission + expiration)
- Verification status

#### 2. TrezaComplianceIntegration Contract (`contracts/kyc/TrezaComplianceIntegration.sol`)

This contract bridges the KYC verification system with TREZA token governance and compliance features.

**Core Functionality:**
- **Compliance Gating**: Enforces KYC requirements for token transfers and governance
- **Weighted Voting**: Multiplies voting power based on verification level
  - Basic verification: 1x voting weight
  - Enhanced verification: 2x voting weight
  - Institutional verification: 3x voting weight
- **Proposal-Specific Requirements**: Different governance proposals can require different verification levels
- **Exemption System**: Allows owner to exempt specific addresses (e.g., DEX pools, bridges)
- **Batch Operations**: Efficiently check compliance for multiple users

**Integration Flow:**
```
User → ZKPassport App → KYCVerifier.submitProof()
                              ↓
                        Proof Stored On-Chain
                              ↓
                TrezaComplianceIntegration.isUserCompliant()
                              ↓
                    Token Transfer/Governance Action
```

**Key Methods:**
```solidity
isUserCompliant(address user) → checks KYC status via KYCVerifier
checkGovernanceEligibility(address user, uint256 proposalId) → returns voting power
canTransfer(address from, address to, uint256 amount) → validates transfer compliance
batchCheckCompliance(address[] users) → efficient multi-user checking
```

**Compliance Levels:**
1. **None**: No KYC submitted or expired
2. **Basic**: Standard identity verification (country, age verification)
3. **Enhanced**: Additional due diligence for higher limits
4. **Institutional**: Full KYC/AML for institutional participants

#### Privacy Guarantees

The system ensures privacy through:
1. **Zero-Knowledge Proofs**: Verify identity claims without revealing underlying data
2. **Local Proof Generation**: All proofs generated on user's device (ZKPassport app)
3. **Selective Disclosure**: Users choose which claims to reveal (age, nationality, etc.)
4. **No Personal Data On-Chain**: Only cryptographic commitments stored
5. **Decentralized Verification**: No centralized identity database

#### Example Use Cases

**Governance Participation:**
```solidity
// Check if user can vote on proposal
(bool canVote, uint256 votingPower, , ) = 
    complianceIntegration.checkGovernanceEligibility(voter, proposalId);

if (canVote) {
    // Cast vote with compliance-weighted power
    governance.castVote(proposalId, votingPower);
}
```

**Compliant Token Transfers:**
```solidity
// Verify both sender and receiver are compliant
(bool allowed, string memory reason) = 
    complianceIntegration.canTransfer(from, to, amount);

require(allowed, reason);
token.transfer(to, amount);
```

**Fair Launch Protection**
- Multi-phase anti-sniping mechanisms
- Time-based fee structures
- Maximum wallet limits during launch

**Decentralized Governance**
- Community-driven decision making
- Timelock-protected critical functions
- Compliance-weighted voting power

## Quick Start

### Prerequisites

- Node.js v16+ 
- npm or yarn
- Git

### Installation

```bash
git clone https://github.com/treza-labs/treza-contracts.git
cd treza-contracts
npm install
```

### Compilation

```bash
npx hardhat compile
```

### Testing

```bash
npx hardhat test
```

### Deployment

#### Basic Deployment
```bash
# Deploy core contracts to testnet
npx hardhat run scripts/deploy.ts --network sepolia

# Verify contracts
npx hardhat run scripts/verify.ts --network sepolia
```

#### zkVerify Production Systems
```bash
# Deploy zkVerify Oracle and Attestation systems
npx hardhat run scripts/compliance/deploy-zkverify-systems.ts --network sepolia

# Deploy compliance contracts only
npx hardhat run scripts/compliance/deploy-compliance-contracts.ts --network sepolia
```

## Documentation

### Contract Interfaces

All contracts expose clean, well-documented interfaces:

#### Core Interfaces
- [`ITreza`](contracts/token/interfaces/ITreza.sol) - Main token interface
- [`IZKPassportVerifier`](contracts/kyc/interfaces/IZKPassportVerifier.sol) - Compliance verification interface

### KYC Verification Features

#### KYC Verifier (`KYCVerifier.sol`)
- **Zero-Knowledge Proofs**: Privacy-preserving identity verification
- **Role-Based Access**: Configurable verifier authorization
- **Time-Based Validity**: Automatic expiration of KYC proofs
- **Gas Optimized**: Efficient storage and retrieval of verification status
- **Flexible Verification**: Support for multiple verification levels

#### Compliance Integration (`TrezaComplianceIntegration.sol`)
- **Token Integration**: Direct integration with TREZA token
- **Governance Controls**: Compliance-gated governance participation
- **Batch Operations**: Efficient multi-user compliance checking
- **Exemption System**: Configurable compliance exemptions
- **Flexible Configuration**: Runtime configuration of compliance rules

### Available Documentation

For comprehensive documentation, see the [`docs/`](docs/) directory:

- [Deployment Guide](docs/DEPLOYMENT_GUIDE.md) - Complete deployment instructions
- [Anti-Snipe Guide](docs/ANTI_SNIPE_GUIDE.md) - MEV protection system details
- [Governance System](docs/GOVERNANCE_CONTRACTS_README.md) - DAO governance documentation
- [Stealth Wallet Proposal](docs/STEALTH_WALLET_PROPOSAL.md) - Privacy-focused wallet system
- [Governance Migration Guide](docs/GOVERNANCE_MIGRATION_GUIDE.md) - Migration instructions
- [Governance Roles](docs/GOVERNANCE_ROLES.md) - Role-based access control

## Development

### Project Structure

```
contracts/
├── token/                  # ERC20 token contracts
│   ├── interfaces/         # Public interfaces
│   └── *.sol              # Implementation contracts
├── kyc/                    # KYC and compliance system
│   ├── interfaces/         # Compliance interfaces
│   │   └── IZKPassportVerifier.sol
│   ├── KYCVerifier.sol               # Main KYC contract
│   └── TrezaComplianceIntegration.sol # Compliance integration
├── governance/             # DAO governance contracts
└── utils/                  # Utility contracts

scripts/
├── compliance/             # Compliance deployment scripts
│   ├── deploy-compliance-contracts.ts
│   └── deploy-integration-only.ts
└── *.ts                   # Other deployment scripts

test/
├── kyc/                    # KYC system tests
│   └── KYCVerifier.test.ts
└── *.test.ts              # Other contract tests
```

### Environment Setup

1. Copy environment template:
```bash
cp .env.example .env
```

2. Configure your environment variables:
```bash
# Network configuration
SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/your-api-key
MAINNET_RPC_URL=https://eth-mainnet.g.alchemy.com/v2/your-api-key

# Deployment keys (use test keys for development)
PRIVATE_KEY=your-private-key

# API keys
ETHERSCAN_API_KEY=your-etherscan-api-key
COINMARKETCAP_API_KEY=your-coinmarketcap-api-key
```

### Testing

Run the full test suite:
```bash
npm test
```

Run specific tests:
```bash
npx hardhat test test/TrezaToken.test.ts
```

Generate coverage report:
```bash
npm run coverage
```

## Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

### Development Workflow

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass
6. Submit a pull request

### Code Standards

- Follow Solidity style guide
- Add comprehensive NatSpec documentation
- Include unit tests for all functions
- Use meaningful variable and function names


### Pre-Deployment
Before deploying to mainnet, complete the [Pre-Deployment Checklist](docs/PRE_DEPLOYMENT_CHECKLIST.md).

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Links

- **Website**: [trezalabs.com](https://trezalabs.com)
- **Documentation**: [docs.trezalabs.com](https://docs.trezalabs.com)
- **SDK**: [@treza/sdk](https://www.npmjs.com/package/@treza/sdk)
- **Twitter**: [@trezalabs](https://twitter.com/trezalabs)

## Disclaimer

This software is provided "as is", without warranty of any kind. Use at your own risk. The contracts have not yet been audited - please exercise caution when using in production environments.
