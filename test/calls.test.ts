import { expect } from "chai";
import { ethers } from "ethers";
import { deploy } from "./helpers/setup.js";
import { encodeContextBlock } from "./helpers/blocks.js";

describe("Command calls", () => {
  it("encodes command(bytes) and its context in one exact calldata buffer", async () => {
    const helper = await deploy("TestCommandCalls");
    const selector = "0x12345678";
    const account = ethers.zeroPadValue("0xab", 32);
    const state = "0x0102030405";
    const input = "0xaabbccddeeff00";
    const context = encodeContextBlock(account, state, input);
    const expected = ethers.concat([
      selector,
      ethers.AbiCoder.defaultAbiCoder().encode(["bytes"], [context]),
    ]);

    expect(await helper.testEncodeCommandCall(selector, account, state, input))
      .to.equal(expected);
  });
});
