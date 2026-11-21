/**
 * Vouch end-to-end demo on Avalanche Fuji.
 *
 *   Alice holds an encrypted USDC balance in eERC converter mode.
 *   Bob is a lender. Bob wants to know one thing: does Alice hold
 *   at least 1,000 USDC?
 *
 *   Alice proves it. Bob checks it. Nobody learns her balance, her
 *   counterparties, or anything else — and Bob does not get her
 *   auditor key, because there is no auditor key to get.
 *
 * Run:  npx hardhat run scripts/demo.ts --network fuji
 */
import { ethers } from "hardhat";
import { proveBalanceAtLeast, randomNonce } from "../sdk/src";
import { deployments } from "./deployments";
import { loadEercAccount } from "./eerc";

const USDC_6 = (n: number) => BigInt(n) * 10n ** 6n;

async function main() {
  const [alice, bob] = await ethers.getSigners();
  const chainId = Number((await ethers.provider.getNetwork()).chainId);
  const d = deployments[chainId];

  console.log("\n  Vouch — BalanceAtLeast demo");
  console.log("  ───────────────────────────────────────────");
  console.log(`  subject (Alice):  ${alice.address}`);
  console.log(`  verifier (Bob):   ${bob.address}`);
  console.log(`  registry:         ${d.vouchRegistry}\n`);

  // 1. Read Alice's encrypted state. The ciphertext is public; the
  //    value inside it is not.
  const account = await loadEercAccount(alice, d.eerc, d.registrar, d.tokenId);
  console.log(`  on-chain ciphertext C1.x: ${account.balanceC1[0]}`);
  console.log("  (the balance itself is only in Alice's browser)\n");

  // 2. Alice and Bob agree the terms off-chain. Bob is named in the
  //    statement, so only Bob can ever present it.
  const statement = {
    subject: alice.address as `0x${string}`,
    verifier: bob.address as `0x${string}`,
    tokenId: d.tokenId,
    threshold: USDC_6(1_000),
    expiry: BigInt(Math.floor(Date.now() / 1000) + 3600),
    nonce: randomNonce(),
  };

  // 3. Alice proves it, client-side.
  console.time("  proof generated in");
  const vs = await proveBalanceAtLeast({
    statement,
    chainId,
    registry: d.vouchRegistry as `0x${string}`,
    publicKey: account.publicKey,
    balanceC1: account.balanceC1,
    balanceC2: account.balanceC2,
    privateKey: account.prunedPrivateKey,
    balance: account.balance,
    wasmPath: "build/balance_at_least_js/balance_at_least.wasm",
    zkeyPath: "build/balance_at_least_final.zkey",
  });
  console.timeEnd("  proof generated in");

  // 4. Bob presents it. This is the only on-chain transaction.
  const registry = await ethers.getContractAt("VouchRegistry", d.vouchRegistry, bob);
  const tx = await registry.present(
    [statement.subject, statement.verifier, statement.tokenId,
     statement.threshold, statement.expiry, statement.nonce],
    [[vs.proof.a, vs.proof.b, vs.proof.c]],
    vs.balanceC1,
    vs.balanceC2
  );
  const receipt = await tx.wait();

  console.log(`\n  ✓ verified on chain — gas used: ${receipt.gasUsed}`);
  console.log(`  ✓ Bob now knows: Alice holds >= 1,000 USDC`);
  console.log(`  ✓ Bob does not know: the balance, the history, anything else\n`);

  // 5. Prove the binding actually binds. A third party replaying the
  //    same proof must fail.
  const [, , mallory] = await ethers.getSigners();
  try {
    await registry.connect(mallory).present(
      [statement.subject, statement.verifier, statement.tokenId,
       statement.threshold, statement.expiry, statement.nonce],
      [[vs.proof.a, vs.proof.b, vs.proof.c]],
      vs.balanceC1,
      vs.balanceC2
    );
    throw new Error("REPLAY SUCCEEDED — binding is broken");
  } catch {
    console.log("  ✓ replay by a third party rejected (NotTheNamedVerifier)\n");
  }
}

main().catch((e) => {
  console.error(e);
  process.exitCode = 1;
});
