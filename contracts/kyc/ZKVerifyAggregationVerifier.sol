// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./interfaces/IVerifyProofAggregation.sol";
import "./interfaces/IZKPassportVerifier.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title ZKVerifyAggregationVerifier
 * @dev Verifies ZKPassport proofs using zkVerify's on-chain aggregation contract
 * 
 * This contract provides trustless proof verification by calling zkVerify's
 * deployed aggregation contract directly. No oracle infrastructure required.
 * 
 * Benefits:
 * - Trustless verification (no oracle nodes)
 * - Cost efficient at scale (batched proofs)
 * - No backend infrastructure needed
 * - Censorship resistant
 * 
 * Tradeoff:
 * - Requires waiting for aggregation (5-10 minutes)
 * - Only works with aggregated proofs
 * 
 * Documentation: https://docs.zkverify.io/overview/getting-started/smart-contract
 */
contract ZKVerifyAggregationVerifier is Ownable, ReentrancyGuard {
    
    // =========================================================================
    // CONSTANTS
    // =========================================================================
    
    /// @notice Proving system identifier for Groth16 (used by ZKPassport)
    bytes32 public constant PROVING_SYSTEM_ID = keccak256(abi.encodePacked("groth16"));
    
    /// @notice Version hash for Groth16 proofs (empty string for default version)
    bytes32 public constant VERSION_HASH = sha256(abi.encodePacked(""));
    
    /// @notice Maximum age for verified proofs (365 days)
    uint256 public constant MAX_PROOF_AGE = 365 days;
    
    // =========================================================================
    // STATE VARIABLES
    // =========================================================================
    
    /// @notice Address of zkVerify's aggregation verification contract
    address public zkVerifyContract;
    
    /// @notice Verification key hash for ZKPassport proofs
    bytes32 public vkey;
    
    /// @notice Mapping of user addresses to their compliance status
    mapping(address => ComplianceStatus) public userCompliance;
    
    /// @notice Mapping of proof hashes to prevent replay attacks
    mapping(bytes32 => bool) public usedProofHashes;
    
    /// @notice Total number of verified users
    uint256 public totalVerifiedUsers;
    
    /// @notice Mapping of aggregation IDs to verification timestamps
    mapping(uint256 => uint256) public aggregationTimestamps;
    
    struct ComplianceStatus {
        bool isVerified;
        bytes32 proofHash;
        uint256 verificationTimestamp;
        uint256 expirationTimestamp;
        uint256 aggregationId;
        string verificationLevel;
    }
    
    // =========================================================================
    // EVENTS
    // =========================================================================
    
    event ComplianceVerifiedWithAggregation(
        address indexed user,
        bytes32 indexed proofHash,
        uint256 aggregationId,
        uint256 timestamp
    );
    
    event ComplianceRevoked(
        address indexed user,
        uint256 timestamp
    );
    
    event ZKVerifyContractUpdated(
        address indexed oldContract,
        address indexed newContract
    );
    
    event VerificationKeyUpdated(
        bytes32 indexed oldVkey,
        bytes32 indexed newVkey
    );
    
    // =========================================================================
    // CONSTRUCTOR
    // =========================================================================
    
    /**
     * @dev Initialize the aggregation verifier
     * @param _zkVerifyContract Address of zkVerify's aggregation contract
     * @param _vkey Verification key hash for ZKPassport proofs
     */
    constructor(
        address _zkVerifyContract,
        bytes32 _vkey
    ) Ownable(msg.sender) {
        require(_zkVerifyContract != address(0), "Invalid zkVerify contract");
        require(_vkey != bytes32(0), "Invalid verification key");
        
        zkVerifyContract = _zkVerifyContract;
        vkey = _vkey;
    }
    
    // =========================================================================
    // VERIFICATION FUNCTIONS
    // =========================================================================
    
    /**
     * @dev Verify user compliance using zkVerify aggregation
     * @param user The user's Ethereum address
     * @param publicInputHash Hash of the public inputs from the proof
     * @param aggregationId The aggregation ID from zkVerify
     * @param domainId The domain ID from zkVerify aggregation
     * @param merklePath Merkle proof path for verification
     * @param leafCount Total number of leaves in the Merkle tree
     * @param leafIndex Index of this proof's leaf in the tree
     * @param verificationLevel Level of verification (e.g., "basic", "enhanced")
     */
    function verifyComplianceWithAggregation(
        address user,
        uint256 publicInputHash,
        uint256 aggregationId,
        uint256 domainId,
        bytes32[] calldata merklePath,
        uint256 leafCount,
        uint256 leafIndex,
        string calldata verificationLevel
    ) external nonReentrant {
        require(user != address(0), "Invalid user address");
        require(bytes(verificationLevel).length > 0, "Invalid verification level");
        
        // Generate leaf digest (includes endianness conversion for Groth16)
        bytes32 leaf = _generateLeafDigest(publicInputHash);
        
        // Verify against zkVerify's aggregation contract
        bool isValid = IVerifyProofAggregation(zkVerifyContract).verifyProofAggregation(
            domainId,
            aggregationId,
            leaf,
            merklePath,
            leafCount,
            leafIndex
        );
        
        require(isValid, "zkVerify aggregation verification failed");
        
        // Generate proof hash for replay protection
        bytes32 proofHash = keccak256(abi.encodePacked(
            user,
            publicInputHash,
            aggregationId,
            leafIndex
        ));
        
        require(!usedProofHashes[proofHash], "Proof already used");
        usedProofHashes[proofHash] = true;
        
        // Check if user was previously verified
        bool wasVerified = userCompliance[user].isVerified;
        
        // Update compliance status
        userCompliance[user] = ComplianceStatus({
            isVerified: true,
            proofHash: proofHash,
            verificationTimestamp: block.timestamp,
            expirationTimestamp: block.timestamp + MAX_PROOF_AGE,
            aggregationId: aggregationId,
            verificationLevel: verificationLevel
        });
        
        // Track aggregation timestamp
        if (aggregationTimestamps[aggregationId] == 0) {
            aggregationTimestamps[aggregationId] = block.timestamp;
        }
        
        // Update total verified users
        if (!wasVerified) {
            totalVerifiedUsers++;
        }
        
        emit ComplianceVerifiedWithAggregation(user, proofHash, aggregationId, block.timestamp);
    }
    
    /**
     * @dev Batch verify multiple users with the same aggregation
     * @notice Gas efficient when multiple users are in the same aggregation
     */
    function batchVerifyCompliance(
        address[] calldata users,
        uint256[] calldata publicInputHashes,
        uint256 aggregationId,
        uint256 domainId,
        bytes32[][] calldata merklePaths,
        uint256 leafCount,
        uint256[] calldata leafIndices,
        string[] calldata verificationLevels
    ) external nonReentrant {
        require(users.length == publicInputHashes.length, "Array length mismatch");
        require(users.length == merklePaths.length, "Array length mismatch");
        require(users.length == leafIndices.length, "Array length mismatch");
        require(users.length == verificationLevels.length, "Array length mismatch");
        require(users.length > 0, "Empty arrays");
        
        for (uint256 i = 0; i < users.length; i++) {
            // Generate leaf digest
            bytes32 leaf = _generateLeafDigest(publicInputHashes[i]);
            
            // Verify against zkVerify
            bool isValid = IVerifyProofAggregation(zkVerifyContract).verifyProofAggregation(
                domainId,
                aggregationId,
                leaf,
                merklePaths[i],
                leafCount,
                leafIndices[i]
            );
            
            require(isValid, "Batch verification failed");
            
            // Generate proof hash
            bytes32 proofHash = keccak256(abi.encodePacked(
                users[i],
                publicInputHashes[i],
                aggregationId,
                leafIndices[i]
            ));
            
            require(!usedProofHashes[proofHash], "Proof already used in batch");
            usedProofHashes[proofHash] = true;
            
            // Check if user was previously verified
            bool wasVerified = userCompliance[users[i]].isVerified;
            
            // Update compliance
            userCompliance[users[i]] = ComplianceStatus({
                isVerified: true,
                proofHash: proofHash,
                verificationTimestamp: block.timestamp,
                expirationTimestamp: block.timestamp + MAX_PROOF_AGE,
                aggregationId: aggregationId,
                verificationLevel: verificationLevels[i]
            });
            
            if (!wasVerified) {
                totalVerifiedUsers++;
            }
            
            emit ComplianceVerifiedWithAggregation(
                users[i],
                proofHash,
                aggregationId,
                block.timestamp
            );
        }
        
        // Track aggregation timestamp
        if (aggregationTimestamps[aggregationId] == 0) {
            aggregationTimestamps[aggregationId] = block.timestamp;
        }
    }
    
    // =========================================================================
    // VIEW FUNCTIONS
    // =========================================================================
    
    /**
     * @dev Check if a user is compliant (verified and not expired)
     * @param user The user's Ethereum address
     * @return isCompliant True if user is compliant
     */
    function isCompliant(address user) external view returns (bool) {
        ComplianceStatus memory status = userCompliance[user];
        return status.isVerified && block.timestamp <= status.expirationTimestamp;
    }
    
    /**
     * @dev Get detailed compliance status for a user
     * @param user The user's Ethereum address
     * @return status The compliance status struct
     */
    function getComplianceStatus(address user) 
        external 
        view 
        returns (ComplianceStatus memory) 
    {
        return userCompliance[user];
    }
    
    /**
     * @dev Get contract statistics
     * @return totalVerified Total number of verified users
     * @return contractAddress Address of zkVerify aggregation contract
     * @return vkeyHash Current verification key hash
     */
    function getStats() 
        external 
        view 
        returns (
            uint256 totalVerified,
            address contractAddress,
            bytes32 vkeyHash
        ) 
    {
        return (totalVerifiedUsers, zkVerifyContract, vkey);
    }
    
    // =========================================================================
    // ADMIN FUNCTIONS
    // =========================================================================
    
    /**
     * @dev Update zkVerify contract address
     * @param newContract New zkVerify aggregation contract address
     */
    function updateZKVerifyContract(address newContract) external onlyOwner {
        require(newContract != address(0), "Invalid contract address");
        address oldContract = zkVerifyContract;
        zkVerifyContract = newContract;
        emit ZKVerifyContractUpdated(oldContract, newContract);
    }
    
    /**
     * @dev Update verification key hash
     * @param newVkey New verification key hash
     */
    function updateVerificationKey(bytes32 newVkey) external onlyOwner {
        require(newVkey != bytes32(0), "Invalid verification key");
        bytes32 oldVkey = vkey;
        vkey = newVkey;
        emit VerificationKeyUpdated(oldVkey, newVkey);
    }
    
    /**
     * @dev Revoke a user's compliance status
     * @param user The user's Ethereum address
     */
    function revokeCompliance(address user) external onlyOwner {
        require(user != address(0), "Invalid user address");
        require(userCompliance[user].isVerified, "User not verified");
        
        userCompliance[user].isVerified = false;
        totalVerifiedUsers--;
        
        emit ComplianceRevoked(user, block.timestamp);
    }
    
    // =========================================================================
    // INTERNAL FUNCTIONS
    // =========================================================================
    
    /**
     * @dev Generate leaf digest for zkVerify aggregation verification
     * @param publicInputHash Hash of public inputs from the proof
     * @return leaf The computed leaf hash
     */
    function _generateLeafDigest(uint256 publicInputHash) 
        internal 
        view 
        returns (bytes32) 
    {
        // For Groth16, we need to convert endianness (EVM is little-endian, zkVerify uses big-endian)
        uint256 convertedHash = _changeEndianness(publicInputHash);
        
        // Compute leaf: keccak256(PROVING_SYSTEM_ID || vkey || VERSION_HASH || keccak256(publicInputHash))
        return keccak256(abi.encodePacked(
            PROVING_SYSTEM_ID,
            vkey,
            VERSION_HASH,
            keccak256(abi.encodePacked(convertedHash))
        ));
    }
    
    /**
     * @dev Convert endianness for Groth16 field elements
     * @notice Required because EVM uses little-endian but zkVerify uses big-endian
     * @param input The input value to convert
     * @return v The converted value
     */
    function _changeEndianness(uint256 input) internal pure returns (uint256 v) {
        v = input;
        
        // swap bytes
        v = ((v & 0xFF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00) >> 8) |
            ((v & 0x00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF) << 8);
        
        // swap 2-byte long pairs
        v = ((v & 0xFFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000) >> 16) |
            ((v & 0x0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF) << 16);
        
        // swap 4-byte long pairs
        v = ((v & 0xFFFFFFFF00000000FFFFFFFF00000000FFFFFFFF00000000FFFFFFFF00000000) >> 32) |
            ((v & 0x00000000FFFFFFFF00000000FFFFFFFF00000000FFFFFFFF00000000FFFFFFFF) << 32);
        
        // swap 8-byte long pairs
        v = ((v & 0xFFFFFFFFFFFFFFFF0000000000000000FFFFFFFFFFFFFFFF0000000000000000) >> 64) |
            ((v & 0x0000000000000000FFFFFFFFFFFFFFFF0000000000000000FFFFFFFFFFFFFFFF) << 64);
        
        // swap 16-byte long pairs
        v = (v >> 128) | (v << 128);
    }
}

