export interface Statement {
  /** The account the claim is about. */
  subject: `0x${string}`;
  /** The only address permitted to present this statement. */
  verifier: `0x${string}`;
  /** eERC token id the balance sits in. */
  tokenId: bigint;
  /** The number being asserted, in the token's smallest unit. */
  threshold: bigint;
  /** Unix seconds. After this, presentation reverts. */
  expiry: bigint;
  /** One-time value chosen by the subject. */
  nonce: bigint;
}

export interface Groth16Proof {
  a: [bigint, bigint];
  b: [[bigint, bigint], [bigint, bigint]];
  c: [bigint, bigint];
}

export interface VouchStatement {
  kind: "BalanceAtLeast";
  statement: Statement;
  proof: Groth16Proof;
  /** The ciphertext the proof was generated against. */
  balanceC1: [bigint, bigint];
  balanceC2: [bigint, bigint];
  chainId: number;
  registry: `0x${string}`;
}
