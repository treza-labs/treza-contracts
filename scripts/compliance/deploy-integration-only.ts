import hre from "hardhat";

const { ethers } = hre;

async function main() {
    console.log("🚀 Deploying TrezaComplianceIntegration...");

    const [deployer] = await ethers.getSigners();
    console.log("👤 Deployer:", deployer.address);
    
    const balance = await ethers.provider.getBalance(deployer.address);
    console.log("💰 Balance:", ethers.formatEther(balance), "ETH");

    // Use the latest deployed ZKPassportVerifier address
    const zkPassportVerifierAddress = "0x8c0C6e0Eaf6bc693745A1A3a722e2c9028BBe874";
    
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
        zkPassportVerifierAddress,
        trezaTokenAddress,
        {
            gasLimit: 3000000,
            gasPrice: ethers.parseUnits("5", "gwei")
        }
    );

    await complianceIntegration.waitForDeployment();
    const integrationAddress = await complianceIntegration.getAddress();
    
    console.log("✅ TrezaComplianceIntegration deployed to:", integrationAddress);
    
    // Add integration as authorized verifier
    console.log("🔐 Adding integration as authorized verifier...");
    const zkPassportVerifier = await ethers.getContractAt("ZKPassportVerifier", zkPassportVerifierAddress);
    const addVerifierTx = await zkPassportVerifier.addAuthorizedVerifier(integrationAddress);
    await addVerifierTx.wait();
    console.log("✅ Authorized verifier added");

    console.log("\n📄 Deployment Summary:");
    console.log("=" .repeat(60));
    console.log("ZKPassportVerifier:", zkPassportVerifierAddress);
    console.log("TREZA Token:", trezaTokenAddress);
    console.log("TrezaComplianceIntegration:", integrationAddress);
    console.log("=" .repeat(60));
    
    console.log("\n🔧 Environment Variables for SDK:");
    console.log(`REACT_APP_COMPLIANCE_VERIFIER_ADDRESS=${zkPassportVerifierAddress}`);
    console.log(`REACT_APP_COMPLIANCE_INTEGRATION_ADDRESS=${integrationAddress}`);
    console.log(`REACT_APP_TREZA_TOKEN_ADDRESS=${trezaTokenAddress}`);

    console.log("\n🔍 Etherscan Links:");
    console.log(`ZKPassportVerifier: https://sepolia.etherscan.io/address/${zkPassportVerifierAddress}`);
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
