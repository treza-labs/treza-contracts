import axios from 'axios';
import * as fs from 'fs';
import * as dotenv from 'dotenv';

dotenv.config();

/**
 * Setup script to obtain zkVerify configuration values
 * 
 * This script helps you:
 * 1. Register your verification key with zkVerify
 * 2. Get the vkHash for deployment
 * 3. Find the zkVerify contract address
 * 
 * Usage:
 *   npx ts-node scripts/setup-zkverify-config.ts
 */

const RELAYER_API_URL = process.env.ZKVERIFY_RELAYER_URL || 
  'https://relayer-api-testnet.horizenlabs.io/api/v1';
const RELAYER_API_KEY = process.env.ZKVERIFY_RELAYER_API_KEY;

async function main() {
    console.log("🔧 zkVerify Configuration Setup\n");

    // Step 1: Check API key
    if (!RELAYER_API_KEY || RELAYER_API_KEY === 'your_api_key_here') {
        console.error("❌ Error: ZKVERIFY_RELAYER_API_KEY not configured");
        console.log("\nPlease set your Relayer API key:");
        console.log("1. Get an API key from: https://relayer-testnet.horizenlabs.io");
        console.log("2. Add to .env: ZKVERIFY_RELAYER_API_KEY=your_key\n");
        process.exit(1);
    }

    console.log("✅ Relayer API key found\n");

    // Step 2: Find zkVerify contract address
    console.log("📋 Step 1: zkVerify Contract Address\n");
    console.log("The zkVerify aggregation contract is deployed by Horizen Labs.");
    console.log("You need to get this address from:\n");
    console.log("Option 1: zkVerify Documentation");
    console.log("  - Visit: https://docs.zkverify.io");
    console.log("  - Look for 'Deployed Contracts' or 'Contract Addresses'");
    console.log("  - Find the address for your target network (Sepolia/Mainnet)\n");
    
    console.log("Option 2: Contact Horizen Labs");
    console.log("  - Discord: https://discord.gg/horizen");
    console.log("  - Ask for: IVerifyProofAggregation contract address\n");
    
    console.log("Option 3: Check Relayer API");
    console.log("  - The aggregation response may include contract references\n");

    // Placeholder for zkVerify contract
    const zkVerifyContractAddress = "0x0000000000000000000000000000000000000000"; // UPDATE THIS
    
    console.log(`Current value: ${zkVerifyContractAddress}`);
    console.log("⚠️  This is a placeholder - update before deployment!\n");

    // Step 3: Register verification key
    console.log("📋 Step 2: Register Verification Key\n");
    console.log("To get your VERIFICATION_KEY_HASH, you need to register your VK.\n");

    // Check if VK file exists (common locations)
    const vkPaths = [
        './verification_key.json',
        './vkey.json',
        './circuit_vkey.json',
        '../verification_key.json'
    ];

    let vkPath: string | null = null;
    for (const path of vkPaths) {
        if (fs.existsSync(path)) {
            vkPath = path;
            break;
        }
    }

    if (!vkPath) {
        console.log("❌ No verification key file found in common locations.");
        console.log("\nExpected locations:");
        vkPaths.forEach(path => console.log(`  - ${path}`));
        console.log("\nTo register your VK:");
        console.log("1. Generate your circuit verification key");
        console.log("2. Use the Relayer API to register it:");
        console.log("\nExample:");
        console.log(`
curl -X POST ${RELAYER_API_URL}/register-vk/${RELAYER_API_KEY} \\
  -H "Content-Type: application/json" \\
  -d '{
    "proofType": "groth16",
    "proofOptions": {
      "library": "snarkjs",
      "curve": "bn128"
    },
    "vk": {
      "protocol": "groth16",
      "curve": "bn128",
      "nPublic": 2,
      "vk_alpha_1": [...],
      "vk_beta_2": [...],
      "vk_gamma_2": [...],
      "vk_delta_2": [...],
      "vk_alphabeta_12": [...],
      "IC": [...]
    }
  }'
        `);
        console.log("\n3. Save the returned vkHash\n");
        process.exit(1);
    }

    console.log(`✅ Found verification key: ${vkPath}\n`);
    console.log("📤 Registering verification key with zkVerify...\n");

    try {
        const vkData = JSON.parse(fs.readFileSync(vkPath, 'utf-8'));

        const response = await axios.post(
            `${RELAYER_API_URL}/register-vk/${RELAYER_API_KEY}`,
            {
                proofType: 'groth16',
                proofOptions: {
                    library: 'snarkjs',
                    curve: 'bn128'
                },
                vk: vkData
            }
        );

        const vkHash = response.data.vkHash || response.data.meta?.vkHash;

        console.log("✅ Verification key registered successfully!\n");
        console.log(`VK Hash: ${vkHash}\n`);

        // Save configuration to .env
        const envPath = '.env';
        let envContent = '';
        
        if (fs.existsSync(envPath)) {
            envContent = fs.readFileSync(envPath, 'utf-8');
        }

        // Update or add zkVerify configuration
        const updates = {
            'ZKVERIFY_CONTRACT_ADDRESS': zkVerifyContractAddress,
            'VERIFICATION_KEY_HASH': vkHash
        };

        for (const [key, value] of Object.entries(updates)) {
            const regex = new RegExp(`^${key}=.*$`, 'm');
            if (regex.test(envContent)) {
                envContent = envContent.replace(regex, `${key}=${value}`);
            } else {
                envContent += `\n${key}=${value}`;
            }
        }

        fs.writeFileSync(envPath, envContent);
        console.log(`✅ Configuration saved to ${envPath}\n`);

        // Print summary
        console.log("📋 Configuration Summary:\n");
        console.log(`ZKVERIFY_CONTRACT_ADDRESS=${zkVerifyContractAddress}`);
        console.log(`  ⚠️  PLACEHOLDER - Update with real address before deployment!\n`);
        console.log(`VERIFICATION_KEY_HASH=${vkHash}`);
        console.log(`  ✅ Registered and ready to use\n`);

        console.log("🚀 Next Steps:\n");
        console.log("1. Update ZKVERIFY_CONTRACT_ADDRESS with the real address");
        console.log("   - Check zkVerify docs or contact Horizen Labs");
        console.log("2. Deploy ZKVerifyAggregationVerifier:");
        console.log("   npx hardhat run scripts/deploy-aggregation-verifier.ts --network sepolia");
        console.log("3. Test the integration:");
        console.log("   npx hardhat test test/compliance/ZKVerifyAggregationVerifier.test.ts\n");

    } catch (error: any) {
        if (error.response?.data?.vkHash) {
            // VK already registered
            const vkHash = error.response.data.vkHash;
            console.log("ℹ️  Verification key already registered\n");
            console.log(`VK Hash: ${vkHash}\n`);
            console.log(`VERIFICATION_KEY_HASH=${vkHash}\n`);
        } else {
            console.error("❌ Error registering verification key:");
            console.error(error.response?.data || error.message);
            console.log("\nPlease check:");
            console.log("1. Your VK file format is correct");
            console.log("2. Your Relayer API key is valid");
            console.log("3. The Relayer service is accessible\n");
        }
    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

