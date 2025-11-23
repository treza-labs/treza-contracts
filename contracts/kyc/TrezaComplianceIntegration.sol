// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./interfaces/IZKPassportVerifier.sol";
import "../token/interfaces/ITreza.sol";

/**
 * @title TrezaComplianceIntegration
 * @dev Integration contract between TREZA token and ZKPassport compliance verification
 * 
 * This contract provides compliance-gated access to TREZA token features including:
 * - Transfer restrictions based on compliance status
 * - Governance participation eligibility
 * - Batch compliance checking for multiple users
 */
contract TrezaComplianceIntegration is Ownable, ReentrancyGuard {

    // =========================================================================
    // STATE VARIABLES
    // =========================================================================

    /// @notice ZKPassport verifier contract
    IZKPassportVerifier public immutable zkPassportVerifier;

    /// @notice TREZA token contract
    ITreza public immutable trezaToken;

    /// @notice Whether compliance checking is enabled
    bool public complianceEnabled = true;

    /// @notice Minimum compliance level required for governance
    mapping(string => uint256) public governanceRequirements;

    /// @notice Proposal-specific compliance requirements
    mapping(uint256 => ComplianceRequirement) public proposalRequirements;

    /// @notice User voting weights based on compliance level
    mapping(address => mapping(uint256 => uint256)) public userVotingWeights;

    /// @notice Addresses exempt from compliance checks
    mapping(address => bool) public complianceExempt;

    // =========================================================================
    // STRUCTS
    // =========================================================================

    struct ComplianceRequirement {
        string[] requiredLevels;
        uint256 minAge;
        string[] allowedCountries;
        bool isActive;
    }

    struct GovernanceEligibility {
        bool canParticipate;
        uint256 votingWeight;
        string complianceLevel;
        uint256 expirationTime;
    }

    // =========================================================================
    // EVENTS
    // =========================================================================

    event ComplianceStatusChanged(bool enabled);
    event ComplianceExemptionUpdated(address indexed user, bool exempt);
    event GovernanceRequirementUpdated(string level, uint256 weight);
    event ProposalRequirementSet(uint256 indexed proposalId, string[] requiredLevels);
    event VotingWeightUpdated(address indexed user, uint256 indexed proposalId, uint256 weight);

    // =========================================================================
    // MODIFIERS
    // =========================================================================

    modifier onlyCompliant(address user) {
        if (complianceEnabled && !complianceExempt[user]) {
            require(isUserCompliant(user), "User not compliant");
        }
        _;
    }

    modifier complianceEnabledOnly() {
        require(complianceEnabled, "Compliance checking disabled");
        _;
    }

    // =========================================================================
    // CONSTRUCTOR
    // =========================================================================

    constructor(
        address _zkPassportVerifier,
        address _trezaToken
    ) Ownable(msg.sender) {
        require(_zkPassportVerifier != address(0), "Invalid verifier address");
        require(_trezaToken != address(0), "Invalid token address");

        zkPassportVerifier = IZKPassportVerifier(_zkPassportVerifier);
        trezaToken = ITreza(_trezaToken);

        // Set default governance requirements
        governanceRequirements["basic"] = 1;
        governanceRequirements["enhanced"] = 2;
        governanceRequirements["institutional"] = 3;
    }

    // =========================================================================
    // EXTERNAL FUNCTIONS
    // =========================================================================

    /**
     * @dev Check if a user is compliant
     * @param user User address to check
     * @return compliant True if user is compliant or exempt
     */
    function isUserCompliant(address user) public view returns (bool compliant) {
        if (!complianceEnabled || complianceExempt[user]) {
            return true;
        }
        
        return zkPassportVerifier.isCompliant(user);
    }

    /**
     * @dev Batch check compliance for multiple users
     * @param users Array of user addresses
     * @return results Array of compliance status for each user
     */
    function batchCheckCompliance(address[] calldata users) external view returns (bool[] memory results) {
        results = new bool[](users.length);
        
        for (uint256 i = 0; i < users.length; i++) {
            results[i] = isUserCompliant(users[i]);
        }
    }

    /**
     * @dev Check governance eligibility for a user
     * @param user User address to check
     * @param proposalId Proposal ID (0 for general governance)
     * @return eligibility Detailed eligibility information
     */
    function checkGovernanceEligibility(
        address user, 
        uint256 proposalId
    ) external view returns (GovernanceEligibility memory eligibility) {
        
        if (!complianceEnabled || complianceExempt[user]) {
            return GovernanceEligibility({
                canParticipate: true,
                votingWeight: trezaToken.balanceOf(user),
                complianceLevel: "exempt",
                expirationTime: type(uint256).max
            });
        }

        IZKPassportVerifier.ComplianceStatus memory status = zkPassportVerifier.getComplianceStatus(user);
        
        if (!status.isVerified || block.timestamp > status.expirationTimestamp) {
            return GovernanceEligibility({
                canParticipate: false,
                votingWeight: 0,
                complianceLevel: "none",
                expirationTime: 0
            });
        }

        // Check proposal-specific requirements
        if (proposalId > 0 && proposalRequirements[proposalId].isActive) {
            bool meetsRequirement = _meetsProposalRequirement(user, proposalId, status.verificationLevel);
            if (!meetsRequirement) {
                return GovernanceEligibility({
                    canParticipate: false,
                    votingWeight: 0,
                    complianceLevel: status.verificationLevel,
                    expirationTime: status.expirationTimestamp
                });
            }
        }

        // Calculate voting weight based on compliance level
        uint256 baseWeight = trezaToken.balanceOf(user);
        uint256 multiplier = governanceRequirements[status.verificationLevel];
        if (multiplier == 0) multiplier = 1; // Default multiplier

        return GovernanceEligibility({
            canParticipate: true,
            votingWeight: baseWeight * multiplier,
            complianceLevel: status.verificationLevel,
            expirationTime: status.expirationTimestamp
        });
    }

    /**
     * @dev Get detailed compliance information for a user
     * @param user User address
     * @return isCompliant Whether user is compliant
     * @return status Full compliance status from verifier
     * @return isExempt Whether user is exempt from compliance
     */
    function getDetailedComplianceInfo(address user) external view returns (
        bool isCompliant,
        IZKPassportVerifier.ComplianceStatus memory status,
        bool isExempt
    ) {
        isExempt = complianceExempt[user];
        isCompliant = isUserCompliant(user);
        
        if (!isExempt) {
            status = zkPassportVerifier.getComplianceStatus(user);
        }
    }

    /**
     * @dev Check if user can transfer tokens (compliance-gated)
     * @param from Sender address
     * @param to Recipient address
     * @param amount Transfer amount
     * @return allowed True if transfer is allowed
     * @return reason Reason if transfer is not allowed
     */
    function canTransfer(
        address from,
        address to,
        uint256 amount
    ) external view returns (bool allowed, string memory reason) {
        
        // Check sender compliance
        if (!isUserCompliant(from)) {
            return (false, "Sender not compliant");
        }
        
        // Check recipient compliance
        if (!isUserCompliant(to)) {
            return (false, "Recipient not compliant");
        }
        
        // Additional checks can be added here (e.g., transfer limits)
        return (true, "");
    }

    // =========================================================================
    // ADMIN FUNCTIONS
    // =========================================================================

    /**
     * @dev Enable or disable compliance checking
     * @param enabled Whether compliance checking should be enabled
     */
    function setComplianceEnabled(bool enabled) external onlyOwner {
        complianceEnabled = enabled;
        emit ComplianceStatusChanged(enabled);
    }

    /**
     * @dev Set compliance exemption for an address
     * @param user User address
     * @param exempt Whether user should be exempt from compliance
     */
    function setComplianceExemption(address user, bool exempt) external onlyOwner {
        require(user != address(0), "Invalid user address");
        complianceExempt[user] = exempt;
        emit ComplianceExemptionUpdated(user, exempt);
    }

    /**
     * @dev Batch set compliance exemptions
     * @param users Array of user addresses
     * @param exempt Whether users should be exempt from compliance
     */
    function batchSetComplianceExemption(address[] calldata users, bool exempt) external onlyOwner {
        for (uint256 i = 0; i < users.length; i++) {
            require(users[i] != address(0), "Invalid user address");
            complianceExempt[users[i]] = exempt;
            emit ComplianceExemptionUpdated(users[i], exempt);
        }
    }

    /**
     * @dev Update governance requirements for compliance levels
     * @param level Compliance level ("basic", "enhanced", "institutional")
     * @param weight Voting weight multiplier for this level
     */
    function updateGovernanceRequirement(string calldata level, uint256 weight) external onlyOwner {
        require(bytes(level).length > 0, "Invalid level");
        require(weight > 0 && weight <= 10, "Invalid weight");
        
        governanceRequirements[level] = weight;
        emit GovernanceRequirementUpdated(level, weight);
    }

    /**
     * @dev Set proposal-specific compliance requirements
     * @param proposalId Proposal ID
     * @param requiredLevels Array of required compliance levels
     */
    function setProposalRequirement(
        uint256 proposalId,
        string[] calldata requiredLevels
    ) external onlyOwner {
        require(proposalId > 0, "Invalid proposal ID");
        require(requiredLevels.length > 0, "No required levels specified");
        
        proposalRequirements[proposalId] = ComplianceRequirement({
            requiredLevels: requiredLevels,
            minAge: 18, // Default minimum age
            allowedCountries: new string[](0), // Empty array means all countries allowed
            isActive: true
        });
        
        emit ProposalRequirementSet(proposalId, requiredLevels);
    }

    /**
     * @dev Deactivate proposal-specific requirements
     * @param proposalId Proposal ID
     */
    function deactivateProposalRequirement(uint256 proposalId) external onlyOwner {
        require(proposalId > 0, "Invalid proposal ID");
        proposalRequirements[proposalId].isActive = false;
    }

    // =========================================================================
    // INTERNAL FUNCTIONS
    // =========================================================================

    /**
     * @dev Check if user meets proposal-specific requirements
     * @param user User address
     * @param proposalId Proposal ID
     * @param userLevel User's compliance level
     * @return meets True if user meets requirements
     */
    function _meetsProposalRequirement(
        address user,
        uint256 proposalId,
        string memory userLevel
    ) internal view returns (bool meets) {
        ComplianceRequirement memory requirement = proposalRequirements[proposalId];
        
        // Check if user's level is in required levels
        for (uint256 i = 0; i < requirement.requiredLevels.length; i++) {
            if (keccak256(bytes(requirement.requiredLevels[i])) == keccak256(bytes(userLevel))) {
                return true;
            }
        }
        
        return false;
    }

    // =========================================================================
    // VIEW FUNCTIONS
    // =========================================================================

    /**
     * @dev Get contract configuration
     * @return verifierAddress ZKPassport verifier contract address
     * @return tokenAddress TREZA token contract address
     * @return isEnabled Whether compliance checking is enabled
     * @return totalExempt Number of exempt addresses
     */
    function getContractConfig() external view returns (
        address verifierAddress,
        address tokenAddress,
        bool isEnabled,
        uint256 totalExempt
    ) {
        // Note: totalExempt would require additional tracking in a real implementation
        return (
            address(zkPassportVerifier),
            address(trezaToken),
            complianceEnabled,
            0 // Placeholder - would need to track this separately
        );
    }

    /**
     * @dev Get governance requirement for a compliance level
     * @param level Compliance level
     * @return weight Voting weight multiplier
     */
    function getGovernanceRequirement(string calldata level) external view returns (uint256 weight) {
        return governanceRequirements[level];
    }

    /**
     * @dev Get proposal requirement details
     * @param proposalId Proposal ID
     * @return requirement Full requirement details
     */
    function getProposalRequirement(uint256 proposalId) external view returns (ComplianceRequirement memory requirement) {
        return proposalRequirements[proposalId];
    }
}
