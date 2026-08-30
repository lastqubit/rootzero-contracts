import { expect } from "chai";
import { ethers } from "ethers";
import { commandId, deploy } from "./helpers/setup.js";
import { encodeContextBlock, encodeStepBlock } from "./helpers/blocks.js";

describe("Command calls", () => {
  it("calls a selector with separately encoded arguments and forwards value", async () => {
    const helper = await deploy("TestCommandCalls");
    const selector = helper.interface.getFunction("echo")!.selector;
    const args = ethers.AbiCoder.defaultAbiCoder().encode(
      ["uint", "bytes"],
      [42n, "0xaabbcc"],
    );
    const value = 9n;

    const out = await helper.testRawCall.staticCall(
      selector,
      await helper.getAddress(),
      value,
      args,
      { value },
    );
    expect(ethers.AbiCoder.defaultAbiCoder().decode(
      ["uint", "bytes", "uint"],
      out,
    )).to.deep.equal([42n, "0xaabbcc", value]);
  });

  it("tries a selector call without reverting on target failure", async () => {
    const helper = await deploy("TestCommandCalls");
    const target = await helper.getAddress();
    const coder = ethers.AbiCoder.defaultAbiCoder();

    expect(await helper.testTryRawCall.staticCall(
      helper.interface.getFunction("echo")!.selector,
      target,
      0n,
      coder.encode(["uint", "bytes"], [7n, "0x"]),
    )).to.equal(true);
    expect(await helper.testTryRawCall.staticCall(
      helper.interface.getFunction("fail")!.selector,
      target,
      0n,
      coder.encode(["uint"], [7n]),
    )).to.equal(false);
  });

  it("queries a selector with separately encoded arguments", async () => {
    const helper = await deploy("TestCommandCalls");
    const args = ethers.AbiCoder.defaultAbiCoder().encode(
      ["uint", "bytes"],
      [17n, "0x010203"],
    );
    const out = await helper.testRawQuery(
      helper.interface.getFunction("query")!.selector,
      await helper.getAddress(),
      args,
    );

    expect(ethers.AbiCoder.defaultAbiCoder().decode(
      ["uint", "bytes", "address"],
      out,
    )).to.deep.equal([17n, "0x010203", await helper.getAddress()]);
  });

  it("calls a separate selector with empty arguments", async () => {
    const helper = await deploy("TestCommandCalls");
    const out = await helper.testRawQuery(
      helper.interface.getFunction("noArgs")!.selector,
      await helper.getAddress(),
      "0x",
    );

    expect(ethers.AbiCoder.defaultAbiCoder().decode(["uint"], out)[0]).to.equal(42n);
  });

  it("reports the separate selector when a raw call fails", async () => {
    const helper = await deploy("TestCommandCalls");
    const selector = helper.interface.getFunction("fail")!.selector;
    const target = await helper.getAddress();
    const reason = helper.interface.encodeErrorResult("TargetFailure", [13n]);
    const args = ethers.AbiCoder.defaultAbiCoder().encode(["uint"], [13n]);
    const errors = new ethers.Interface([
      "error FailedCall(address addr, bytes4 selector, bytes err)",
    ]);

    let data: string | undefined;
    try {
      await helper.testRawCall(selector, target, 0n, args);
    } catch (error: any) {
      data = error.data ?? error.info?.error?.data;
    }

    const failure = errors.parseError(data!);
    expect(failure?.name).to.equal("FailedCall");
    expect(failure?.args).to.deep.equal([target, selector, reason]);
  });

  it("calls command(bytes) with an exact context and decodes state and credit", async () => {
    const helper = await deploy("TestCommandCalls");
    const account = ethers.zeroPadValue("0xab", 32);
    const state = "0x0102030405";
    const input = "0xaabbccddeeff00";
    const value = 11n;
    const context = encodeContextBlock(account, state, input);
    const command = await commandId("command(bytes)", helper);
    const steps = encodeStepBlock(command, value, input);

    expect(
      await helper.testPipe.staticCall(
        account,
        state,
        steps,
        { value },
      ),
    ).to.equal(BigInt(ethers.keccak256(context)) ^ value);
  });

  it("wraps failed command calls in FailedCall", async () => {
    const helper = await deploy("TestCommandCalls");
    const selector = helper.interface.getFunction("failing")!.selector;
    const target = await helper.getAddress();
    const command = await commandId("failing(bytes)", helper);
    const steps = encodeStepBlock(command, 0n, "0x");
    const reason = helper.interface.encodeErrorResult("TargetFailure", [7n]);
    const errors = new ethers.Interface([
      "error FailedCall(address addr, bytes4 selector, bytes err)",
    ]);

    let data: string | undefined;
    try {
      await helper.testPipe(ethers.ZeroHash, "0x", steps);
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
    const command = await commandId("malformed(bytes)", helper);
    const steps = encodeStepBlock(command, 0n, "0x");

    let data: string | undefined;
    try {
      await helper.testPipe(ethers.ZeroHash, "0x", steps);
    } catch (error: any) {
      data = error.data ?? error.info?.error?.data;
    }

    expect(data).to.equal("0x");
  });

  for (const name of ["shortReturn", "oversizedLength", "trailingData"] as const) {
    it(`rejects ${name} command return data`, async () => {
      const helper = await deploy("TestCommandCalls");
      const command = await commandId(`${name}(bytes)`, helper);
      const steps = encodeStepBlock(command, 0n, "0x");

      let data: string | undefined;
      try {
        await helper.testPipe(ethers.ZeroHash, "0x", steps);
      } catch (error: any) {
        data = error.data ?? error.info?.error?.data;
      }

      expect(data).to.equal("0x");
    });
  }
});
