import { buildPoseidon } from "circomlibjs";
import type { Statement } from "./types";

let poseidon: Awaited<ReturnType<typeof buildPoseidon>> | undefined;

/**
 * Recomputes the contextHash the circuit binds to.
 *
 * This MUST stay byte-for-byte identical to
 * VouchRegistry._contextHash(). If the two ever drift, every proof
 * silently fails verification on chain with no useful error. There is a
 * parity test for exactly this in test/context-parity.test.ts; run it
 * before you touch either side.
 */
export async function contextHash(statement: Statement, chainId: number): Promise<bigint> {
  poseidon ??= await buildPoseidon();
  const F = poseidon.F;
  const out = poseidon([
    BigInt(statement.subject),
    BigInt(statement.verifier),
    statement.tokenId,
    statement.threshold,
    statement.expiry,
    statement.nonce,
    BigInt(chainId),
  ]);
  return BigInt(F.toString(out));
}

/** A nonce with enough entropy that collisions are not a concern. */
export function randomNonce(): bigint {
  const bytes = crypto.getRandomValues(new Uint8Array(31));
  return BigInt("0x" + Buffer.from(bytes).toString("hex"));
}
