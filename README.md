# Vouch
 
**Selective disclosure for Avalanche's Encrypted ERC.**
 
Prove one fact about an encrypted balance, to one named counterparty, without revealing the balance — and without handing over an auditor key.
 
> Proof-of-concept, Avalanche Fuji. Built for the Team1 Mini Grant application. Not audited. Do not put real money behind it yet.
 
---
 
## The gap this fills
 
eERC is the best confidential-token primitive in production on any EVM chain. It gives an account two disclosure modes, and only two:
 
| Mode | Who sees | Granularity |
|---|---|---|
| Default | Nobody | — |
| `AuditorManager` | One globally-designated auditor | Everything, forever |
 
There is no third mode. So the moment an encrypted balance has to deal with anyone who isn't that auditor — a lender, an exchange, a landlord, an OTC desk, a regulator in a second jurisdiction, a grants committee — the holder's only options are *reveal nothing* or *hand over the master key*.
 
That is why eERC today is used almost exclusively for payroll demos. Payroll is the one use case where the payer already knows the amount. Everything else in finance requires proving something to someone who shouldn't see everything.
 
**Confidential money cannot participate in an economy it can't prove anything to.** Vouch is the missing third mode.
 
## What it does
 
A holder generates a zero-knowledge proof that their encrypted balance clears a threshold. The proof is bound to a specific verifier address, a deadline and a one-time nonce. The verifier submits it and learns exactly one bit.
 
```
Alice holds an encrypted USDC balance in eERC.
Bob is a lender and wants to know: does she hold at least $1,000?
 
  Alice ──[ proof: balance ≥ 1000, for Bob, expires in 1h ]──► Bob
                                                               │
                                           VouchRegistry.present()
                                                               │
                                                               ▼
  Bob learns:      balance ≥ 1000 ✓
  Bob never learns: the balance, the history, the counterparties,
                    any other token, or anything at all tomorrow.
  Carol replaying Bob's proof: rejected.
```
 
## Why this is a small build, not a moonshot
 
The hard cryptography already exists and is audited.
 
eERC's `Withdraw` circuit **already proves `balance >= amount`** — it has to, before it will let you move funds. It just couples that fact to a state change and then throws it away.
 
`BalanceAtLeast` is that same proof with the state change removed and a context binding added. Same curve (BabyJubJub), same proving system (Groth16), same decryption check, same comparator. The circuit is ~90 lines.
 
That is the whole insight on the engineering side: the primitive Avalanche needs is already sitting inside a circuit Avalanche already shipped and audited. Nobody has pulled it out.
 
## Repo layout
 
```
circuits/balance_at_least.circom   the claim — 4 constraints groups, ~90 lines
contracts/VouchRegistry.sol        verify, bind to one verifier, record, revoke
contracts/interfaces/              the read-only slice of eERC that Vouch touches
sdk/src/prove.ts                   client-side proving; no key ever leaves
sdk/src/context.ts                 the Poseidon binding (must match the contract)
scripts/demo.ts                    the end-to-end run, including a replay attempt
test/context-parity.test.ts        asserts Solidity and TypeScript hash identically
docs/SPEC.md                       statement format, trust assumptions, open questions
docs/ROADMAP.md                    what the grant buys
```
 
## Run it
 
```bash
npm install
npm run build:circuits      # circom -> r1cs + wasm
npm run setup               # phase-2 setup, writes the Solidity verifier
npm run build:contracts
npm test                    # start here: context parity
 
cp .env.example .env        # add an existing eERC deployment on Fuji
npm run deploy:fuji
npm run demo:fuji
```
 
You need an eERC deployment to point at. Vouch does not deploy, fork, proxy or upgrade eERC — it reads it. If this repo needed write access to eERC, the design would be wrong.
 
## Design decisions worth arguing with
 
**Statements are about *now*, not the past.** `present()` reads the ciphertext currently stored in eERC and rejects the proof if it doesn't match. A subject cannot prove a statement about a balance they held last year. This is the strict version, and it means a statement expires the moment the balance changes. Historical attestation needs a commitment accumulator; that is v2, and it is the harder half.
 
**The verifier pays.** `present()` is called by whoever wants the answer. The subject's only cost is local proving. A protocol where proving your own solvency costs you gas does not get used.
 
**Revocation is honest about what it can do.** A subject can burn an unused nonce. It cannot un-ring the bell for a verifier who already presented — nothing on-chain can. The docs say so rather than implying otherwise.
 
**Poseidon parity is the thing that will break.** The circuit, the SDK and the contract all compute the same context hash three different ways. If they drift, every proof fails with `InvalidProof` and no useful error. Hence `test/context-parity.test.ts` running first.
 
## What is deliberately not here
 
- `FlowAtLeast` / `FlowFromSet` (prove income over a window, prove inflows came from *k* distinct payers). These need a receipt accumulator and are the roadmap, not the PoC. Claiming them as done would be lying.
- A multi-party trusted setup. The phase-2 contribution in `scripts/trusted-setup.sh` is local-only and labelled as such.
- An audit. `contracts/` has not been reviewed by anyone.
- Cross-L1 delivery over Interchain Messaging. Designed in `docs/SPEC.md`, unimplemented.
See [`docs/ROADMAP.md`](docs/ROADMAP.md) for what gets built and in what order.
 
## Why Avalanche specifically
 
This cannot be ported. It is built on eERC, which exists on Avalanche and nowhere else, and it is pointed at the market Avalanche is actually winning — tokenized equities, tokenized Treasuries, institutional credit — all of which are blocked on exactly this problem the moment they need a counterparty to verify something without seeing a book.
 
The ICM path in `docs/SPEC.md` is the version that matters longer term: a bank on a permissioned Avalanche L1 proving a fact to a counterparty on C-Chain without exposing the chain. Granite made that cheap enough to be worth building.
 
## Built on
 
- [`ava-labs/EncryptedERC`](https://github.com/ava-labs/EncryptedERC) — the standard this extends
- [`@avalabs/ac-eerc-sdk`](https://www.npmjs.com/package/@avalabs/ac-eerc-sdk) — key derivation and balance decryption
- circomlib, snarkjs, Hardhat
Vouch is additive. It makes every existing eERC application more useful — Benzo, QuietPay, VeilPay and anything built after them — and competes with none of them. If you are building on eERC and want a statement type that doesn't exist yet, open an issue.
 
MIT licensed.
 
