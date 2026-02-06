/**
 * Split Fees Script
 * 
 * Splits collected fees from the fee collection account 50/50
 * to the two treasury wallets using the Treza Fee Splitter program.
 * 
 * Usage:
 *   npx ts-node scripts/split-fees.ts
 *   npx ts-node scripts/split-fees.ts --network mainnet-beta
 */

import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import {
  Connection,
  Keypair,
  PublicKey,
} from "@solana/web3.js";
import {
  TOKEN_2022_PROGRAM_ID,
  getAccount,
  getAssociatedTokenAddressSync,
  ASSOCIATED_TOKEN_PROGRAM_ID,
  createAssociatedTokenAccountInstruction,
} from "@solana/spl-token";
import { Transaction, sendAndConfirmTransaction } from "@solana/web3.js";
import * as fs from "fs";
import * as path from "path";

// ============================================================================
// CONFIGURATION
// ============================================================================

interface SplitConfig {
  network: string;
  mint: PublicKey;
  configPda: PublicKey;
  feeCollectionAccount: PublicKey;
  treasuryWallet1: PublicKey;
  treasuryWallet2: PublicKey;
  authorityKeypairPath: string;
  tokenDecimals: number;
}

function loadConfig(): SplitConfig {
  const args = process.argv.slice(2);
  const networkArg = args.find(arg => arg.startsWith("--network="));
  const network = networkArg ? networkArg.split("=")[1] : "devnet";

  const deploymentPath = path.join(__dirname, `../deployments/treza-${network}.json`);
  
  if (!fs.existsSync(deploymentPath)) {
    throw new Error(`Deployment not found: ${deploymentPath}\nRun deploy-token.ts first.`);
  }

  const deployment = JSON.parse(fs.readFileSync(deploymentPath, "utf-8"));
  const configFilePath = path.join(__dirname, `../config/${network}.json`);
  const configFile = JSON.parse(fs.readFileSync(configFilePath, "utf-8"));

  return {
    network,
    mint: new PublicKey(deployment.mint),
    configPda: new PublicKey(deployment.configPda),
    feeCollectionAccount: new PublicKey(deployment.feeCollectionAccount),
    treasuryWallet1: new PublicKey(deployment.treasuryWallet1),
    treasuryWallet2: new PublicKey(deployment.treasuryWallet2),
    authorityKeypairPath: configFile.authorityKeypairPath,
    tokenDecimals: deployment.tokenDecimals,
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
// TOKEN ACCOUNT HELPERS
// ============================================================================

async function ensureTokenAccount(
  connection: Connection,
  payer: Keypair,
  mint: PublicKey,
  owner: PublicKey
): Promise<PublicKey> {
  const ata = getAssociatedTokenAddressSync(
    mint,
    owner,
    false,
    TOKEN_2022_PROGRAM_ID,
    ASSOCIATED_TOKEN_PROGRAM_ID
  );

  const accountInfo = await connection.getAccountInfo(ata);
  
  if (!accountInfo) {
    console.log(`   Creating token account for ${owner.toBase58().slice(0, 8)}...`);
    
    const createAtaIx = createAssociatedTokenAccountInstruction(
      payer.publicKey,
      ata,
      owner,
      mint,
      TOKEN_2022_PROGRAM_ID,
      ASSOCIATED_TOKEN_PROGRAM_ID
    );

    const tx = new Transaction().add(createAtaIx);
    await sendAndConfirmTransaction(connection, tx, [payer]);
  }

  return ata;
}

async function getTokenBalance(
  connection: Connection,
  tokenAccount: PublicKey,
  decimals: number
): Promise<{ raw: bigint; formatted: string }> {
  try {
    const account = await getAccount(
      connection,
      tokenAccount,
      "confirmed",
      TOKEN_2022_PROGRAM_ID
    );
    
    const raw = account.amount;
    const formatted = (Number(raw) / (10 ** decimals)).toLocaleString(undefined, {
      minimumFractionDigits: 2,
      maximumFractionDigits: decimals,
    });
    
    return { raw, formatted };
  } catch {
    return { raw: BigInt(0), formatted: "0.00" };
  }
}

// ============================================================================
// MAIN
// ============================================================================

async function main() {
  console.log("═══════════════════════════════════════════════════════════════");
  console.log("                TREZA FEE SPLITTING - SOLANA");
  console.log("═══════════════════════════════════════════════════════════════");

  try {
    const config = loadConfig();
    console.log(`\n🌐 Network: ${config.network}`);
    console.log(`🪙  Mint: ${config.mint.toBase58()}`);
    
    const connection = await getConnection(config.network);
    const payer = loadKeypair(config.authorityKeypairPath);
    
    console.log(`🔑 Payer: ${payer.publicKey.toBase58()}`);

    // Check collection account balance
    const collectionBalance = await getTokenBalance(
      connection,
      config.feeCollectionAccount,
      config.tokenDecimals
    );
    
    console.log(`\n📊 Fee Collection Account Balance: ${collectionBalance.formatted} TREZA`);
    
    if (collectionBalance.raw === BigInt(0)) {
      console.log("\n⚠️  No fees to split. Run 'npm run collect-fees' first.");
      return;
    }

    // Ensure treasury token accounts exist
    console.log("\n🏦 Ensuring treasury token accounts exist...");
    
    const treasuryAccount1 = await ensureTokenAccount(
      connection,
      payer,
      config.mint,
      config.treasuryWallet1
    );
    
    const treasuryAccount2 = await ensureTokenAccount(
      connection,
      payer,
      config.mint,
      config.treasuryWallet2
    );

    // Get pre-split balances
    const preTreasury1 = await getTokenBalance(connection, treasuryAccount1, config.tokenDecimals);
    const preTreasury2 = await getTokenBalance(connection, treasuryAccount2, config.tokenDecimals);
    
    console.log(`\n📍 Treasury 1 Balance: ${preTreasury1.formatted} TREZA`);
    console.log(`📍 Treasury 2 Balance: ${preTreasury2.formatted} TREZA`);

    // Load the fee splitter program
    const provider = new anchor.AnchorProvider(
      connection,
      new anchor.Wallet(payer),
      { commitment: "confirmed" }
    );
    anchor.setProvider(provider);

    const idlPath = path.join(__dirname, "../target/idl/treza_fee_splitter.json");
    
    if (!fs.existsSync(idlPath)) {
      throw new Error(
        "Fee splitter program IDL not found. Run `anchor build` first."
      );
    }

    const idl = JSON.parse(fs.readFileSync(idlPath, "utf-8"));
    const program = new Program(idl, provider);

    // Call split_fees
    console.log("\n💫 Splitting fees 50/50...");
    
    const tx = await program.methods
      .splitFees()
      .accounts({
        payer: payer.publicKey,
        config: config.configPda,
        mint: config.mint,
        feeCollectionAccount: config.feeCollectionAccount,
        treasuryAccount1: treasuryAccount1,
        treasuryAccount2: treasuryAccount2,
        tokenProgram: TOKEN_2022_PROGRAM_ID,
      })
      .signers([payer])
      .rpc();

    console.log(`   ✅ Transaction: ${tx}`);

    // Get post-split balances
    const postTreasury1 = await getTokenBalance(connection, treasuryAccount1, config.tokenDecimals);
    const postTreasury2 = await getTokenBalance(connection, treasuryAccount2, config.tokenDecimals);
    const postCollection = await getTokenBalance(connection, config.feeCollectionAccount, config.tokenDecimals);

    const received1 = Number(postTreasury1.raw - preTreasury1.raw) / (10 ** config.tokenDecimals);
    const received2 = Number(postTreasury2.raw - preTreasury2.raw) / (10 ** config.tokenDecimals);

    console.log("\n═══════════════════════════════════════════════════════════════");
    console.log("                     SPLIT COMPLETE!");
    console.log("═══════════════════════════════════════════════════════════════");
    console.log(`\n   Treasury 1 received: +${received1.toLocaleString()} TREZA`);
    console.log(`   Treasury 1 balance:  ${postTreasury1.formatted} TREZA`);
    console.log(`   Wallet: ${config.treasuryWallet1.toBase58()}`);
    console.log(`\n   Treasury 2 received: +${received2.toLocaleString()} TREZA`);
    console.log(`   Treasury 2 balance:  ${postTreasury2.formatted} TREZA`);
    console.log(`   Wallet: ${config.treasuryWallet2.toBase58()}`);
    console.log(`\n   Collection account remaining: ${postCollection.formatted} TREZA\n`);

  } catch (error) {
    console.error("\n❌ Fee splitting failed:", error);
    process.exit(1);
  }
}

main();
