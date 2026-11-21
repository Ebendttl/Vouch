#!/usr/bin/env bash
# Phase 2 setup for balance_at_least.
#
# Reuses the Hermez powers-of-tau ceremony, which is what eERC itself
# uses (see ava-labs/EncryptedERC, "Notes"). The circuit is small enough
# for the 2^14 file. The phase-2 contribution below is a PLACEHOLDER for
# local work only — a production deployment needs a multi-party
# ceremony, which is one of the things the grant pays for.
set -euo pipefail

PTAU=powersOfTau28_hez_final_14.ptau
mkdir -p build && cd build

[ -f "$PTAU" ] || curl -LO "https://storage.googleapis.com/zkevm/ptau/$PTAU"

snarkjs groth16 setup balance_at_least.r1cs "$PTAU" balance_at_least_0.zkey
snarkjs zkey contribute balance_at_least_0.zkey balance_at_least_final.zkey \
  --name="local dev — NOT for production" -v -e="$(head -c 64 /dev/urandom | base64)"
snarkjs zkey export verificationkey balance_at_least_final.zkey verification_key.json
snarkjs zkey export solidityverifier balance_at_least_final.zkey \
  ../contracts/verifiers/BalanceAtLeastVerifier.sol

echo
echo "  Verifier written to contracts/verifiers/BalanceAtLeastVerifier.sol"
echo "  Rename the generated contract to BalanceAtLeastVerifier and widen"
echo "  its publicSignals array to uint256[8] to match IVerifier."
