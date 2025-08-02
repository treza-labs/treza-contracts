import { run } from "hardhat";

async function main() {
  const contractAddress = "0x6b6663612D5D3abd92171006F25e724DB434A0CB";
  
  console.log("🔍 Verifying Treza Token contract on Sepolia Etherscan...\n");
  
  // Constructor arguments - same as deployment
  const constructorParams = {
    initialLiquidityWallet: "0xCE7142c6183e210d8e39F59A582f0331E29c5928",
    teamWallet: "0xaD3C1b898635f93b093F516F6FCd61013920377b",
    treasuryWallet: "0xCe130Dd137D13276C5F2Dd7E71e26cb914bb1177",
    partnershipsGrantsWallet: "0x2919dd0794D2c20A83E710c97A431aE36bde332f",
    rndWallet: "0xFe8eED935f1E5DF73c6C6aBB0dcb596D9A1E559F",
    marketingOpsWallet: "0xf11419cC95d06051E6B3cC59C79036A8a933a53f",
    treasury1: "0x451DabB82841ae729B7EDF07877c45470719459B",
    treasury2: "0x742d35cc6634c0532925a3b8d404d4c47dd1f0a2",
    timelockDelay: 86400,
  };

  const proposers = ["0x1efFc09e27a42a6fAf74093901522D846eB50a8e"];
  const executors = ["0x1efFc09e27a42a6fAf74093901522D846eB50a8e"];

  try {
    await run("verify:verify", {
      address: contractAddress,
      constructorArguments: [
        constructorParams,
        proposers,
        executors
      ],
    });
    
    console.log("✅ Contract verified successfully!");
    console.log(`📍 View on Etherscan: https://sepolia.etherscan.io/address/${contractAddress}`);
    
  } catch (error) {
    console.error("❌ Verification failed:", error);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });