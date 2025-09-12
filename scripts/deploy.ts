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
    "0x742d35Cc6532C4532532C4532C4532C4532C4541", // Your governor contract
    "0x742d35Cc6532C4532532C4532C4532C4532C4542", // Team multisig
    "0x742d35Cc6532C4532532C4532C4532C4532C4543", // Community multisig    
  ];

  // Additional whitelist addresses to add during deployment
  const additionalWhitelistAddresses = [
    // DEX contracts
    "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D", // Uniswap V2 Router
    "0xE592427A0AEce92De3Edee1F18E0157C05861564", // Uniswap V3 Router
    
    // Important wallets
    "0x742d35Cc6532C4532532C4532C4532C4532C4544", // VIP investor 1
    "0x742d35Cc6532C4532532C4532C4532C4532C4545", // VIP investor 2
    "0x742d35Cc6532C4532532C4532C4532C4532C4546", // Partner wallet
    "0x742d35Cc6532C4532532C4532C4532C4532C4547", // CEX listing wallet
    
    // Your multisigs
    "0x742d35Cc6532C4532532C4532C4532C4532C4548", // Team multisig
    "0x742d35Cc6532C4532532C4532C4532C4532C4549", // Treasury multisig
  ];

  console.log("🔧 Anti-Sniping Configuration:");
  console.log("=" .repeat(60));
  console.log("✅ Whitelist-only mode: ENABLED");
  console.log("✅ Trading: DISABLED (owner must enable)");
  console.log("✅ Time-based fees: 40% → 30% → 20% → 10% → 5%");
  console.log("✅ Dynamic max wallet: 0.10% → 0.15% → 0.20% → 0.30% → unlimited");
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
  // ADD ADDITIONAL WHITELIST ADDRESSES
  // =========================================================================

  if (additionalWhitelistAddresses.length > 0) {
    console.log("📝 Adding additional addresses to whitelist...");
    
    try {
      const tx = await trezaToken.setWhitelist(additionalWhitelistAddresses, true);
      await tx.wait();
      
      console.log(`✅ Successfully whitelisted ${additionalWhitelistAddresses.length} additional addresses`);
      console.log("   Whitelisted addresses:");
      additionalWhitelistAddresses.forEach((addr, i) => {
        console.log(`   ${i + 1}. ${addr}`);
      });
      console.log("");
    } catch (error) {
      console.log("❌ Failed to add whitelist addresses:", error);
      console.log("⚠️  You'll need to add them manually after deployment");
      console.log("");
    }
  }

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
  console.log(`Anti-Bot Blocks Remaining: ${launchStatus._antiBotBlocksRemaining}`);
  
  // Note: These values are dynamic based on anti-sniper phases
  console.log(`Current Max Wallet: Dynamic (0.10% → 0.30% → unlimited)`);
  console.log(`Time-Based Anti-Sniper: Enabled by default`);
  
  console.log(`Current Fee: ${await trezaToken.getCurrentFee()}%`);
  console.log("");

  console.log("🔥 LAUNCH SEQUENCE (Execute in order):");
  console.log("=" .repeat(60));
  console.log("1. ✅ Whitelist addresses added during deployment");
  console.log("   📝 Add more if needed: trezaToken.setWhitelist([...addresses], true)");
  console.log("");
  console.log("2. 🏊 Add liquidity to DEX (whitelisted addresses only)");
  console.log("");
  console.log("3. 🚀 Enable trading:");
  console.log(`   trezaToken.setTradingEnabled(true)`);
  console.log("");
  console.log("4. ⏰ After initial launch period:");
  console.log(`   trezaToken.setWhitelistMode(false) // Open to public`);
  console.log("");

  // Show all whitelisted addresses
  console.log("📋 ALL WHITELISTED ADDRESSES:");
  console.log("=" .repeat(60));
  console.log("✅ Auto-whitelisted (from constructor):");
  console.log(`   • Deployer: ${deployer.address}`);
  console.log(`   • Initial Liquidity: ${constructorParams.initialLiquidityWallet}`);
  console.log(`   • Team: ${constructorParams.teamWallet}`);
  console.log(`   • Treasury: ${constructorParams.treasuryWallet}`);
  console.log(`   • Partnerships: ${constructorParams.partnershipsGrantsWallet}`);
  console.log(`   • R&D: ${constructorParams.rndWallet}`);
  console.log(`   • Marketing: ${constructorParams.marketingOpsWallet}`);
  console.log(`   • Treasury Fee 1: ${constructorParams.treasury1}`);
  console.log(`   • Treasury Fee 2: ${constructorParams.treasury2}`);
  if (additionalWhitelistAddresses.length > 0) {
    console.log("");
    console.log("✅ Additional whitelisted (from deployment script):");
    additionalWhitelistAddresses.forEach((addr, i) => {
      console.log(`   • ${addr}`);
    });
  }
  console.log("");

  console.log("🛡️ Anti-Sniping Features ACTIVE:");
  console.log("=" .repeat(60));
  console.log("✅ Whitelist-only trading (until you disable)");
  console.log("✅ Time-based anti-sniper (40% → 30% → 20% → 10% → 5% fees)");
  console.log("✅ Dynamic max wallet limits (0.10% → 0.15% → 0.20% → 0.30% → unlimited)");
  console.log("✅ Transfer cooldown (1 second)");
  console.log("✅ 3-block anti-bot protection after trading enabled");
  console.log("✅ Emergency blacklist functionality");
  console.log("✅ All allocation wallets pre-whitelisted");
  console.log("");

  console.log("⚠️  IMPORTANT NEXT STEPS:");
  console.log("=" .repeat(60));
  console.log("1. 🔍 Verify contract on Etherscan");
  console.log("2. ✅ Whitelist addresses already added during deployment");
  console.log("3. 📝 Add more whitelist addresses if needed");
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