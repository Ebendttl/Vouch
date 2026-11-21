# Roadmap

What exists, what the grant buys, and in what order.

## Written, in this repo

Not yet compiled, deployed or audited. This is the design made concrete.

- `BalanceAtLeast` circuit and its context binding
- `VouchRegistry`, with verifier binding, expiry, nonce and revocation
- Client SDK and an end-to-end Fuji demo script, including a replay attempt that must fail
- A Solidity/TypeScript Poseidon parity test

## Week 0 — make it run

- Compile the circuit, run the phase-2 setup, get the parity test green
- Deploy against a live eERC deployment on Fuji and publish the addresses

## Weeks 1–2 — harden the primitive

- Circuit test vectors, including the adversarial cases: wrong key,
  stale ciphertext, threshold above the real balance, malleated proof
- `RangeBand`
- Public Fuji deployment with addresses in the README

## Weeks 3–4 — make it usable by someone else

- `@vouch/sdk` published to npm
- Hosted verify page: paste a statement, see one green tick and nothing else
- Integration guide written against a real eERC app, not a toy

## Weeks 5–6 — the hard statement

- `FlowAtLeast`: receipt accumulator design, circuit, tests
- `FlowFromSet` to make it un-gameable

## Weeks 7–8 — mainnet

- Independent review of the circuits by a ZK auditor
- Multi-party phase-2 ceremony
- C-Chain deployment, first live statement against USDC in converter mode

## Weeks 9–10 — prove demand

- Two design-partner integrations: one existing eERC application, one
  lender or OTC desk
- ICM cross-L1 verification demo

## Weeks 11–12 — hand it to the ecosystem

- Builder Hub tutorial submission
- "Proof of Grant": a demo where a grant programme proves its total
  disbursement without publishing per-recipient amounts, and each
  recipient can prove they were funded without exposing a wallet
- Write-up, and apply to Retro9000 on the strength of shipped tooling

## Not on this roadmap

- A token
- A chain
- Anything that requires Vouch to custody funds or hold a key
