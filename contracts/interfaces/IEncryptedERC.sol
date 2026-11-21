// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

/// @notice Minimal view surface of ava-labs/EncryptedERC that Vouch needs.
///         Vouch never writes to eERC and never holds a key.
interface IEncryptedERC {
    struct Point {
        uint256 x;
        uint256 y;
    }

    /// @dev ElGamal ciphertext on BabyJubJub: C1 = r*G, C2 = b*G + r*PK
    struct EGCT {
        Point c1;
        Point c2;
    }

    function balanceOf(address user, uint256 tokenId) external view returns (EGCT memory);

    function isConverter() external view returns (bool);
}
