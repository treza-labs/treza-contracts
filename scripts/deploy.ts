import { ethers } from "hardhat";

async function main() {
  console.log("🚀 Deploying TrezaToken with Anti-Sniping Protection\n");

  // Get the deployer
  const [deployer] = await ethers.getSigners();
  console.log("📋 Deploying from:", deployer.address);
  console.log("💰 Balance:", ethers.formatEther(await ethers.provider.getBalance(deployer.address)), "ETH\n");

  // =========================================================================
  // DEPLOYMENT CONFIGURATION
  // =========================================================================

  // Constructor parameters - UPDATE THESE ADDRESSES
  const constructorParams = {
    // Allocation wallets (UPDATE WITH YOUR ADDRESSES)
    initialLiquidityWallet: "0x742d35Cc6532C4532532C4532C4532C4532C4532", // 35% - Update this!
    teamWallet: "0x742d35Cc6532C4532532C4532C4532C4532C4533", // 20% - Update this!
    treasuryWallet: "0x742d35Cc6532C4532532C4532C4532C4532C4534", // 20% - Update this!
    partnershipsGrantsWallet: "0x742d35Cc6532C4532532C4532C4532C4532C4535", // 10% - Update this!
    rndWallet: "0x742d35Cc6532C4532532C4532C4532C4532C4536", // 5% - Update this!
    marketingOpsWallet: "0x742d35Cc6532C4532532C4532C4532C4532C4537", // 10% - Update this!
    
    // Treasury fee wallets (UPDATE WITH YOUR ADDRESSES)
    treasury1: "0x742d35Cc6532C4532532C4532C4532C4532C4538", // 50% fees - Update this!
    treasury2: "0x742d35Cc6532C4532532C4532C4532C4532C4539", // 50% fees - Update this!
    
    // Timelock delay (24 hours = 86400 seconds)
    timelockDelay: 86400
  };

  // Timelock proposers and executors (UPDATE WITH YOUR ADDRESSES)
  const proposers = [
    "0x742d35Cc6532C4532532C4532C4532C4532C4540", // Add your governance addresses
  ];
  
  const executors = [
    "0x742d35Cc6532C4532532C4532C4532C4532C4541", // Add your execution addresses
  ];

  console.log("🔧 Anti-Sniping Configuration:");
  console.log("=" .repeat(60));
  console.log("✅ Whitelist-only mode: ENABLED");
  console.log("✅ Trading: DISABLED (owner must enable)");
  console.log("✅ Max transaction: 0.1% of supply");
  console.log("✅ Max wallet: 0.2% of supply");
  console.log("✅ Transfer cooldown: 1 second");
  console.log("✅ Anti-bot protection: 3 blocks after trading enabled");
  console.log("✅ Blacklist capability: Available");
  console.log("");

  // =========================================================================
  // DEPLOY CONTRACT
  // =========================================================================

  console.log("🏗️ Deploying TrezaToken with Anti-Sniping Protection...");

  const TrezaToken = await ethers.getContractFactory("TrezaToken");
  
  const trezaToken = await TrezaToken.deploy(
    constructorParams,
    proposers,
    executors
  );

  await trezaToken.waitForDeployment();
  const contractAddress = await trezaToken.getAddress();

  console.log("✅ TrezaToken with Anti-Sniping deployed to:", contractAddress);
  console.log("");

  // =========================================================================
  // DEPLOYMENT SUMMARY
  // =========================================================================

  console.log("📊 Deployment Summary:");
  console.log("=" .repeat(60));
  console.log(`🏠 Contract Address: ${contractAddress}`);
  console.log(`⛽ Deploy Transaction: ${trezaToken.deploymentTransaction()?.hash}`);
  console.log(`🔍 Etherscan: https://sepolia.etherscan.io/address/${contractAddress}`);
  console.log("");

  console.log("🎯 Initial State:");
  console.log("=" .repeat(60));
  const launchStatus = await trezaToken.getLaunchStatus();
  console.log(`Trading Enabled: ${launchStatus._tradingEnabled}`);
  console.log(`Whitelist Mode: ${launchStatus._whitelistMode}`);
  console.log(`Max Limits Active: ${launchStatus._maxLimitsActive}`);
  console.log(`Max Transaction: ${ethers.formatEther(launchStatus._maxTransaction)} TREZA`);
  console.log(`Max Wallet: ${ethers.formatEther(launchStatus._maxWallet)} TREZA`);
  console.log(`Current Fee: ${await trezaToken.getCurrentFee()}%`);
  console.log("");

  console.log("🔥 LAUNCH SEQUENCE (Execute in order):");
  console.log("=" .repeat(60));
  console.log("1. 📝 Add trusted addresses to whitelist:");
  console.log(`   trezaToken.setWhitelist([...addresses], true)`);
  console.log("");
  console.log("2. 🏊 Add liquidity to DEX (whitelisted addresses only)");
  console.log("");
  console.log("3. 🚀 Enable trading:");
  console.log(`   trezaToken.setTradingEnabled(true)`);
  console.log("");
  console.log("4. ⏰ After initial launch period:");
  console.log(`   trezaToken.setWhitelistMode(false) // Open to public`);
  console.log(`   trezaToken.setMaxLimitsActive(false) // Remove limits`);
  console.log("");

  console.log("🛡️ Anti-Sniping Features ACTIVE:");
  console.log("=" .repeat(60));
  console.log("✅ Whitelist-only trading (until you disable)");
  console.log("✅ Max transaction limits (0.1% of supply)");
  console.log("✅ Max wallet limits (0.2% of supply)");
  console.log("✅ Transfer cooldown (1 second)");
  console.log("✅ 3-block anti-bot protection after trading enabled");
  console.log("✅ Emergency blacklist functionality");
  console.log("✅ All allocation wallets pre-whitelisted");
  console.log("");

  console.log("⚠️  IMPORTANT NEXT STEPS:");
  console.log("=" .repeat(60));
  console.log("1. 🔍 Verify contract on Etherscan");
  console.log("2. 📝 Add your DEX addresses to whitelist");
  console.log("3. 📝 Add your community whitelist");
  console.log("4. 🧪 Test with small amounts first");
  console.log("5. 🚀 Execute launch sequence above");
  console.log("");
  
  console.log("🎉 Your anti-snipe protected TREZA token is ready!");
  console.log("Bots won't be able to snipe your launch! 🛡️");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("❌ Deployment failed:", error);
    process.exit(1);
  });