/**
 * Collect Withheld Fees Script
 * 
 * Harvests withheld transfer fees from token accounts and deposits
 * them into the fee collection account for splitting.
 * 
 * Token-2022 transfer fees are withheld in recipient accounts.
 * This script collects those fees so they can be split to treasuries.
 * 
 * Usage:
 *   npx ts-node scripts/collect-fees.ts
 *   npx ts-node scripts/collect-fees.ts --network mainnet-beta
 */

import {
  Connection,
  Keypair,
  PublicKey,
  Transaction,
  sendAndConfirmTransaction,
} from "@solana/web3.js";
import {
  TOKEN_2022_PROGRAM_ID,
  getTransferFeeConfig,
  getMint,
  getAccount,
  harvestWithheldTokensToMint,
  withdrawWithheldTokensFromMint,
  getAssociatedTokenAddressSync,
  ASSOCIATED_TOKEN_PROGRAM_ID,
} from "@solana/spl-token";
import * as fs from "fs";
import * as path from "path";

// ============================================================================
// CONFIGURATION
// ============================================================================

interface CollectConfig {
  network: string;
  mint: PublicKey;
  feeCollectionAccount: PublicKey;
  authorityKeypairPath: string;
}

function loadConfig(): CollectConfig {
  const args = process.argv.slice(2);
  const networkArg = args.find(arg => arg.startsWith("--network="));
  const network = networkArg ? networkArg.split("=")[1] : "devnet";

  const deploymentPath = path.join(__dirname, `../deployments/treza-${network}.json`);
  
  if (!fs.existsSync(deploymentPath)) {
    throw new Error(`Deployment not found: ${deploymentPath}\nRun deploy-token.ts first.`);
  }

  const deployment = JSON.parse(fs.readFileSync(deploymentPath, "utf-8"));
  const configPath = path.join(__dirname, `../config/${network}.json`);
  const config = JSON.parse(fs.readFileSync(configPath, "utf-8"));

  return {
    network,
    mint: new PublicKey(deployment.mint),
    feeCollectionAccount: new PublicKey(deployment.feeCollectionAccount),
    authorityKeypairPath: config.authorityKeypairPath,
  };
}

function loadKeypair(keypairPath: string): Keypair {
  const expandedPath = keypairPath.replace("~", process.env.HOME || "");
  const secretKey = JSON.parse(fs.readFileSync(expandedPath, "utf-8"));
  return Keypair.fromSecretKey(Uint8Array.from(secretKey));
}

async function getConnection(network: string): Promise<Connection> {
  const endpoints: Record<string, string> = {
    devnet: "https://api.devnet.solana.com",
    testnet: "https://api.testnet.solana.com",
    "mainnet-beta": "https://api.mainnet-beta.solana.com",
  };
  
  return new Connection(endpoints[network], "confirmed");
}

// ============================================================================
// FEE COLLECTION FUNCTIONS
// ============================================================================

async function getTokenAccountsWithWithheldFees(
  connection: Connection,
  mint: PublicKey
): Promise<PublicKey[]> {
  console.log("\n🔍 Scanning for accounts with withheld fees...");
  
  // Get all token accounts for this mint
  const accounts = await connection.getProgramAccounts(TOKEN_2022_PROGRAM_ID, {
    filters: [
      { dataSize: 182 }, // Token account size with extensions
      {
        memcmp: {
          offset: 0,
          bytes: mint.toBase58(),
        },
      },
    ],
  });

  const accountsWithFees: PublicKey[] = [];
  
  for (const { pubkey } of accounts) {
    try {
      const accountInfo = await getAccount(
        connection,
        pubkey,
        "confirmed",
        TOKEN_2022_PROGRAM_ID
      );
      
      // Check if account has withheld fees (stored in extension data)
      // For Token-2022, we need to check the transfer fee amount
      // This is a simplified check - in production, parse the extension data
      if (accountInfo) {
        accountsWithFees.push(pubkey);
      }
    } catch (e) {
      // Skip accounts that can't be parsed
      continue;
    }
  }

  console.log(`   Found ${accountsWithFees.length} token accounts to check`);
  return accountsWithFees;
}

async function harvestFeesToMint(
  connection: Connection,
  payer: Keypair,
  mint: PublicKey,
  tokenAccounts: PublicKey[]
): Promise<bigint> {
  console.log("\n🌾 Harvesting withheld fees to mint...");
  
  if (tokenAccounts.length === 0) {
    console.log("   No accounts to harvest from");
    return BigInt(0);
  }

  // Harvest in batches (max ~20 accounts per transaction due to size limits)
  const batchSize = 20;
  let totalHarvested = BigInt(0);
  
  for (let i = 0; i < tokenAccounts.length; i += batchSize) {
    const batch = tokenAccounts.slice(i, i + batchSize);
    
    try {
      const signature = await harvestWithheldTokensToMint(
        connection,
        payer,
        mint,
        batch,
        undefined,
        TOKEN_2022_PROGRAM_ID
      );
      
      console.log(`   ✅ Harvested batch ${Math.floor(i / batchSize) + 1}: ${signature}`);
    } catch (e: any) {
      console.log(`   ⚠️  Batch ${Math.floor(i / batchSize) + 1} skipped: ${e.message}`);
    }
  }

  // Get mint info to see total withheld
  const mintInfo = await getMint(connection, mint, "confirmed", TOKEN_2022_PROGRAM_ID);
  const transferFeeConfig = getTransferFeeConfig(mintInfo);
  
  if (transferFeeConfig) {
    totalHarvested = transferFeeConfig.withheldAmount;
    console.log(`   💰 Total withheld at mint: ${totalHarvested}`);
  }

  return totalHarvested;
}

async function withdrawFeesToCollection(
  connection: Connection,
  payer: Keypair,
  mint: PublicKey,
  feeCollectionAccount: PublicKey
): Promise<bigint> {
  console.log("\n💸 Withdrawing fees to collection account...");
  
  // Get current withheld amount at mint
  const mintInfo = await getMint(connection, mint, "confirmed", TOKEN_2022_PROGRAM_ID);
  const transferFeeConfig = getTransferFeeConfig(mintInfo);
  
  if (!transferFeeConfig || transferFeeConfig.withheldAmount === BigInt(0)) {
    console.log("   No fees to withdraw");
    return BigInt(0);
  }

  const withheldAmount = transferFeeConfig.withheldAmount;
  console.log(`   Withdrawing ${withheldAmount} tokens...`);

  const signature = await withdrawWithheldTokensFromMint(
    connection,
    payer,
    mint,
    feeCollectionAccount,
    payer.publicKey, // withdraw authority
    [],
    undefined,
    TOKEN_2022_PROGRAM_ID
  );

  console.log(`   ✅ Withdrawn: ${signature}`);
  
  return withheldAmount;
}

// ============================================================================
// MAIN
// ============================================================================

async function main() {
  console.log("═══════════════════════════════════════════════════════════════");
  console.log("              TREZA FEE COLLECTION - SOLANA");
  console.log("═══════════════════════════════════════════════════════════════");

  try {
    const config = loadConfig();
    console.log(`\n🌐 Network: ${config.network}`);
    console.log(`🪙  Mint: ${config.mint.toBase58()}`);
    
    const connection = await getConnection(config.network);
    const payer = loadKeypair(config.authorityKeypairPath);
    
    console.log(`🔑 Authority: ${payer.publicKey.toBase58()}`);

    // 1. Find accounts with withheld fees
    const accountsWithFees = await getTokenAccountsWithWithheldFees(
      connection,
      config.mint
    );

    // 2. Harvest fees to mint
    await harvestFeesToMint(connection, payer, config.mint, accountsWithFees);

    // 3. Withdraw from mint to collection account
    const collectedAmount = await withdrawFeesToCollection(
      connection,
      payer,
      config.mint,
      config.feeCollectionAccount
    );

    // 4. Check collection account balance
    const collectionAccountInfo = await getAccount(
      connection,
      config.feeCollectionAccount,
      "confirmed",
      TOKEN_2022_PROGRAM_ID
    );

    console.log("\n═══════════════════════════════════════════════════════════════");
    console.log("                   COLLECTION COMPLETE!");
    console.log("═══════════════════════════════════════════════════════════════");
    console.log(`\n   Fee Collection Account: ${config.feeCollectionAccount.toBase58()}`);
    console.log(`   Current Balance: ${collectionAccountInfo.amount} tokens`);
    console.log(`\n   Run 'npm run split-fees' to distribute to treasuries.\n`);

  } catch (error) {
    console.error("\n❌ Fee collection failed:", error);
    process.exit(1);
  }
}

main();
