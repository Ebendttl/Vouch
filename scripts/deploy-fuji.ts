/**
 * Deploys VouchRegistry against an existing eERC deployment on Fuji.
 *
 * Vouch adds contracts next to eERC. It never upgrades, proxies or
 * forks it, and it cannot touch the auditor key. If this script needed
 * write access to eERC, the design would be wrong.
 */
import { ethers } from "hardhat";
import { poseidonContract } from "circomlibjs";

async function main() {
  const [deployer] = await ethers.getSigners();
  const eerc = required("EERC_ADDRESS");
  const registrar = required("REGISTRAR_ADDRESS");

  // 1. Poseidon(7), generated rather than hand-written, so the on-chain
  //    hash is bit-identical to circomlib's.
  const PoseidonT8 = new ethers.ContractFactory(
    poseidonContract.generateABI(7),
    poseidonContract.createCode(7),
    deployer
  );
  const poseidon = await PoseidonT8.deploy();
  await poseidon.waitForDeployment();
  console.log("PoseidonT8      ", await poseidon.getAddress());

  // 2. The Groth16 verifier snarkjs generated from the circuit.
  const Verifier = await ethers.getContractFactory("BalanceAtLeastVerifier");
  const verifier = await Verifier.deploy();
  await verifier.waitForDeployment();
  console.log("Verifier        ", await verifier.getAddress());

  // 3. The registry.
  const Registry = await ethers.getContractFactory("VouchRegistry", {
    libraries: { PoseidonT8: await poseidon.getAddress() },
  });
  const registry = await Registry.deploy(eerc, registrar, await verifier.getAddress());
  await registry.waitForDeployment();
  console.log("VouchRegistry   ", await registry.getAddress());
}

function required(key: string): string {
  const v = process.env[key];
  if (!v) throw new Error(`Set ${key} in .env — see .env.example`);
  return v;
}

main().catch((e) => {
  console.error(e);
  process.exitCode = 1;
});
