import { ethers } from "hardhat";
import * as fs from "fs";
import * as path from "path";

/**
 * Deploy PIIConsentRegistry and optionally link KYCVerifier + consent registry addresses.
 *
 * Usage:
 *   npx hardhat run scripts/deploy-pii-contracts.ts --network sepolia
 *
 * Env:
 *   KYC_VERIFIER_ADDRESS — if set, calls setPiiConsentRegistry on KYCVerifier after deploy.
 */
async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying PIIConsentRegistry with:", deployer.address);

  const Factory = await ethers.getContractFactory("PIIConsentRegistry");
  const registry = await Factory.deploy();
  await registry.waitForDeployment();
  const registryAddress = await registry.getAddress();
  console.log("PIIConsentRegistry:", registryAddress);

  const kycAddr = process.env.KYC_VERIFIER_ADDRESS;
  if (kycAddr) {
    const kyc = await ethers.getContractAt("KYCVerifier", kycAddr, deployer);
    const tx = await kyc.setPiiConsentRegistry(registryAddress);
    await tx.wait();
    console.log("Linked KYCVerifier -> piiConsentRegistry");
    const tx2 = await registry.setKycVerifier(kycAddr);
    await tx2.wait();
    console.log("Linked PIIConsentRegistry -> kycVerifier");
  }

  const outDir = path.join(__dirname, "../deployments");
  if (!fs.existsSync(outDir)) fs.mkdirSync(outDir, { recursive: true });
  const net = await ethers.provider.getNetwork();
  fs.writeFileSync(
    path.join(outDir, `pii-consent-${net.chainId}.json`),
    JSON.stringify({ registry: registryAddress, kycVerifier: kycAddr || null }, null, 2)
  );
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
