import { groth16 } from "snarkjs";
import { contextHash } from "./context";
import type { Groth16Proof, Statement, VouchStatement } from "./types";

export interface ProveInput {
  statement: Statement;
  chainId: number;
  registry: `0x${string}`;
  /** Registered BabyJubJub public key, as stored by eERC's Registrar. */
  publicKey: [bigint, bigint];
  /** Current on-chain ElGamal ciphertext for (subject, tokenId). */
  balanceC1: [bigint, bigint];
  balanceC2: [bigint, bigint];
  /**
   * The pruned BabyJubJub scalar. Derive it with the same routine
   * @avalabs/ac-eerc-sdk uses — never a raw secp256k1 key.
   */
  privateKey: bigint;
  /** The decrypted balance, in the token's smallest unit. */
  balance: bigint;
  wasmPath: string;
  zkeyPath: string;
}

/**
 * Generates a BalanceAtLeast proof. Runs entirely on the subject's
 * machine: no key, no balance and no ciphertext leaves this function.
 * The returned object is safe to hand to the named verifier and to
 * nobody else.
 */
export async function proveBalanceAtLeast(input: ProveInput): Promise<VouchStatement> {
  if (input.balance < input.statement.threshold) {
    throw new Error(
      "Balance is below the threshold — this statement is not provable. " +
      "Lower the threshold or fund the account."
    );
  }

  const ctx = await contextHash(input.statement, input.chainId);

  const witness = {
    senderPublicKey: input.publicKey.map(String),
    senderBalanceC1: input.balanceC1.map(String),
    senderBalanceC2: input.balanceC2.map(String),
    threshold: input.statement.threshold.toString(),
    contextHash: ctx.toString(),
    senderPrivateKey: input.privateKey.toString(),
    senderBalance: input.balance.toString(),
  };

  const { proof } = await groth16.fullProve(witness, input.wasmPath, input.zkeyPath);

  const formatted: Groth16Proof = {
    a: [BigInt(proof.pi_a[0]), BigInt(proof.pi_a[1])],
    // snarkjs emits G2 coordinates in reverse order from what the
    // Solidity pairing precompile expects. This swap is not optional.
    b: [
      [BigInt(proof.pi_b[0][1]), BigInt(proof.pi_b[0][0])],
      [BigInt(proof.pi_b[1][1]), BigInt(proof.pi_b[1][0])],
    ],
    c: [BigInt(proof.pi_c[0]), BigInt(proof.pi_c[1])],
  };

  return {
    kind: "BalanceAtLeast",
    statement: input.statement,
    proof: formatted,
    balanceC1: input.balanceC1,
    balanceC2: input.balanceC2,
    chainId: input.chainId,
    registry: input.registry,
  };
}
