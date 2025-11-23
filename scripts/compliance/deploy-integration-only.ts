import hre from "hardhat";

const { ethers } = hre;

async function main() {
    console.log("🚀 Deploying TrezaComplianceIntegration...");

    const [deployer] = await ethers.getSigners();
    console.log("👤 Deployer:", deployer.address);
    
    const balance = await ethers.provider.getBalance(deployer.address);
    console.log("💰 Balance:", ethers.formatEther(balance), "ETH");

    // Use the latest deployed KYCVerifier address (update with your deployed address)
    const kycVerifierAddress = "0x0000000000000000000000000000000000000000"; // Update with actual KYCVerifier address
    
    // Deploy simple mock TREZA token for testing
    console.log("📋 Deploying Mock TREZA Token...");
    const MockTrezaFactory = await ethers.getContractFactory("MockTreza");
    
    const mockTreza = await MockTrezaFactory.deploy({
        gasLimit: 2000000,
        gasPrice: ethers.parseUnits("5", "gwei")
    });

    await mockTreza.waitForDeployment();
    const trezaTokenAddress = await mockTreza.getAddress();
    console.log("✅ Mock TREZA Token deployed to:", trezaTokenAddress);

    // Now deploy TrezaComplianceIntegration
    console.log("📋 Deploying TrezaComplianceIntegration...");
    const TrezaComplianceIntegrationFactory = await ethers.getContractFactory("TrezaComplianceIntegration");
    
    const complianceIntegration = await TrezaComplianceIntegrationFactory.deploy(
        kycVerifierAddress,
        trezaTokenAddress,
        {
            gasLimit: 3000000,
            gasPrice: ethers.parseUnits("5", "gwei")
        }
    );

    await complianceIntegration.waitForDeployment();
    const integrationAddress = await complianceIntegration.getAddress();
    
    console.log("✅ TrezaComplianceIntegration deployed to:", integrationAddress);

    console.log("\n📄 Deployment Summary:");
    console.log("=" .repeat(60));
    console.log("KYCVerifier:", kycVerifierAddress);
    console.log("TREZA Token:", trezaTokenAddress);
    console.log("TrezaComplianceIntegration:", integrationAddress);
    console.log("=" .repeat(60));
    
    console.log("\n🔧 Environment Variables for SDK:");
    console.log(`REACT_APP_KYC_VERIFIER_ADDRESS=${kycVerifierAddress}`);
    console.log(`REACT_APP_COMPLIANCE_INTEGRATION_ADDRESS=${integrationAddress}`);
    console.log(`REACT_APP_TREZA_TOKEN_ADDRESS=${trezaTokenAddress}`);

    console.log("\n🔍 Etherscan Links:");
    console.log(`KYCVerifier: https://sepolia.etherscan.io/address/${kycVerifierAddress}`);
    console.log(`TREZA Token: https://sepolia.etherscan.io/address/${trezaTokenAddress}`);
    console.log(`TrezaComplianceIntegration: https://sepolia.etherscan.io/address/${integrationAddress}`);

    console.log("\n🎉 Deployment completed successfully!");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error("\n❌ Deployment failed:");
        console.error(error);
        process.exit(1);
    });
