pragma circom 2.1.9;

include "circomlib/circuits/babyjub.circom";
include "circomlib/circuits/escalarmulany.circom";
include "circomlib/circuits/bitify.circom";
include "circomlib/circuits/comparators.circom";
include "circomlib/circuits/poseidon.circom";

/*
 * BalanceAtLeast
 * ------------------------------------------------------------------
 * Proves: "the eERC balance held at `senderPublicKey` is at least
 *          `threshold`" — without revealing the balance.
 *
 * This is a NON-SPENDING generalisation of the Withdraw circuit in
 * ava-labs/EncryptedERC. Withdraw already proves `balance >= amount`
 * as a precondition of moving funds; it just throws that fact away
 * afterwards and couples it to a state change. Vouch keeps the fact,
 * drops the state change, and binds it to one named verifier.
 *
 * eERC stores a balance as an ElGamal ciphertext on BabyJubJub:
 *     C1 = r * G
 *     C2 = b * G + r * PK
 * where PK = sk * G. So:
 *     b * G == C2 - sk * C1
 *
 * The circuit therefore:
 *   1. binds the witness to the registered public key (PK = sk * G)
 *   2. proves correct decryption of the on-chain ciphertext to `b`
 *   3. proves b >= threshold
 *   4. binds the whole proof to a context (verifier, expiry, nonce,
 *      chain) so it cannot be replayed, resold, or shown to someone
 *      it was not issued to
 *
 * PUBLIC inputs are exactly what a verifier is allowed to learn:
 * the subject's public key, the ciphertext that was on chain, the
 * threshold, and the context hash. The balance never leaves the
 * prover's machine.
 *
 * nBits: bit-width of the balance comparison. eERC supports values up
 * to 2^251; we constrain to 128 bits, which covers every realistic
 * token amount and keeps the comparator cheap. Values are compared in
 * the token's smallest unit (see docs/SPEC.md, "Decimals").
 */
template BalanceAtLeast(nBits) {
    // ---- public ----
    signal input senderPublicKey[2];    // registered BabyJubJub pubkey
    signal input senderBalanceC1[2];    // ElGamal C1, read from chain
    signal input senderBalanceC2[2];    // ElGamal C2, read from chain
    signal input threshold;             // the number being asserted
    signal input contextHash;           // Poseidon binding, see below

    // ---- private ----
    signal input senderPrivateKey;      // pruned/formatted scalar
    signal input senderBalance;         // the real balance, b

    signal output valid;

    // ----------------------------------------------------------------
    // 1. The prover controls the account the statement is about.
    //    senderPrivateKey must already be the pruned BabyJubJub scalar
    //    that eERC's Registrar derived the stored key from — the SDK
    //    does this with the same derivation as @avalabs/ac-eerc-sdk.
    // ----------------------------------------------------------------
    component pk = BabyPbk();
    pk.in <== senderPrivateKey;
    pk.Ax === senderPublicKey[0];
    pk.Ay === senderPublicKey[1];

    // ----------------------------------------------------------------
    // 2. Correct decryption: b * G == C2 - sk * C1
    // ----------------------------------------------------------------
    component skBits = Num2Bits(253);
    skBits.in <== senderPrivateKey;

    component skC1 = EscalarMulAny(253);
    skC1.p[0] <== senderBalanceC1[0];
    skC1.p[1] <== senderBalanceC1[1];
    for (var i = 0; i < 253; i++) {
        skC1.e[i] <== skBits.out[i];
    }

    // Point subtraction on a twisted Edwards curve: negate x, then add.
    component diff = BabyAdd();
    diff.x1 <== senderBalanceC2[0];
    diff.y1 <== senderBalanceC2[1];
    diff.x2 <== 0 - skC1.out[0];
    diff.y2 <== skC1.out[1];

    component balBits = Num2Bits(nBits);
    balBits.in <== senderBalance;

    component balPoint = BabyPbk();
    balPoint.in <== senderBalance;

    balPoint.Ax === diff.xout;
    balPoint.Ay === diff.yout;

    // ----------------------------------------------------------------
    // 3. The actual assertion.
    // ----------------------------------------------------------------
    component ge = GreaterEqThan(nBits);
    ge.in[0] <== senderBalance;
    ge.in[1] <== threshold;
    ge.out === 1;

    // ----------------------------------------------------------------
    // 4. Context binding.
    //
    //    contextHash is a public input but is otherwise unused by the
    //    arithmetic, so the compiler would optimise it away and the
    //    proof would be replayable against any context. The squaring
    //    constraint below is the standard way to pin it into the R1CS.
    //
    //    The hash itself is recomputed on chain by VouchRegistry from
    //    (subject, verifier, tokenId, threshold, expiry, nonce,
    //    chainId) — see contracts/VouchRegistry.sol. A proof is
    //    therefore valid for exactly one verifier, once, before one
    //    deadline, on one chain.
    // ----------------------------------------------------------------
    signal contextSquared;
    contextSquared <== contextHash * contextHash;

    valid <== 1;
}

component main {
    public [
        senderPublicKey,
        senderBalanceC1,
        senderBalanceC2,
        threshold,
        contextHash
    ]
} = BalanceAtLeast(128);
