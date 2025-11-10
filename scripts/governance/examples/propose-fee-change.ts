import { ethers } from "hardhat";

/**
 * Example: Propose a fee change through timelock governance
 * 
 * This script demonstrates how to:
 * 1. Encode a function call for governance
 * 2. Schedule a proposal in the timelock
 * 3. Wait for the delay period
 * 4. Execute the approved proposal
 */

async function main() {
    console.log("🏛️ Governance Example: Propose Fee Change\n");

    // =========================================================================
    // CONFIGURATION - UPDATE THESE ADDRESSES
    // =========================================================================

    const TREZA_TOKEN_ADDRESS = "0xYourTrezaTokenAddress"; // UPDATE: Your deployed Treza token
    const TIMELOCK_ADDRESS = "0xYourTimelockAddress";     // UPDATE: Your deployed timelock

    const NEW_FEE_PERCENTAGE = 3; // Propose changing fee to 3%

    // =========================================================================
    // SETUP
    // =========================================================================

    const [proposer] = await ethers.getSigners();
    console.log("📋 Proposer:", proposer.address);
    console.log("🎯 Target:", TREZA_TOKEN_ADDRESS);
    console.log("⚙️ New Fee:", NEW_FEE_PERCENTAGE + "%");
    console.log("");

    // Connect to contracts
    const trezaToken = await ethers.getContractAt("TrezaToken", TREZA_TOKEN_ADDRESS);
    const timelock = await ethers.getContractAt("TrezaTimelock", TIMELOCK_ADDRESS);

    // =========================================================================
    // STEP 1: PREPARE PROPOSAL
    // =========================================================================

    console.log("📝 Step 1: Preparing proposal...");

    // Encode the function call
    const target = TREZA_TOKEN_ADDRESS;
    const value = 0; // No ETH being sent
    const data = trezaToken.interface.encodeFunctionData("setFeePercentage", [NEW_FEE_PERCENTAGE]);
    const predecessor = ethers.ZeroHash; // No dependency on other operations
    const salt = ethers.keccak256(ethers.toUtf8Bytes(`fee-change-${NEW_FEE_PERCENTAGE}-${Date.now()}`));

    // Get the minimum delay
    const delay = await timelock.getMinDelay();

    console.log("   Target:", target);
    console.log("   Value:", value);
    console.log("   Data:", data);
    console.log("   Salt:", salt);
    console.log("   Delay:", delay.toString(), "seconds");
    console.log("");

    // =========================================================================
    // STEP 2: SCHEDULE PROPOSAL
    // =========================================================================

    console.log("⏰ Step 2: Scheduling proposal...");

    try {
        const scheduleTx = await timelock.schedule(target, value, data, predecessor, salt, delay);
        const receipt = await scheduleTx.wait();
        
        console.log("✅ Proposal scheduled successfully!");
        console.log("   Transaction:", receipt?.hash);
        
        // Calculate execution time
        const currentTime = Math.floor(Date.now() / 1000);
        const executionTime = currentTime + Number(delay);
        const executionDate = new Date(executionTime * 1000);
        
        console.log("   Can execute after:", executionDate.toLocaleString());
        console.log("");
    } catch (error) {
        console.error("❌ Failed to schedule proposal:", error);
        return;
    }

    // =========================================================================
    // STEP 3: CHECK PROPOSAL STATUS
    // =========================================================================

    console.log("🔍 Step 3: Checking proposal status...");

    // Generate operation ID
    const operationId = await timelock.hashOperation(target, value, data, predecessor, salt);
    console.log("   Operation ID:", operationId);

    try {
        const isPending = await timelock.isOperationPending(operationId);
        const isReady = await timelock.isOperationReady(operationId);
        const timestamp = await timelock.getTimestamp(operationId);

        console.log("   Is Pending:", isPending);
        console.log("   Is Ready:", isReady);
        console.log("   Execution Timestamp:", timestamp.toString());
        console.log("");
    } catch (error) {
        console.log("⚠️ Could not check status:", error);
        console.log("");
    }

    // =========================================================================
    // STEP 4: EXECUTION INSTRUCTIONS
    // =========================================================================

    console.log("⚡ Step 4: Execution Instructions");
    console.log("=" .repeat(60));
    console.log("After the delay period expires, anyone can execute this proposal:");
    console.log("");
    console.log("```typescript");
    console.log("// Execute the proposal");
    console.log(`await timelock.execute(`);
    console.log(`    "${target}",`);
    console.log(`    ${value},`);
    console.log(`    "${data}",`);
    console.log(`    "${predecessor}",`);
    console.log(`    "${salt}"`);
    console.log(`);`);
    console.log("```");
    console.log("");

    console.log("Or run the execution script:");
    console.log(`npx hardhat run scripts/governance/examples/execute-proposal.ts --network your-network`);
    console.log("");

    // =========================================================================
    // STEP 5: SIMULATE EXECUTION (OPTIONAL)
    // =========================================================================

    console.log("🧪 Step 5: Simulate execution (for testing)...");
    console.log("⚠️ This will only work if the delay has passed!");
    console.log("");

    const shouldSimulate = false; // Set to true to attempt execution

    if (shouldSimulate) {
        try {
            // Check if ready
            const isReady = await timelock.isOperationReady(operationId);
            
            if (isReady) {
                console.log("✅ Proposal is ready for execution");
                
                // Get current fee before execution
                const currentFee = await trezaToken.getCurrentFee();
                console.log("   Current fee:", currentFee.toString() + "%");
                
                // Execute the proposal
                const executeTx = await timelock.execute(target, value, data, predecessor, salt);
                await executeTx.wait();
                
                // Get new fee after execution
                const newFee = await trezaToken.getCurrentFee();
                console.log("   New fee:", newFee.toString() + "%");
                
                console.log("🎉 Proposal executed successfully!");
            } else {
                console.log("⏳ Proposal is not ready yet - delay period has not passed");
            }
        } catch (error) {
            console.log("❌ Execution failed:", error);
        }
    }

    console.log("");
    console.log("🎯 Summary:");
    console.log("=" .repeat(60));
    console.log("✅ Proposal to change fee to " + NEW_FEE_PERCENTAGE + "% has been scheduled");
    console.log("⏰ Must wait " + delay + " seconds (" + (Number(delay) / 3600) + " hours) before execution");
    console.log("⚡ Anyone can execute the proposal after the delay");
    console.log("🏛️ This demonstrates decentralized governance in action!");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error("❌ Script failed:", error);
        process.exit(1);
    });
