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

- **Compliance Contracts** (`contracts/compliance/`)
  - Zero-knowledge identity verification using ZKPassport
  - Privacy-preserving KYC/AML compliance
  - Production zkVerify integration with Oracle and Attestation systems
  - Multi-tier verification: Oracle (automated) + Attestation (professional)
  - Hybrid verification routing based on transaction value and risk

- **Governance Contracts** (`contracts/governance/`)
  - Decentralized governance with timelock controls
  - Token-weighted voting with compliance integration
  - Proposal execution and treasury management

### Key Features

**Production zkVerify Integration**
- Zero-knowledge identity verification with ZKPassport
- Oracle system: Fast, automated verification for high-volume transactions
- Attestation system: Professional oversight for high-value transactions
- Hybrid routing: Smart verification based on transaction requirements
- No personal data stored on-chain

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
- [`IZKPassportVerifier`](contracts/compliance/interfaces/IZKPassportVerifier.sol) - Compliance verification
- [`IComplianceIntegration`](contracts/compliance/interfaces/IComplianceIntegration.sol) - Integration layer

#### zkVerify Production Systems
- [`IZKVerifyOracle`](contracts/compliance/interfaces/IZKVerifyOracle.sol) - Oracle system interface
- [`IAttestationSystem`](contracts/compliance/interfaces/IAttestationSystem.sol) - Professional attestation interface

### zkVerify Integration Features

#### Oracle System (`ZKVerifyOracle.sol`)
- **Multi-Oracle Consensus**: Multiple authorized oracles for redundancy
- **Signature Verification**: Cryptographic proof of zkVerify results
- **Time-Based Validity**: Automatic expiration of old verifications
- **Gas Optimized**: Efficient storage and retrieval of verification results

#### Attestation System (`AttestationSystem.sol`)
- **Professional Attesters**: KYC'd institutional and individual attesters
- **Tier-Based Access**: Bronze, Silver, Gold, Platinum attester levels
- **Staking Mechanism**: Economic incentives for honest attestation
- **Slashing Protection**: Penalties for incorrect attestations
- **Metadata Support**: Rich context for attestation decisions

#### Hybrid Verification (`ZKPassportVerifier.sol`)
- **Smart Routing**: Automatic selection between Oracle and Attestation
- **Value-Based Logic**: High-value transactions → Attestation, High-volume → Oracle
- **Fallback Modes**: Graceful degradation when systems are unavailable
- **Admin Controls**: Runtime configuration of verification strategies

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
├── compliance/             # Privacy compliance system
│   ├── interfaces/         # Compliance interfaces
│   │   ├── IZKPassportVerifier.sol
│   │   ├── IZKVerifyOracle.sol
│   │   └── IAttestationSystem.sol
│   ├── ZKPassportVerifier.sol      # Main compliance contract
│   ├── ZKVerifyOracle.sol          # Oracle consensus system
│   ├── AttestationSystem.sol       # Professional attestation system
│   └── TrezaComplianceIntegration.sol
├── governance/             # DAO governance contracts
└── utils/                  # Utility contracts

scripts/
├── compliance/             # zkVerify deployment scripts
│   ├── deploy-compliance-contracts.ts
│   └── deploy-zkverify-systems.ts
└── *.ts                   # Other deployment scripts

test/
├── compliance/             # Compliance system tests
│   ├── ZKPassportVerifier.test.ts
│   └── ZKVerifyOracle.test.ts
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
