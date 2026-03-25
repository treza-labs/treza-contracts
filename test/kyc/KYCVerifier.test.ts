import { expect } from "chai";
import { ethers } from "hardhat";
import { KYCVerifier, PIIConsentRegistry } from "../../typechain-types";
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";

describe("KYCVerifier", function () {
  let verifier: KYCVerifier;
  let owner: SignerWithAddress;
  let user1: SignerWithAddress;
  let user2: SignerWithAddress;
  let verifierRole: SignerWithAddress;

  const sampleCommitment = ethers.keccak256(
    ethers.toUtf8Bytes("John|Doe|1982-03-21|C13016372|salt123")
  );
  const sampleProof = ethers.toUtf8Bytes("proof_signature_data_here");
  const samplePublicInputs = [
    "country:United States",
    "documentType:Passport",
    "isAdult:true",
    "documentValid:true"
  ];

  beforeEach(async function () {
    [owner, user1, user2, verifierRole] = await ethers.getSigners();

    const KYCVerifier = await ethers.getContractFactory("KYCVerifier");
    verifier = await KYCVerifier.deploy();
    await verifier.waitForDeployment();
  });

  describe("Deployment", function () {
    it("Should set the deployer as admin", async function () {
      const ADMIN_ROLE = await verifier.ADMIN_ROLE();
      expect(await verifier.hasRole(ADMIN_ROLE, owner.address)).to.be.true;
    });

    it("Should set default validity period to 30 days", async function () {
      const period = await verifier.proofValidityPeriod();
      expect(period).to.equal(30 * 24 * 60 * 60); // 30 days in seconds
    });

    it("Should return correct version", async function () {
      expect(await verifier.version()).to.equal("1.1.0");
    });
  });

  describe("Proof Submission", function () {
    it("Should allow users to submit proofs", async function () {
      const tx = await verifier.connect(user1).submitProof(
        sampleCommitment,
        sampleProof,
        samplePublicInputs
      );
      
      const receipt = await tx.wait();
      expect(receipt).to.not.be.null;

      // Check event was emitted
      const events = await verifier.queryFilter(
        verifier.filters.ProofSubmitted()
      );
      expect(events.length).to.be.greaterThan(0);
    });

    it("Should store proof correctly", async function () {
      const tx = await verifier.connect(user1).submitProof(
        sampleCommitment,
        sampleProof,
        samplePublicInputs
      );
      
      const receipt = await tx.wait();
      const event = (await verifier.queryFilter(
        verifier.filters.ProofSubmitted()
      ))[0];
      const proofId = event.args.proofId;

      const proof = await verifier.getProof(proofId);
      expect(proof.commitment).to.equal(sampleCommitment);
      expect(proof.submitter).to.equal(user1.address);
      expect(proof.publicInputs).to.deep.equal(samplePublicInputs);
    });

    it("Should update user's latest proof", async function () {
      const tx = await verifier.connect(user1).submitProof(
        sampleCommitment,
        sampleProof,
        samplePublicInputs
      );
      
      await tx.wait();
      const event = (await verifier.queryFilter(
        verifier.filters.ProofSubmitted()
      ))[0];
      const proofId = event.args.proofId;

      const userProofId = await verifier.getUserProofId(user1.address);
      expect(userProofId).to.equal(proofId);
    });

    it("Should reject duplicate commitments", async function () {
      await verifier.connect(user1).submitProof(
        sampleCommitment,
        sampleProof,
        samplePublicInputs
      );

      await expect(
        verifier.connect(user2).submitProof(
          sampleCommitment,
          sampleProof,
          samplePublicInputs
        )
      ).to.be.revertedWith("Commitment already exists");
    });

    it("Should reject empty commitment", async function () {
      await expect(
        verifier.connect(user1).submitProof(
          ethers.ZeroHash,
          sampleProof,
          samplePublicInputs
        )
      ).to.be.revertedWith("Invalid commitment");
    });

    it("Should reject empty proof", async function () {
      await expect(
        verifier.connect(user1).submitProof(
          sampleCommitment,
          new Uint8Array(0),
          samplePublicInputs
        )
      ).to.be.revertedWith("Empty proof");
    });
  });

  describe("Proof Verification", function () {
    let proofId: string;

    beforeEach(async function () {
      const tx = await verifier.connect(user1).submitProof(
        sampleCommitment,
        sampleProof,
        samplePublicInputs
      );
      
      await tx.wait();
      const event = (await verifier.queryFilter(
        verifier.filters.ProofSubmitted()
      ))[0];
      proofId = event.args.proofId;
    });

    it("Should allow anyone to verify proof", async function () {
      await expect(
        verifier.connect(user2).verifyProof(proofId)
      ).to.not.be.reverted;
    });

    it("Should mark proof as verified", async function () {
      await verifier.verifyProof(proofId);
      
      const proof = await verifier.getProof(proofId);
      expect(proof.isVerified).to.be.true;
    });

    it("Should emit ProofVerified event", async function () {
      await verifier.verifyProof(proofId);
      
      const events = await verifier.queryFilter(
        verifier.filters.ProofVerified()
      );
      expect(events.length).to.be.greaterThan(0);
      expect(events[0].args.isValid).to.be.true;
    });

    it("Should reject verifying same proof twice", async function () {
      await verifier.verifyProof(proofId);
      
      await expect(
        verifier.verifyProof(proofId)
      ).to.be.revertedWith("Proof already verified");
    });

    it("Should reject non-existent proof", async function () {
      const fakeProofId = ethers.keccak256(ethers.toUtf8Bytes("fake"));
      
      await expect(
        verifier.verifyProof(fakeProofId)
      ).to.be.revertedWith("Proof does not exist");
    });
  });

  describe("KYC Status", function () {
    it("Should return false for users without proofs", async function () {
      expect(await verifier.hasValidKYC(user1.address)).to.be.false;
    });

    it("Should return false for unverified proofs", async function () {
      await verifier.connect(user1).submitProof(
        sampleCommitment,
        sampleProof,
        samplePublicInputs
      );
      
      expect(await verifier.hasValidKYC(user1.address)).to.be.false;
    });

    it("Should return true for verified proofs", async function () {
      const tx = await verifier.connect(user1).submitProof(
        sampleCommitment,
        sampleProof,
        samplePublicInputs
      );
      
      await tx.wait();
      const event = (await verifier.queryFilter(
        verifier.filters.ProofSubmitted()
      ))[0];
      const proofId = event.args.proofId;
      
      await verifier.verifyProof(proofId);
      
      expect(await verifier.hasValidKYC(user1.address)).to.be.true;
    });
  });

  describe("Admin Functions", function () {
    it("Should allow admin to update validity period", async function () {
      const newPeriod = 60 * 24 * 60 * 60; // 60 days
      
      await verifier.setValidityPeriod(newPeriod);
      
      expect(await verifier.proofValidityPeriod()).to.equal(newPeriod);
    });

    it("Should reject non-admin updating validity period", async function () {
      const newPeriod = 60 * 24 * 60 * 60;
      
      await expect(
        verifier.connect(user1).setValidityPeriod(newPeriod)
      ).to.be.reverted;
    });

    it("Should allow admin to revoke proofs", async function () {
      const tx = await verifier.connect(user1).submitProof(
        sampleCommitment,
        sampleProof,
        samplePublicInputs
      );
      
      await tx.wait();
      const event = (await verifier.queryFilter(
        verifier.filters.ProofSubmitted()
      ))[0];
      const proofId = event.args.proofId;
      
      await verifier.verifyProof(proofId);
      expect(await verifier.hasValidKYC(user1.address)).to.be.true;
      
      await verifier.revokeProof(proofId);
      expect(await verifier.hasValidKYC(user1.address)).to.be.false;
    });
  });

  describe("Public Claims", function () {
    it("Should return correct public claims", async function () {
      const tx = await verifier.connect(user1).submitProof(
        sampleCommitment,
        sampleProof,
        samplePublicInputs
      );
      
      await tx.wait();
      const event = (await verifier.queryFilter(
        verifier.filters.ProofSubmitted()
      ))[0];
      const proofId = event.args.proofId;
      
      const claims = await verifier.getPublicClaims(proofId);
      expect(claims).to.deep.equal(samplePublicInputs);
    });
  });

  describe("PII artifact binding (KYC ↔ opaque hash)", function () {
    it("Should bind piiArtifactHash after verified proof", async function () {
      const tx = await verifier.connect(user1).submitProof(
        sampleCommitment,
        sampleProof,
        samplePublicInputs
      );
      await tx.wait();
      const event = (await verifier.queryFilter(verifier.filters.ProofSubmitted()))[0];
      const proofId = event.args.proofId;
      await verifier.verifyProof(proofId);

      const piiHash = ethers.keccak256(ethers.toUtf8Bytes("pii-envelope-ref"));
      await expect(verifier.connect(user1).bindPiiArtifactHash(sampleCommitment, piiHash))
        .to.emit(verifier, "PiiArtifactHashBound")
        .withArgs(user1.address, sampleCommitment, piiHash);

      expect(await verifier.kycCommitmentToPiiArtifactHash(sampleCommitment)).to.equal(piiHash);
    });

    it("Should reject bind from wrong wallet", async function () {
      const tx = await verifier.connect(user1).submitProof(
        sampleCommitment,
        sampleProof,
        samplePublicInputs
      );
      await tx.wait();
      const event = (await verifier.queryFilter(verifier.filters.ProofSubmitted()))[0];
      await verifier.verifyProof(event.args.proofId);

      const piiHash = ethers.keccak256(ethers.toUtf8Bytes("x"));
      await expect(
        verifier.connect(user2).bindPiiArtifactHash(sampleCommitment, piiHash)
      ).to.be.revertedWith("No proof for sender");
    });

    it("Should reject bind before KYC verification", async function () {
      const tx = await verifier.connect(user1).submitProof(
        sampleCommitment,
        sampleProof,
        samplePublicInputs
      );
      await tx.wait();
      const piiHash = ethers.keccak256(ethers.toUtf8Bytes("unverified-bind"));
      await expect(
        verifier.connect(user1).bindPiiArtifactHash(sampleCommitment, piiHash)
      ).to.be.revertedWith("KYC not verified");
    });

    it("Should reject bind after proof expiry", async function () {
      const tx = await verifier.connect(user1).submitProof(
        sampleCommitment,
        sampleProof,
        samplePublicInputs
      );
      await tx.wait();
      const event = (await verifier.queryFilter(verifier.filters.ProofSubmitted()))[0];
      await verifier.verifyProof(event.args.proofId);

      await ethers.provider.send("evm_increaseTime", [31 * 24 * 60 * 60]);
      await ethers.provider.send("evm_mine", []);

      const piiHash = ethers.keccak256(ethers.toUtf8Bytes("expired"));
      await expect(
        verifier.connect(user1).bindPiiArtifactHash(sampleCommitment, piiHash)
      ).to.be.revertedWith("KYC expired");
    });
  });

  describe("PII ↔ KYC integration", function () {
    let registry: PIIConsentRegistry;
    const piiHash = ethers.keccak256(ethers.toUtf8Bytes("consent-bound-pii"));
    const farFuture = Math.floor(Date.now() / 1000) + 86400 * 365;

    beforeEach(async function () {
      const Reg = await ethers.getContractFactory("PIIConsentRegistry");
      registry = await Reg.deploy();
      await registry.waitForDeployment();
    });

    it("assertValidKycForPii reflects hasValidKYC", async function () {
      await expect(verifier.assertValidKycForPii.staticCall(user1.address)).to.be.rejected;

      const tx = await verifier.connect(user1).submitProof(
        sampleCommitment,
        sampleProof,
        samplePublicInputs
      );
      await tx.wait();
      const event = (await verifier.queryFilter(verifier.filters.ProofSubmitted()))[0];
      await verifier.verifyProof(event.args.proofId);

      await expect(verifier.assertValidKycForPii.staticCall(user1.address)).to.be.fulfilled;
    });

    it("requireConsentForPii is a no-op when registry unset", async function () {
      await expect(
        verifier.requireConsentForPii.staticCall(user1.address, piiHash, user2.address)
      ).to.be.fulfilled;
    });

    it("requireConsentForPii enforces on-chain consent when registry is set", async function () {
      await verifier.setPiiConsentRegistry(await registry.getAddress());
      await registry.connect(owner).setKycVerifier(await verifier.getAddress());

      await expect(
        verifier.requireConsentForPii.staticCall(user1.address, piiHash, user2.address)
      ).to.be.rejected;

      const tx = await verifier.connect(user1).submitProof(
        sampleCommitment,
        sampleProof,
        samplePublicInputs
      );
      await tx.wait();
      const event = (await verifier.queryFilter(verifier.filters.ProofSubmitted()))[0];
      await verifier.verifyProof(event.args.proofId);

      await registry.connect(user1).grantConsent(piiHash, user2.address, farFuture);

      await expect(
        verifier.requireConsentForPii.staticCall(user1.address, piiHash, user2.address)
      ).to.be.fulfilled;
    });
  });
});

