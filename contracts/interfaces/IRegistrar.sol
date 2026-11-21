// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

/// @notice eERC's Registrar, which maps an address to its BabyJubJub public key.
interface IRegistrar {
    function getUserPublicKey(address user) external view returns (uint256[2] memory);

    function isUserRegistered(address user) external view returns (bool);
}
