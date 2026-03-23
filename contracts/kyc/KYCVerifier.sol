// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface IPIIConsentRegistry {
    function verifyConsent(address user, bytes32 piiHash, address requester) external view returns (bool);
}

/**
 * @title KYCVerifier
 * @dev Stores and verifies ZK proofs for KYC verification on-chain
 * @notice This contract allows users to submit zero-knowledge proofs of KYC completion
 *         without revealing personal information
 */
contract KYCVerifier is AccessControl, ReentrancyGuard {
    
    bytes32 public constant VERIFIER_ROLE = keccak256("VERIFIER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    
    struct ZKProof {
        bytes32 commitment;        // Hash of KYC data
        bytes proof;               // Cryptographic proof
        string[] publicInputs;     // Public claims (e.g., "isAdult:true")
        uint256 timestamp;         // Submission time
        address submitter;         // Who submitted
        bool isVerified;           // Verification status
        uint256 expiresAt;         // Expiration timestamp
    }
    
    // Mapping: proofId => ZKProof
    mapping(bytes32 => ZKProof) public proofs;
    
    // Mapping: userAddress => latest proofId
    mapping(address => bytes32) public userProofs;
    
    // Mapping: commitment => exists (prevent duplicates)
    mapping(bytes32 => bool) public commitmentExists;
    
    // Configuration
    uint256 public proofValidityPeriod = 30 days;
    bool public requireVerifierRole = false;

    /// @notice Optional PII consent registry for cross-checking verified users & consent (no PII on-chain).
    address public piiConsentRegistry;

    /// @notice Opaque hash binding a verified KYC commitment to an off-chain PII envelope id (never raw PII on-chain).
    mapping(bytes32 => bytes32) public kycCommitmentToPiiArtifactHash;
    
    // Events
    event ProofSubmitted(
        bytes32 indexed proofId,
        address indexed submitter,
        bytes32 commitment,
        uint256 timestamp
    );
    
    event ProofVerified(
        bytes32 indexed proofId,
        bool isValid,
        address verifier
    );
    
    event ProofRevoked(
        bytes32 indexed proofId,
        address revoker
    );
    
    event ValidityPeriodUpdated(
        uint256 oldPeriod,
        uint256 newPeriod
    );

    event PiiArtifactHashBound(
        address indexed user,
        bytes32 indexed kycCommitment,
        bytes32 piiArtifactHash
    );
    
    /**
     * @dev Constructor - sets up roles
     */
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(VERIFIER_ROLE, msg.sender);
    }
    
    /**
     * @dev Submit a ZK proof to the blockchain
     * @param _commitment The commitment hash (64 hex chars = 32 bytes)
     * @param _proof The cryptographic proof
     * @param _publicInputs Array of public claims
     * @return proofId The unique identifier for this proof
     */
    function submitProof(
        bytes32 _commitment,
        bytes memory _proof,
        string[] memory _publicInputs
    ) external nonReentrant returns (bytes32) {
        require(_commitment != bytes32(0), "Invalid commitment");
        require(_proof.length > 0, "Empty proof");
        require(_publicInputs.length > 0, "No public inputs");
        require(!commitmentExists[_commitment], "Commitment already exists");
        
        // Generate unique proof ID
        bytes32 proofId = keccak256(
            abi.encodePacked(
                _commitment,
                msg.sender,
                block.timestamp,
                block.number
            )
        );
        
        // Calculate expiration
        uint256 expiresAt = block.timestamp + proofValidityPeriod;
        
        // Store proof
        proofs[proofId] = ZKProof({
            commitment: _commitment,
            proof: _proof,
            publicInputs: _publicInputs,
            timestamp: block.timestamp,
            submitter: msg.sender,
            isVerified: false,
            expiresAt: expiresAt
        });
        
        // Update mappings
        userProofs[msg.sender] = proofId;
        commitmentExists[_commitment] = true;
        
        emit ProofSubmitted(proofId, msg.sender, _commitment, block.timestamp);
        
        return proofId;
    }
    
    /**
     * @dev Verify a proof (can be called by anyone or restricted to VERIFIER_ROLE)
     * @param _proofId The ID of the proof to verify
     * @return isValid Whether the proof is valid
     */
    function verifyProof(bytes32 _proofId) external nonReentrant returns (bool) {
        if (requireVerifierRole) {
            require(hasRole(VERIFIER_ROLE, msg.sender), "Not authorized to verify");
        }
        
        ZKProof storage zkProof = proofs[_proofId];
        
        require(zkProof.timestamp > 0, "Proof does not exist");
        require(!zkProof.isVerified, "Proof already verified");
        
        bool isValid = true;
        
        // Validation checks
        
        // 1. Check proof is not expired
        if (block.timestamp > zkProof.expiresAt) {
            isValid = false;
        }
        
        // 2. Check commitment is valid
        if (zkProof.commitment == bytes32(0)) {
            isValid = false;
        }
        
        // 3. Check proof is not empty
        if (zkProof.proof.length == 0) {
            isValid = false;
        }
        
        // In production: Call zk-SNARK verifier contract here
        // Example: isValid = SNARKVerifier.verify(zkProof.proof, zkProof.commitment);
        
        // Mark as verified
        zkProof.isVerified = isValid;
        
        emit ProofVerified(_proofId, isValid, msg.sender);
        
        return isValid;
    }
    
    /**
     * @dev Get proof details
     * @param _proofId The ID of the proof
     * @return commitment The commitment hash
     * @return publicInputs The public claims
     * @return timestamp When the proof was submitted
     * @return submitter Who submitted the proof
     * @return isVerified Whether the proof has been verified
     * @return expiresAt When the proof expires
     */
    function getProof(bytes32 _proofId) 
        external 
        view 
        returns (
            bytes32 commitment,
            string[] memory publicInputs,
            uint256 timestamp,
            address submitter,
            bool isVerified,
            uint256 expiresAt
        ) 
    {
        ZKProof storage zkProof = proofs[_proofId];
        require(zkProof.timestamp > 0, "Proof does not exist");
        
        return (
            zkProof.commitment,
            zkProof.publicInputs,
            zkProof.timestamp,
            zkProof.submitter,
            zkProof.isVerified,
            zkProof.expiresAt
        );
    }
    
    /**
     * @dev Link deployed PIIConsentRegistry (admin).
     */
    function setPiiConsentRegistry(address registry) external onlyRole(ADMIN_ROLE) {
        piiConsentRegistry = registry;
    }

    /**
     * @dev Requires verified, non-expired KYC (for composability with PII / consent flows).
     */
    function assertValidKycForPii(address user) external view {
        require(this.hasValidKYC(user), "KYC required for PII operations");
    }

    /**
     * @dev Optional consent check when `piiConsentRegistry` is configured.
     */
    function requireConsentForPii(address user, bytes32 piiHash, address requester) external view {
        if (piiConsentRegistry == address(0)) {
            return;
        }
        require(
            IPIIConsentRegistry(piiConsentRegistry).verifyConsent(user, piiHash, requester),
            "Missing PII consent"
        );
    }

    /**
     * @dev Check if a user has valid KYC
     * @param _user The address to check
     * @return hasValidKYC Whether the user has a valid, verified, non-expired proof
     */
    function hasValidKYC(address _user) external view returns (bool) {
        bytes32 proofId = userProofs[_user];
        
        if (proofId == bytes32(0)) {
            return false;
        }
        
        ZKProof storage zkProof = proofs[proofId];
        
        // Check if verified and not expired
        return (
            zkProof.isVerified &&
            block.timestamp <= zkProof.expiresAt
        );
    }

    /**
     * @dev Bind KYC ZK commitment to an opaque PII artifact hash (e.g. keccak256(piiId) or envelope digest).
     *      Caller must be the submitter of the proof that owns `kycCommitment`.
     */
    function bindPiiArtifactHash(bytes32 kycCommitment, bytes32 piiArtifactHash) external {
        require(commitmentExists[kycCommitment], "Unknown KYC commitment");
        require(piiArtifactHash != bytes32(0), "Invalid PII artifact hash");
        bytes32 proofId = userProofs[msg.sender];
        require(proofId != bytes32(0), "No proof for sender");
        require(proofs[proofId].commitment == kycCommitment, "Commitment not owned by sender");
        kycCommitmentToPiiArtifactHash[kycCommitment] = piiArtifactHash;
        emit PiiArtifactHashBound(msg.sender, kycCommitment, piiArtifactHash);
    }
    
    /**
     * @dev Get public claims from a proof
     * @param _proofId The ID of the proof
     * @return The array of public claims
     */
    function getPublicClaims(bytes32 _proofId) 
        external 
        view 
        returns (string[] memory) 
    {
        require(proofs[_proofId].timestamp > 0, "Proof does not exist");
        return proofs[_proofId].publicInputs;
    }
    
    /**
     * @dev Get user's latest proof ID
     * @param _user The address to check
     * @return The latest proof ID for the user
     */
    function getUserProofId(address _user) external view returns (bytes32) {
        return userProofs[_user];
    }
    
    /**
     * @dev Check if a commitment exists
     * @param _commitment The commitment to check
     * @return Whether the commitment exists
     */
    function doesCommitmentExist(bytes32 _commitment) external view returns (bool) {
        return commitmentExists[_commitment];
    }
    
    /**
     * @dev Revoke a proof (admin only)
     * @param _proofId The ID of the proof to revoke
     */
    function revokeProof(bytes32 _proofId) external onlyRole(ADMIN_ROLE) {
        require(proofs[_proofId].timestamp > 0, "Proof does not exist");
        
        // Invalidate immediately (same-block expiry would still satisfy timestamp <= expiresAt)
        proofs[_proofId].isVerified = false;
        proofs[_proofId].expiresAt = block.timestamp;
        
        emit ProofRevoked(_proofId, msg.sender);
    }
    
    /**
     * @dev Update the validity period for new proofs (admin only)
     * @param _newPeriod The new validity period in seconds
     */
    function setValidityPeriod(uint256 _newPeriod) external onlyRole(ADMIN_ROLE) {
        require(_newPeriod > 0, "Invalid period");
        require(_newPeriod <= 365 days, "Period too long");
        
        uint256 oldPeriod = proofValidityPeriod;
        proofValidityPeriod = _newPeriod;
        
        emit ValidityPeriodUpdated(oldPeriod, _newPeriod);
    }
    
    /**
     * @dev Toggle whether VERIFIER_ROLE is required to verify (admin only)
     * @param _required Whether to require VERIFIER_ROLE
     */
    function setRequireVerifierRole(bool _required) external onlyRole(ADMIN_ROLE) {
        requireVerifierRole = _required;
    }
    
    /**
     * @dev Get contract version
     * @return The version string
     */
    function version() external pure returns (string memory) {
        return "1.1.0";
    }
}

