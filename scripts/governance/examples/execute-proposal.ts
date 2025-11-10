import { ethers } from "hardhat";

/**
 * Example: Execute a queued governance proposal
 * 
 * This script demonstrates how to execute a proposal that has passed
 * its delay period in the timelock controller.
 */

async function main() {
    console.log("⚡ Governance Example: Execute Proposal\n");

    // =========================================================================
    // CONFIGURATION - UPDATE THESE VALUES
    // =========================================================================

    const TIMELOCK_ADDRESS = "0xYourTimelockAddress";     // UPDATE: Your deployed timelock
    const TREZA_TOKEN_ADDRESS = "0xYourTrezaTokenAddress"; // UPDATE: Your deployed Treza token

    // Proposal details (must match the scheduled proposal exactly)
    const target = TREZA_TOKEN_ADDRESS;
    const value = 0;
    const newFeePercentage = 3; // Must match the originally proposed value
    const predecessor = ethers.ZeroHash;
    const salt = "0x..."; // UPDATE: Use the same salt from the proposal

    // =========================================================================
    // SETUP
    // =========================================================================

    const [executor] = await ethers.getSigners();
    console.log("📋 Executor:", executor.address);
    console.log("🎯 Target:", target);
    console.log("⚙️ New Fee:", newFeePercentage + "%");
    console.log("");

    // Connect to contracts
    const trezaToken = await ethers.getContractAt("TrezaToken", TREZA_TOKEN_ADDRESS);
    const timelock = await ethers.getContractAt("TrezaTimelock", TIMELOCK_ADDRESS);

    // Encode the function call (must match original proposal)
    const data = trezaToken.interface.encodeFunctionData("setFeePercentage", [newFeePercentage]);

    // =========================================================================
    // STEP 1: VERIFY PROPOSAL STATUS
    // =========================================================================

    console.log("🔍 Step 1: Verifying proposal status...");

    const operationId = await timelock.hashOperation(target, value, data, predecessor, salt);
    console.log("   Operation ID:", operationId);

    try {
        const isPending = await timelock.isOperationPending(operationId);
        const isReady = await timelock.isOperationReady(operationId);
        const timestamp = await timelock.getTimestamp(operationId);

        console.log("   Is Pending:", isPending);
        console.log("   Is Ready:", isReady);
        console.log("   Execution Timestamp:", timestamp.toString());

        if (!isPending) {
            console.log("❌ Proposal is not pending - it may not exist or already executed");
            return;
        }

        if (!isReady) {
            const currentTime = Math.floor(Date.now() / 1000);
            const timeRemaining = Number(timestamp) - currentTime;
            console.log(`⏳ Proposal is not ready yet - ${timeRemaining} seconds remaining`);
            console.log(`   Can execute after: ${new Date(Number(timestamp) * 1000).toLocaleString()}`);
            return;
        }

        console.log("✅ Proposal is ready for execution!");
        console.log("");
    } catch (error) {
        console.error("❌ Error checking proposal status:", error);
        return;
    }

    // =========================================================================
    // STEP 2: GET CURRENT STATE
    // =========================================================================

    console.log("📊 Step 2: Current token state...");

    try {
        const currentFee = await trezaToken.getCurrentFee();
        const owner = await trezaToken.owner();

        console.log("   Current Fee:", currentFee.toString() + "%");
        console.log("   Token Owner:", owner);
        console.log("   Expected Owner:", TIMELOCK_ADDRESS);

        if (owner.toLowerCase() !== TIMELOCK_ADDRESS.toLowerCase()) {
            console.log("⚠️ Warning: Token is not owned by timelock!");
            console.log("   You may need to transfer ownership first");
        }
        console.log("");
    } catch (error) {
        console.log("⚠️ Could not get current state:", error);
        console.log("");
    }

    // =========================================================================
    // STEP 3: EXECUTE PROPOSAL
    // =========================================================================

    console.log("⚡ Step 3: Executing proposal...");

    try {
        // Estimate gas for the execution
        const gasEstimate = await timelock.execute.estimateGas(target, value, data, predecessor, salt);
        console.log("   Estimated Gas:", gasEstimate.toString());

        // Execute the proposal
        const executeTx = await timelock.execute(target, value, data, predecessor, salt);
        console.log("   Transaction submitted:", executeTx.hash);

        // Wait for confirmation
        const receipt = await executeTx.wait();
        console.log("✅ Proposal executed successfully!");
        console.log("   Block:", receipt?.blockNumber);
        console.log("   Gas Used:", receipt?.gasUsed.toString());
        console.log("");
    } catch (error) {
        console.error("❌ Execution failed:", error);
        
        // Common error explanations
        if (error.message.includes("TimelockController: operation is not ready")) {
            console.log("💡 This means the delay period has not passed yet");
        } else if (error.message.includes("TimelockController: operation cannot be cancelled")) {
            console.log("💡 This might mean the proposal doesn't exist or was already executed");
        } else if (error.message.includes("Ownable: caller is not the owner")) {
            console.log("💡 This means the token is not owned by the timelock");
        }
        
        return;
    }

    // =========================================================================
    // STEP 4: VERIFY EXECUTION
    // =========================================================================

    console.log("✅ Step 4: Verifying execution...");

    try {
        const newFee = await trezaToken.getCurrentFee();
        console.log("   New Fee:", newFee.toString() + "%");

        if (newFee.toString() === newFeePercentage.toString()) {
            console.log("🎉 Fee change successful!");
        } else {
            console.log("⚠️ Fee may not have changed as expected");
        }

        // Check if operation is still pending (should be false after execution)
        const stillPending = await timelock.isOperationPending(operationId);
        console.log("   Still Pending:", stillPending);
        console.log("");
    } catch (error) {
        console.log("⚠️ Could not verify execution:", error);
        console.log("");
    }

    // =========================================================================
    // SUMMARY
    // =========================================================================

    console.log("🎯 Execution Summary:");
    console.log("=" .repeat(60));
    console.log("✅ Governance proposal executed successfully");
    console.log("🏛️ Token fee changed through decentralized governance");
    console.log("⚡ Anyone was able to execute this approved proposal");
    console.log("🔒 Change required 24-hour delay for community review");
    console.log("");
    console.log("This demonstrates how decentralized governance protects the community");
    console.log("while still allowing necessary changes to be made! 🎉");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error("❌ Script failed:", error);
        process.exit(1);
    });
