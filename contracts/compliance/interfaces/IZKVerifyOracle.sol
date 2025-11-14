// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IZKVerifyOracle
 * @dev Interface for zkVerify Oracle system that monitors zkVerify blockchain
 * and provides verification results to Ethereum/L2 contracts
 */
interface IZKVerifyOracle {
    
    // =========================================================================
    // STRUCTS
    // =========================================================================
    
    /**
     * @dev Verification result from zkVerify blockchain
     */
    struct VerificationResult {
        bool verified;              // Whether the proof was successfully verified
        bytes32 zkVerifyBlockHash;  // Block hash from zkVerify containing the verification
        bytes32 proofHash;          // Hash of the original proof
        uint256 timestamp;          // When the verification was recorded
        address submitter;          // Oracle that submitted this result
        uint256 confirmations;      // Number of oracle confirmations
        bool finalized;             // Whether the result is finalized (consensus reached)
    }
    
    /**
     * @dev Oracle node information
     */
    struct OracleNode {
        bool isActive;              // Whether the oracle is currently active
        uint256 stakedAmount;       // Amount of ETH staked by the oracle
        uint256 totalSubmissions;   // Total number of submissions
        uint256 correctSubmissions; // Number of correct submissions
        uint256 lastActiveBlock;    // Last block when oracle was active
        string endpoint;            // Oracle's zkVerify endpoint
    }
    
    // =========================================================================
    // EVENTS
    // =========================================================================
    
    event VerificationSubmitted(
        bytes32 indexed proofHash,
        address indexed oracle,
        bool verified,
        bytes32 zkVerifyBlockHash
    );
    
    event VerificationFinalized(
        bytes32 indexed proofHash,
        bool verified,
        uint256 confirmations
    );
    
    event OracleAdded(address indexed oracle, uint256 stakedAmount);
    event OracleRemoved(address indexed oracle, string reason);
    event OracleSlashed(address indexed oracle, uint256 amount, string reason);
    
    // =========================================================================
    // VIEW FUNCTIONS
    // =========================================================================
    
    /**
     * @dev Check if a proof has been verified by zkVerify
     * @param proofHash Hash of the proof to check
     * @return verified True if proof was verified on zkVerify
     */
    function isProofVerified(bytes32 proofHash) external view returns (bool verified);
    
    /**
     * @dev Get detailed verification result for a proof
     * @param proofHash Hash of the proof
     * @return result Complete verification result
     */
    function getVerificationResult(bytes32 proofHash) 
        external view returns (VerificationResult memory result);
    
    /**
     * @dev Check if verification result is finalized (has enough confirmations)
     * @param proofHash Hash of the proof
     * @return finalized True if result is finalized
     */
    function isResultFinalized(bytes32 proofHash) external view returns (bool finalized);
    
    /**
     * @dev Get oracle node information
     * @param oracle Address of the oracle
     * @return node Oracle node information
     */
    function getOracleNode(address oracle) external view returns (OracleNode memory node);
    
    /**
     * @dev Get total number of active oracles
     * @return count Number of active oracles
     */
    function getActiveOracleCount() external view returns (uint256 count);
    
    /**
     * @dev Get required confirmations for finalization
     * @return confirmations Number of confirmations required
     */
    function getRequiredConfirmations() external view returns (uint256 confirmations);
    
    // =========================================================================
    // ORACLE FUNCTIONS
    // =========================================================================
    
    /**
     * @dev Submit verification result from zkVerify (called by oracle)
     * @param proofHash Hash of the verified proof
     * @param verified Whether the proof was successfully verified
     * @param zkVerifyBlockHash Block hash from zkVerify containing the verification
     * @param signature Oracle's signature proving authenticity
     */
    function submitVerificationResult(
        bytes32 proofHash,
        bool verified,
        bytes32 zkVerifyBlockHash,
        bytes calldata signature
    ) external;
    
    /**
     * @dev Batch submit multiple verification results
     * @param proofHashes Array of proof hashes
     * @param verificationResults Array of verification results
     * @param zkVerifyBlockHashes Array of zkVerify block hashes
     * @param signature Oracle's batch signature
     */
    function batchSubmitVerificationResults(
        bytes32[] calldata proofHashes,
        bool[] calldata verificationResults,
        bytes32[] calldata zkVerifyBlockHashes,
        bytes calldata signature
    ) external;
    
    // =========================================================================
    // ADMIN FUNCTIONS
    // =========================================================================
    
    /**
     * @dev Add a new oracle node
     * @param oracle Address of the oracle
     * @param endpoint zkVerify endpoint for the oracle
     */
    function addOracle(address oracle, string calldata endpoint) external;
    
    /**
     * @dev Remove an oracle node
     * @param oracle Address of the oracle to remove
     * @param reason Reason for removal
     */
    function removeOracle(address oracle, string calldata reason) external;
    
    /**
     * @dev Update required confirmations for finalization
     * @param confirmations New number of required confirmations
     */
    function updateRequiredConfirmations(uint256 confirmations) external;
    
    /**
     * @dev Emergency pause oracle operations
     */
    function pauseOracle() external;
    
    /**
     * @dev Resume oracle operations
     */
    function resumeOracle() external;
    
    // =========================================================================
    // CHALLENGE FUNCTIONS
    // =========================================================================
    
    /**
     * @dev Challenge an oracle's submission
     * @param proofHash Hash of the proof in question
     * @param oracle Address of the oracle being challenged
     * @param evidence Evidence proving the oracle was wrong
     */
    function challengeSubmission(
        bytes32 proofHash,
        address oracle,
        bytes calldata evidence
    ) external;
    
    /**
     * @dev Resolve a challenge
     * @param challengeId ID of the challenge to resolve
     * @param oracleWasWrong Whether the oracle was proven wrong
     */
    function resolveChallenge(uint256 challengeId, bool oracleWasWrong) external;
}
