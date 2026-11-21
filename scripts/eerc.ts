import { ethers, type Signer } from "ethers";

/**
 * Reads everything the prover needs out of a live eERC deployment.
 *
 * The balance is decrypted locally from the balance PCT, the same way
 * @avalabs/ac-eerc-sdk does it — the ElGamal ciphertext alone would
 * require solving a discrete log, which is why eERC stores a Poseidon
 * ciphertext alongside it for the owner's benefit.
 */
export async function loadEercAccount(
  signer: Signer,
  eercAddress: string,
  registrarAddress: string,
  tokenId: bigint
) {
  const eerc = new ethers.Contract(
    eercAddress,
    [
      "function balanceOf(address,uint256) view returns (((uint256,uint256),(uint256,uint256)))",
      "function getBalanceFromTokenAddress(address,address) view returns (((uint256,uint256),(uint256,uint256)),uint256[7],uint256,uint256,uint256)",
    ],
    signer
  );
  const registrar = new ethers.Contract(
    registrarAddress,
    ["function getUserPublicKey(address) view returns (uint256[2])"],
    signer
  );

  const address = await signer.getAddress();
  const egct = await eerc.balanceOf(address, tokenId);
  const publicKey = await registrar.getUserPublicKey(address);

  const { prunedPrivateKey, balance } = await deriveLocalState(signer, egct);

  return {
    publicKey: [BigInt(publicKey[0]), BigInt(publicKey[1])] as [bigint, bigint],
    balanceC1: [BigInt(egct[0][0]), BigInt(egct[0][1])] as [bigint, bigint],
    balanceC2: [BigInt(egct[1][0]), BigInt(egct[1][1])] as [bigint, bigint],
    prunedPrivateKey,
    balance,
  };
}

/**
 * Key derivation + balance decryption.
 *
 * Deliberately a thin wrapper rather than a reimplementation: eERC's own
 * SDK owns this logic and getting it subtly wrong is how you produce
 * proofs that verify against the wrong key. Wire @avalabs/ac-eerc-sdk in
 * here rather than hand-rolling BabyJubJub pruning.
 */
async function deriveLocalState(signer: Signer, _egct: unknown): Promise<{
  prunedPrivateKey: bigint;
  balance: bigint;
}> {
  const { deriveKeysFromUser, decryptBalance } = await import("@avalabs/ac-eerc-sdk");
  const keys = await deriveKeysFromUser(signer);
  const balance = await decryptBalance(keys);
  return { prunedPrivateKey: keys.formattedPrivateKey, balance };
}
