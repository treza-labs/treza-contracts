import { expect } from "chai";
import { ethers } from "hardhat";
import { KYCVerifier, PIIConsentRegistry } from "../../typechain-types";
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";

describe("PIIConsentRegistry", function () {
  let registry: PIIConsentRegistry;
  let kyc: KYCVerifier;
  let owner: SignerWithAddress;
  let user: SignerWithAddress;
  let recipient: SignerWithAddress;

  const piiHash = ethers.keccak256(ethers.toUtf8Bytes("pii-commitment-demo"));
  const farFuture = Math.floor(Date.now() / 1000) + 86400 * 365;

  beforeEach(async function () {
    [owner, user, recipient] = await ethers.getSigners();

    const KYC = await ethers.getContractFactory("KYCVerifier");
    kyc = await KYC.deploy();
    await kyc.waitForDeployment();

    const Reg = await ethers.getContractFactory("PIIConsentRegistry");
    registry = await Reg.deploy();
    await registry.waitForDeployment();
  });

  it("grants and verifies consent without KYC gate", async function () {
    await registry.connect(user).grantConsent(piiHash, recipient.address, farFuture);
    expect(await registry.verifyConsent(user.address, piiHash, recipient.address)).to.equal(true);
    expect(await registry.verifyConsent(user.address, piiHash, owner.address)).to.equal(false);
  });

  it("revokes consent", async function () {
    const tx = await registry.connect(user).grantConsent(piiHash, recipient.address, farFuture);
    const receipt = await tx.wait();
    const parsed = receipt!.logs
      .map((log) => {
        try {
          return registry.interface.parseLog({
            topics: log.topics as string[],
            data: log.data,
          });
        } catch {
          return null;
        }
      })
      .find((p) => p?.name === "ConsentGranted");
    expect(parsed).to.not.equal(undefined);
    const consentId = parsed!.args.consentId as string;

    await registry.connect(user).revokeConsent(consentId);
    expect(await registry.verifyConsent(user.address, piiHash, recipient.address)).to.equal(false);
  });

  it("requires KYC when kycVerifier is set", async function () {
    await registry.connect(owner).setKycVerifier(await kyc.getAddress());

    await expect(
      registry.connect(user).grantConsent(piiHash, recipient.address, farFuture)
    ).to.be.revertedWith("KYC required");
  });

  it("verifyAttributeProof returns true for sufficiently long calldata", async function () {
    expect(await registry.verifyAttributeProof(ethers.randomBytes(33))).to.equal(true);
    expect(await registry.verifyAttributeProof(ethers.randomBytes(16))).to.equal(false);
  });
});
