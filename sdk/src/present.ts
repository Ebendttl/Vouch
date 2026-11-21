import { Contract, type Signer } from "ethers";
import type { VouchStatement } from "./types";

const REGISTRY_ABI = [
  "function present((address,address,uint256,uint256,uint64,uint256) s, ((uint256[2],uint256[2][2],uint256[2])) proof, uint256[2] balanceC1, uint256[2] balanceC2) returns (bool)",
  "function revoke(uint256 nonce)",
];

/**
 * Called by the VERIFIER, not the subject. Costs the verifier one
 * transaction and tells them one thing: whether the claim holds.
 */
export async function present(vs: VouchStatement, verifier: Signer): Promise<boolean> {
  const registry = new Contract(vs.registry, REGISTRY_ABI, verifier);
  const s = vs.statement;

  const tx = await registry.present(
    [s.subject, s.verifier, s.tokenId, s.threshold, s.expiry, s.nonce],
    [[vs.proof.a, vs.proof.b, vs.proof.c]],
    vs.balanceC1,
    vs.balanceC2
  );
  const receipt = await tx.wait();
  return receipt.status === 1;
}
