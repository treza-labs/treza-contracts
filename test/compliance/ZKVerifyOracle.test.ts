import { expect } from "chai";
import { ethers } from "hardhat";
import { Contract, Signer } from "ethers";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";

describe("ZKVerifyOracle", function () {
    // Test fixture for deployment
    async function deployZKVerifyOracleFixture() {
        const [owner, oracle1, oracle2, oracle3, challenger, user] = await ethers.getSigners();
        
        const ZKVerifyOracle = await ethers.getContractFactory("ZKVerifyOracle");
        const zkVerifyOracle = await ZKVerifyOracle.deploy(2); // Require 2 confirmations
        
        return {
            zkVerifyOracle,
            owner,
            oracle1,
            oracle2,
            oracle3,
            challenger,
            user
        };
    }
    
    describe("Deployment", function () {
        it("Should deploy with correct initial configuration", async function () {
            const { zkVerifyOracle, owner } = await loadFixture(deployZKVerifyOracleFixture);
            
            expect(await zkVerifyOracle.owner()).to.equal(owner.address);
            expect(await zkVerifyOracle.getRequiredConfirmations()).to.equal(2);
            expect(await zkVerifyOracle.getActiveOracleCount()).to.equal(0);
        });
    });
    
    describe("Oracle Management", function () {
        it("Should allow owner to add oracles", async function () {
            const { zkVerifyOracle, owner, oracle1 } = await loadFixture(deployZKVerifyOracleFixture);
            
            await expect(zkVerifyOracle.addOracle(oracle1.address, "https://oracle1.example.com"))
                .to.emit(zkVerifyOracle, "OracleAdded")
                .withArgs(oracle1.address, 0);
            
            const oracleNode = await zkVerifyOracle.getOracleNode(oracle1.address);
            expect(oracleNode.isActive).to.be.true;
            expect(oracleNode.endpoint).to.equal("https://oracle1.example.com");
            expect(await zkVerifyOracle.getActiveOracleCount()).to.equal(1);
        });
        
        it("Should not allow non-owner to add oracles", async function () {
            const { zkVerifyOracle, oracle1, oracle2 } = await loadFixture(deployZKVerifyOracleFixture);
            
            await expect(
                zkVerifyOracle.connect(oracle1).addOracle(oracle2.address, "https://oracle2.example.com")
            ).to.be.revertedWithCustomError(zkVerifyOracle, "OwnableUnauthorizedAccount");
        });
        
        it("Should allow owner to remove oracles", async function () {
            const { zkVerifyOracle, owner, oracle1 } = await loadFixture(deployZKVerifyOracleFixture);
            
            // Add oracle first
            await zkVerifyOracle.addOracle(oracle1.address, "https://oracle1.example.com");
            
            // Remove oracle
            await expect(zkVerifyOracle.removeOracle(oracle1.address, "Test removal"))
                .to.emit(zkVerifyOracle, "OracleRemoved")
                .withArgs(oracle1.address, "Test removal");
            
            const oracleNode = await zkVerifyOracle.getOracleNode(oracle1.address);
            expect(oracleNode.isActive).to.be.false;
            expect(await zkVerifyOracle.getActiveOracleCount()).to.equal(0);
        });
    });
    
    describe("Oracle Staking", function () {
        it("Should allow oracles to stake ETH", async function () {
            const { zkVerifyOracle, oracle1 } = await loadFixture(deployZKVerifyOracleFixture);
            
            // Add oracle
            await zkVerifyOracle.addOracle(oracle1.address, "https://oracle1.example.com");
            
            // Stake ETH
            const stakeAmount = ethers.parseEther("2");
            await zkVerifyOracle.connect(oracle1).stakeAsOracle({ value: stakeAmount });
            
            const oracleNode = await zkVerifyOracle.getOracleNode(oracle1.address);
            expect(oracleNode.stakedAmount).to.equal(stakeAmount);
        });
        
        it("Should allow oracles to unstake ETH", async function () {
            const { zkVerifyOracle, oracle1 } = await loadFixture(deployZKVerifyOracleFixture);
            
            // Add oracle and stake
            await zkVerifyOracle.addOracle(oracle1.address, "https://oracle1.example.com");
            const stakeAmount = ethers.parseEther("2");
            await zkVerifyOracle.connect(oracle1).stakeAsOracle({ value: stakeAmount });
            
            // Unstake partial amount
            const unstakeAmount = ethers.parseEther("0.5");
            const initialBalance = await ethers.provider.getBalance(oracle1.address);
            
            await zkVerifyOracle.connect(oracle1).unstakeOracle(unstakeAmount);
            
            const oracleNode = await zkVerifyOracle.getOracleNode(oracle1.address);
            expect(oracleNode.stakedAmount).to.equal(stakeAmount - unstakeAmount);
        });
        
        it("Should not allow unstaking below minimum", async function () {
            const { zkVerifyOracle, oracle1 } = await loadFixture(deployZKVerifyOracleFixture);
            
            // Add oracle and stake minimum
            await zkVerifyOracle.addOracle(oracle1.address, "https://oracle1.example.com");
            const minStake = ethers.parseEther("1"); // MIN_STAKE_AMOUNT
            await zkVerifyOracle.connect(oracle1).stakeAsOracle({ value: minStake });
            
            // Try to unstake any amount (would go below minimum)
            await expect(
                zkVerifyOracle.connect(oracle1).unstakeOracle(ethers.parseEther("0.1"))
            ).to.be.revertedWith("Would go below minimum stake");
        });
    });
    
    describe("Proof Verification", function () {
        async function setupOraclesFixture() {
            const fixture = await deployZKVerifyOracleFixture();
            const { zkVerifyOracle, oracle1, oracle2 } = fixture;
            
            // Add oracles and stake
            await zkVerifyOracle.addOracle(oracle1.address, "https://oracle1.example.com");
            await zkVerifyOracle.addOracle(oracle2.address, "https://oracle2.example.com");
            
            const stakeAmount = ethers.parseEther("2");
            await zkVerifyOracle.connect(oracle1).stakeAsOracle({ value: stakeAmount });
            await zkVerifyOracle.connect(oracle2).stakeAsOracle({ value: stakeAmount });
            
            return fixture;
        }
        
        it("Should allow oracles to submit verification results", async function () {
            const { zkVerifyOracle, oracle1 } = await loadFixture(setupOraclesFixture);
            
            const proofHash = ethers.keccak256(ethers.toUtf8Bytes("test-proof"));
            const zkVerifyBlockHash = ethers.keccak256(ethers.toUtf8Bytes("zkverify-block"));
            
            // Create signature
            const messageHash = ethers.solidityPackedKeccak256(
                ["bytes32", "bool", "bytes32", "uint256", "address"],
                [proofHash, true, zkVerifyBlockHash, 31337, await zkVerifyOracle.getAddress()] // 31337 is hardhat chain id
            );
            const signature = await oracle1.signMessage(ethers.getBytes(messageHash));
            
            await expect(
                zkVerifyOracle.connect(oracle1).submitVerificationResult(
                    proofHash,
                    true,
                    zkVerifyBlockHash,
                    signature
                )
            ).to.emit(zkVerifyOracle, "VerificationSubmitted")
             .withArgs(proofHash, oracle1.address, true, zkVerifyBlockHash);
            
            const result = await zkVerifyOracle.getVerificationResult(proofHash);
            expect(result.verified).to.be.true;
            expect(result.confirmations).to.equal(1);
            expect(result.finalized).to.be.false; // Need 2 confirmations
        });
        
        it("Should finalize verification with enough confirmations", async function () {
            const { zkVerifyOracle, oracle1, oracle2 } = await loadFixture(setupOraclesFixture);
            
            const proofHash = ethers.keccak256(ethers.toUtf8Bytes("test-proof"));
            const zkVerifyBlockHash = ethers.keccak256(ethers.toUtf8Bytes("zkverify-block"));
            
            // First oracle submits
            const messageHash1 = ethers.solidityPackedKeccak256(
                ["bytes32", "bool", "bytes32", "uint256", "address"],
                [proofHash, true, zkVerifyBlockHash, 31337, await zkVerifyOracle.getAddress()]
            );
            const signature1 = await oracle1.signMessage(ethers.getBytes(messageHash1));
            
            await zkVerifyOracle.connect(oracle1).submitVerificationResult(
                proofHash,
                true,
                zkVerifyBlockHash,
                signature1
            );
            
            // Second oracle submits
            const messageHash2 = ethers.solidityPackedKeccak256(
                ["bytes32", "bool", "bytes32", "uint256", "address"],
                [proofHash, true, zkVerifyBlockHash, 31337, await zkVerifyOracle.getAddress()]
            );
            const signature2 = await oracle2.signMessage(ethers.getBytes(messageHash2));
            
            await expect(
                zkVerifyOracle.connect(oracle2).submitVerificationResult(
                    proofHash,
                    true,
                    zkVerifyBlockHash,
                    signature2
                )
            ).to.emit(zkVerifyOracle, "VerificationFinalized")
             .withArgs(proofHash, true, 2);
            
            const result = await zkVerifyOracle.getVerificationResult(proofHash);
            expect(result.finalized).to.be.true;
            expect(result.confirmations).to.equal(2);
            
            // Should return true for isProofVerified
            expect(await zkVerifyOracle.isProofVerified(proofHash)).to.be.true;
        });
        
        it("Should not allow duplicate confirmations from same oracle", async function () {
            const { zkVerifyOracle, oracle1 } = await loadFixture(setupOraclesFixture);
            
            const proofHash = ethers.keccak256(ethers.toUtf8Bytes("test-proof"));
            const zkVerifyBlockHash = ethers.keccak256(ethers.toUtf8Bytes("zkverify-block"));
            
            // First submission
            const messageHash = ethers.solidityPackedKeccak256(
                ["bytes32", "bool", "bytes32", "uint256", "address"],
                [proofHash, true, zkVerifyBlockHash, 31337, await zkVerifyOracle.getAddress()]
            );
            const signature = await oracle1.signMessage(ethers.getBytes(messageHash));
            
            await zkVerifyOracle.connect(oracle1).submitVerificationResult(
                proofHash,
                true,
                zkVerifyBlockHash,
                signature
            );
            
            // Second submission from same oracle should fail
            await expect(
                zkVerifyOracle.connect(oracle1).submitVerificationResult(
                    proofHash,
                    true,
                    zkVerifyBlockHash,
                    signature
                )
            ).to.be.revertedWith("Already confirmed");
        });
        
        it("Should handle batch submissions", async function () {
            const { zkVerifyOracle, oracle1 } = await loadFixture(setupOraclesFixture);
            
            const proofHashes = [
                ethers.keccak256(ethers.toUtf8Bytes("test-proof-1")),
                ethers.keccak256(ethers.toUtf8Bytes("test-proof-2"))
            ];
            const verificationResults = [true, false];
            const zkVerifyBlockHashes = [
                ethers.keccak256(ethers.toUtf8Bytes("zkverify-block-1")),
                ethers.keccak256(ethers.toUtf8Bytes("zkverify-block-2"))
            ];
            
            // Create batch signature
            const batchHash = ethers.solidityPackedKeccak256(
                ["bytes32[]", "bool[]", "bytes32[]", "uint256", "address"],
                [proofHashes, verificationResults, zkVerifyBlockHashes, 31337, await zkVerifyOracle.getAddress()]
            );
            const signature = await oracle1.signMessage(ethers.getBytes(batchHash));
            
            await expect(
                zkVerifyOracle.connect(oracle1).batchSubmitVerificationResults(
                    proofHashes,
                    verificationResults,
                    zkVerifyBlockHashes,
                    signature
                )
            ).to.emit(zkVerifyOracle, "VerificationSubmitted");
            
            // Check both proofs were processed
            const result1 = await zkVerifyOracle.getVerificationResult(proofHashes[0]);
            const result2 = await zkVerifyOracle.getVerificationResult(proofHashes[1]);
            
            expect(result1.verified).to.be.true;
            expect(result2.verified).to.be.false;
        });
    });
    
    describe("Challenge System", function () {
        async function setupChallengeFixture() {
            const fixture = await setupOraclesFixture();
            const { zkVerifyOracle, oracle1 } = fixture;
            
            // Submit a verification result
            const proofHash = ethers.keccak256(ethers.toUtf8Bytes("test-proof"));
            const zkVerifyBlockHash = ethers.keccak256(ethers.toUtf8Bytes("zkverify-block"));
            
            const messageHash = ethers.solidityPackedKeccak256(
                ["bytes32", "bool", "bytes32", "uint256", "address"],
                [proofHash, true, zkVerifyBlockHash, 31337, await zkVerifyOracle.getAddress()]
            );
            const signature = await oracle1.signMessage(ethers.getBytes(messageHash));
            
            await zkVerifyOracle.connect(oracle1).submitVerificationResult(
                proofHash,
                true,
                zkVerifyBlockHash,
                signature
            );
            
            return { ...fixture, proofHash, zkVerifyBlockHash };
        }
        
        it("Should allow challenges with sufficient stake", async function () {
            const { zkVerifyOracle, challenger, oracle1, proofHash } = await loadFixture(setupChallengeFixture);
            
            const challengeStake = ethers.parseEther("0.1");
            const evidence = ethers.toUtf8Bytes("Evidence that oracle was wrong");
            
            await expect(
                zkVerifyOracle.connect(challenger).challengeSubmission(
                    proofHash,
                    oracle1.address,
                    evidence,
                    { value: challengeStake }
                )
            ).to.emit(zkVerifyOracle, "AttestationChallenged");
        });
        
        it("Should not allow challenges with insufficient stake", async function () {
            const { zkVerifyOracle, challenger, oracle1, proofHash } = await loadFixture(setupChallengeFixture);
            
            const insufficientStake = ethers.parseEther("0.05"); // Less than 0.1 ETH required
            const evidence = ethers.toUtf8Bytes("Evidence that oracle was wrong");
            
            await expect(
                zkVerifyOracle.connect(challenger).challengeSubmission(
                    proofHash,
                    oracle1.address,
                    evidence,
                    { value: insufficientStake }
                )
            ).to.be.revertedWith("Insufficient challenge stake");
        });
        
        it("Should allow owner to resolve challenges", async function () {
            const { zkVerifyOracle, owner, challenger, oracle1, proofHash } = await loadFixture(setupChallengeFixture);
            
            // Submit challenge
            const challengeStake = ethers.parseEther("0.1");
            const evidence = ethers.toUtf8Bytes("Evidence that oracle was wrong");
            
            await zkVerifyOracle.connect(challenger).challengeSubmission(
                proofHash,
                oracle1.address,
                evidence,
                { value: challengeStake }
            );
            
            // Resolve challenge (oracle was wrong)
            await expect(
                zkVerifyOracle.connect(owner).resolveChallenge(1, true) // challengeId = 1, oracleWasWrong = true
            ).to.emit(zkVerifyOracle, "ChallengeResolved")
             .withArgs(1, true, 0); // challengeId, challengerWon, slashAmount
        });
    });
    
    describe("Access Control", function () {
        it("Should only allow active oracles to submit results", async function () {
            const { zkVerifyOracle, user } = await loadFixture(deployZKVerifyOracleFixture);
            
            const proofHash = ethers.keccak256(ethers.toUtf8Bytes("test-proof"));
            const zkVerifyBlockHash = ethers.keccak256(ethers.toUtf8Bytes("zkverify-block"));
            const signature = "0x" + "00".repeat(65); // Dummy signature
            
            await expect(
                zkVerifyOracle.connect(user).submitVerificationResult(
                    proofHash,
                    true,
                    zkVerifyBlockHash,
                    signature
                )
            ).to.be.revertedWith("Not an active oracle");
        });
        
        it("Should only allow owner to update required confirmations", async function () {
            const { zkVerifyOracle, user } = await loadFixture(deployZKVerifyOracleFixture);
            
            await expect(
                zkVerifyOracle.connect(user).updateRequiredConfirmations(3)
            ).to.be.revertedWithCustomError(zkVerifyOracle, "OwnableUnauthorizedAccount");
        });
    });
    
    describe("Pausable Functionality", function () {
        it("Should allow owner to pause and resume", async function () {
            const { zkVerifyOracle, owner } = await loadFixture(deployZKVerifyOracleFixture);
            
            await zkVerifyOracle.connect(owner).pauseOracle();
            expect(await zkVerifyOracle.paused()).to.be.true;
            
            await zkVerifyOracle.connect(owner).resumeOracle();
            expect(await zkVerifyOracle.paused()).to.be.false;
        });
        
        it("Should prevent submissions when paused", async function () {
            const { zkVerifyOracle, owner, oracle1 } = await loadFixture(deployZKVerifyOracleFixture);
            
            // Setup oracle
            await zkVerifyOracle.addOracle(oracle1.address, "https://oracle1.example.com");
            await zkVerifyOracle.connect(oracle1).stakeAsOracle({ value: ethers.parseEther("2") });
            
            // Pause contract
            await zkVerifyOracle.connect(owner).pauseOracle();
            
            const proofHash = ethers.keccak256(ethers.toUtf8Bytes("test-proof"));
            const zkVerifyBlockHash = ethers.keccak256(ethers.toUtf8Bytes("zkverify-block"));
            const signature = "0x" + "00".repeat(65); // Dummy signature
            
            await expect(
                zkVerifyOracle.connect(oracle1).submitVerificationResult(
                    proofHash,
                    true,
                    zkVerifyBlockHash,
                    signature
                )
            ).to.be.revertedWithCustomError(zkVerifyOracle, "EnforcedPause");
        });
    });
});
