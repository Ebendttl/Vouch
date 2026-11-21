// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

/// @notice Groth16 verifier interface, matching the shape snarkjs emits.
interface IVerifier {
    function verifyProof(
        uint256[2] calldata a,
        uint256[2][2] calldata b,
        uint256[2] calldata c,
        uint256[8] calldata publicSignals
    ) external view returns (bool);
}
