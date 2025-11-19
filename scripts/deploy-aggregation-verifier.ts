import { ethers } from "hardhat";

/**
 * Deploy ZKVerifyAggregationVerifier contract
 * 
 * This contract enables trustless proof verification using zkVerify's
 * on-chain aggregation contract.
 * 
 * Prerequisites:
 * 1. zkVerify aggregation contract deployed on target chain
 * 2. Verification key hash from zkVerify
 * 
 * Usage:
 *   npx hardhat run scripts/deploy-aggregation-verifier.ts --network sepolia
 */
async function main() {
    console.log("🚀 Deploying ZKVerifyAggregationVerifier...\n");

    // Configuration
    // TODO: Update these values for your deployment
    const ZKVERIFY_CONTRACT_ADDRESS = process.env.ZKVERIFY_CONTRACT_ADDRESS || "0x...";
    const VERIFICATION_KEY_HASH = process.env.VERIFICATION_KEY_HASH || "0x...";

    if (ZKVERIFY_CONTRACT_ADDRESS === "0x..." || VERIFICATION_KEY_HASH === "0x...") {
        console.error("❌ Error: Please set ZKVERIFY_CONTRACT_ADDRESS and VERIFICATION_KEY_HASH");
        console.log("\nYou can set them in .env:");
        console.log("  ZKVERIFY_CONTRACT_ADDRESS=0x...");
        console.log("  VERIFICATION_KEY_HASH=0x...");
        console.log("\nOr pass them as environment variables:");
        console.log("  ZKVERIFY_CONTRACT_ADDRESS=0x... VERIFICATION_KEY_HASH=0x... npx hardhat run ...");
        process.exit(1);
    }

    console.log("Configuration:");
    console.log(`  zkVerify Contract: ${ZKVERIFY_CONTRACT_ADDRESS}`);
    console.log(`  Verification Key: ${VERIFICATION_KEY_HASH}\n`);

    // Get deployer
    const [deployer] = await ethers.getSigners();
    console.log(`Deploying with account: ${deployer.address}`);
    
    const balance = await ethers.provider.getBalance(deployer.address);
    console.log(`Account balance: ${ethers.formatEther(balance)} ETH\n`);

    // Deploy contract
    console.log("📝 Deploying ZKVerifyAggregationVerifier...");
    const ZKVerifyAggregationVerifier = await ethers.getContractFactory("ZKVerifyAggregationVerifier");
    const verifier = await ZKVerifyAggregationVerifier.deploy(
        ZKVERIFY_CONTRACT_ADDRESS,
        VERIFICATION_KEY_HASH
    );

    await verifier.waitForDeployment();
    const verifierAddress = await verifier.getAddress();

    console.log("✅ ZKVerifyAggregationVerifier deployed!");
    console.log(`   Address: ${verifierAddress}\n`);

    // Verify deployment
    console.log("🔍 Verifying deployment...");
    const zkVerifyContract = await verifier.getFunction("zkVerifyContract")();
    const vkey = await verifier.getFunction("vkey")();
    const provingSystemId = await verifier.getFunction("PROVING_SYSTEM_ID")();

    console.log(`   zkVerify Contract: ${zkVerifyContract}`);
    console.log(`   Verification Key: ${vkey}`);
    console.log(`   Proving System: ${provingSystemId}\n`);

    // Print next steps
    console.log("📋 Next Steps:\n");
    console.log("1. Update your .env file:");
    console.log(`   ZKVERIFY_AGGREGATION_VERIFIER_ADDRESS=${verifierAddress}\n`);
    
    console.log("2. Verify contract on block explorer:");
    console.log(`   npx hardhat verify --network sepolia ${verifierAddress} ${ZKVERIFY_CONTRACT_ADDRESS} ${VERIFICATION_KEY_HASH}\n`);
    
    console.log("3. Test verification:");
    console.log(`   npx hardhat run scripts/test-aggregation-verification.ts --network sepolia\n`);
    
    console.log("4. Update your SDK configuration:");
    console.log(`   const verifierAddress = "${verifierAddress}";`);

    // Save deployment info
    const deploymentInfo = {
        network: (await ethers.provider.getNetwork()).name,
        chainId: (await ethers.provider.getNetwork()).chainId,
        deployer: deployer.address,
        verifierAddress: verifierAddress,
        zkVerifyContract: ZKVERIFY_CONTRACT_ADDRESS,
        verificationKeyHash: VERIFICATION_KEY_HASH,
        timestamp: new Date().toISOString(),
        blockNumber: await ethers.provider.getBlockNumber()
    };

    console.log("\n📄 Deployment Info:");
    console.log(JSON.stringify(deploymentInfo, null, 2));
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

