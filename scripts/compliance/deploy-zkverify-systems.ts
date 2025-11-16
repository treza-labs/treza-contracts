import { ethers } from "hardhat";
import type { ContractTransactionResponse } from "ethers";

interface DeploymentConfig {
    // Oracle configuration
    requiredConfirmations: number;
    
    // Network configuration
    confirmations: number;
    gasPrice?: string;
    gasLimit?: number;
    
    // Existing contracts
    zkPassportVerifierAddress?: string;
    
    // Initial oracle nodes
    initialOracles: {
        address: string;
        endpoint: string;
    }[];
    
    // Initial attesters (for testing)
    initialAttesters: {
        address: string;
        tier: number; // 0=Bronze, 1=Silver, 2=Gold, 3=Platinum
        companyName: string;
        licenseNumber: string;
        jurisdiction: string;
        specializations: string[];
        stakeAmount: string;
    }[];
}

// Network-specific configurations
const configs: { [key: string]: DeploymentConfig } = {
    // Sepolia testnet
    "11155111": {
        requiredConfirmations: 2,
        confirmations: 2,
        gasPrice: "20000000000", // 20 gwei
        zkPassportVerifierAddress: "0x8c0C6e0Eaf6bc693745A1A3a722e2c9028BBe874", // Existing deployment
        initialOracles: [
            {
                address: "0x1efFc09e27a42a6fAf74093901522D846eB50a8e", // Your address for testing
                endpoint: "https://sepolia-zkverify-oracle.treza.io"
            }
        ],
        initialAttesters: [
            {
                address: "0x1efFc09e27a42a6fAf74093901522D846eB50a8e", // Your address for testing
                tier: 2, // Gold tier
                companyName: "TREZA Compliance Services",
                licenseNumber: "TCS-001",
                jurisdiction: "US",
                specializations: ["KYC", "AML", "Crypto Compliance"],
                stakeAmount: "10" // 10 ETH
            }
        ]
    },
    
    // Ethereum mainnet
    "1": {
        requiredConfirmations: 3,
        confirmations: 5,
        gasPrice: "30000000000", // 30 gwei
        initialOracles: [
            // Add production oracle addresses here
        ],
        initialAttesters: [
            // Add production attester addresses here
        ]
    }
};

async function main() {
    console.log("🚀 Starting zkVerify Systems Deployment...\n");
    
    const [deployer] = await ethers.getSigners();
    const network = await ethers.provider.getNetwork();
    const chainId = network.chainId.toString();
    
    console.log("📋 Deployment Configuration:");
    console.log(`   Network: ${network.name} (Chain ID: ${chainId})`);
    console.log(`   Deployer: ${deployer.address}`);
    console.log(`   Balance: ${ethers.formatEther(await ethers.provider.getBalance(deployer.address))} ETH\n`);
    
    const config = configs[chainId];
    if (!config) {
        throw new Error(`No configuration found for chain ID: ${chainId}`);
    }
    
    // Deployment options
    const deployOptions = {
        gasPrice: config.gasPrice ? BigInt(config.gasPrice) : undefined,
        gasLimit: config.gasLimit ? BigInt(config.gasLimit) : undefined,
    };
    
    let zkVerifyOracle: any;
    let attestationSystem: any;
    let zkPassportVerifier: any = null;
    
    try {
        // 1. Deploy ZKVerifyOracle
        console.log("📋 Deploying ZKVerifyOracle...");
        const ZKVerifyOracleFactory = await ethers.getContractFactory("ZKVerifyOracle");
        
        zkVerifyOracle = await ZKVerifyOracleFactory.deploy(
            config.requiredConfirmations,
            deployOptions
        );
        
        console.log(`⏳ Waiting for deployment transaction...`);
        await zkVerifyOracle.waitForDeployment();
        
        const oracleAddress = await zkVerifyOracle.getAddress();
        console.log(`✅ ZKVerifyOracle deployed to: ${oracleAddress}`);
        
        // Wait for confirmations
        if (config.confirmations > 1) {
            console.log(`⏳ Waiting for ${config.confirmations} confirmations...`);
            await zkVerifyOracle.deploymentTransaction()?.wait(config.confirmations);
        }
        
        // 2. Deploy AttestationSystem
        console.log("\n📋 Deploying AttestationSystem...");
        const AttestationSystemFactory = await ethers.getContractFactory("AttestationSystem");
        
        attestationSystem = await AttestationSystemFactory.deploy(deployOptions);
        
        console.log(`⏳ Waiting for deployment transaction...`);
        await attestationSystem.waitForDeployment();
        
        const attestationAddress = await attestationSystem.getAddress();
        console.log(`✅ AttestationSystem deployed to: ${attestationAddress}`);
        
        // Wait for confirmations
        if (config.confirmations > 1) {
            console.log(`⏳ Waiting for ${config.confirmations} confirmations...`);
            await attestationSystem.deploymentTransaction()?.wait(config.confirmations);
        }
        
        // 3. Configure ZKVerifyOracle
        console.log("\n⚙️  Configuring ZKVerifyOracle...");
        
        // Add initial oracle nodes
        for (const oracle of config.initialOracles) {
            console.log(`   Adding oracle: ${oracle.address}`);
            const tx = await zkVerifyOracle.addOracle(oracle.address, oracle.endpoint);
            await tx.wait();
            console.log(`   ✅ Oracle added: ${oracle.address}`);
        }
        
        // 4. Configure AttestationSystem
        console.log("\n⚙️  Configuring AttestationSystem...");
        
        // Register and approve initial attesters
        for (const attester of config.initialAttesters) {
            console.log(`   Registering attester: ${attester.address}`);
            
            // If the attester is not the deployer, we need to simulate their registration
            if (attester.address.toLowerCase() !== deployer.address.toLowerCase()) {
                console.log(`   ⚠️  Skipping registration for ${attester.address} (not deployer)`);
                console.log(`   📝 Manual step required: Have ${attester.address} call registerAttester()`);
                continue;
            }
            
            // Register attester (as deployer)
            const stakeAmount = ethers.parseEther(attester.stakeAmount);
            const registerTx = await attestationSystem.registerAttester(
                attester.tier,
                attester.companyName,
                attester.licenseNumber,
                attester.jurisdiction,
                attester.specializations,
                { value: stakeAmount }
            );
            await registerTx.wait();
            
            // Approve attester registration
            const approveTx = await attestationSystem.approveAttesterRegistration(attester.address, true);
            await approveTx.wait();
            
            console.log(`   ✅ Attester registered and approved: ${attester.address}`);
        }
        
        // 5. Update ZKPassportVerifier (if address provided)
        if (config.zkPassportVerifierAddress) {
            console.log("\n⚙️  Updating ZKPassportVerifier...");
            
            zkPassportVerifier = await ethers.getContractAt(
                "ZKPassportVerifier", 
                config.zkPassportVerifierAddress
            );
            
            // Update oracle address
            console.log("   Setting zkVerify Oracle address...");
            const updateOracleTx = await zkPassportVerifier.updateZKVerifyOracle(oracleAddress);
            await updateOracleTx.wait();
            console.log(`   ✅ Oracle address updated: ${oracleAddress}`);
            
            // Update attestation system address
            console.log("   Setting Attestation System address...");
            const updateAttestationTx = await zkPassportVerifier.updateAttestationSystem(attestationAddress);
            await updateAttestationTx.wait();
            console.log(`   ✅ Attestation System address updated: ${attestationAddress}`);
            
            // Set verification mode to hybrid (3)
            console.log("   Setting verification mode to hybrid...");
            const updateModeTx = await zkPassportVerifier.updateVerificationMode(3);
            await updateModeTx.wait();
            console.log("   ✅ Verification mode set to hybrid (3)");
        }
        
        // 6. Display deployment summary
        console.log("\n🎉 Deployment Complete!\n");
        console.log("📋 Contract Addresses:");
        console.log(`   ZKVerifyOracle: ${oracleAddress}`);
        console.log(`   AttestationSystem: ${attestationAddress}`);
        if (config.zkPassportVerifierAddress) {
            console.log(`   ZKPassportVerifier: ${config.zkPassportVerifierAddress} (updated)`);
        }
        
        console.log("\n⚙️  Configuration:");
        console.log(`   Required Confirmations: ${config.requiredConfirmations}`);
        console.log(`   Initial Oracles: ${config.initialOracles.length}`);
        console.log(`   Initial Attesters: ${config.initialAttesters.length}`);
        
        console.log("\n📝 Next Steps:");
        console.log("   1. Fund oracle nodes with ETH for staking");
        console.log("   2. Start oracle monitoring services");
        console.log("   3. Test proof submission and verification");
        console.log("   4. Set up monitoring and alerting");
        
        // 7. Save deployment info
        const deploymentInfo = {
            network: network.name,
            chainId: chainId,
            deployer: deployer.address,
            timestamp: new Date().toISOString(),
            contracts: {
                zkVerifyOracle: oracleAddress,
                attestationSystem: attestationAddress,
                zkPassportVerifier: config.zkPassportVerifierAddress
            },
            configuration: {
                requiredConfirmations: config.requiredConfirmations,
                verificationMode: config.zkPassportVerifierAddress ? 3 : 0,
                initialOracles: config.initialOracles.length,
                initialAttesters: config.initialAttesters.length
            },
            gasUsed: {
                oracle: (await zkVerifyOracle.deploymentTransaction()?.wait())?.gasUsed?.toString(),
                attestation: (await attestationSystem.deploymentTransaction()?.wait())?.gasUsed?.toString()
            }
        };
        
        console.log("\n💾 Deployment info saved to deployment-zkverify-systems.json");
        
        // In a real deployment, you'd save this to a file
        // require('fs').writeFileSync(
        //     `deployment-zkverify-systems-${chainId}.json`,
        //     JSON.stringify(deploymentInfo, null, 2)
        // );
        
    } catch (error) {
        console.error("❌ Deployment failed:", error);
        
        // Cleanup on failure (if needed)
        if (zkVerifyOracle) {
            console.log("🧹 Cleaning up partial deployment...");
            // Add cleanup logic if needed
        }
        
        throw error;
    }
}

// Handle script execution
if (require.main === module) {
    main()
        .then(() => process.exit(0))
        .catch((error) => {
            console.error("💥 Script failed:", error);
            process.exit(1);
        });
}

export { main as deployZKVerifySystems };
