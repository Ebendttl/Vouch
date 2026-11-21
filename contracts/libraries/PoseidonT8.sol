// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

/// @notice Poseidon over 7 field elements, matching circomlib's Poseidon(7).
/// @dev    The deployed bytecode is generated at build time by
///         `circomlibjs.poseidonContract` and linked in scripts/deploy-fuji.ts.
///         This wrapper exists so VouchRegistry has a typed call site; see
///         hardhat.config.ts for the generation step. Keeping the hash
///         identical on-chain and in-circuit is the single most important
///         invariant in this repo — test/context-parity.test.ts asserts it.
library PoseidonT8 {
    address internal constant POSEIDON_T8 = 0x0000000000000000000000000000000000000000;

    function hash(uint256[7] memory input) internal view returns (uint256 result) {
        address target = POSEIDON_T8;
        require(target != address(0), "PoseidonT8: not linked");
        (bool ok, bytes memory out) = target.staticcall(
            abi.encodeWithSignature(
                "poseidon(uint256[7])",
                input
            )
        );
        require(ok, "PoseidonT8: call failed");
        result = abi.decode(out, (uint256));
    }
}
