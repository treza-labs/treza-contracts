import { ethers } from "hardhat";

async function main() {
    console.log("🏛️ Deploying Treza Governance - Timelock Only\n");

    const [deployer] = await ethers.getSigners();
    console.log("📋 Deploying from:", deployer.address);
    console.log("💰 Balance:", ethers.formatEther(await ethers.provider.getBalance(deployer.address)), "ETH\n");

    // =========================================================================
    // TIMELOCK CONFIGURATION
    // =========================================================================

    console.log("⚙️ Timelock Configuration:");
    console.log("=" .repeat(60));

    // Minimum delay (24 hours recommended)
    const minDelay = 86400; // 24 hours in seconds
    console.log(`⏰ Min Delay: ${minDelay} seconds (${minDelay / 3600} hours)`);

    // Proposers - addresses that can propose governance actions
    const proposers = [
        "0x742d35Cc6532C4532532C4532C4532C4532C4540", // UPDATE: Your team multisig
        "0x742d35Cc6532C4532532C4532C4532C4532C4541", // UPDATE: Backup multisig (optional)
    ];
    console.log(`🏛️ Proposers (${proposers.length}):`);
    proposers.forEach((addr, i) => {
        console.log(`   ${i + 1}. ${addr}`);
    });

    // Executors - addresses that can execute approved proposals
    // Using zero address means anyone can execute (recommended for decentralization)
    const executors = [
        "0x0000000000000000000000000000000000000000" // Anyone can execute
    ];
    console.log(`⚡ Executors: Open execution (anyone can execute after delay)`);

    // Admin - will be renounced after setup for full decentralization
    const admin = deployer.address;
    console.log(`👤 Initial Admin: ${admin} (will renounce after setup)`);
    console.log("");

    // =========================================================================
    // DEPLOY TIMELOCK
    // =========================================================================

    console.log("🚀 Deploying TrezaTimelock...");
    
    const TrezaTimelock = await ethers.getContractFactory("TrezaTimelock");
    const timelock = await TrezaTimelock.deploy(minDelay, proposers, executors, admin);
    
    await timelock.waitForDeployment();
    const timelockAddress = await timelock.getAddress();
    
    console.log("✅ TrezaTimelock deployed to:", timelockAddress);
    console.log("");

    // =========================================================================
    // SETUP AND RENOUNCE ADMIN
    // =========================================================================

    console.log("🔧 Setting up roles and renouncing admin...");
    
    try {
        // Get role constants
        const TIMELOCK_ADMIN_ROLE = await timelock.TIMELOCK_ADMIN_ROLE();
        
        // Renounce admin role for full decentralization
        const renounceTx = await timelock.renounceRole(TIMELOCK_ADMIN_ROLE, deployer.address);
        await renounceTx.wait();
        
        console.log("✅ Admin role renounced - timelock is now fully decentralized");
        console.log("");
    } catch (error) {
        console.log("⚠️ Warning: Could not renounce admin role:", error);
        console.log("⚠️ You may need to renounce manually later for full decentralization");
        console.log("");
    }

    // =========================================================================
    // DEPLOYMENT SUMMARY
    // =========================================================================

    console.log("📊 Deployment Summary:");
    console.log("=" .repeat(60));
    console.log(`🏛️ Timelock Address: ${timelockAddress}`);
    console.log(`⏰ Min Delay: ${minDelay} seconds (${minDelay / 3600} hours)`);
    console.log(`🏛️ Proposers: ${proposers.length} addresses`);
    console.log(`⚡ Executors: Open (anyone can execute)`);
    console.log(`🔒 Admin: Renounced (fully decentralized)`);
    console.log("");

    console.log("🎯 Next Steps:");
    console.log("=" .repeat(60));
    console.log("1. 📝 Update your .env or config with the timelock address");
    console.log("2. 🔄 Transfer your Treza token ownership to this timelock:");
    console.log(`   await trezaToken.transferOwnership("${timelockAddress}");`);
    console.log("3. 🏛️ All token management now requires governance proposals");
    console.log("4. ⏳ All changes will have a 24-hour delay for community review");
    console.log("");

    console.log("📚 Usage Examples:");
    console.log("=" .repeat(60));
    console.log("// Propose fee change to 3%");
    console.log(`const target = "YOUR_TREZA_TOKEN_ADDRESS";`);
    console.log(`const data = trezaToken.interface.encodeFunctionData("setFeePercentage", [3]);`);
    console.log(`await timelock.schedule(target, 0, data, ethers.ZeroHash, salt, ${minDelay});`);
    console.log("");
    console.log("// Execute after 24 hours");
    console.log(`await timelock.execute(target, 0, data, ethers.ZeroHash, salt);`);
    console.log("");

    console.log("🎉 Timelock governance is ready!");
    console.log("Your token can now be controlled through decentralized governance! 🏛️");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error("❌ Deployment failed:", error);
        process.exit(1);
    });
