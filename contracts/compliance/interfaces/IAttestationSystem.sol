// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IAttestationSystem
 * @dev Interface for trusted attester verification system
 * Allows qualified professionals to attest to zkVerify results
 */
interface IAttestationSystem {
    
    // =========================================================================
    // ENUMS
    // =========================================================================
    
    enum AttestationLevel { 
        BASIC,          // Basic compliance verification
        ENHANCED,       // Enhanced due diligence
        INSTITUTIONAL   // Full institutional KYC/AML
    }
    
    enum AttesterTier { 
        BRONZE,         // Entry level attesters
        SILVER,         // Experienced attesters  
        GOLD,           // Expert attesters
        PLATINUM        // Premium institutional attesters
    }
    
    enum AttestationStatus {
        PENDING,        // Attestation submitted but not finalized
        ACTIVE,         // Attestation is active and valid
        EXPIRED,        // Attestation has expired
        REVOKED,        // Attestation was revoked
        CHALLENGED      // Attestation is being challenged
    }
    
    // =========================================================================
    // STRUCTS
    // =========================================================================
    
    /**
     * @dev Individual attestation record
     */
    struct Attestation {
        bool verified;                  // Whether the proof was verified
        address attester;               // Address of the attester
        AttestationLevel level;         // Level of attestation provided
        AttesterTier attesterTier;      // Tier of the attester at time of attestation
        AttestationStatus status;       // Current status of the attestation
        bytes32 zkVerifyBlockHash;      // zkVerify block containing the proof
        uint256 timestamp;              // When attestation was created
        uint256 expirationTimestamp;    // When attestation expires
        uint256 stakeAmount;            // Amount staked by attester
        string metadata;                // Additional compliance notes
        bytes signature;                // Attester's cryptographic signature
    }
    
    /**
     * @dev Attester profile and statistics
     */
    struct AttesterProfile {
        bool isActive;                  // Whether attester is currently active
        AttesterTier tier;              // Current tier of the attester
        uint256 totalAttestations;      // Total attestations provided
        uint256 successfulAttestations; // Number of successful attestations
        uint256 challengedAttestations; // Number of challenged attestations
        uint256 stakedAmount;           // Total amount currently staked
        uint256 earnedFees;             // Total fees earned
        uint256 slashedAmount;          // Total amount slashed
        uint256 registrationTimestamp;  // When attester was registered
        string companyName;             // Company/organization name
        string licenseNumber;           // Professional license number
        string jurisdiction;            // Legal jurisdiction
        string[] specializations;       // Areas of specialization
    }
    
    /**
     * @dev Attestation challenge record
     */
    struct Challenge {
        uint256 challengeId;            // Unique challenge ID
        bytes32 proofHash;              // Proof being challenged
        address challenger;             // Who initiated the challenge
        address attester;               // Attester being challenged
        bytes evidence;                 // Evidence supporting the challenge
        uint256 challengeTimestamp;     // When challenge was created
        uint256 resolutionTimestamp;    // When challenge was resolved
        bool resolved;                  // Whether challenge has been resolved
        bool challengerWon;             // Whether challenger was correct
        uint256 stakeAmount;            // Amount at stake in the challenge
    }
    
    // =========================================================================
    // EVENTS
    // =========================================================================
    
    event AttestationSubmitted(
        bytes32 indexed proofHash,
        address indexed attester,
        AttestationLevel level,
        uint256 stakeAmount
    );
    
    event AttestationFinalized(
        bytes32 indexed proofHash,
        address indexed attester,
        bool verified
    );
    
    event AttesterRegistered(
        address indexed attester,
        AttesterTier tier,
        string companyName
    );
    
    event AttesterTierUpdated(
        address indexed attester,
        AttesterTier oldTier,
        AttesterTier newTier
    );
    
    event AttestationChallenged(
        uint256 indexed challengeId,
        bytes32 indexed proofHash,
        address indexed challenger,
        address attester
    );
    
    event ChallengeResolved(
        uint256 indexed challengeId,
        bool challengerWon,
        uint256 slashAmount
    );
    
    event AttesterSlashed(
        address indexed attester,
        uint256 amount,
        string reason
    );
    
    // =========================================================================
    // VIEW FUNCTIONS
    // =========================================================================
    
    /**
     * @dev Check if proof has valid attestation at specified level
     * @param proofHash Hash of the proof
     * @param minLevel Minimum attestation level required
     * @return valid True if proof has valid attestation
     */
    function isProofAttested(bytes32 proofHash, AttestationLevel minLevel) 
        external view returns (bool valid);
    
    /**
     * @dev Get attestation details for a proof
     * @param proofHash Hash of the proof
     * @return attestation Complete attestation record
     */
    function getAttestation(bytes32 proofHash) 
        external view returns (Attestation memory attestation);
    
    /**
     * @dev Get attester profile
     * @param attester Address of the attester
     * @return profile Complete attester profile
     */
    function getAttesterProfile(address attester) 
        external view returns (AttesterProfile memory profile);
    
    /**
     * @dev Check if address is qualified attester for given level
     * @param attester Address to check
     * @param level Attestation level required
     * @return qualified True if attester can provide this level
     */
    function isQualifiedAttester(address attester, AttestationLevel level) 
        external view returns (bool qualified);
    
    /**
     * @dev Get attestation fee for given level and attester
     * @param attester Address of the attester
     * @param level Attestation level
     * @return fee Fee amount in wei
     */
    function getAttestationFee(address attester, AttestationLevel level) 
        external view returns (uint256 fee);
    
    /**
     * @dev Get challenge details
     * @param challengeId ID of the challenge
     * @return challenge Complete challenge record
     */
    function getChallenge(uint256 challengeId) 
        external view returns (Challenge memory challenge);
    
    /**
     * @dev Get total number of active attesters
     * @return count Number of active attesters
     */
    function getActiveAttesterCount() external view returns (uint256 count);
    
    // =========================================================================
    // ATTESTER FUNCTIONS
    // =========================================================================
    
    /**
     * @dev Submit attestation for a zkVerify proof
     * @param proofHash Hash of the proof being attested
     * @param verified Whether the proof was successfully verified
     * @param level Level of attestation being provided
     * @param zkVerifyBlockHash Block hash from zkVerify
     * @param metadata Additional compliance notes
     * @param signature Attester's cryptographic signature
     */
    function submitAttestation(
        bytes32 proofHash,
        bool verified,
        AttestationLevel level,
        bytes32 zkVerifyBlockHash,
        string calldata metadata,
        bytes calldata signature
    ) external payable;
    
    /**
     * @dev Batch submit multiple attestations
     * @param proofHashes Array of proof hashes
     * @param verificationResults Array of verification results
     * @param levels Array of attestation levels
     * @param zkVerifyBlockHashes Array of zkVerify block hashes
     * @param metadataArray Array of metadata strings
     * @param signature Batch signature
     */
    function batchSubmitAttestations(
        bytes32[] calldata proofHashes,
        bool[] calldata verificationResults,
        AttestationLevel[] calldata levels,
        bytes32[] calldata zkVerifyBlockHashes,
        string[] calldata metadataArray,
        bytes calldata signature
    ) external payable;
    
    /**
     * @dev Revoke an attestation (only by original attester)
     * @param proofHash Hash of the proof
     * @param reason Reason for revocation
     */
    function revokeAttestation(bytes32 proofHash, string calldata reason) external;
    
    // =========================================================================
    // REGISTRATION FUNCTIONS
    // =========================================================================
    
    /**
     * @dev Register as an attester
     * @param tier Desired attester tier
     * @param companyName Name of company/organization
     * @param licenseNumber Professional license number
     * @param jurisdiction Legal jurisdiction
     * @param specializations Areas of specialization
     */
    function registerAttester(
        AttesterTier tier,
        string calldata companyName,
        string calldata licenseNumber,
        string calldata jurisdiction,
        string[] calldata specializations
    ) external payable;
    
    /**
     * @dev Update attester profile
     * @param companyName Updated company name
     * @param licenseNumber Updated license number
     * @param specializations Updated specializations
     */
    function updateAttesterProfile(
        string calldata companyName,
        string calldata licenseNumber,
        string[] calldata specializations
    ) external;
    
    /**
     * @dev Request tier upgrade
     * @param newTier Requested new tier
     * @param evidence Evidence supporting the upgrade request
     */
    function requestTierUpgrade(AttesterTier newTier, bytes calldata evidence) external payable;
    
    // =========================================================================
    // CHALLENGE FUNCTIONS
    // =========================================================================
    
    /**
     * @dev Challenge an attestation
     * @param proofHash Hash of the proof being challenged
     * @param evidence Evidence supporting the challenge
     */
    function challengeAttestation(bytes32 proofHash, bytes calldata evidence) external payable;
    
    /**
     * @dev Respond to a challenge (attester defense)
     * @param challengeId ID of the challenge
     * @param response Attester's response/defense
     */
    function respondToChallenge(uint256 challengeId, bytes calldata response) external;
    
    // =========================================================================
    // ADMIN FUNCTIONS
    // =========================================================================
    
    /**
     * @dev Approve attester registration
     * @param attester Address of the attester
     * @param approved Whether to approve or reject
     */
    function approveAttesterRegistration(address attester, bool approved) external;
    
    /**
     * @dev Update attester tier (admin only)
     * @param attester Address of the attester
     * @param newTier New tier to assign
     */
    function updateAttesterTier(address attester, AttesterTier newTier) external;
    
    /**
     * @dev Resolve challenge
     * @param challengeId ID of the challenge
     * @param challengerWon Whether the challenger was correct
     * @param slashAmount Amount to slash from attester
     */
    function resolveChallenge(
        uint256 challengeId, 
        bool challengerWon, 
        uint256 slashAmount
    ) external;
    
    /**
     * @dev Emergency pause attestation system
     */
    function pauseAttestations() external;
    
    /**
     * @dev Resume attestation system
     */
    function resumeAttestations() external;
    
    /**
     * @dev Update attestation fees
     * @param tier Attester tier
     * @param level Attestation level
     * @param fee New fee amount
     */
    function updateAttestationFee(AttesterTier tier, AttestationLevel level, uint256 fee) external;
}
