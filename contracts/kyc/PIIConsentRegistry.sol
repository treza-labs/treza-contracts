// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title PIIConsentRegistry
 * @notice On-chain consent metadata only — never stores raw PII.
 *         PII commitments are referenced as opaque bytes32 hashes.
 */
contract PIIConsentRegistry is Ownable {
    struct Consent {
        bytes32 consentId;
        bytes32 piiHash;
        address recipient;
        uint256 expiry;
        bool active;
    }

    mapping(address => Consent[]) internal _userConsents;
    mapping(bytes32 => bool) public consentRevoked;

    /// @notice Optional KYC verifier — when set, grantConsent requires a valid KYC proof.
    address public kycVerifier;

    event ConsentGranted(address indexed user, bytes32 indexed piiHash, address recipient, bytes32 consentId);
    event ConsentRevoked(address indexed user, bytes32 indexed consentId);
    event PIIAccessed(bytes32 indexed piiHash, address indexed accessor, string purpose);
    event KycVerifierSet(address indexed verifier);

    constructor() Ownable(msg.sender) {}

    function setKycVerifier(address verifier) external onlyOwner {
        kycVerifier = verifier;
        emit KycVerifierSet(verifier);
    }

    function grantConsent(bytes32 piiHash, address recipient, uint256 expiry) external returns (bytes32) {
        if (kycVerifier != address(0)) {
            require(IKYCVerifierLite(kycVerifier).hasValidKYC(msg.sender), "KYC required");
        }
        require(piiHash != bytes32(0), "Invalid piiHash");
        require(recipient != address(0), "Invalid recipient");

        bytes32 consentId = keccak256(abi.encodePacked(msg.sender, piiHash, recipient, block.timestamp));
        _userConsents[msg.sender].push(
            Consent({ consentId: consentId, piiHash: piiHash, recipient: recipient, expiry: expiry, active: true })
        );

        emit ConsentGranted(msg.sender, piiHash, recipient, consentId);
        return consentId;
    }

    function revokeConsent(bytes32 consentId) external {
        Consent[] storage arr = _userConsents[msg.sender];
        for (uint256 i = 0; i < arr.length; i++) {
            if (arr[i].consentId == consentId && arr[i].active) {
                arr[i].active = false;
                consentRevoked[consentId] = true;
                emit ConsentRevoked(msg.sender, consentId);
                return;
            }
        }
        revert("Consent not found");
    }

    function verifyConsent(address user, bytes32 piiHash, address requester) external view returns (bool) {
        Consent[] storage arr = _userConsents[user];
        for (uint256 i = 0; i < arr.length; i++) {
            Consent storage c = arr[i];
            if (!c.active || consentRevoked[c.consentId]) continue;
            if (c.piiHash != piiHash) continue;
            if (c.recipient != requester) continue;
            if (c.expiry != 0 && block.timestamp > c.expiry) continue;
            return true;
        }
        return false;
    }

    /// @dev Placeholder for zk proof of attribute — integrate with your verifier network.
    function verifyAttributeProof(bytes calldata zkProof) external pure returns (bool) {
        return zkProof.length > 32;
    }

    function userConsents(address user, uint256 index) external view returns (Consent memory) {
        return _userConsents[user][index];
    }

    function consentCount(address user) external view returns (uint256) {
        return _userConsents[user].length;
    }
}

interface IKYCVerifierLite {
    function hasValidKYC(address user) external view returns (bool);
}
