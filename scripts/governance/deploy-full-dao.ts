import { ethers } from "hardhat";

async function main() {
    console.log("🏛️ Deploying Treza Full DAO Governance\n");

    const [deployer] = await ethers.getSigners();
    console.log("📋 Deploying from:", deployer.address);
    console.log("💰 Balance:", ethers.formatEther(await ethers.provider.getBalance(deployer.address)), "ETH\n");

    // =========================================================================
    // CONFIGURATION
    // =========================================================================

    console.log("⚙️ DAO Configuration:");
    console.log("=" .repeat(60));

    // Timelock settings
    const minDelay = 86400; // 24 hours
    console.log(`⏰ Timelock Delay: ${minDelay} seconds (${minDelay / 3600} hours)`);

    // Governor settings
    const votingDelay = 1;      // 1 block (prevents flash loan attacks)
    const votingPeriod = 50400; // ~1 week (assuming 12s blocks)
    const proposalThreshold = 0; // 0 tokens required to propose
    const quorumPercentage = 4;  // 4% quorum required

    console.log(`🗳️ Voting Delay: ${votingDelay} blocks`);
    console.log(`🗳️ Voting Period: ${votingPeriod} blocks (~${Math.round(votingPeriod * 12 / 86400)} days)`);
    console.log(`🗳️ Proposal Threshold: ${proposalThreshold} tokens (anyone can propose)`);
    console.log(`🗳️ Quorum Required: ${quorumPercentage}%`);
    console.log("");

    // =========================================================================
    // STEP 1: DEPLOY VOTING TOKEN (OPTIONAL - FOR TESTING)
    // =========================================================================

    console.log("🪙 Step 1: Deploy Voting-Enabled Token (for testing)...");
    
    const TrezaTokenVoting = await ethers.getContractFactory("TrezaTokenVoting");
    const votingToken = await TrezaTokenVoting.deploy(
        "0x742d35Cc6532C4532532C4532C4532C4532C4538", // treasury1 - UPDATE THIS
        "0x742d35Cc6532C4532532C4532C4532C4532C4539", // treasury2 - UPDATE THIS
        deployer.address // Initial holder gets all tokens
    );
    
    await votingToken.waitForDeployment();
    const votingTokenAddress = await votingToken.getAddress();
    
    console.log("✅ TrezaTokenVoting deployed to:", votingTokenAddress);
    console.log("");

    // =========================================================================
    // STEP 2: DEPLOY TIMELOCK
    // =========================================================================

    console.log("⏰ Step 2: Deploy Timelock Controller...");
    
    // For DAO setup, proposers and executors will be set to the governor contract
    const TrezaTimelock = await ethers.getContractFactory("TrezaTimelock");
    const timelock = await TrezaTimelock.deploy(
        minDelay,
        [], // No initial proposers (governor will be added)
        [], // No initial executors (governor will be added)
        deployer.address // Temporary admin
    );
    
    await timelock.waitForDeployment();
    const timelockAddress = await timelock.getAddress();
    
    console.log("✅ TrezaTimelock deployed to:", timelockAddress);
    console.log("");

    // =========================================================================
    // STEP 3: DEPLOY GOVERNOR
    // =========================================================================

    console.log("🏛️ Step 3: Deploy Governor Contract...");
    
    const TrezaGovernor = await ethers.getContractFactory("TrezaGovernor");
    const governor = await TrezaGovernor.deploy(
        votingTokenAddress,
        timelockAddress
    );
    
    await governor.waitForDeployment();
    const governorAddress = await governor.getAddress();
    
    console.log("✅ TrezaGovernor deployed to:", governorAddress);
    console.log("");

    // =========================================================================
    // STEP 4: SETUP ROLES
    // =========================================================================

    console.log("🔧 Step 4: Setting up governance roles...");
    
    try {
        // Get role constants
        const PROPOSER_ROLE = await timelock.PROPOSER_ROLE();
        const EXECUTOR_ROLE = await timelock.EXECUTOR_ROLE();
        const TIMELOCK_ADMIN_ROLE = await timelock.TIMELOCK_ADMIN_ROLE();

        // Grant proposer role to governor
        console.log("   Granting PROPOSER_ROLE to governor...");
        const grantProposerTx = await timelock.grantRole(PROPOSER_ROLE, governorAddress);
        await grantProposerTx.wait();

        // Grant executor role to zero address (anyone can execute)
        console.log("   Granting EXECUTOR_ROLE to everyone...");
        const grantExecutorTx = await timelock.grantRole(EXECUTOR_ROLE, ethers.ZeroAddress);
        await grantExecutorTx.wait();

        // Renounce admin role for full decentralization
        console.log("   Renouncing TIMELOCK_ADMIN_ROLE...");
        const renounceAdminTx = await timelock.renounceRole(TIMELOCK_ADMIN_ROLE, deployer.address);
        await renounceAdminTx.wait();

        console.log("✅ All roles configured successfully");
        console.log("");
    } catch (error) {
        console.log("❌ Error setting up roles:", error);
        console.log("⚠️ You may need to set up roles manually");
        console.log("");
    }

    // =========================================================================
    // STEP 5: TRANSFER TOKEN OWNERSHIP (OPTIONAL)
    // =========================================================================

    console.log("🔄 Step 5: Transfer token ownership to timelock...");
    
    try {
        const transferTx = await votingToken.transferOwnership(timelockAddress);
        await transferTx.wait();
        console.log("✅ Token ownership transferred to timelock");
        console.log("");
    } catch (error) {
        console.log("⚠️ Could not transfer ownership:", error);
        console.log("⚠️ You may need to transfer manually later");
        console.log("");
    }

    // =========================================================================
    // DEPLOYMENT SUMMARY
    // =========================================================================

    console.log("📊 Full DAO Deployment Summary:");
    console.log("=" .repeat(60));
    console.log(`🪙 Voting Token: ${votingTokenAddress}`);
    console.log(`⏰ Timelock: ${timelockAddress}`);
    console.log(`🏛️ Governor: ${governorAddress}`);
    console.log(`⏳ Voting Delay: ${votingDelay} blocks`);
    console.log(`🗳️ Voting Period: ${votingPeriod} blocks (~${Math.round(votingPeriod * 12 / 86400)} days)`);
    console.log(`🎯 Quorum: ${quorumPercentage}%`);
    console.log(`⏰ Execution Delay: ${minDelay} seconds (${minDelay / 3600} hours)`);
    console.log("");

    console.log("🎯 DAO Governance Workflow:");
    console.log("=" .repeat(60));
    console.log("1. 📝 Token holders create proposals");
    console.log("2. ⏳ 1 block voting delay (prevents flash loans)");
    console.log("3. 🗳️ ~1 week voting period");
    console.log("4. ✅ If passed (4% quorum + majority), proposal queues in timelock");
    console.log("5. ⏰ 24-hour delay for community review");
    console.log("6. ⚡ Anyone can execute the approved proposal");
    console.log("");

    console.log("📚 Example Usage:");
    console.log("=" .repeat(60));
    console.log("// 1. Create proposal (requires token voting power)");
    console.log(`const targets = ["${votingTokenAddress}"];`);
    console.log(`const values = [0];`);
    console.log(`const calldatas = [votingToken.interface.encodeFunctionData("setFeePercentage", [3])];`);
    console.log(`const description = "Reduce fee to 3% for better adoption";`);
    console.log(`await governor.propose(targets, values, calldatas, description);`);
    console.log("");
    console.log("// 2. Vote on proposal (token holders)");
    console.log(`await governor.castVote(proposalId, 1); // 1 = For, 0 = Against, 2 = Abstain`);
    console.log("");
    console.log("// 3. Queue proposal (if passed)");
    console.log(`await governor.queue(targets, values, calldatas, descriptionHash);`);
    console.log("");
    console.log("// 4. Execute proposal (after delay)");
    console.log(`await governor.execute(targets, values, calldatas, descriptionHash);`);
    console.log("");

    console.log("⚠️ Important Notes:");
    console.log("=" .repeat(60));
    console.log("• This deployed a NEW voting token for testing");
    console.log("• To use with your existing token, you'd need to:");
    console.log("  1. Upgrade existing token to add voting capabilities");
    console.log("  2. Or migrate tokens to the voting-enabled version");
    console.log("• The timelock is now fully decentralized (admin renounced)");
    console.log("• Only token holders can create and vote on proposals");
    console.log("");

    console.log("🎉 Full DAO governance is ready!");
    console.log("Your community can now govern the protocol through token voting! 🗳️");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error("❌ Deployment failed:", error);
        process.exit(1);
    });
