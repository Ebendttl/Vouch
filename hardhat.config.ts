import type { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.27",
    settings: { optimizer: { enabled: true, runs: 200 } },
  },
  networks: {
    fuji: {
      url: process.env.FUJI_RPC_URL ?? "https://api.avax-test.network/ext/bc/C/rpc",
      chainId: 43113,
      accounts: [
        process.env.PRIVATE_KEY,
        process.env.PRIVATE_KEY_2,
        process.env.PRIVATE_KEY_3,
      ].filter(Boolean) as string[],
    },
  },
};

export default config;
