# Vouch — Statement specification (v0.1, draft)

## 1. What a statement is

A statement is a claim about an encrypted eERC position, provable by the
holder and verifiable by exactly one named party, once, before a deadline,
on one chain.

```
Statement {
  subject   : address   // whose position
  verifier  : address   // the only party who may present it
  tokenId   : uint256   // which eERC position
  threshold : uint256   // the number asserted, smallest unit
  expiry    : uint64    // unix seconds
  nonce     : uint256   // one-time, chosen by the subject
}
```

The binding is a Poseidon hash over all six fields plus `chainId`, taken
as a public input by the circuit and recomputed on-chain at presentation.
Change any field and the proof fails. This is what stops a statement
being replayed, forwarded, resold, or shown to a party it was not issued
to.

## 2. Statement types

### `BalanceAtLeast` — implemented

> "The eERC balance at this account is at least T."

Public inputs: `senderPublicKey[2]`, `senderBalanceC1[2]`,
`senderBalanceC2[2]`, `threshold`, `contextHash`.

Private: the pruned BabyJubJub scalar, the balance.

Constraints:
1. `PK = sk · G` — the prover controls the account eERC has on file
2. `b · G = C2 − sk · C1` — correct ElGamal decryption
3. `b ≥ threshold` — the assertion
4. `contextHash` pinned into the R1CS

### `RangeBand` — trivial extension

> "The balance is in [A, B]."

Two comparators instead of one. Useful for tiering a counterparty
without giving them a figure.

### `FlowAtLeast` — roadmap

> "This account received at least T over the last N days."

Requires accumulating over receipts rather than reading one balance.
eERC emits an encrypted amount per transfer; the design is a Merkle
accumulator of per-transfer PCTs that the subject maintains locally and
commits to on-chain, with the circuit proving a sum over an opened
subset. This is the hard one and the valuable one — it is what turns
Vouch from a solvency check into income verification.

### `FlowFromSet` — roadmap

> "Inflows came from at least k distinct registered payers."

Anti-wash-trading. Without it, `FlowAtLeast` is trivially gamed by
sending yourself money in a loop.

### `Solvency` — roadmap

> "Assets across these positions exceed declared liabilities."

Sum over several `BalanceAtLeast` proofs against a signed liability
figure. The exchange proof-of-reserves use case.

## 3. Trust assumptions

**You must trust:**
- The Groth16 setup for the circuit. Phase 1 reuses the Hermez ceremony.
  Phase 2 currently has a single local contribution and is **not**
  production-safe. A multi-party ceremony is a funded milestone.
- circomlib's BabyJubJub and Poseidon implementations.
- That eERC's stored ciphertext reflects reality — Vouch inherits every
  assumption eERC makes.

**You do not need to trust:**
- Vouch's operators. There are none; the contracts hold no keys and no
  funds.
- The subject's honesty. That is the entire point.
- Any relayer or off-chain service. Proving is local, verification is
  on-chain.

## 4. What leaks

A presented statement puts on-chain, permanently and publicly:

- the subject's address
- the verifier's address
- the token id
- the threshold
- the block it was presented in

That last bullet matters more than it looks. A subject who presents
`balance ≥ 10,000` to five lenders in a week has published a pattern,
even though no lender saw a figure. Anyone building a consumer product
on Vouch should warn users about this, and v2 should support presenting
through a designated relayer address so the subject is not in the event.

Not leaked: the balance, the ciphertext contents, transfer history,
counterparties, other tokens, or anything about the account after the
block of presentation.

## 5. Cross-L1 delivery over ICM

The institutional version. A subject's position lives on a permissioned
Avalanche L1; the counterparty is on C-Chain or a different L1.

Sketch: `VouchRegistry` on the source chain verifies the proof locally,
then emits a Warp/ICM message carrying only `(statementId, held,
blockNumber)` to a `VouchReceiver` on the destination chain. The
destination learns the fact; the source chain's state, membership and
balances never cross.

This is the piece that makes Avalanche's L1 estate composable for
anything credit-shaped, and it is cheap post-Granite. Unimplemented.

## 6. Decimals

Thresholds are in the token's smallest unit, always. `1,000 USDC` is
`1_000_000_000`. The circuit compares 128-bit values, which covers every
realistic amount while keeping the comparator cheap; eERC itself
supports up to 2^251 and a statement about a balance above 2^128 will
fail to prove rather than wrap. Documented here because this is exactly
the kind of thing that produces a silent, confident, wrong answer.

## 7. Open questions

- Should a statement be presentable by the subject rather than the
  verifier, with the verifier only reading the event? Cheaper for the
  verifier, worse for the subject, and it changes who the trust anchor is.
- Should `attestations` be storage at all, or just an event? Storage
  costs gas the verifier pays and is only useful for contracts that want
  to read a past attestation. Probably event-only plus an optional
  storage flag.
- Is binding to a single verifier address too strict for institutional
  use, where the counterparty is a desk and not a key? A verifier set,
  or an EIP-1271 contract verifier, is the likely answer.
