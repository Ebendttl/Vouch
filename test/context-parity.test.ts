import { expect } from "chai";
import { ethers } from "hardhat";
import { poseidonContract } from "circomlibjs";
import { contextHash } from "../sdk/src/context";

/**
 * The single most important test in this repo.
 *
 * The circuit binds a proof to a contextHash the SDK computes in
 * TypeScript. The contract recomputes that hash in Solidity. If the two
 * ever disagree — a reordered field, a different chainId source, an
 * address not zero-extended the same way — every proof fails on chain
 * with `InvalidProof` and no indication why. Hours disappear into that.
 *
 * So: assert parity, on every commit, before anything else.
 */
describe("contextHash parity: Solidity <-> TypeScript", () => {
  it("produces identical field elements for the same statement", async () => {
    const [subject, verifier] = await ethers.getSigners();
    const chainId = Number((await ethers.provider.getNetwork()).chainId);

    const Poseidon = new ethers.ContractFactory(
      poseidonContract.generateABI(7),
      poseidonContract.createCode(7),
      subject
    );
    const poseidon = await Poseidon.deploy();

    const statement = {
      subject: subject.address as `0x${string}`,
      verifier: verifier.address as `0x${string}`,
      tokenId: 1n,
      threshold: 1_000_000_000n,
      expiry: 1900000000n,
      nonce: 42n,
    };

    const fromTs = await contextHash(statement, chainId);
    const fromSol = await poseidon["poseidon(uint256[7])"]([
      BigInt(statement.subject),
      BigInt(statement.verifier),
      statement.tokenId,
      statement.threshold,
      statement.expiry,
      statement.nonce,
      BigInt(chainId),
    ]);

    expect(fromTs).to.equal(BigInt(fromSol));
  });
});
