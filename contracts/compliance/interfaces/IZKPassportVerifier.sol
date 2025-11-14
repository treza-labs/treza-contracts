// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IZKPassportVerifier
 * @dev Interface for ZKPassport verification contract
 */
interface IZKPassportVerifier {
    
    // =========================================================================
    // STRUCTS
    // =========================================================================
    
    struct ComplianceStatus {
        bool isVerified;
        bytes32 proofHash;
        uint256 verificationTimestamp;
        uint256 expirationTimestamp;
        string verificationLevel;
    }
    
    // =========================================================================
    // EVENTS
    // =========================================================================
    
    event ComplianceVerified(address indexed user, bytes32 indexed proofHash, uint256 timestamp);
    event ComplianceRevoked(address indexed user, uint256 timestamp);
    event RequirementsUpdated(uint256 minAge, string[] allowedCountries);
    
    // =========================================================================
    // FUNCTIONS
    // =========================================================================
    
    /**
     * @dev Verify a user's compliance using ZKPassport proof
     */
    function verifyCompliance(
        address user,
        bytes32 proofHash,
        string memory verificationLevel
    ) external;
    
    /**
     * @dev Check if a user is compliant
     */
    function isCompliant(address user) external view returns (bool isCompliant);
    
    /**
     * @dev Get detailed compliance status for a user
     */
    function getComplianceStatus(address user) external view returns (ComplianceStatus memory status);
    
    /**
     * @dev Check if a country is allowed
     */
    function isCountryAllowed(string memory countryCode) external view returns (bool allowed);
    
    /**
     * @dev Get list of allowed countries
     */
    function getAllowedCountries() external view returns (string[] memory countries);
    
    /**
     * @dev Get current verification requirements
     */
    function getRequirements() external view returns (
        uint256 minAge,
        uint256 proofValidityPeriod,
        string[] memory countries
    );
}

