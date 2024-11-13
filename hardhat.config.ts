import type { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox-viem";
import { NetworksUserConfig } from "hardhat/types";
import "dotenv/config";


const networks: NetworksUserConfig = {
  hardhat: {
    allowUnlimitedContractSize: true,
  },

  core: {
    url: process.env.CORE_SCAN_URL || "",
    // accounts: [private_key],
  },
}

const config: HardhatUserConfig = {
  solidity: {
    version:  "0.8.20",
    settings: {
      optimizer: {
        enabled: true,   // Enable the optimizer
        runs: 1 
      }
    }
  },
  networks,
  etherscan: {
    apiKey:  process.env.ETHERSCAN_API_KEY,
    customChains: [
      {
        network: "core",
        chainId: 1116,
        urls: {
          apiURL: "https:///openapi.coredao.org/api",
          browserURL: "https://scan.coredao.org/"
        }
      }
    ]
  } 
 
};


export default config;



