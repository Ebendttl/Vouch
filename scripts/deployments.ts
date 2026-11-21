/**
 * Addresses this PoC talks to. The eERC and Registrar addresses are
 * whatever you deployed with ava-labs/EncryptedERC's own
 * scripts/deploy-converter.ts — Vouch does not deploy or modify eERC.
 */
export const deployments: Record<number, {
  eerc: string;
  registrar: string;
  vouchRegistry: string;
  tokenId: bigint;
}> = {
  // Avalanche Fuji
  43113: {
    eerc: process.env.EERC_ADDRESS ?? "",
    registrar: process.env.REGISTRAR_ADDRESS ?? "",
    vouchRegistry: process.env.VOUCH_REGISTRY_ADDRESS ?? "",
    tokenId: 1n,
  },
};
