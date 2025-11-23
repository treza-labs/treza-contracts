import hre from "hardhat";
import * as fs from "fs";
import * as path from "path";

const { ethers } = hre;

/**
 * Deploy KYCVerifier to testnet and save deployment info
 */
async function main() {
    console.log("🚀 Deploying KYCVerifier to testnet...\n");

    // Get network info
    const network = await ethers.provider.getNetwork();
    const networkName = network.name === "unknown" ? "localhost" : network.name;
    
    console.log(`📡 Network: ${networkName} (Chain ID: ${network.chainId})`);

    // Get deployer account
    const [deployer] = await ethers.getSigners();
    console.log(`👤 Deployer: ${deployer.address}`);
    
    const balance = await ethers.provider.getBalance(deployer.address);
    console.log(`💰 Balance: ${ethers.formatEther(balance)} ETH\n`);

    if (balance === 0n) {
        console.error("❌ Error: Deployer has no ETH!");
        console.log("\nPlease fund your deployer address:");
        console.log(`   Address: ${deployer.address}`);
        console.log(`   Network: ${networkName}`);
        if (networkName === "sepolia") {
            console.log("\n   Get Sepolia ETH from:");
            console.log("   - https://sepoliafaucet.com");
            console.log("   - https://www.alchemy.com/faucets/ethereum-sepolia");
        }
        process.exit(1);
    }

    try {
        // Deploy KYCVerifier
        console.log("📋 Deploying KYCVerifier contract...");
        const KYCVerifierFactory = await ethers.getContractFactory("KYCVerifier");
        
        const kycVerifier = await KYCVerifierFactory.deploy({
            gasLimit: 3000000,
        });

        console.log(`⏳ Waiting for deployment transaction...`);
        await kycVerifier.waitForDeployment();
        
        const verifierAddress = await kycVerifier.getAddress();
        console.log(`✅ KYCVerifier deployed to: ${verifierAddress}`);

        // Wait for confirmations on testnet
        if (networkName !== "localhost") {
            console.log(`⏳ Waiting for 2 block confirmations...`);
            const deployTx = kycVerifier.deploymentTransaction();
            if (deployTx) {
                await deployTx.wait(2);
                console.log(`✅ Confirmed!`);
            }
        }

        // Get deployment info
        const owner = await kycVerifier.DEFAULT_ADMIN_ROLE();
        const validityPeriod = await kycVerifier.proofValidityPeriod();
        const version = await kycVerifier.version();

        console.log("\n📊 Contract Details:");
        console.log(`   Address: ${verifierAddress}`);
        console.log(`   Owner Role: ${owner}`);
        console.log(`   Proof Validity: ${validityPeriod} seconds (${Number(validityPeriod) / 86400} days)`);
        console.log(`   Version: ${version}`);

        // Save deployment info
        const deploymentInfo = {
            network: networkName,
            chainId: network.chainId.toString(),
            deployer: deployer.address,
            timestamp: new Date().toISOString(),
            contract: {
                name: "KYCVerifier",
                address: verifierAddress,
                version: version,
                proofValidityPeriod: validityPeriod.toString(),
            },
            transactionHash: kycVerifier.deploymentTransaction()?.hash,
        };

        // Save to file
        const deploymentsDir = path.join(__dirname, "../../deployments");
        if (!fs.existsSync(deploymentsDir)) {
            fs.mkdirSync(deploymentsDir, { recursive: true });
        }

        const deploymentFile = path.join(deploymentsDir, `kyc-verifier-${networkName}.json`);
        fs.writeFileSync(deploymentFile, JSON.stringify(deploymentInfo, null, 2));
        console.log(`\n💾 Deployment info saved to: ${deploymentFile}`);

        // Generate configuration for treza-app
        console.log("\n🔧 Configuration for treza-app:");
        console.log("=" .repeat(60));
        console.log(`NEXT_PUBLIC_KYC_VERIFIER_ADDRESS=${verifierAddress}`);
        console.log(`NEXT_PUBLIC_NETWORK=${networkName}`);
        console.log(`NEXT_PUBLIC_CHAIN_ID=${network.chainId}`);
        console.log("=" .repeat(60));

        // Generate configuration for iOS app
        console.log("\n📱 Configuration for iOS app:");
        console.log("Update APIClient.swift baseURL to point to your deployed treza-app");

        // Etherscan verification command
        if (networkName === "sepolia") {
            console.log("\n🔍 Verify on Etherscan:");
            console.log(`npx hardhat verify --network sepolia ${verifierAddress}`);
        }

        console.log("\n🎉 Deployment completed successfully!");
        console.log("\n📝 Next Steps:");
        console.log("1. Copy the environment variables to treza-app/.env.local");
        console.log("2. Deploy treza-app to a hosting service (Vercel, Railway, etc.)");
        console.log("3. Update iOS app APIClient baseURL with deployed API URL");
        console.log("4. Run the end-to-end test script");

    } catch (error) {
        console.error("\n❌ Deployment failed:");
        console.error(error);
        process.exit(1);
    }
}

// Execute deployment
if (require.main === module) {
    main()
        .then(() => process.exit(0))
        .catch((error) => {
            console.error(error);
            process.exit(1);
        });
}

export { main as deployKYCVerifierToTestnet };

