// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {IEncryptedERC} from "./interfaces/IEncryptedERC.sol";
import {IRegistrar} from "./interfaces/IRegistrar.sol";
import {IVerifier} from "./interfaces/IVerifier.sol";
import {PoseidonT8} from "./libraries/PoseidonT8.sol";

/**
 * @title VouchRegistry
 * @notice Selective disclosure for Encrypted ERC balances.
 *
 * eERC gives an account two disclosure modes: nobody sees anything, or
 * the single auditor registered in AuditorManager sees everything. There
 * is no way to tell one counterparty one fact.
 *
 * VouchRegistry adds that third mode. A holder generates a zk proof that
 * their encrypted balance clears a threshold, bound to a specific
 * verifier address, a deadline and a one-time nonce. The verifier — a
 * lender, an exchange, a landlord, a trading desk — calls `present()`
 * and learns exactly one bit: the claim holds, or it does not.
 *
 * Design notes
 * ------------
 * 1. The statement is checked against the ciphertext CURRENTLY stored in
 *    EncryptedERC, read in the same transaction. A statement is therefore
 *    a fact about the balance at the block it was presented in, not an
 *    unverifiable claim about the past. This is deliberately the strict
 *    version; historical attestation is a v2 problem (see docs/SPEC.md).
 *
 * 2. The subject never pays. `present()` is called by the verifier, who
 *    is the party that wants the answer. The subject's only cost is
 *    generating the proof client-side.
 *
 * 3. Nothing here can read a balance. The contract holds no keys and the
 *    auditor key is untouched. Revoking a statement does not revoke the
 *    knowledge a verifier already gained — it stops future presentations
 *    of the same nonce.
 */
contract VouchRegistry {
    // -------------------------------------------------------------- //
    //                            types                               //
    // -------------------------------------------------------------- //

    struct Statement {
        address subject;      // who the claim is about
        address verifier;     // the only address that may present it
        uint256 tokenId;      // eERC token id the balance is held in
        uint256 threshold;    // the number being asserted, smallest unit
        uint64 expiry;        // unix seconds
        uint256 nonce;        // one-time, chosen by the subject
    }

    struct Attestation {
        bool held;
        uint64 blockNumber;
        uint64 presentedAt;
        uint256 threshold;
    }

    struct Proof {
        uint256[2] a;
        uint256[2][2] b;
        uint256[2] c;
    }

    // -------------------------------------------------------------- //
    //                            state                               //
    // -------------------------------------------------------------- //

    IEncryptedERC public immutable eerc;
    IRegistrar public immutable registrar;
    IVerifier public immutable balanceAtLeastVerifier;

    /// @dev statementId => attestation. Append-only record of what was proven.
    mapping(bytes32 => Attestation) public attestations;

    /// @dev subject => nonce => consumed. A nonce is good for one presentation.
    mapping(address => mapping(uint256 => bool)) public nonceUsed;

    /// @dev subject => nonce => revoked before use.
    mapping(address => mapping(uint256 => bool)) public revoked;

    // -------------------------------------------------------------- //
    //                            events                              //
    // -------------------------------------------------------------- //

    /**
     * @notice Emitted on a successful presentation.
     * @dev Note what is NOT in here: the balance, the ciphertext, the
     *      counterparties, the token amount history. Only the claim.
     */
    event StatementPresented(
        bytes32 indexed statementId,
        address indexed subject,
        address indexed verifier,
        uint256 tokenId,
        uint256 threshold,
        uint64 blockNumber
    );

    event StatementRevoked(address indexed subject, uint256 nonce);

    // -------------------------------------------------------------- //
    //                            errors                              //
    // -------------------------------------------------------------- //

    error NotTheNamedVerifier();
    error StatementExpired();
    error NonceAlreadyUsed();
    error StatementRevokedError();
    error SubjectNotRegistered();
    error StaleCiphertext();
    error InvalidProof();

    constructor(address _eerc, address _registrar, address _verifier) {
        eerc = IEncryptedERC(_eerc);
        registrar = IRegistrar(_registrar);
        balanceAtLeastVerifier = IVerifier(_verifier);
    }

    // -------------------------------------------------------------- //
    //                          presentation                          //
    // -------------------------------------------------------------- //

    /**
     * @notice Present a BalanceAtLeast statement. Callable only by the
     *         verifier the statement was issued to.
     * @param s The statement terms, agreed off-chain between the parties.
     * @param proof Groth16 proof generated by the subject.
     * @param balanceC1 The ElGamal C1 the proof was generated against.
     * @param balanceC2 The ElGamal C2 the proof was generated against.
     * @return held True if the claim verified. Reverts otherwise, so a
     *         false return is unreachable — the bool exists for callers
     *         that wrap this in a try/catch.
     */
    function present(
        Statement calldata s,
        Proof calldata proof,
        uint256[2] calldata balanceC1,
        uint256[2] calldata balanceC2
    ) external returns (bool held) {
        if (msg.sender != s.verifier) revert NotTheNamedVerifier();
        if (block.timestamp > s.expiry) revert StatementExpired();
        if (nonceUsed[s.subject][s.nonce]) revert NonceAlreadyUsed();
        if (revoked[s.subject][s.nonce]) revert StatementRevokedError();

        // The public key eERC has on file for this subject.
        uint256[2] memory pk = registrar.getUserPublicKey(s.subject);
        if (pk[0] == 0 && pk[1] == 0) revert SubjectNotRegistered();

        // The ciphertext the proof claims to be about must be the one
        // actually on chain right now. Without this check a subject could
        // prove a statement about a balance they held last year.
        _assertCurrentCiphertext(s.subject, s.tokenId, balanceC1, balanceC2);

        uint256 contextHash = _contextHash(s);

        uint256[8] memory publicSignals = [
            pk[0],
            pk[1],
            balanceC1[0],
            balanceC1[1],
            balanceC2[0],
            balanceC2[1],
            s.threshold,
            contextHash
        ];

        if (!balanceAtLeastVerifier.verifyProof(proof.a, proof.b, proof.c, publicSignals)) {
            revert InvalidProof();
        }

        nonceUsed[s.subject][s.nonce] = true;

        bytes32 statementId = _statementId(s);
        attestations[statementId] = Attestation({
            held: true,
            blockNumber: uint64(block.number),
            presentedAt: uint64(block.timestamp),
            threshold: s.threshold
        });

        emit StatementPresented(
            statementId,
            s.subject,
            s.verifier,
            s.tokenId,
            s.threshold,
            uint64(block.number)
        );

        return true;
    }

    /**
     * @notice A subject can burn an unused nonce — e.g. a deal fell
     *         through and they do not want the counterparty presenting it.
     */
    function revoke(uint256 nonce) external {
        revoked[msg.sender][nonce] = true;
        emit StatementRevoked(msg.sender, nonce);
    }

    // -------------------------------------------------------------- //
    //                           read path                            //
    // -------------------------------------------------------------- //

    function statementId(Statement calldata s) external view returns (bytes32) {
        return _statementId(s);
    }

    function contextHash(Statement calldata s) external view returns (uint256) {
        return _contextHash(s);
    }

    // -------------------------------------------------------------- //
    //                           internals                            //
    // -------------------------------------------------------------- //

    function _assertCurrentCiphertext(
        address subject,
        uint256 tokenId,
        uint256[2] calldata c1,
        uint256[2] calldata c2
    ) internal view {
        IEncryptedERC.EGCT memory onChain = eerc.balanceOf(subject, tokenId);
        bool same = onChain.c1.x == c1[0]
            && onChain.c1.y == c1[1]
            && onChain.c2.x == c2[0]
            && onChain.c2.y == c2[1];
        if (!same) revert StaleCiphertext();
    }

    /**
     * @dev Poseidon over the statement terms, matching the `contextHash`
     *      public input the circuit binds to. Field order here and in
     *      sdk/src/context.ts must stay identical.
     */
    function _contextHash(Statement calldata s) internal view returns (uint256) {
        return PoseidonT8.hash(
            [
                uint256(uint160(s.subject)),
                uint256(uint160(s.verifier)),
                s.tokenId,
                s.threshold,
                uint256(s.expiry),
                s.nonce,
                block.chainid
            ]
        );
    }

    function _statementId(Statement calldata s) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(s.subject, s.verifier, s.tokenId, s.threshold, s.expiry, s.nonce)
        );
    }
}
