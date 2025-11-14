// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./interfaces/IZKPassportVerifier.sol";
import "./interfaces/IZKVerifyOracle.sol";
import "./interfaces/IAttestationSystem.sol";

/**
 * @title ZKPassportVerifier
 * @dev Implementation of ZKPassport verification contract for TREZA compliance
 * 
 * This contract verifies ZKPassport proofs and manages user compliance status
 * for the TREZA ecosystem. It integrates with zkVerify for proof verification.
 */
contract ZKPassportVerifier is IZKPassportVerifier, Ownable, ReentrancyGuard {
    using ECDSA for bytes32;

    // =========================================================================
    // STATE VARIABLES
    // =========================================================================

    /// @notice Mapping of user addresses to their compliance status
    mapping(address => ComplianceStatus) private userCompliance;

    /// @notice Mapping of proof hashes to prevent replay attacks
    mapping(bytes32 => bool) private usedProofHashes;

    /// @notice Minimum age requirement for compliance
    uint256 public minAge = 18;

    /// @notice Proof validity period in seconds (default: 1 year)
    uint256 public proofValidityPeriod = 365 days;

    /// @notice List of allowed countries (ISO country codes)
    string[] public allowedCountries;

    /// @notice Mapping for quick country lookup
    mapping(string => bool) private isCountryAllowedMapping;

    /// @notice zkVerify contract address for proof verification (deprecated)
    address public zkVerifyContract;

    /// @notice zkVerify Oracle contract for automated verification
    IZKVerifyOracle public zkVerifyOracle;

    /// @notice Attestation System contract for manual verification
    IAttestationSystem public attestationSystem;

    /// @notice Authorized verifier addresses (can submit proofs)
    mapping(address => bool) public authorizedVerifiers;

    /// @notice Verification mode: 0=fallback, 1=oracle, 2=attestation, 3=hybrid
    uint256 public verificationMode;

    /// @notice Total number of verified users
    uint256 public totalVerifiedUsers;

    // =========================================================================
    // EVENTS
    // =========================================================================

    event AuthorizedVerifierAdded(address indexed verifier);
    event AuthorizedVerifierRemoved(address indexed verifier);
    event ZKVerifyContractUpdated(address indexed oldContract, address indexed newContract);
    event ZKVerifyOracleUpdated(address indexed oldOracle, address indexed newOracle);
    event AttestationSystemUpdated(address indexed oldSystem, address indexed newSystem);
    event VerificationModeUpdated(uint256 oldMode, uint256 newMode);
    // Note: RequirementsUpdated event is defined in the interface
    event ProofValidityPeriodUpdated(uint256 oldPeriod, uint256 newPeriod);

    // =========================================================================
    // MODIFIERS
    // =========================================================================

    modifier onlyAuthorizedVerifier() {
        require(authorizedVerifiers[msg.sender] || msg.sender == owner(), "Not authorized verifier");
        _;
    }

    modifier validProofHash(bytes32 proofHash) {
        require(proofHash != bytes32(0), "Invalid proof hash");
        require(!usedProofHashes[proofHash], "Proof hash already used");
        _;
    }

    // =========================================================================
    // CONSTRUCTOR
    // =========================================================================

    constructor(
        address _zkVerifyContract,
        string[] memory _allowedCountries
    ) Ownable(msg.sender) {
        zkVerifyContract = _zkVerifyContract;
        verificationMode = 0; // Start in fallback mode
        
        // Set initial allowed countries
        _updateAllowedCountries(_allowedCountries);
        
        // Add deployer as authorized verifier
        authorizedVerifiers[msg.sender] = true;
        emit AuthorizedVerifierAdded(msg.sender);
    }

    // =========================================================================
    // EXTERNAL FUNCTIONS
    // =========================================================================

    /**
     * @dev Verify a user's compliance using ZKPassport proof
     * @param user The user's Ethereum address
     * @param proofHash Hash of the ZKPassport proof
     * @param verificationLevel Level of verification ("basic", "enhanced", "institutional")
     */
    function verifyCompliance(
        address user,
        bytes32 proofHash,
        string memory verificationLevel
    ) external override onlyAuthorizedVerifier validProofHash(proofHash) nonReentrant {
        require(user != address(0), "Invalid user address");
        require(bytes(verificationLevel).length > 0, "Invalid verification level");

        // Verify the proof with zkVerify (simplified for now)
        require(_verifyZKProof(proofHash), "ZK proof verification failed");

        // Mark proof hash as used
        usedProofHashes[proofHash] = true;

        // Check if user was previously verified
        bool wasVerified = userCompliance[user].isVerified;

        // Update user compliance status
        userCompliance[user] = ComplianceStatus({
            isVerified: true,
            proofHash: proofHash,
            verificationTimestamp: block.timestamp,
            expirationTimestamp: block.timestamp + proofValidityPeriod,
            verificationLevel: verificationLevel
        });

        // Update total verified users count
        if (!wasVerified) {
            totalVerifiedUsers++;
        }

        emit ComplianceVerified(user, proofHash, block.timestamp);
    }

    /**
     * @dev Revoke a user's compliance status
     * @param user The user's Ethereum address
     */
    function revokeCompliance(address user) external onlyOwner {
        require(user != address(0), "Invalid user address");
        require(userCompliance[user].isVerified, "User not verified");

        // Update compliance status
        userCompliance[user].isVerified = false;
        totalVerifiedUsers--;

        emit ComplianceRevoked(user, block.timestamp);
    }

    /**
     * @dev Check if a user is compliant (verified and not expired)
     * @param user The user's Ethereum address
     * @return isCompliant True if user is compliant
     */
    function isCompliant(address user) external view override returns (bool) {
        ComplianceStatus memory status = userCompliance[user];
        return status.isVerified && block.timestamp <= status.expirationTimestamp;
    }

    /**
     * @dev Get detailed compliance status for a user
     * @param user The user's Ethereum address
     * @return status Complete compliance status
     */
    function getComplianceStatus(address user) external view override returns (ComplianceStatus memory) {
        return userCompliance[user];
    }

    /**
     * @dev Check if a country is allowed
     * @param countryCode ISO country code
     * @return allowed True if country is allowed
     */
    function isCountryAllowed(string memory countryCode) external view override returns (bool) {
        return isCountryAllowedMapping[countryCode];
    }

    /**
     * @dev Get list of allowed countries
     * @return countries Array of allowed country codes
     */
    function getAllowedCountries() external view override returns (string[] memory) {
        return allowedCountries;
    }

    /**
     * @dev Get current verification requirements
     * @return minAge Minimum age requirement
     * @return proofValidityPeriod Proof validity period in seconds
     * @return countries Array of allowed countries
     */
    function getRequirements() external view override returns (
        uint256,
        uint256,
        string[] memory
    ) {
        return (minAge, proofValidityPeriod, allowedCountries);
    }

    /**
     * @dev Batch check compliance for multiple users
     * @param users Array of user addresses
     * @return results Array of compliance status for each user
     */
    function batchCheckCompliance(address[] calldata users) external view returns (bool[] memory results) {
        results = new bool[](users.length);
        
        for (uint256 i = 0; i < users.length; i++) {
            ComplianceStatus memory status = userCompliance[users[i]];
            results[i] = status.isVerified && block.timestamp <= status.expirationTimestamp;
        }
    }

    /**
     * @dev Check if a proof hash has been used
     * @param proofHash The proof hash to check
     * @return used True if proof hash has been used
     */
    function isProofHashUsed(bytes32 proofHash) external view returns (bool) {
        return usedProofHashes[proofHash];
    }

    // =========================================================================
    // ADMIN FUNCTIONS
    // =========================================================================

    /**
     * @dev Update verification requirements
     * @param _minAge New minimum age requirement
     * @param _allowedCountries New list of allowed countries
     */
    function updateRequirements(
        uint256 _minAge,
        string[] memory _allowedCountries
    ) external onlyOwner {
        require(_minAge >= 16 && _minAge <= 25, "Invalid minimum age");
        
        minAge = _minAge;
        _updateAllowedCountries(_allowedCountries);
        
        emit RequirementsUpdated(_minAge, _allowedCountries);
    }

    /**
     * @dev Update proof validity period
     * @param _proofValidityPeriod New validity period in seconds
     */
    function updateProofValidityPeriod(uint256 _proofValidityPeriod) external onlyOwner {
        require(_proofValidityPeriod >= 30 days && _proofValidityPeriod <= 1095 days, "Invalid validity period");
        
        uint256 oldPeriod = proofValidityPeriod;
        proofValidityPeriod = _proofValidityPeriod;
        
        emit ProofValidityPeriodUpdated(oldPeriod, _proofValidityPeriod);
    }

    /**
     * @dev Update zkVerify contract address
     * @param _zkVerifyContract New zkVerify contract address
     */
    function updateZKVerifyContract(address _zkVerifyContract) external onlyOwner {
        require(_zkVerifyContract != address(0), "Invalid zkVerify contract address");
        
        address oldContract = zkVerifyContract;
        zkVerifyContract = _zkVerifyContract;
        
        emit ZKVerifyContractUpdated(oldContract, _zkVerifyContract);
    }

    /**
     * @dev Add authorized verifier
     * @param verifier Address to authorize
     */
    function addAuthorizedVerifier(address verifier) external onlyOwner {
        require(verifier != address(0), "Invalid verifier address");
        require(!authorizedVerifiers[verifier], "Already authorized");
        
        authorizedVerifiers[verifier] = true;
        emit AuthorizedVerifierAdded(verifier);
    }

    /**
     * @dev Remove authorized verifier
     * @param verifier Address to remove authorization
     */
    function removeAuthorizedVerifier(address verifier) external onlyOwner {
        require(authorizedVerifiers[verifier], "Not authorized");
        
        authorizedVerifiers[verifier] = false;
        emit AuthorizedVerifierRemoved(verifier);
    }

    /**
     * @dev Update zkVerify Oracle contract
     * @param _zkVerifyOracle New zkVerify Oracle contract address
     */
    function updateZKVerifyOracle(address _zkVerifyOracle) external onlyOwner {
        address oldOracle = address(zkVerifyOracle);
        zkVerifyOracle = IZKVerifyOracle(_zkVerifyOracle);
        
        emit ZKVerifyOracleUpdated(oldOracle, _zkVerifyOracle);
    }

    /**
     * @dev Update Attestation System contract
     * @param _attestationSystem New Attestation System contract address
     */
    function updateAttestationSystem(address _attestationSystem) external onlyOwner {
        address oldSystem = address(attestationSystem);
        attestationSystem = IAttestationSystem(_attestationSystem);
        
        emit AttestationSystemUpdated(oldSystem, _attestationSystem);
    }

    /**
     * @dev Update verification mode
     * @param _verificationMode New verification mode (0=fallback, 1=oracle, 2=attestation, 3=hybrid)
     */
    function updateVerificationMode(uint256 _verificationMode) external onlyOwner {
        require(_verificationMode <= 3, "Invalid verification mode");
        
        uint256 oldMode = verificationMode;
        verificationMode = _verificationMode;
        
        emit VerificationModeUpdated(oldMode, _verificationMode);
    }

    // =========================================================================
    // INTERNAL FUNCTIONS
    // =========================================================================

    /**
     * @dev Update allowed countries list
     * @param _allowedCountries New list of allowed countries
     */
    function _updateAllowedCountries(string[] memory _allowedCountries) internal {
        // Clear existing mappings
        for (uint256 i = 0; i < allowedCountries.length; i++) {
            isCountryAllowedMapping[allowedCountries[i]] = false;
        }
        
        // Update with new countries
        allowedCountries = _allowedCountries;
        for (uint256 i = 0; i < _allowedCountries.length; i++) {
            isCountryAllowedMapping[_allowedCountries[i]] = true;
        }
    }

    /**
     * @dev Verify ZK proof using production verification systems
     * @param proofHash Hash of the proof to verify
     * @return valid True if proof is valid
     */
    function _verifyZKProof(bytes32 proofHash) internal view returns (bool) {
        // Production verification modes:
        // 0 = Fallback (authorized verifiers only)
        // 1 = Oracle only
        // 2 = Attestation only  
        // 3 = Hybrid (oracle for low-value, attestation for high-value)
        
        if (verificationMode == 0) {
            // Fallback mode: authorized verifiers only
            return authorizedVerifiers[msg.sender] || msg.sender == owner();
        }
        
        if (verificationMode == 1) {
            // Oracle mode: check zkVerify oracle
            if (address(zkVerifyOracle) != address(0)) {
                return zkVerifyOracle.isProofVerified(proofHash);
            }
            return false;
        }
        
        if (verificationMode == 2) {
            // Attestation mode: check attestation system
            if (address(attestationSystem) != address(0)) {
                return attestationSystem.isProofAttested(proofHash, IAttestationSystem.AttestationLevel.BASIC);
            }
            return false;
        }
        
        if (verificationMode == 3) {
            // Hybrid mode: try oracle first, then attestation
            if (address(zkVerifyOracle) != address(0) && zkVerifyOracle.isProofVerified(proofHash)) {
                return true;
            }
            
            if (address(attestationSystem) != address(0)) {
                return attestationSystem.isProofAttested(proofHash, IAttestationSystem.AttestationLevel.BASIC);
            }
            
            return false;
        }
        
        // Default fallback
        return authorizedVerifiers[msg.sender] || msg.sender == owner();
    }

    // =========================================================================
    // VIEW FUNCTIONS
    // =========================================================================

    /**
     * @dev Get contract statistics
     * @return totalUsers Total number of verified users
     * @return totalCountries Number of allowed countries
     * @return currentMinAge Current minimum age requirement
     * @return currentValidityPeriod Current proof validity period
     */
    function getContractStats() external view returns (
        uint256 totalUsers,
        uint256 totalCountries,
        uint256 currentMinAge,
        uint256 currentValidityPeriod
    ) {
        return (
            totalVerifiedUsers,
            allowedCountries.length,
            minAge,
            proofValidityPeriod
        );
    }

    /**
     * @dev Check if user's compliance is expired
     * @param user User address to check
     * @return expired True if compliance is expired
     */
    function isComplianceExpired(address user) external view returns (bool) {
        ComplianceStatus memory status = userCompliance[user];
        return status.isVerified && block.timestamp > status.expirationTimestamp;
    }
}
