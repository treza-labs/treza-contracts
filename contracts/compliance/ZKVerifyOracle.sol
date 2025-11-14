// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./interfaces/IZKVerifyOracle.sol";

/**
 * @title ZKVerifyOracle
 * @dev Oracle system that monitors zkVerify blockchain and provides verification results
 * to Ethereum/L2 contracts with multi-oracle consensus and slashing mechanisms
 */
contract ZKVerifyOracle is IZKVerifyOracle, Ownable, ReentrancyGuard, Pausable {
    using ECDSA for bytes32;

    // =========================================================================
    // CONSTANTS
    // =========================================================================
    
    uint256 public constant MIN_STAKE_AMOUNT = 1 ether;
    uint256 public constant MAX_VERIFICATION_AGE = 7 days;
    uint256 public constant CHALLENGE_PERIOD = 1 days;
    uint256 public constant SLASH_PERCENTAGE = 50; // 50% of stake
    
    // =========================================================================
    // STATE VARIABLES
    // =========================================================================
    
    /// @notice Mapping of proof hashes to verification results
    mapping(bytes32 => VerificationResult) private verificationResults;
    
    /// @notice Mapping of oracle addresses to their information
    mapping(address => OracleNode) private oracleNodes;
    
    /// @notice Array of active oracle addresses
    address[] private activeOracles;
    
    /// @notice Mapping to track oracle confirmations for each proof
    mapping(bytes32 => mapping(address => bool)) private oracleConfirmations;
    
    /// @notice Required number of confirmations for finalization
    uint256 public requiredConfirmations;
    
    /// @notice Challenge counter for unique challenge IDs
    uint256 private challengeCounter;
    
    /// @notice Mapping of challenge IDs to challenge data
    mapping(uint256 => Challenge) private challenges;
    
    /// @notice Mapping of proof hashes to active challenges
    mapping(bytes32 => uint256[]) private proofChallenges;
    
    struct Challenge {
        uint256 challengeId;
        bytes32 proofHash;
        address challenger;
        address oracle;
        bytes evidence;
        uint256 timestamp;
        bool resolved;
        bool oracleWasWrong;
        uint256 stakeAmount;
    }
    
    // =========================================================================
    // MODIFIERS
    // =========================================================================
    
    modifier onlyActiveOracle() {
        require(oracleNodes[msg.sender].isActive, "Not an active oracle");
        require(oracleNodes[msg.sender].stakedAmount >= MIN_STAKE_AMOUNT, "Insufficient stake");
        _;
    }
    
    modifier validProofHash(bytes32 proofHash) {
        require(proofHash != bytes32(0), "Invalid proof hash");
        _;
    }
    
    // =========================================================================
    // CONSTRUCTOR
    // =========================================================================
    
    constructor(uint256 _requiredConfirmations) Ownable(msg.sender) {
        require(_requiredConfirmations > 0, "Invalid confirmation count");
        requiredConfirmations = _requiredConfirmations;
    }
    
    // =========================================================================
    // VIEW FUNCTIONS
    // =========================================================================
    
    function isProofVerified(bytes32 proofHash) 
        external view override returns (bool verified) {
        VerificationResult memory result = verificationResults[proofHash];
        return result.finalized && 
               result.verified && 
               result.timestamp > 0 &&
               block.timestamp - result.timestamp < MAX_VERIFICATION_AGE;
    }
    
    function getVerificationResult(bytes32 proofHash) 
        external view override returns (VerificationResult memory result) {
        return verificationResults[proofHash];
    }
    
    function isResultFinalized(bytes32 proofHash) 
        external view override returns (bool finalized) {
        return verificationResults[proofHash].finalized;
    }
    
    function getOracleNode(address oracle) 
        external view override returns (OracleNode memory node) {
        return oracleNodes[oracle];
    }
    
    function getActiveOracleCount() external view override returns (uint256 count) {
        return activeOracles.length;
    }
    
    function getRequiredConfirmations() external view override returns (uint256 confirmations) {
        return requiredConfirmations;
    }
    
    // =========================================================================
    // ORACLE FUNCTIONS
    // =========================================================================
    
    function submitVerificationResult(
        bytes32 proofHash,
        bool verified,
        bytes32 zkVerifyBlockHash,
        bytes calldata signature
    ) external override onlyActiveOracle whenNotPaused validProofHash(proofHash) nonReentrant {
        require(zkVerifyBlockHash != bytes32(0), "Invalid zkVerify block hash");
        require(!oracleConfirmations[proofHash][msg.sender], "Already confirmed");
        
        // Verify oracle signature
        bytes32 messageHash = keccak256(abi.encodePacked(
            proofHash,
            verified,
            zkVerifyBlockHash,
            block.chainid,
            address(this)
        ));
        
        require(_verifyOracleSignature(messageHash, signature, msg.sender), "Invalid signature");
        
        // Record oracle confirmation
        oracleConfirmations[proofHash][msg.sender] = true;
        
        // Update or create verification result
        VerificationResult storage result = verificationResults[proofHash];
        if (result.timestamp == 0) {
            // First submission for this proof
            result.proofHash = proofHash;
            result.verified = verified;
            result.zkVerifyBlockHash = zkVerifyBlockHash;
            result.timestamp = block.timestamp;
            result.submitter = msg.sender;
        }
        
        result.confirmations++;
        
        // Update oracle statistics
        oracleNodes[msg.sender].totalSubmissions++;
        oracleNodes[msg.sender].lastActiveBlock = block.number;
        
        emit VerificationSubmitted(proofHash, msg.sender, verified, zkVerifyBlockHash);
        
        // Check if we have enough confirmations to finalize
        if (result.confirmations >= requiredConfirmations && !result.finalized) {
            result.finalized = true;
            
            // Update successful submissions for all confirming oracles
            for (uint256 i = 0; i < activeOracles.length; i++) {
                if (oracleConfirmations[proofHash][activeOracles[i]]) {
                    oracleNodes[activeOracles[i]].correctSubmissions++;
                }
            }
            
            emit VerificationFinalized(proofHash, verified, result.confirmations);
        }
    }
    
    function batchSubmitVerificationResults(
        bytes32[] calldata proofHashes,
        bool[] calldata verificationResults,
        bytes32[] calldata zkVerifyBlockHashes,
        bytes calldata signature
    ) external override onlyActiveOracle whenNotPaused nonReentrant {
        require(proofHashes.length == verificationResults.length, "Array length mismatch");
        require(proofHashes.length == zkVerifyBlockHashes.length, "Array length mismatch");
        require(proofHashes.length > 0, "Empty arrays");
        
        // Verify batch signature
        bytes32 batchHash = keccak256(abi.encodePacked(
            proofHashes,
            verificationResults,
            zkVerifyBlockHashes,
            block.chainid,
            address(this)
        ));
        
        require(_verifyOracleSignature(batchHash, signature, msg.sender), "Invalid batch signature");
        
        // Process each verification result
        for (uint256 i = 0; i < proofHashes.length; i++) {
            bytes32 proofHash = proofHashes[i];
            require(proofHash != bytes32(0), "Invalid proof hash");
            require(!oracleConfirmations[proofHash][msg.sender], "Already confirmed");
            
            // Record confirmation and update result (simplified for batch)
            oracleConfirmations[proofHash][msg.sender] = true;
            
            VerificationResult storage result = verificationResults[proofHash];
            if (result.timestamp == 0) {
                result.proofHash = proofHash;
                result.verified = verificationResults[i];
                result.zkVerifyBlockHash = zkVerifyBlockHashes[i];
                result.timestamp = block.timestamp;
                result.submitter = msg.sender;
            }
            
            result.confirmations++;
            
            emit VerificationSubmitted(proofHash, msg.sender, verificationResults[i], zkVerifyBlockHashes[i]);
            
            // Check finalization
            if (result.confirmations >= requiredConfirmations && !result.finalized) {
                result.finalized = true;
                emit VerificationFinalized(proofHash, verificationResults[i], result.confirmations);
            }
        }
        
        // Update oracle statistics
        oracleNodes[msg.sender].totalSubmissions += proofHashes.length;
        oracleNodes[msg.sender].lastActiveBlock = block.number;
    }
    
    // =========================================================================
    // ADMIN FUNCTIONS
    // =========================================================================
    
    function addOracle(address oracle, string calldata endpoint) 
        external override onlyOwner {
        require(oracle != address(0), "Invalid oracle address");
        require(!oracleNodes[oracle].isActive, "Oracle already active");
        require(bytes(endpoint).length > 0, "Invalid endpoint");
        
        oracleNodes[oracle] = OracleNode({
            isActive: true,
            stakedAmount: 0,
            totalSubmissions: 0,
            correctSubmissions: 0,
            lastActiveBlock: block.number,
            endpoint: endpoint
        });
        
        activeOracles.push(oracle);
        
        emit OracleAdded(oracle, 0);
    }
    
    function removeOracle(address oracle, string calldata reason) 
        external override onlyOwner {
        require(oracleNodes[oracle].isActive, "Oracle not active");
        
        oracleNodes[oracle].isActive = false;
        
        // Remove from active oracles array
        for (uint256 i = 0; i < activeOracles.length; i++) {
            if (activeOracles[i] == oracle) {
                activeOracles[i] = activeOracles[activeOracles.length - 1];
                activeOracles.pop();
                break;
            }
        }
        
        emit OracleRemoved(oracle, reason);
    }
    
    function updateRequiredConfirmations(uint256 confirmations) 
        external override onlyOwner {
        require(confirmations > 0, "Invalid confirmation count");
        require(confirmations <= activeOracles.length, "Too many confirmations required");
        
        requiredConfirmations = confirmations;
    }
    
    function pauseOracle() external override onlyOwner {
        _pause();
    }
    
    function resumeOracle() external override onlyOwner {
        _unpause();
    }
    
    // =========================================================================
    // CHALLENGE FUNCTIONS
    // =========================================================================
    
    function challengeSubmission(
        bytes32 proofHash,
        address oracle,
        bytes calldata evidence
    ) external override payable {
        require(msg.value >= 0.1 ether, "Insufficient challenge stake");
        require(oracleNodes[oracle].isActive, "Oracle not active");
        require(verificationResults[proofHash].timestamp > 0, "No submission to challenge");
        require(
            block.timestamp - verificationResults[proofHash].timestamp <= CHALLENGE_PERIOD,
            "Challenge period expired"
        );
        
        challengeCounter++;
        challenges[challengeCounter] = Challenge({
            challengeId: challengeCounter,
            proofHash: proofHash,
            challenger: msg.sender,
            oracle: oracle,
            evidence: evidence,
            timestamp: block.timestamp,
            resolved: false,
            oracleWasWrong: false,
            stakeAmount: msg.value
        });
        
        proofChallenges[proofHash].push(challengeCounter);
        
        emit AttestationChallenged(challengeCounter, proofHash, msg.sender, oracle);
    }
    
    function resolveChallenge(uint256 challengeId, bool oracleWasWrong) 
        external override onlyOwner {
        Challenge storage challenge = challenges[challengeId];
        require(!challenge.resolved, "Challenge already resolved");
        
        challenge.resolved = true;
        challenge.oracleWasWrong = oracleWasWrong;
        
        if (oracleWasWrong) {
            // Slash oracle
            uint256 slashAmount = (oracleNodes[challenge.oracle].stakedAmount * SLASH_PERCENTAGE) / 100;
            oracleNodes[challenge.oracle].stakedAmount -= slashAmount;
            
            // Reward challenger
            payable(challenge.challenger).transfer(challenge.stakeAmount + slashAmount);
            
            emit OracleSlashed(challenge.oracle, slashAmount, "Incorrect submission");
        } else {
            // Oracle was correct, challenger loses stake
            // Stake goes to oracle as compensation
            payable(challenge.oracle).transfer(challenge.stakeAmount);
        }
        
        emit ChallengeResolved(challengeId, oracleWasWrong, 0);
    }
    
    // =========================================================================
    // STAKING FUNCTIONS
    // =========================================================================
    
    function stakeAsOracle() external payable {
        require(oracleNodes[msg.sender].isActive, "Not an active oracle");
        require(msg.value > 0, "Must stake some ETH");
        
        oracleNodes[msg.sender].stakedAmount += msg.value;
    }
    
    function unstakeOracle(uint256 amount) external nonReentrant {
        require(oracleNodes[msg.sender].isActive, "Not an active oracle");
        require(amount > 0, "Invalid amount");
        require(oracleNodes[msg.sender].stakedAmount >= amount, "Insufficient stake");
        require(
            oracleNodes[msg.sender].stakedAmount - amount >= MIN_STAKE_AMOUNT,
            "Would go below minimum stake"
        );
        
        oracleNodes[msg.sender].stakedAmount -= amount;
        payable(msg.sender).transfer(amount);
    }
    
    // =========================================================================
    // INTERNAL FUNCTIONS
    // =========================================================================
    
    function _verifyOracleSignature(
        bytes32 messageHash,
        bytes calldata signature,
        address oracle
    ) internal pure returns (bool) {
        bytes32 ethSignedMessageHash = messageHash.toEthSignedMessageHash();
        address recoveredSigner = ethSignedMessageHash.recover(signature);
        return recoveredSigner == oracle;
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
