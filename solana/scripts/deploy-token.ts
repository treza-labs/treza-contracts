/**
 * Treza Token Deployment Script for Solana
 * 
 * Deploys:
 * 1. Token-2022 mint with 5% transfer fee
 * 2. Initializes fee splitter program config
 * 3. Creates fee collection account
 * 4. Mints initial allocations
 * 
 * Usage:
 *   npx ts-node scripts/deploy-token.ts --network devnet
 *   npx ts-node scripts/deploy-token.ts --network mainnet-beta
 */

import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import {
  Connection,
  Keypair,
  PublicKey,
  SystemProgram,
  Transaction,
  sendAndConfirmTransaction,
  LAMPORTS_PER_SOL,
} from "@solana/web3.js";
import {
  TOKEN_2022_PROGRAM_ID,
  ExtensionType,
  createInitializeMintInstruction,
  createInitializeTransferFeeConfigInstruction,
  createInitializeMetadataPointerInstruction,
  getMintLen,
  createMintToInstruction,
  createAssociatedTokenAccountInstruction,
  getAssociatedTokenAddressSync,
  ASSOCIATED_TOKEN_PROGRAM_ID,
  TYPE_SIZE,
  LENGTH_SIZE,
} from "@solana/spl-token";
import {
  createInitializeInstruction,
  pack,
  TokenMetadata,
} from "@solana/spl-token-metadata";
import * as fs from "fs";
import * as path from "path";

// ============================================================================
// CONFIGURATION
// ============================================================================

interface DeployConfig {
  network: "devnet" | "testnet" | "mainnet-beta";
  authorityKeypairPath: string;
  treasuryWallet1: PublicKey;
  treasuryWallet2: PublicKey;
  tokenName: string;
  tokenSymbol: string;
  tokenUri: string;
  tokenDecimals: number;
  totalSupply: bigint;
  transferFeeBasisPoints: number;
  maxTransferFee: bigint;
  allocations: {
    team: { wallet: PublicKey; percentage: number };
    initialLiquidity: { wallet: PublicKey; percentage: number };
    marketingOps: { wallet: PublicKey; percentage: number };
    rnd: { wallet: PublicKey; percentage: number };
    seedInvestors: { wallet: PublicKey; percentage: number };
    cexListing: { wallet: PublicKey; percentage: number };
  };
}

function loadConfig(): DeployConfig {
  // Parse command line arguments
  const args = process.argv.slice(2);
  const networkArg = args.find(arg => arg.startsWith("--network="));
  const network = networkArg ? networkArg.split("=")[1] : "devnet";

  if (!["devnet", "testnet", "mainnet-beta"].includes(network)) {
    throw new Error(`Invalid network: ${network}`);
  }

  // Load from environment or config file
  const configPath = path.join(__dirname, "../config", `${network}.json`);
  
  if (!fs.existsSync(configPath)) {
    console.log(`\nConfig file not found: ${configPath}`);
    console.log("Please create a config file with the following structure:\n");
    console.log(JSON.stringify(getExampleConfig(), null, 2));
    process.exit(1);
  }

  const rawConfig = JSON.parse(fs.readFileSync(configPath, "utf-8"));
  
  return {
    network: network as DeployConfig["network"],
    authorityKeypairPath: rawConfig.authorityKeypairPath,
    treasuryWallet1: new PublicKey(rawConfig.treasuryWallet1),
    treasuryWallet2: new PublicKey(rawConfig.treasuryWallet2),
    tokenName: rawConfig.tokenName || "Treza",
    tokenSymbol: rawConfig.tokenSymbol || "TREZA",
    tokenUri: rawConfig.tokenUri || "",
    tokenDecimals: rawConfig.tokenDecimals || 9,
    totalSupply: BigInt(rawConfig.totalSupply) * BigInt(10 ** (rawConfig.tokenDecimals || 9)),
    transferFeeBasisPoints: rawConfig.transferFeeBasisPoints || 500,
    maxTransferFee: BigInt(rawConfig.maxTransferFee || "1000000000000"),
    allocations: {
      team: {
        wallet: new PublicKey(rawConfig.allocations.team.wallet),
        percentage: rawConfig.allocations.team.percentage,
      },
      initialLiquidity: {
        wallet: new PublicKey(rawConfig.allocations.initialLiquidity.wallet),
        percentage: rawConfig.allocations.initialLiquidity.percentage,
      },
      marketingOps: {
        wallet: new PublicKey(rawConfig.allocations.marketingOps.wallet),
        percentage: rawConfig.allocations.marketingOps.percentage,
      },
      rnd: {
        wallet: new PublicKey(rawConfig.allocations.rnd.wallet),
        percentage: rawConfig.allocations.rnd.percentage,
      },
      seedInvestors: {
        wallet: new PublicKey(rawConfig.allocations.seedInvestors.wallet),
        percentage: rawConfig.allocations.seedInvestors.percentage,
      },
      cexListing: {
        wallet: new PublicKey(rawConfig.allocations.cexListing.wallet),
        percentage: rawConfig.allocations.cexListing.percentage,
      },
    },
  };
}

function getExampleConfig() {
  return {
    authorityKeypairPath: "~/.config/solana/treza-authority.json",
    treasuryWallet1: "YOUR_TREASURY_WALLET_1_PUBKEY",
    treasuryWallet2: "YOUR_TREASURY_WALLET_2_PUBKEY",
    tokenName: "Treza",
    tokenSymbol: "TREZA",
    tokenUri: "https://trezalabs.com/tokens/treza-metadata.json",
    tokenDecimals: 9,
    totalSupply: "100000000",
    transferFeeBasisPoints: 500,
    maxTransferFee: "1000000000000",
    allocations: {
      team: { wallet: "TEAM_WALLET_PUBKEY", percentage: 65 },
      initialLiquidity: { wallet: "LIQUIDITY_WALLET_PUBKEY", percentage: 10 },
      marketingOps: { wallet: "MARKETING_WALLET_PUBKEY", percentage: 10 },
      rnd: { wallet: "RND_WALLET_PUBKEY", percentage: 5 },
      seedInvestors: { wallet: "SEED_WALLET_PUBKEY", percentage: 5 },
      cexListing: { wallet: "CEX_WALLET_PUBKEY", percentage: 5 },
    },
  };
}

// ============================================================================
// DEPLOYMENT FUNCTIONS
// ============================================================================

async function getConnection(network: string): Promise<Connection> {
  const endpoints: Record<string, string> = {
    devnet: "https://api.devnet.solana.com",
    testnet: "https://api.testnet.solana.com",
    "mainnet-beta": "https://api.mainnet-beta.solana.com",
  };
  
  return new Connection(endpoints[network], "confirmed");
}

function loadKeypair(keypairPath: string): Keypair {
  const expandedPath = keypairPath.replace("~", process.env.HOME || "");
  const secretKey = JSON.parse(fs.readFileSync(expandedPath, "utf-8"));
  return Keypair.fromSecretKey(Uint8Array.from(secretKey));
}

async function createToken2022WithTransferFee(
  connection: Connection,
  payer: Keypair,
  config: DeployConfig
): Promise<Keypair> {
  console.log("\n📦 Creating Token-2022 mint with transfer fee and metadata...");
  
  const mintKeypair = Keypair.generate();
  
  // Create token metadata
  const metadata: TokenMetadata = {
    mint: mintKeypair.publicKey,
    name: config.tokenName,
    symbol: config.tokenSymbol,
    uri: config.tokenUri,
    additionalMetadata: [],
  };

  // Calculate space needed for mint with extensions
  // MetadataPointer extension + TransferFeeConfig extension
  const mintLen = getMintLen([
    ExtensionType.TransferFeeConfig,
    ExtensionType.MetadataPointer,
  ]);
  
  // Calculate metadata space
  const metadataLen = TYPE_SIZE + LENGTH_SIZE + pack(metadata).length;
  const totalLen = mintLen + metadataLen;
  
  const mintLamports = await connection.getMinimumBalanceForRentExemption(totalLen);

  // Create mint account with space for all extensions
  const createMintAccountIx = SystemProgram.createAccount({
    fromPubkey: payer.publicKey,
    newAccountPubkey: mintKeypair.publicKey,
    space: totalLen,
    lamports: mintLamports,
    programId: TOKEN_2022_PROGRAM_ID,
  });

  // Initialize metadata pointer (points to the mint itself for on-chain metadata)
  const initMetadataPointerIx = createInitializeMetadataPointerInstruction(
    mintKeypair.publicKey,
    payer.publicKey, // metadata authority
    mintKeypair.publicKey, // metadata address (self-referencing for on-chain)
    TOKEN_2022_PROGRAM_ID
  );

  // Initialize transfer fee config
  // Fee authority and withdraw authority are both the payer (can be changed later)
  const initTransferFeeIx = createInitializeTransferFeeConfigInstruction(
    mintKeypair.publicKey,
    payer.publicKey, // transfer fee config authority
    payer.publicKey, // withdraw withheld authority
    config.transferFeeBasisPoints,
    config.maxTransferFee,
    TOKEN_2022_PROGRAM_ID
  );

  // Initialize the mint
  const initMintIx = createInitializeMintInstruction(
    mintKeypair.publicKey,
    config.tokenDecimals,
    payer.publicKey, // mint authority
    payer.publicKey, // freeze authority (can be null)
    TOKEN_2022_PROGRAM_ID
  );

  // Initialize the metadata
  const initMetadataIx = createInitializeInstruction({
    programId: TOKEN_2022_PROGRAM_ID,
    mint: mintKeypair.publicKey,
    metadata: mintKeypair.publicKey,
    name: metadata.name,
    symbol: metadata.symbol,
    uri: metadata.uri,
    mintAuthority: payer.publicKey,
    updateAuthority: payer.publicKey,
  });

  // Order matters: create account, then init extensions, then init mint, then init metadata
  const tx = new Transaction().add(
    createMintAccountIx,
    initMetadataPointerIx,
    initTransferFeeIx,
    initMintIx,
    initMetadataIx
  );

  await sendAndConfirmTransaction(connection, tx, [payer, mintKeypair]);
  
  console.log(`   ✅ Mint created: ${mintKeypair.publicKey.toBase58()}`);
  console.log(`   🏷️  Name: ${config.tokenName}`);
  console.log(`   🎫 Symbol: ${config.tokenSymbol}`);
  console.log(`   📊 Transfer fee: ${config.transferFeeBasisPoints / 100}%`);
  
  return mintKeypair;
}

async function createTokenAccount(
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

  // Check if account already exists
  const accountInfo = await connection.getAccountInfo(ata);
  if (accountInfo) {
    return ata;
  }

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
  
  return ata;
}

async function mintInitialAllocations(
  connection: Connection,
  payer: Keypair,
  mint: PublicKey,
  config: DeployConfig
): Promise<void> {
  console.log("\n💰 Minting initial allocations...");
  
  const allocations = [
    { name: "Team", ...config.allocations.team },
    { name: "Initial Liquidity", ...config.allocations.initialLiquidity },
    { name: "Marketing/Ops", ...config.allocations.marketingOps },
    { name: "R&D", ...config.allocations.rnd },
    { name: "Seed Investors", ...config.allocations.seedInvestors },
    { name: "CEX Listing", ...config.allocations.cexListing },
  ];

  // Verify allocations sum to 100%
  const totalPercentage = allocations.reduce((sum, a) => sum + a.percentage, 0);
  if (totalPercentage !== 100) {
    throw new Error(`Allocations must sum to 100%, got ${totalPercentage}%`);
  }

  for (const allocation of allocations) {
    const amount = (config.totalSupply * BigInt(allocation.percentage)) / BigInt(100);
    
    // Create token account for recipient
    const recipientAta = await createTokenAccount(
      connection,
      payer,
      mint,
      allocation.wallet
    );
    
    // Mint tokens
    const mintIx = createMintToInstruction(
      mint,
      recipientAta,
      payer.publicKey,
      amount,
      [],
      TOKEN_2022_PROGRAM_ID
    );
    
    const tx = new Transaction().add(mintIx);
    await sendAndConfirmTransaction(connection, tx, [payer]);
    
    const displayAmount = Number(amount) / (10 ** config.tokenDecimals);
    console.log(`   ✅ ${allocation.name}: ${displayAmount.toLocaleString()} TREZA (${allocation.percentage}%)`);
    console.log(`      Wallet: ${allocation.wallet.toBase58()}`);
  }
}

async function initializeFeeSplitter(
  connection: Connection,
  payer: Keypair,
  mint: PublicKey,
  config: DeployConfig,
  program: Program
): Promise<PublicKey> {
  console.log("\n⚙️  Initializing fee splitter program...");
  
  // Derive config PDA
  const [configPda] = PublicKey.findProgramAddressSync(
    [Buffer.from("config"), mint.toBuffer()],
    program.programId
  );

  await program.methods
    .initialize(config.treasuryWallet1, config.treasuryWallet2)
    .accounts({
      authority: payer.publicKey,
      config: configPda,
      mint: mint,
      systemProgram: SystemProgram.programId,
    })
    .signers([payer])
    .rpc();

  console.log(`   ✅ Config PDA: ${configPda.toBase58()}`);
  console.log(`   📍 Treasury 1: ${config.treasuryWallet1.toBase58()}`);
  console.log(`   📍 Treasury 2: ${config.treasuryWallet2.toBase58()}`);
  
  return configPda;
}

async function createFeeCollectionAccount(
  connection: Connection,
  payer: Keypair,
  mint: PublicKey,
  configPda: PublicKey
): Promise<PublicKey> {
  console.log("\n🏦 Creating fee collection account...");
  
  const feeCollectionAta = await createTokenAccount(
    connection,
    payer,
    mint,
    configPda
  );
  
  console.log(`   ✅ Fee collection account: ${feeCollectionAta.toBase58()}`);
  
  return feeCollectionAta;
}

async function saveDeployment(
  network: string,
  mint: PublicKey,
  configPda: PublicKey,
  feeCollectionAccount: PublicKey,
  config: DeployConfig
): Promise<void> {
  const deploymentInfo = {
    network,
    timestamp: new Date().toISOString(),
    tokenName: config.tokenName,
    tokenSymbol: config.tokenSymbol,
    tokenUri: config.tokenUri,
    mint: mint.toBase58(),
    configPda: configPda.toBase58(),
    feeCollectionAccount: feeCollectionAccount.toBase58(),
    treasuryWallet1: config.treasuryWallet1.toBase58(),
    treasuryWallet2: config.treasuryWallet2.toBase58(),
    tokenDecimals: config.tokenDecimals,
    transferFeeBasisPoints: config.transferFeeBasisPoints,
    totalSupply: config.totalSupply.toString(),
  };

  const deploymentsDir = path.join(__dirname, "../deployments");
  if (!fs.existsSync(deploymentsDir)) {
    fs.mkdirSync(deploymentsDir, { recursive: true });
  }

  const filename = `treza-${network}.json`;
  fs.writeFileSync(
    path.join(deploymentsDir, filename),
    JSON.stringify(deploymentInfo, null, 2)
  );

  console.log(`\n📝 Deployment info saved to: deployments/${filename}`);
}

// ============================================================================
// MAIN
// ============================================================================

async function main() {
  console.log("═══════════════════════════════════════════════════════════════");
  console.log("               TREZA TOKEN DEPLOYMENT - SOLANA");
  console.log("═══════════════════════════════════════════════════════════════");

  try {
    const config = loadConfig();
    console.log(`\n🌐 Network: ${config.network}`);
    
    const connection = await getConnection(config.network);
    const payer = loadKeypair(config.authorityKeypairPath);
    
    console.log(`🔑 Authority: ${payer.publicKey.toBase58()}`);
    
    // Check balance
    const balance = await connection.getBalance(payer.publicKey);
    console.log(`💳 Balance: ${balance / LAMPORTS_PER_SOL} SOL`);
    
    if (balance < 0.5 * LAMPORTS_PER_SOL) {
      if (config.network === "devnet") {
        console.log("\n⚠️  Low balance. Requesting airdrop...");
        const signature = await connection.requestAirdrop(
          payer.publicKey,
          2 * LAMPORTS_PER_SOL
        );
        await connection.confirmTransaction(signature);
        console.log("   ✅ Airdrop received");
      } else {
        throw new Error("Insufficient balance for deployment");
      }
    }

    // Load fee splitter program
    const provider = new anchor.AnchorProvider(
      connection,
      new anchor.Wallet(payer),
      { commitment: "confirmed" }
    );
    anchor.setProvider(provider);
    
    // Note: You'll need to build the program first with `anchor build`
    // and update the IDL path
    const idlPath = path.join(__dirname, "../target/idl/treza_fee_splitter.json");
    if (!fs.existsSync(idlPath)) {
      console.log("\n⚠️  Fee splitter program not built. Run `anchor build` first.");
      console.log("   Continuing with token deployment only...\n");
    }

    // 1. Create Token-2022 mint with transfer fee
    const mintKeypair = await createToken2022WithTransferFee(connection, payer, config);

    // 2. Mint initial allocations
    await mintInitialAllocations(connection, payer, mintKeypair.publicKey, config);

    // 3. Initialize fee splitter (if program is deployed)
    let configPda: PublicKey | undefined;
    let feeCollectionAccount: PublicKey | undefined;
    
    if (fs.existsSync(idlPath)) {
      const idl = JSON.parse(fs.readFileSync(idlPath, "utf-8"));
      const program = new Program(idl, provider);
      
      configPda = await initializeFeeSplitter(
        connection,
        payer,
        mintKeypair.publicKey,
        config,
        program
      );

      // 4. Create fee collection account
      feeCollectionAccount = await createFeeCollectionAccount(
        connection,
        payer,
        mintKeypair.publicKey,
        configPda
      );
    }

    // 5. Save deployment info
    await saveDeployment(
      config.network,
      mintKeypair.publicKey,
      configPda || PublicKey.default,
      feeCollectionAccount || PublicKey.default,
      config
    );

    console.log("\n═══════════════════════════════════════════════════════════════");
    console.log("                    DEPLOYMENT COMPLETE!");
    console.log("═══════════════════════════════════════════════════════════════");
    console.log(`\n🎉 ${config.tokenName} (${config.tokenSymbol}) deployed successfully!`);
    console.log(`\n   Mint Address: ${mintKeypair.publicKey.toBase58()}`);
    console.log(`   Name: ${config.tokenName}`);
    console.log(`   Symbol: ${config.tokenSymbol}`);
    console.log(`   Transfer Fee: ${config.transferFeeBasisPoints / 100}%`);
    console.log(`   Decimals: ${config.tokenDecimals}`);
    console.log(`   Total Supply: ${Number(config.totalSupply) / (10 ** config.tokenDecimals)} ${config.tokenSymbol}`);
    
    if (configPda) {
      console.log(`\n   Fee Splitter Config: ${configPda.toBase58()}`);
      console.log(`   Fee Collection Account: ${feeCollectionAccount?.toBase58()}`);
    }

    console.log("\n📋 Next Steps:");
    console.log("   1. Verify the deployment on Solana Explorer");
    console.log("   2. Create treasury token accounts if not exists");
    console.log("   3. Set up a cron job to periodically collect and split fees");
    console.log("   4. Consider revoking mint authority after verifying allocations\n");

  } catch (error) {
    console.error("\n❌ Deployment failed:", error);
    process.exit(1);
  }
}

main();
