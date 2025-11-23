import hre from "hardhat";

// Access ethers through the Hardhat Runtime Environment
const { ethers } = hre;

/**
 * Deploy TREZA Compliance Contracts
 * 
 * This script deploys:
 * 1. KYCVerifier - Core KYC verification contract
 * 2. TrezaComplianceIntegration - Integration with TREZA token
 */

interface DeploymentConfig {
    // TrezaComplianceIntegration config
    trezaTokenAddress: string;
    
    // Network config
    confirmations: number;
    gasPrice?: string;
}

// Configuration for different networks
const DEPLOYMENT_CONFIG: { [network: string]: DeploymentConfig } = {
    // Sepolia testnet
    sepolia: {
        trezaTokenAddress: "0x0000000000000000000000000000000000000000", // Update with deployed TREZA token
        confirmations: 2,
        gasPrice: "5000000000" // 5 gwei
    },
    
    // Mainnet
    mainnet: {
        trezaTokenAddress: "0x0000000000000000000000000000000000000000", // Update with deployed TREZA token
        confirmations: 5,
        gasPrice: "30000000000" // 30 gwei
    },
    
    // Local development
    localhost: {
        trezaTokenAddress: "0x0000000000000000000000000000000000000000", // Deploy TREZA token first
        confirmations: 1
    }
};

async function main() {
    console.log("🚀 Starting TREZA Compliance Contracts Deployment...\n");

    // Get network and configuration
    const network = await ethers.provider.getNetwork();
    const networkName = network.name === "unknown" ? "localhost" : network.name;
    const config = DEPLOYMENT_CONFIG[networkName];

    if (!config) {
        throw new Error(`No deployment configuration found for network: ${networkName}`);
    }

    console.log(`📡 Network: ${networkName} (Chain ID: ${network.chainId})`);
    console.log(`⚙️  Configuration:`, config);

    // Get deployer account
    const [deployer] = await ethers.getSigners();
    console.log(`👤 Deployer: ${deployer.address}`);
    
    const balance = await ethers.provider.getBalance(deployer.address);
    console.log(`💰 Balance: ${ethers.formatEther(balance)} ETH\n`);

    // Deployment options
    const deployOptions = {
        gasPrice: config.gasPrice ? BigInt(config.gasPrice) : undefined,
        gasLimit: 3000000, // 3M gas limit
    };

    let kycVerifier: any;
    let complianceIntegration: any;

    try {
        // 1. Deploy KYCVerifier
        console.log("📋 Deploying KYCVerifier...");
        const KYCVerifierFactory = await ethers.getContractFactory("KYCVerifier");
        
        kycVerifier = await KYCVerifierFactory.deploy(deployOptions);

        console.log(`⏳ Waiting for deployment transaction...`);
        await kycVerifier.waitForDeployment();
        
        const verifierAddress = await kycVerifier.getAddress();
        console.log(`✅ KYCVerifier deployed to: ${verifierAddress}`);

        // Wait for confirmations
        if (config.confirmations > 1) {
            console.log(`⏳ Waiting for ${config.confirmations} confirmations...`);
            await kycVerifier.deploymentTransaction()?.wait(config.confirmations);
        }

        // 2. Deploy TrezaComplianceIntegration
        console.log("\n📋 Deploying TrezaComplianceIntegration...");
        const TrezaComplianceIntegrationFactory = await ethers.getContractFactory("TrezaComplianceIntegration");
        
        complianceIntegration = await TrezaComplianceIntegrationFactory.deploy(
            verifierAddress,
            config.trezaTokenAddress,
            deployOptions
        );

        console.log(`⏳ Waiting for deployment transaction...`);
        await complianceIntegration.waitForDeployment();
        
        const integrationAddress = await complianceIntegration.getAddress();
        console.log(`✅ TrezaComplianceIntegration deployed to: ${integrationAddress}`);

        // Wait for confirmations
        if (config.confirmations > 1) {
            console.log(`⏳ Waiting for ${config.confirmations} confirmations...`);
            await complianceIntegration.deploymentTransaction()?.wait(config.confirmations);
        }

        // 3. Configure contracts
        console.log("\n⚙️  Configuring contracts...");
        
        // Grant VERIFIER_ROLE to deployer
        console.log("🔐 Granting VERIFIER_ROLE to deployer...");
        const VERIFIER_ROLE = await kycVerifier.VERIFIER_ROLE();
        const grantRoleTx = await kycVerifier.grantRole(VERIFIER_ROLE, deployer.address);
        await grantRoleTx.wait(config.confirmations);
        console.log("✅ VERIFIER_ROLE granted");

        // 4. Verify deployment
        console.log("\n🔍 Verifying deployment...");
        
        // Check KYCVerifier
        const hasAdminRole = await kycVerifier.hasRole(await kycVerifier.DEFAULT_ADMIN_ROLE(), deployer.address);
        const hasVerifierRole = await kycVerifier.hasRole(VERIFIER_ROLE, deployer.address);
        const validityPeriod = await kycVerifier.proofValidityPeriod();
        
        console.log(`📊 KYCVerifier Status:`);
        console.log(`   Has Admin Role: ${hasAdminRole}`);
        console.log(`   Has Verifier Role: ${hasVerifierRole}`);
        console.log(`   Proof Validity Period: ${validityPeriod} seconds`);

        // Check TrezaComplianceIntegration
        const integrationOwner = await complianceIntegration.owner();
        const complianceEnabled = await complianceIntegration.complianceEnabled();
        
        console.log(`📊 TrezaComplianceIntegration Status:`);
        console.log(`   Owner: ${integrationOwner}`);
        console.log(`   Compliance Enabled: ${complianceEnabled}`);
        console.log(`   KYC Verifier: ${await complianceIntegration.zkPassportVerifier()}`);
        console.log(`   TREZA Token: ${await complianceIntegration.trezaToken()}`);

        // 5. Generate deployment summary
        console.log("\n📄 Deployment Summary:");
        console.log("=" .repeat(60));
        console.log(`Network: ${networkName}`);
        console.log(`Deployer: ${deployer.address}`);
        console.log(`KYCVerifier: ${verifierAddress}`);
        console.log(`TrezaComplianceIntegration: ${integrationAddress}`);
        console.log("=" .repeat(60));

        // 6. Generate environment variables
        console.log("\n🔧 Environment Variables for SDK:");
        console.log(`REACT_APP_KYC_VERIFIER_ADDRESS=${verifierAddress}`);
        console.log(`REACT_APP_COMPLIANCE_INTEGRATION_ADDRESS=${integrationAddress}`);
        console.log(`REACT_APP_TREZA_TOKEN_ADDRESS=${config.trezaTokenAddress}`);

        // 7. Generate verification commands (for Etherscan)
        if (networkName !== "localhost") {
            console.log("\n🔍 Etherscan Verification Commands:");
            console.log(`npx hardhat verify --network ${networkName} ${verifierAddress}`);
            console.log(`npx hardhat verify --network ${networkName} ${integrationAddress} "${verifierAddress}" "${config.trezaTokenAddress}"`);
        }

        console.log("\n🎉 Deployment completed successfully!");

    } catch (error) {
        console.error("\n❌ Deployment failed:");
        console.error(error);
        process.exit(1);
    }
}

// Handle script execution
if (require.main === module) {
    main()
        .then(() => process.exit(0))
        .catch((error) => {
            console.error(error);
            process.exit(1);
        });
}

export { main as deployComplianceContracts };
