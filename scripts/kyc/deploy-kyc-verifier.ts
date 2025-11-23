import { ethers } from "hardhat";
import * as fs from "fs";
import * as path from "path";

/**
 * Deploy KYCVerifier contract
 * 
 * Usage:
 *   npx hardhat run scripts/kyc/deploy-kyc-verifier.ts --network sepolia
 *   npx hardhat run scripts/kyc/deploy-kyc-verifier.ts --network mainnet
 */
async function main() {
  console.log("🚀 Deploying KYCVerifier contract...\n");

  // Get deployer account
  const [deployer] = await ethers.getSigners();
  console.log("📝 Deploying with account:", deployer.address);
  
  const balance = await ethers.provider.getBalance(deployer.address);
  console.log("💰 Account balance:", ethers.formatEther(balance), "ETH\n");

  // Deploy KYCVerifier
  console.log("📦 Deploying KYCVerifier...");
  const KYCVerifier = await ethers.getContractFactory("KYCVerifier");
  const verifier = await KYCVerifier.deploy();
  
  await verifier.waitForDeployment();
  const verifierAddress = await verifier.getAddress();
  
  console.log("✅ KYCVerifier deployed to:", verifierAddress);
  console.log("🔗 Network:", await ethers.provider.getNetwork().then(n => n.name));
  console.log();

  // Get contract version
  const version = await verifier.version();
  console.log("📌 Contract version:", version);

  // Get default settings
  const validityPeriod = await verifier.proofValidityPeriod();
  const requireVerifierRole = await verifier.requireVerifierRole();
  
  console.log("⚙️  Default Settings:");
  console.log("   - Validity Period:", validityPeriod.toString(), "seconds (", Number(validityPeriod) / 86400, "days)");
  console.log("   - Require Verifier Role:", requireVerifierRole);
  console.log();

  // Check deployer roles
  const DEFAULT_ADMIN_ROLE = await verifier.DEFAULT_ADMIN_ROLE();
  const ADMIN_ROLE = await verifier.ADMIN_ROLE();
  const VERIFIER_ROLE = await verifier.VERIFIER_ROLE();
  
  const hasDefaultAdmin = await verifier.hasRole(DEFAULT_ADMIN_ROLE, deployer.address);
  const hasAdmin = await verifier.hasRole(ADMIN_ROLE, deployer.address);
  const hasVerifier = await verifier.hasRole(VERIFIER_ROLE, deployer.address);
  
  console.log("👤 Deployer Roles:");
  console.log("   - DEFAULT_ADMIN_ROLE:", hasDefaultAdmin ? "✅" : "❌");
  console.log("   - ADMIN_ROLE:", hasAdmin ? "✅" : "❌");
  console.log("   - VERIFIER_ROLE:", hasVerifier ? "✅" : "❌");
  console.log();

  // Save deployment info
  const deploymentInfo = {
    network: await ethers.provider.getNetwork().then(n => n.name),
    chainId: await ethers.provider.getNetwork().then(n => n.chainId),
    contractAddress: verifierAddress,
    deployer: deployer.address,
    deployedAt: new Date().toISOString(),
    version: version,
    validityPeriod: validityPeriod.toString(),
    txHash: verifier.deploymentTransaction()?.hash,
    blockNumber: await ethers.provider.getBlockNumber(),
  };

  // Save to deployments folder
  const deploymentsDir = path.join(__dirname, "../../deployments");
  if (!fs.existsSync(deploymentsDir)) {
    fs.mkdirSync(deploymentsDir, { recursive: true });
  }

  const deploymentFile = path.join(deploymentsDir, "kyc-verifier.json");
  fs.writeFileSync(deploymentFile, JSON.stringify(deploymentInfo, null, 2));
  
  console.log("💾 Deployment info saved to:", deploymentFile);
  console.log();

  // Save address for SDK integration
  const sdkDir = path.join(__dirname, "../../../treza-sdk/src/contracts");
  if (fs.existsSync(sdkDir)) {
    const addressesFile = path.join(sdkDir, "addresses.json");
    
    let addresses: any = {};
    if (fs.existsSync(addressesFile)) {
      addresses = JSON.parse(fs.readFileSync(addressesFile, "utf8"));
    }
    
    const networkName = await ethers.provider.getNetwork().then(n => n.name);
    addresses[networkName] = {
      ...addresses[networkName],
      KYCVerifier: verifierAddress,
    };
    
    fs.writeFileSync(addressesFile, JSON.stringify(addresses, null, 2));
    console.log("📦 SDK addresses updated at:", addressesFile);
  } else {
    console.log("⚠️  SDK directory not found, skipping SDK address update");
  }
  console.log();

  // Verification instructions
  console.log("🔍 To verify contract on Etherscan:");
  console.log(`npx hardhat verify --network ${await ethers.provider.getNetwork().then(n => n.name)} ${verifierAddress}`);
  console.log();

  // Usage examples
  console.log("📚 Next Steps:");
  console.log("1. Verify contract on Etherscan (see command above)");
  console.log("2. Grant VERIFIER_ROLE to trusted addresses:");
  console.log(`   await verifier.grantRole(VERIFIER_ROLE, "0x...")`);
  console.log("3. Test proof submission:");
  console.log(`   await verifier.submitProof(commitment, proof, publicInputs)`);
  console.log("4. Update treza-app API with contract address");
  console.log("5. Update treza-sdk with new address");
  console.log();
  
  console.log("✅ Deployment complete!");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("❌ Deployment failed:");
    console.error(error);
    process.exit(1);
  });

