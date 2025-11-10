import { ethers } from "hardhat";

/**
 * Transfer Treza token ownership to governance
 * 
 * This script transfers ownership of your Treza token from direct ownership
 * to a governance contract (timelock or DAO governor).
 * 
 * ⚠️ WARNING: This is irreversible! Make sure you have tested governance thoroughly.
 */

async function main() {
    console.log("🔄 Transfer Treza Token Ownership to Governance\n");

    // =========================================================================
    // CONFIGURATION - UPDATE THESE ADDRESSES
    // =========================================================================

    const TREZA_TOKEN_ADDRESS = "0xYourTrezaTokenAddress"; // UPDATE: Your deployed Treza token
    const GOVERNANCE_ADDRESS = "0xYourGovernanceAddress";  // UPDATE: Timelock or Governor address

    // Choose governance type for display purposes
    const GOVERNANCE_TYPE = "Timelock"; // "Timelock" or "DAO"

    // =========================================================================
    // SAFETY CHECKS
    // =========================================================================

    const [currentOwner] = await ethers.getSigners();
    console.log("📋 Current Owner:", currentOwner.address);
    console.log("🎯 Token Address:", TREZA_TOKEN_ADDRESS);
    console.log("🏛️ New Owner (" + GOVERNANCE_TYPE + "):", GOVERNANCE_ADDRESS);
    console.log("");

    // Confirmation prompt
    console.log("⚠️ IMPORTANT WARNINGS:");
    console.log("=" .repeat(60));
    console.log("• This transfer is IRREVERSIBLE");
    console.log("• You will lose direct control of the token");
    console.log("• All future changes require governance proposals");
    console.log("• Make sure governance contracts are tested and working");
    console.log("• Ensure you have proposer access to the governance system");
    console.log("");

    // Connect to token contract
    const trezaToken = await ethers.getContractAt("TrezaToken", TREZA_TOKEN_ADDRESS);

    // =========================================================================
    // STEP 1: VERIFY CURRENT STATE
    // =========================================================================

    console.log("🔍 Step 1: Verifying current state...");

    try {
        const currentTokenOwner = await trezaToken.owner();
        const currentFee = await trezaToken.getCurrentFee();
        const tradingEnabled = await trezaToken.tradingEnabled();

        console.log("   Current Token Owner:", currentTokenOwner);
        console.log("   Current Fee:", currentFee.toString() + "%");
        console.log("   Trading Enabled:", tradingEnabled);

        if (currentTokenOwner.toLowerCase() !== currentOwner.address.toLowerCase()) {
            console.log("❌ You are not the current owner of this token!");
            console.log("   Current owner:", currentTokenOwner);
            console.log("   Your address:", currentOwner.address);
            return;
        }

        console.log("✅ Ownership verification passed");
        console.log("");
    } catch (error) {
        console.error("❌ Error verifying current state:", error);
        return;
    }

    // =========================================================================
    // STEP 2: VERIFY GOVERNANCE CONTRACT
    // =========================================================================

    console.log("🔍 Step 2: Verifying governance contract...");

    try {
        // Try to get code at governance address
        const code = await ethers.provider.getCode(GOVERNANCE_ADDRESS);
        
        if (code === "0x") {
            console.log("❌ No contract found at governance address!");
            console.log("   Make sure you've deployed the governance contract first");
            return;
        }

        console.log("✅ Contract found at governance address");

        // Try to identify contract type
        try {
            const timelock = await ethers.getContractAt("TrezaTimelock", GOVERNANCE_ADDRESS);
            const minDelay = await timelock.getMinDelay();
            console.log("   Detected: TimelockController");
            console.log("   Min Delay:", minDelay.toString(), "seconds (" + (Number(minDelay) / 3600) + " hours)");
        } catch {
            try {
                const governor = await ethers.getContractAt("TrezaGovernor", GOVERNANCE_ADDRESS);
                const name = await governor.name();
                console.log("   Detected: Governor Contract");
                console.log("   Name:", name);
            } catch {
                console.log("   Detected: Unknown contract type");
                console.log("   ⚠️ Make sure this is the correct governance contract");
            }
        }

        console.log("");
    } catch (error) {
        console.log("⚠️ Could not fully verify governance contract:", error);
        console.log("   Proceeding anyway...");
        console.log("");
    }

    // =========================================================================
    // STEP 3: FINAL CONFIRMATION
    // =========================================================================

    console.log("⚠️ FINAL CONFIRMATION REQUIRED");
    console.log("=" .repeat(60));
    console.log("You are about to transfer ownership of your Treza token to:");
    console.log("   " + GOVERNANCE_ADDRESS);
    console.log("");
    console.log("After this transfer:");
    console.log("• You will NOT be able to call owner functions directly");
    console.log("• All changes will require governance proposals");
    console.log("• Changes will have time delays (if using timelock)");
    console.log("• This action CANNOT be undone");
    console.log("");

    // In a real script, you might want to add a manual confirmation step
    const CONFIRM_TRANSFER = false; // Set to true when you're ready

    if (!CONFIRM_TRANSFER) {
        console.log("🛑 Transfer cancelled - set CONFIRM_TRANSFER = true to proceed");
        console.log("");
        console.log("Before proceeding, make sure:");
        console.log("• Governance contracts are deployed and tested");
        console.log("• You have proposer access to submit governance proposals");
        console.log("• You understand the governance workflow");
        console.log("• You have tested the governance system on testnet");
        return;
    }

    // =========================================================================
    // STEP 4: TRANSFER OWNERSHIP
    // =========================================================================

    console.log("🔄 Step 4: Transferring ownership...");

    try {
        // Estimate gas
        const gasEstimate = await trezaToken.transferOwnership.estimateGas(GOVERNANCE_ADDRESS);
        console.log("   Estimated Gas:", gasEstimate.toString());

        // Transfer ownership
        const transferTx = await trezaToken.transferOwnership(GOVERNANCE_ADDRESS);
        console.log("   Transaction submitted:", transferTx.hash);

        // Wait for confirmation
        const receipt = await transferTx.wait();
        console.log("✅ Ownership transferred successfully!");
        console.log("   Block:", receipt?.blockNumber);
        console.log("   Gas Used:", receipt?.gasUsed.toString());
        console.log("");
    } catch (error) {
        console.error("❌ Transfer failed:", error);
        return;
    }

    // =========================================================================
    // STEP 5: VERIFY TRANSFER
    // =========================================================================

    console.log("✅ Step 5: Verifying transfer...");

    try {
        const newOwner = await trezaToken.owner();
        console.log("   New Owner:", newOwner);

        if (newOwner.toLowerCase() === GOVERNANCE_ADDRESS.toLowerCase()) {
            console.log("🎉 Ownership transfer confirmed!");
        } else {
            console.log("⚠️ Ownership may not have transferred correctly");
        }
        console.log("");
    } catch (error) {
        console.log("⚠️ Could not verify transfer:", error);
        console.log("");
    }

    // =========================================================================
    // NEXT STEPS
    // =========================================================================

    console.log("🎯 Next Steps:");
    console.log("=" .repeat(60));
    console.log("✅ Your token is now controlled by governance!");
    console.log("");
    
    if (GOVERNANCE_TYPE === "Timelock") {
        console.log("📝 To make changes, you now need to:");
        console.log("1. Create governance proposals using the timelock");
        console.log("2. Wait for the delay period (24 hours)");
        console.log("3. Execute approved proposals");
        console.log("");
        console.log("Example scripts:");
        console.log("• scripts/governance/examples/propose-fee-change.ts");
        console.log("• scripts/governance/examples/execute-proposal.ts");
    } else {
        console.log("📝 To make changes, you now need to:");
        console.log("1. Create governance proposals through the DAO");
        console.log("2. Token holders vote on proposals");
        console.log("3. Execute approved proposals after delays");
        console.log("");
        console.log("Your community now controls the token through voting!");
    }

    console.log("");
    console.log("🏛️ Congratulations on decentralizing your token governance! 🎉");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error("❌ Script failed:", error);
        process.exit(1);
    });
