// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

/**
 * @title IVerifyProofAggregation
 * @dev Interface for zkVerify's on-chain aggregation verification contract
 * @notice This interface allows smart contracts to verify proofs that have been
 * aggregated on zkVerify and published to Ethereum/L2
 * 
 * Documentation: https://docs.zkverify.io/overview/getting-started/smart-contract
 */
interface IVerifyProofAggregation {
    /**
     * @dev Verifies a proof within an aggregation using Merkle proof
     * @param _domainId The domain ID from zkVerify aggregation
     * @param _aggregationId The aggregation ID from zkVerify
     * @param _leaf The leaf hash (computed from proof data)
     * @param _merklePath The Merkle path for verification
     * @param _leafCount Total number of leaves in the Merkle tree
     * @param _index Index of the leaf in the tree
     * @return bool True if the proof is valid, false otherwise
     */
    function verifyProofAggregation(
        uint256 _domainId,
        uint256 _aggregationId,
        bytes32 _leaf,
        bytes32[] calldata _merklePath,
        uint256 _leafCount,
        uint256 _index
    ) external view returns (bool);
}

