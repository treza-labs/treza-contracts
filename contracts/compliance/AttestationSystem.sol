// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./interfaces/IAttestationSystem.sol";

/**
 * @title AttestationSystem
 * @dev Trusted attester verification system for zkVerify results
 * Allows qualified professionals to attest to zkVerify verification results
 */
contract AttestationSystem is IAttestationSystem, Ownable, ReentrancyGuard, Pausable {
    using ECDSA for bytes32;

    // =========================================================================
    // CONSTANTS
    // =========================================================================
    
    uint256 public constant ATTESTATION_VALIDITY_PERIOD = 180 days;
    uint256 public constant CHALLENGE_PERIOD = 7 days;
    uint256 public constant CHALLENGE_STAKE = 0.5 ether;
    uint256 public constant SLASH_PERCENTAGE = 30; // 30% of stake
    
    // Minimum stake requirements by tier
    mapping(AttesterTier => uint256) public minimumStakeByTier;
    
    // Attestation fees by tier and level
    mapping(AttesterTier => mapping(AttestationLevel => uint256)) public attestationFees;
    
    // =========================================================================
    // STATE VARIABLES
    // =========================================================================
    
    /// @notice Mapping of proof hashes to attestations
    mapping(bytes32 => Attestation) private attestations;
    
    /// @notice Mapping of attester addresses to their profiles
    mapping(address => AttesterProfile) private attesterProfiles;
    
    /// @notice Array of all registered attesters
    address[] private allAttesters;
    
    /// @notice Challenge counter for unique IDs
    uint256 private challengeCounter;
    
    /// @notice Mapping of challenge IDs to challenge data
    mapping(uint256 => Challenge) private challenges;
    
    /// @notice Mapping of proof hashes to challenge IDs
    mapping(bytes32 => uint256[]) private proofChallenges;
    
    /// @notice Pending attester registrations
    mapping(address => bool) private pendingRegistrations;
    
    /// @notice Total fees collected by the system
    uint256 public totalFeesCollected;
    
    /// @notice Protocol fee percentage (basis points)
    uint256 public protocolFeePercentage = 500; // 5%
    
    // =========================================================================
    // MODIFIERS
    // =========================================================================
    
    modifier onlyActiveAttester() {
        require(attesterProfiles[msg.sender].isActive, "Not an active attester");
        _;
    }
    
    modifier onlyQualifiedAttester(AttestationLevel level) {
        require(isQualifiedAttester(msg.sender, level), "Not qualified for this level");
        _;
    }
    
    modifier validProofHash(bytes32 proofHash) {
        require(proofHash != bytes32(0), "Invalid proof hash");
        _;
    }
    
    // =========================================================================
    // CONSTRUCTOR
    // =========================================================================
    
    constructor() Ownable(msg.sender) {
        // Initialize minimum stake requirements
        minimumStakeByTier[AttesterTier.BRONZE] = 1 ether;
        minimumStakeByTier[AttesterTier.SILVER] = 5 ether;
        minimumStakeByTier[AttesterTier.GOLD] = 10 ether;
        minimumStakeByTier[AttesterTier.PLATINUM] = 25 ether;
        
        // Initialize attestation fees (in wei)
        attestationFees[AttesterTier.BRONZE][AttestationLevel.BASIC] = 0.01 ether;
        attestationFees[AttesterTier.SILVER][AttestationLevel.BASIC] = 0.02 ether;
        attestationFees[AttesterTier.SILVER][AttestationLevel.ENHANCED] = 0.1 ether;
        attestationFees[AttesterTier.GOLD][AttestationLevel.BASIC] = 0.03 ether;
        attestationFees[AttesterTier.GOLD][AttestationLevel.ENHANCED] = 0.15 ether;
        attestationFees[AttesterTier.GOLD][AttestationLevel.INSTITUTIONAL] = 0.5 ether;
        attestationFees[AttesterTier.PLATINUM][AttestationLevel.BASIC] = 0.05 ether;
        attestationFees[AttesterTier.PLATINUM][AttestationLevel.ENHANCED] = 0.2 ether;
        attestationFees[AttesterTier.PLATINUM][AttestationLevel.INSTITUTIONAL] = 1 ether;
    }
    
    // =========================================================================
    // VIEW FUNCTIONS
    // =========================================================================
    
    function isProofAttested(bytes32 proofHash, AttestationLevel minLevel) 
        external view override returns (bool valid) {
        Attestation memory attestation = attestations[proofHash];
        
        return attestation.status == AttestationStatus.ACTIVE &&
               attestation.level >= minLevel &&
               attestation.timestamp > 0 &&
               block.timestamp <= attestation.expirationTimestamp &&
               attesterProfiles[attestation.attester].isActive;
    }
    
    function getAttestation(bytes32 proofHash) 
        external view override returns (Attestation memory attestation) {
        return attestations[proofHash];
    }
    
    function getAttesterProfile(address attester) 
        external view override returns (AttesterProfile memory profile) {
        return attesterProfiles[attester];
    }
    
    function isQualifiedAttester(address attester, AttestationLevel level) 
        public view override returns (bool qualified) {
        AttesterProfile memory profile = attesterProfiles[attester];
        
        if (!profile.isActive) return false;
        if (profile.stakedAmount < minimumStakeByTier[profile.tier]) return false;
        
        // Check tier qualifications for attestation levels
        if (level == AttestationLevel.BASIC) {
            return true; // All tiers can do basic
        } else if (level == AttestationLevel.ENHANCED) {
            return profile.tier >= AttesterTier.SILVER;
        } else if (level == AttestationLevel.INSTITUTIONAL) {
            return profile.tier >= AttesterTier.GOLD;
        }
        
        return false;
    }
    
    function getAttestationFee(address attester, AttestationLevel level) 
        external view override returns (uint256 fee) {
        AttesterProfile memory profile = attesterProfiles[attester];
        return attestationFees[profile.tier][level];
    }
    
    function getChallenge(uint256 challengeId) 
        external view override returns (Challenge memory challenge) {
        return challenges[challengeId];
    }
    
    function getActiveAttesterCount() external view override returns (uint256 count) {
        uint256 activeCount = 0;
        for (uint256 i = 0; i < allAttesters.length; i++) {
            if (attesterProfiles[allAttesters[i]].isActive) {
                activeCount++;
            }
        }
        return activeCount;
    }
    
    // =========================================================================
    // ATTESTER FUNCTIONS
    // =========================================================================
    
    function submitAttestation(
        bytes32 proofHash,
        bool verified,
        AttestationLevel level,
        bytes32 zkVerifyBlockHash,
        string calldata metadata,
        bytes calldata signature
    ) external payable override 
      onlyActiveAttester 
      onlyQualifiedAttester(level) 
      whenNotPaused 
      validProofHash(proofHash) 
      nonReentrant {
        
        require(attestations[proofHash].timestamp == 0, "Proof already attested");
        require(zkVerifyBlockHash != bytes32(0), "Invalid zkVerify block hash");
        
        uint256 requiredFee = attestationFees[attesterProfiles[msg.sender].tier][level];
        require(msg.value >= requiredFee, "Insufficient fee");
        
        // Verify attester signature
        bytes32 messageHash = keccak256(abi.encodePacked(
            proofHash,
            verified,
            level,
            zkVerifyBlockHash,
            metadata,
            block.chainid,
            address(this)
        ));
        
        require(_verifyAttesterSignature(messageHash, signature, msg.sender), "Invalid signature");
        
        // Calculate protocol fee
        uint256 protocolFee = (msg.value * protocolFeePercentage) / 10000;
        uint256 attesterFee = msg.value - protocolFee;
        
        // Create attestation
        attestations[proofHash] = Attestation({
            verified: verified,
            attester: msg.sender,
            level: level,
            attesterTier: attesterProfiles[msg.sender].tier,
            status: AttestationStatus.ACTIVE,
            zkVerifyBlockHash: zkVerifyBlockHash,
            timestamp: block.timestamp,
            expirationTimestamp: block.timestamp + ATTESTATION_VALIDITY_PERIOD,
            stakeAmount: minimumStakeByTier[attesterProfiles[msg.sender].tier],
            metadata: metadata,
            signature: signature
        });
        
        // Update attester statistics
        AttesterProfile storage profile = attesterProfiles[msg.sender];
        profile.totalAttestations++;
        if (verified) {
            profile.successfulAttestations++;
        }
        profile.earnedFees += attesterFee;
        
        // Update system statistics
        totalFeesCollected += protocolFee;
        
        // Transfer attester fee
        payable(msg.sender).transfer(attesterFee);
        
        emit AttestationSubmitted(proofHash, msg.sender, level, profile.stakedAmount);
        emit AttestationFinalized(proofHash, msg.sender, verified);
    }
    
    function batchSubmitAttestations(
        bytes32[] calldata proofHashes,
        bool[] calldata verificationResults,
        AttestationLevel[] calldata levels,
        bytes32[] calldata zkVerifyBlockHashes,
        string[] calldata metadataArray,
        bytes calldata signature
    ) external payable override 
      onlyActiveAttester 
      whenNotPaused 
      nonReentrant {
        
        require(proofHashes.length == verificationResults.length, "Array length mismatch");
        require(proofHashes.length == levels.length, "Array length mismatch");
        require(proofHashes.length == zkVerifyBlockHashes.length, "Array length mismatch");
        require(proofHashes.length == metadataArray.length, "Array length mismatch");
        require(proofHashes.length > 0, "Empty arrays");
        
        // Calculate total required fee
        uint256 totalRequiredFee = 0;
        AttesterTier attesterTier = attesterProfiles[msg.sender].tier;
        
        for (uint256 i = 0; i < levels.length; i++) {
            require(isQualifiedAttester(msg.sender, levels[i]), "Not qualified for level");
            totalRequiredFee += attestationFees[attesterTier][levels[i]];
        }
        
        require(msg.value >= totalRequiredFee, "Insufficient total fee");
        
        // Verify batch signature
        bytes32 batchHash = keccak256(abi.encodePacked(
            proofHashes,
            verificationResults,
            levels,
            zkVerifyBlockHashes,
            metadataArray,
            block.chainid,
            address(this)
        ));
        
        require(_verifyAttesterSignature(batchHash, signature, msg.sender), "Invalid batch signature");
        
        // Process each attestation
        uint256 totalProtocolFee = 0;
        uint256 totalAttesterFee = 0;
        
        for (uint256 i = 0; i < proofHashes.length; i++) {
            require(proofHashes[i] != bytes32(0), "Invalid proof hash");
            require(attestations[proofHashes[i]].timestamp == 0, "Proof already attested");
            
            uint256 attestationFee = attestationFees[attesterTier][levels[i]];
            uint256 protocolFee = (attestationFee * protocolFeePercentage) / 10000;
            
            totalProtocolFee += protocolFee;
            totalAttesterFee += (attestationFee - protocolFee);
            
            // Create attestation
            attestations[proofHashes[i]] = Attestation({
                verified: verificationResults[i],
                attester: msg.sender,
                level: levels[i],
                attesterTier: attesterTier,
                status: AttestationStatus.ACTIVE,
                zkVerifyBlockHash: zkVerifyBlockHashes[i],
                timestamp: block.timestamp,
                expirationTimestamp: block.timestamp + ATTESTATION_VALIDITY_PERIOD,
                stakeAmount: minimumStakeByTier[attesterTier],
                metadata: metadataArray[i],
                signature: signature
            });
            
            emit AttestationSubmitted(proofHashes[i], msg.sender, levels[i], minimumStakeByTier[attesterTier]);
        }
        
        // Update attester statistics
        AttesterProfile storage profile = attesterProfiles[msg.sender];
        profile.totalAttestations += proofHashes.length;
        profile.earnedFees += totalAttesterFee;
        
        // Update system statistics
        totalFeesCollected += totalProtocolFee;
        
        // Transfer attester fees
        payable(msg.sender).transfer(totalAttesterFee);
        
        // Refund excess payment
        if (msg.value > totalRequiredFee) {
            payable(msg.sender).transfer(msg.value - totalRequiredFee);
        }
    }
    
    function revokeAttestation(bytes32 proofHash, string calldata reason) 
        external override onlyActiveAttester {
        Attestation storage attestation = attestations[proofHash];
        require(attestation.attester == msg.sender, "Not your attestation");
        require(attestation.status == AttestationStatus.ACTIVE, "Attestation not active");
        
        attestation.status = AttestationStatus.REVOKED;
        
        // Note: We don't refund fees for revocations as this could be abused
        emit AttestationFinalized(proofHash, msg.sender, false);
    }
    
    // =========================================================================
    // REGISTRATION FUNCTIONS
    // =========================================================================
    
    function registerAttester(
        AttesterTier tier,
        string calldata companyName,
        string calldata licenseNumber,
        string calldata jurisdiction,
        string[] calldata specializations
    ) external payable override {
        require(!attesterProfiles[msg.sender].isActive, "Already registered");
        require(!pendingRegistrations[msg.sender], "Registration pending");
        require(bytes(companyName).length > 0, "Invalid company name");
        require(bytes(licenseNumber).length > 0, "Invalid license number");
        require(msg.value >= minimumStakeByTier[tier], "Insufficient stake");
        
        // Create pending profile
        attesterProfiles[msg.sender] = AttesterProfile({
            isActive: false, // Will be activated by admin approval
            tier: tier,
            totalAttestations: 0,
            successfulAttestations: 0,
            challengedAttestations: 0,
            stakedAmount: msg.value,
            earnedFees: 0,
            slashedAmount: 0,
            registrationTimestamp: block.timestamp,
            companyName: companyName,
            licenseNumber: licenseNumber,
            jurisdiction: jurisdiction,
            specializations: specializations
        });
        
        pendingRegistrations[msg.sender] = true;
        allAttesters.push(msg.sender);
        
        emit AttesterRegistered(msg.sender, tier, companyName);
    }
    
    function updateAttesterProfile(
        string calldata companyName,
        string calldata licenseNumber,
        string[] calldata specializations
    ) external override onlyActiveAttester {
        AttesterProfile storage profile = attesterProfiles[msg.sender];
        
        if (bytes(companyName).length > 0) {
            profile.companyName = companyName;
        }
        if (bytes(licenseNumber).length > 0) {
            profile.licenseNumber = licenseNumber;
        }
        profile.specializations = specializations;
    }
    
    function requestTierUpgrade(AttesterTier newTier, bytes calldata evidence) 
        external payable override onlyActiveAttester {
        AttesterProfile storage profile = attesterProfiles[msg.sender];
        require(newTier > profile.tier, "Not an upgrade");
        
        uint256 additionalStakeRequired = minimumStakeByTier[newTier] - profile.stakedAmount;
        require(msg.value >= additionalStakeRequired, "Insufficient additional stake");
        
        profile.stakedAmount += msg.value;
        
        // Note: Actual tier upgrade requires admin approval
        // This just ensures they have the required stake
    }
    
    // =========================================================================
    // CHALLENGE FUNCTIONS
    // =========================================================================
    
    function challengeAttestation(bytes32 proofHash, bytes calldata evidence) 
        external payable override {
        require(msg.value >= CHALLENGE_STAKE, "Insufficient challenge stake");
        
        Attestation memory attestation = attestations[proofHash];
        require(attestation.timestamp > 0, "No attestation to challenge");
        require(attestation.status == AttestationStatus.ACTIVE, "Attestation not active");
        require(
            block.timestamp - attestation.timestamp <= CHALLENGE_PERIOD,
            "Challenge period expired"
        );
        
        challengeCounter++;
        challenges[challengeCounter] = Challenge({
            challengeId: challengeCounter,
            proofHash: proofHash,
            challenger: msg.sender,
            attester: attestation.attester,
            evidence: evidence,
            challengeTimestamp: block.timestamp,
            resolutionTimestamp: 0,
            resolved: false,
            challengerWon: false,
            stakeAmount: msg.value
        });
        
        proofChallenges[proofHash].push(challengeCounter);
        attestations[proofHash].status = AttestationStatus.CHALLENGED;
        
        emit AttestationChallenged(challengeCounter, proofHash, msg.sender, attestation.attester);
    }
    
    function respondToChallenge(uint256 challengeId, bytes calldata response) 
        external override {
        Challenge memory challenge = challenges[challengeId];
        require(challenge.attester == msg.sender, "Not your challenge to respond to");
        require(!challenge.resolved, "Challenge already resolved");
        
        // Store response in challenge (would need to add response field to struct)
        // For now, this is just a placeholder for the attester to provide their defense
    }
    
    // =========================================================================
    // ADMIN FUNCTIONS
    // =========================================================================
    
    function approveAttesterRegistration(address attester, bool approved) 
        external override onlyOwner {
        require(pendingRegistrations[attester], "No pending registration");
        
        pendingRegistrations[attester] = false;
        
        if (approved) {
            attesterProfiles[attester].isActive = true;
            emit AttesterRegistered(attester, attesterProfiles[attester].tier, attesterProfiles[attester].companyName);
        } else {
            // Refund stake if rejected
            uint256 stakeAmount = attesterProfiles[attester].stakedAmount;
            delete attesterProfiles[attester];
            
            // Remove from allAttesters array
            for (uint256 i = 0; i < allAttesters.length; i++) {
                if (allAttesters[i] == attester) {
                    allAttesters[i] = allAttesters[allAttesters.length - 1];
                    allAttesters.pop();
                    break;
                }
            }
            
            payable(attester).transfer(stakeAmount);
        }
    }
    
    function updateAttesterTier(address attester, AttesterTier newTier) 
        external override onlyOwner {
        require(attesterProfiles[attester].isActive, "Attester not active");
        
        AttesterTier oldTier = attesterProfiles[attester].tier;
        attesterProfiles[attester].tier = newTier;
        
        emit AttesterTierUpdated(attester, oldTier, newTier);
    }
    
    function resolveChallenge(
        uint256 challengeId, 
        bool challengerWon, 
        uint256 slashAmount
    ) external override onlyOwner {
        Challenge storage challenge = challenges[challengeId];
        require(!challenge.resolved, "Challenge already resolved");
        
        challenge.resolved = true;
        challenge.challengerWon = challengerWon;
        challenge.resolutionTimestamp = block.timestamp;
        
        if (challengerWon) {
            // Slash attester
            AttesterProfile storage profile = attesterProfiles[challenge.attester];
            require(profile.stakedAmount >= slashAmount, "Insufficient stake to slash");
            
            profile.stakedAmount -= slashAmount;
            profile.slashedAmount += slashAmount;
            profile.challengedAttestations++;
            
            // Reward challenger
            payable(challenge.challenger).transfer(challenge.stakeAmount + slashAmount);
            
            // Mark attestation as revoked
            attestations[challenge.proofHash].status = AttestationStatus.REVOKED;
            
            emit AttesterSlashed(challenge.attester, slashAmount, "Lost challenge");
        } else {
            // Attester was correct, challenger loses stake
            payable(challenge.attester).transfer(challenge.stakeAmount);
            
            // Restore attestation status
            attestations[challenge.proofHash].status = AttestationStatus.ACTIVE;
        }
        
        emit ChallengeResolved(challengeId, challengerWon, slashAmount);
    }
    
    function pauseAttestations() external override onlyOwner {
        _pause();
    }
    
    function resumeAttestations() external override onlyOwner {
        _unpause();
    }
    
    function updateAttestationFee(AttesterTier tier, AttestationLevel level, uint256 fee) 
        external override onlyOwner {
        attestationFees[tier][level] = fee;
    }
    
    function updateProtocolFeePercentage(uint256 newPercentage) external onlyOwner {
        require(newPercentage <= 1000, "Fee too high"); // Max 10%
        protocolFeePercentage = newPercentage;
    }
    
    // =========================================================================
    // STAKING FUNCTIONS
    // =========================================================================
    
    function addStake() external payable onlyActiveAttester {
        require(msg.value > 0, "Must stake some ETH");
        attesterProfiles[msg.sender].stakedAmount += msg.value;
    }
    
    function withdrawStake(uint256 amount) external onlyActiveAttester nonReentrant {
        AttesterProfile storage profile = attesterProfiles[msg.sender];
        require(amount > 0, "Invalid amount");
        require(profile.stakedAmount >= amount, "Insufficient stake");
        require(
            profile.stakedAmount - amount >= minimumStakeByTier[profile.tier],
            "Would go below minimum stake"
        );
        
        profile.stakedAmount -= amount;
        payable(msg.sender).transfer(amount);
    }
    
    // =========================================================================
    // INTERNAL FUNCTIONS
    // =========================================================================
    
    function _verifyAttesterSignature(
        bytes32 messageHash,
        bytes calldata signature,
        address attester
    ) internal pure returns (bool) {
        bytes32 ethSignedMessageHash = messageHash.toEthSignedMessageHash();
        address recoveredSigner = ethSignedMessageHash.recover(signature);
        return recoveredSigner == attester;
    }
    
    // =========================================================================
    // EMERGENCY FUNCTIONS
    // =========================================================================
    
    function emergencyWithdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
    
    receive() external payable {
        // Allow contract to receive ETH for staking
    }
}
