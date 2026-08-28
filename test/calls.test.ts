import { expect } from "chai";
import { ethers } from "ethers";
import { deploy } from "./helpers/setup.js";
import { encodeContextBlock } from "./helpers/blocks.js";

describe("Command calls", () => {
  it("calls command(bytes) with an exact context and decodes state and credit", async () => {
    const helper = await deploy("TestCommandCalls");
    const selector = helper.interface.getFunction("command")!.selector;
    const target = await helper.getAddress();
    const account = ethers.zeroPadValue("0xab", 32);
    const state = "0x0102030405";
    const input = "0xaabbccddeeff00";
    const value = 11n;

    expect(
      await helper.testRawCommandCall.staticCall(
        selector,
        target,
        value,
        account,
        state,
        input,
        { value },
      ),
    ).to.deep.equal([encodeContextBlock(account, state, input), value + 7n]);
  });

  it("wraps failed command calls in FailedCall", async () => {
    const helper = await deploy("TestCommandCalls");
    const selector = helper.interface.getFunction("failing")!.selector;
    const target = await helper.getAddress();
    const reason = helper.interface.encodeErrorResult("TargetFailure", [7n]);
    const errors = new ethers.Interface([
      "error FailedCall(address addr, bytes4 selector, bytes err)",
    ]);

    let data: string | undefined;
    try {
      await helper.testRawCommandCall(selector, target, 0n, ethers.ZeroHash, "0x", "0x");
    } catch (error: any) {
      data = error.data ?? error.info?.error?.data;
    }

    const failure = errors.parseError(data!);
    expect(failure?.name).to.equal("FailedCall");
    expect(failure?.args).to.deep.equal([
      await helper.getAddress(),
      selector,
      reason,
    ]);
  });

  it("rejects command return data with an invalid bytes offset", async () => {
    const helper = await deploy("TestCommandCalls");
    const selector = helper.interface.getFunction("malformed")!.selector;
    const target = await helper.getAddress();

    let data: string | undefined;
    try {
      await helper.testRawCommandCall(selector, target, 0n, ethers.ZeroHash, "0x", "0x");
    } catch (error: any) {
      data = error.data ?? error.info?.error?.data;
    }

    expect(data).to.equal("0x");
  });

  for (const name of ["shortReturn", "oversizedLength", "trailingData"] as const) {
    it(`rejects ${name} command return data`, async () => {
      const helper = await deploy("TestCommandCalls");
      const selector = helper.interface.getFunction(name)!.selector;
      const target = await helper.getAddress();

      let data: string | undefined;
      try {
        await helper.testRawCommandCall(
          selector,
          target,
          0n,
          ethers.ZeroHash,
          "0x",
          "0x",
        );
      } catch (error: any) {
        data = error.data ?? error.info?.error?.data;
      }

      expect(data).to.equal("0x");
    });
  }
});
