import { expect } from "chai";
import { ethers } from "hardhat";
import { Signer } from "ethers";
import { time } from "@nomicfoundation/hardhat-network-helpers";
import { ZKPassportVerifier } from "../../typechain-types";

describe("ZKPassportVerifier", function () {
    let zkPassportVerifier: ZKPassportVerifier;
    let owner: Signer;
    let user1: Signer;
    let user2: Signer;
    let verifier: Signer;
    let ownerAddress: string;
    let user1Address: string;
    let user2Address: string;
    let verifierAddress: string;

    const mockZKVerifyContract = "0x0000000000000000000000000000000000000000";
    const allowedCountries = ["US", "CA", "GB"];
    const proofHash1 = ethers.keccak256(ethers.toUtf8Bytes("proof1"));
    const proofHash2 = ethers.keccak256(ethers.toUtf8Bytes("proof2"));

    beforeEach(async function () {
        [owner, user1, user2, verifier] = await ethers.getSigners();
        ownerAddress = await owner.getAddress();
        user1Address = await user1.getAddress();
        user2Address = await user2.getAddress();
        verifierAddress = await verifier.getAddress();

        const ZKPassportVerifierFactory = await ethers.getContractFactory("ZKPassportVerifier");
        zkPassportVerifier = await ZKPassportVerifierFactory.deploy(
            mockZKVerifyContract,
            allowedCountries
        );
        await zkPassportVerifier.waitForDeployment();
    });

    describe("Deployment", function () {
        it("Should set the correct owner", async function () {
            expect(await zkPassportVerifier.owner()).to.equal(ownerAddress);
        });

        it("Should set the correct zkVerify contract", async function () {
            expect(await zkPassportVerifier.zkVerifyContract()).to.equal(mockZKVerifyContract);
        });

        it("Should set the correct allowed countries", async function () {
            const countries = await zkPassportVerifier.getAllowedCountries();
            expect(countries).to.deep.equal(allowedCountries);
        });

        it("Should set default minimum age to 18", async function () {
            expect(await zkPassportVerifier.minAge()).to.equal(18);
        });

        it("Should set default proof validity period to 1 year", async function () {
            const oneYear = 365 * 24 * 60 * 60;
            expect(await zkPassportVerifier.proofValidityPeriod()).to.equal(oneYear);
        });

        it("Should add deployer as authorized verifier", async function () {
            expect(await zkPassportVerifier.authorizedVerifiers(ownerAddress)).to.be.true;
        });
    });

    describe("Authorized Verifiers", function () {
        it("Should allow owner to add authorized verifier", async function () {
            await expect(zkPassportVerifier.addAuthorizedVerifier(verifierAddress))
                .to.emit(zkPassportVerifier, "AuthorizedVerifierAdded")
                .withArgs(verifierAddress);

            expect(await zkPassportVerifier.authorizedVerifiers(verifierAddress)).to.be.true;
        });

        it("Should allow owner to remove authorized verifier", async function () {
            await zkPassportVerifier.addAuthorizedVerifier(verifierAddress);
            
            await expect(zkPassportVerifier.removeAuthorizedVerifier(verifierAddress))
                .to.emit(zkPassportVerifier, "AuthorizedVerifierRemoved")
                .withArgs(verifierAddress);

            expect(await zkPassportVerifier.authorizedVerifiers(verifierAddress)).to.be.false;
        });

        it("Should not allow non-owner to add authorized verifier", async function () {
            await expect(
                zkPassportVerifier.connect(user1).addAuthorizedVerifier(verifierAddress)
            ).to.be.revertedWith("Ownable: caller is not the owner");
        });
    });

    describe("Compliance Verification", function () {
        beforeEach(async function () {
            await zkPassportVerifier.addAuthorizedVerifier(verifierAddress);
        });

        it("Should allow authorized verifier to verify compliance", async function () {
            await expect(
                zkPassportVerifier.connect(verifier).verifyCompliance(
                    user1Address,
                    proofHash1,
                    "basic"
                )
            ).to.emit(zkPassportVerifier, "ComplianceVerified")
            .withArgs(user1Address, proofHash1, await time.latest() + 1);

            expect(await zkPassportVerifier.isCompliant(user1Address)).to.be.true;
        });

        it("Should not allow unauthorized verifier to verify compliance", async function () {
            await expect(
                zkPassportVerifier.connect(user2).verifyCompliance(
                    user1Address,
                    proofHash1,
                    "basic"
                )
            ).to.be.revertedWith("Not authorized verifier");
        });

        it("Should not allow reuse of proof hash", async function () {
            await zkPassportVerifier.connect(verifier).verifyCompliance(
                user1Address,
                proofHash1,
                "basic"
            );

            await expect(
                zkPassportVerifier.connect(verifier).verifyCompliance(
                    user2Address,
                    proofHash1,
                    "basic"
                )
            ).to.be.revertedWith("Proof hash already used");
        });

        it("Should return correct compliance status", async function () {
            await zkPassportVerifier.connect(verifier).verifyCompliance(
                user1Address,
                proofHash1,
                "enhanced"
            );

            const status = await zkPassportVerifier.getComplianceStatus(user1Address);
            expect(status.isVerified).to.be.true;
            expect(status.proofHash).to.equal(proofHash1);
            expect(status.verificationLevel).to.equal("enhanced");
        });

        it("Should update total verified users count", async function () {
            expect(await zkPassportVerifier.totalVerifiedUsers()).to.equal(0);

            await zkPassportVerifier.connect(verifier).verifyCompliance(
                user1Address,
                proofHash1,
                "basic"
            );

            expect(await zkPassportVerifier.totalVerifiedUsers()).to.equal(1);

            await zkPassportVerifier.connect(verifier).verifyCompliance(
                user2Address,
                proofHash2,
                "basic"
            );

            expect(await zkPassportVerifier.totalVerifiedUsers()).to.equal(2);
        });
    });

    describe("Compliance Expiration", function () {
        beforeEach(async function () {
            await zkPassportVerifier.addAuthorizedVerifier(verifierAddress);
            await zkPassportVerifier.connect(verifier).verifyCompliance(
                user1Address,
                proofHash1,
                "basic"
            );
        });

        it("Should return false for expired compliance", async function () {
            // Fast forward time beyond validity period
            const oneYear = 365 * 24 * 60 * 60;
            await time.increase(oneYear + 1);

            expect(await zkPassportVerifier.isCompliant(user1Address)).to.be.false;
        });

        it("Should return true for non-expired compliance", async function () {
            // Fast forward time but not beyond validity period
            const sixMonths = 180 * 24 * 60 * 60;
            await time.increase(sixMonths);

            expect(await zkPassportVerifier.isCompliant(user1Address)).to.be.true;
        });

        it("Should correctly identify expired compliance", async function () {
            const oneYear = 365 * 24 * 60 * 60;
            await time.increase(oneYear + 1);

            expect(await zkPassportVerifier.isComplianceExpired(user1Address)).to.be.true;
        });
    });

    describe("Batch Operations", function () {
        beforeEach(async function () {
            await zkPassportVerifier.addAuthorizedVerifier(verifierAddress);
            
            // Verify user1
            await zkPassportVerifier.connect(verifier).verifyCompliance(
                user1Address,
                proofHash1,
                "basic"
            );
        });

        it("Should batch check compliance correctly", async function () {
            const users = [user1Address, user2Address];
            const results = await zkPassportVerifier.batchCheckCompliance(users);

            expect(results[0]).to.be.true;  // user1 is compliant
            expect(results[1]).to.be.false; // user2 is not compliant
        });
    });

    describe("Admin Functions", function () {
        it("Should allow owner to update requirements", async function () {
            const newMinAge = 21;
            const newCountries = ["US", "CA"];

            await expect(
                zkPassportVerifier.updateRequirements(newMinAge, newCountries)
            ).to.emit(zkPassportVerifier, "RequirementsUpdated")
            .withArgs(newMinAge, newCountries);

            expect(await zkPassportVerifier.minAge()).to.equal(newMinAge);
            
            const countries = await zkPassportVerifier.getAllowedCountries();
            expect(countries).to.deep.equal(newCountries);
        });

        it("Should allow owner to update proof validity period", async function () {
            const newPeriod = 180 * 24 * 60 * 60; // 6 months

            await expect(
                zkPassportVerifier.updateProofValidityPeriod(newPeriod)
            ).to.emit(zkPassportVerifier, "ProofValidityPeriodUpdated");

            expect(await zkPassportVerifier.proofValidityPeriod()).to.equal(newPeriod);
        });

        it("Should allow owner to revoke compliance", async function () {
            await zkPassportVerifier.addAuthorizedVerifier(verifierAddress);
            await zkPassportVerifier.connect(verifier).verifyCompliance(
                user1Address,
                proofHash1,
                "basic"
            );

            expect(await zkPassportVerifier.totalVerifiedUsers()).to.equal(1);

            await expect(zkPassportVerifier.revokeCompliance(user1Address))
                .to.emit(zkPassportVerifier, "ComplianceRevoked")
                .withArgs(user1Address, await time.latest() + 1);

            expect(await zkPassportVerifier.isCompliant(user1Address)).to.be.false;
            expect(await zkPassportVerifier.totalVerifiedUsers()).to.equal(0);
        });

        it("Should not allow non-owner to update requirements", async function () {
            await expect(
                zkPassportVerifier.connect(user1).updateRequirements(21, ["US"])
            ).to.be.revertedWith("Ownable: caller is not the owner");
        });
    });

    describe("Country Validation", function () {
        it("Should correctly identify allowed countries", async function () {
            expect(await zkPassportVerifier.isCountryAllowed("US")).to.be.true;
            expect(await zkPassportVerifier.isCountryAllowed("CA")).to.be.true;
            expect(await zkPassportVerifier.isCountryAllowed("GB")).to.be.true;
            expect(await zkPassportVerifier.isCountryAllowed("FR")).to.be.false;
        });

        it("Should update country allowlist correctly", async function () {
            const newCountries = ["US", "FR", "DE"];
            await zkPassportVerifier.updateRequirements(18, newCountries);

            expect(await zkPassportVerifier.isCountryAllowed("US")).to.be.true;
            expect(await zkPassportVerifier.isCountryAllowed("FR")).to.be.true;
            expect(await zkPassportVerifier.isCountryAllowed("DE")).to.be.true;
            expect(await zkPassportVerifier.isCountryAllowed("CA")).to.be.false;
            expect(await zkPassportVerifier.isCountryAllowed("GB")).to.be.false;
        });
    });

    describe("Contract Stats", function () {
        it("Should return correct contract statistics", async function () {
            const stats = await zkPassportVerifier.getContractStats();
            
            expect(stats.totalUsers).to.equal(0);
            expect(stats.totalCountries).to.equal(allowedCountries.length);
            expect(stats.currentMinAge).to.equal(18);
            expect(stats.currentValidityPeriod).to.equal(365 * 24 * 60 * 60);
        });
    });
});
