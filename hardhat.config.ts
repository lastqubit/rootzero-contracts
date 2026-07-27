import { defineConfig } from "hardhat/config";
import hardhatMocha from "@nomicfoundation/hardhat-mocha";

export default defineConfig({
  plugins: [hardhatMocha],
  solidity: {
    version: "0.8.33",
  },
  networks: {
    // TestHost intentionally composes nearly every endpoint into one integration
    // fixture; normal hosts inherit only the endpoints they use.
    default: {
      type: "edr-simulated",
      chainType: "l1",
      allowUnlimitedContractSize: true,
    },
  },
  test: {
    mocha: {
      require: ["./test/helpers/matchers.ts"],
    },
  },
});
