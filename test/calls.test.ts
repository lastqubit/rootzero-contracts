import { expect } from "chai";
import { ethers } from "ethers";
import { commandId, deploy } from "./helpers/setup.js";
import { encodeContextBlock, encodeStepBlock } from "./helpers/blocks.js";
import "./helpers/matchers.js";

describe("Command calls", () => {
  it("calls a selector with one memory bytes argument and forwards value", async () => {
    const helper = await deploy("TestCommandCalls");
    const selector = helper.interface.getFunction("echoBytes")!.selector;
    const input = "0xaabbcc";
    const value = 9n;

    const out = await helper.testRawCall.staticCall(
      selector,
      await helper.getAddress(),
      value,
      input,
      false,
      { value },
    );
    expect(out).to.equal(input);
  });

  it("returns decoded bytes when copying call input from calldata", async () => {
    const helper = await deploy("TestCommandCalls");
    const input = ethers.hexlify(ethers.randomBytes(33));
    const out = await helper.testRawCallCopy.staticCall(
      helper.interface.getFunction("echoBytes")!.selector,
      await helper.getAddress(),
      0n,
      input,
      false,
    );

    expect(out).to.equal(input);
  });

  it("optionally requires empty decoded call output", async () => {
    const helper = await deploy("TestCommandCalls");
    const selector = helper.interface.getFunction("echoBytes")!.selector;
    const target = await helper.getAddress();

    expect(await helper.testRawCall.staticCall(selector, target, 0n, "0x", true))
      .to.equal("0x");
    expect(await helper.testRawCallCopy.staticCall(selector, target, 0n, "0x", true))
      .to.equal("0x");
    for (const call of [
      () => helper.testRawCall.staticCall(selector, target, 0n, "0x01", true),
      () => helper.testRawCallCopy.staticCall(selector, target, 0n, "0x01", true),
    ]) {
      let data: string | undefined;
      try {
        await call();
      } catch (error: any) {
        data = error.data ?? error.info?.error?.data;
      }
      expect(data).to.equal("0x");
    }
  });

  it("handles bytes lengths around ABI word boundaries", async () => {
    const helper = await deploy("TestCommandCalls");
    const selector = helper.interface.getFunction("echoBytes")!.selector;
    const target = await helper.getAddress();

    for (const length of [0, 1, 31, 32, 33, 63, 64, 65]) {
      const input = ethers.hexlify(ethers.randomBytes(length));

      expect(await helper.testRawCall.staticCall(selector, target, 0n, input, false))
        .to.equal(input);
      expect(await helper.testRawCallCopy.staticCall(selector, target, 0n, input, false))
        .to.equal(input);
      expect(await helper.testTryRawCall.staticCall(selector, target, 0n, input))
        .to.equal(true);
      expect(await helper.testTryRawCallCopy.staticCall(selector, target, 0n, input))
        .to.equal(true);
    }
  });

  it("tries a selector call without reverting on target failure", async () => {
    const helper = await deploy("TestCommandCalls");
    const target = await helper.getAddress();
    const input = "0x010203";

    expect(await helper.testTryRawCall.staticCall(
      helper.interface.getFunction("echoBytes")!.selector,
      target,
      0n,
      input,
    )).to.equal(true);
    expect(await helper.testTryRawCall.staticCall(
      helper.interface.getFunction("failBytes")!.selector,
      target,
      0n,
      input,
    )).to.equal(false);
  });

  it("calls a single bytes argument directly from calldata", async () => {
    const helper = await deploy("TestCommandCalls");
    const selector = helper.interface.getFunction("echoBytes")!.selector;
    const target = await helper.getAddress();
    const input = ethers.hexlify(ethers.randomBytes(33));
    const value = 7n;

    const tx = await helper.testTryRawCallCopy(selector, target, value, input, { value });
    await expect(tx).to.emit(helper, "BytesCalled").withArgs(input, value);

    expect(await helper.testTryRawCallCopy.staticCall("0xffffffff", target, 0n, input))
      .to.equal(false);
  });

  it("uses less gas when copying the bytes argument directly from calldata", async () => {
    const helper = await deploy("TestCommandCalls");
    const selector = helper.interface.getFunction("echoBytes")!.selector;
    const target = await helper.getAddress();
    const input = ethers.hexlify(ethers.randomBytes(97));

    const copied = await helper.testTryRawCallCopy.estimateGas(selector, target, 0n, input);
    const memory = await helper.testTryRawCall.estimateGas(selector, target, 0n, input);

    expect(copied).to.be.lessThan(memory);
  });

  it("queries bytes around ABI word boundaries", async () => {
    const helper = await deploy("TestCommandCalls");
    const selector = helper.interface.getFunction("queryBytes")!.selector;
    const target = await helper.getAddress();

    for (const length of [0, 1, 31, 32, 33, 63, 64, 65]) {
      const input = ethers.hexlify(ethers.randomBytes(length));
      expect(await helper.testRawQuery(selector, target, input))
        .to.equal(input);
    }
  });

  it("rejects queries with non-bytes return data", async () => {
    const helper = await deploy("TestCommandCalls");
    const selector = helper.interface.getFunction("noArgs")!.selector;

    let failure: string | undefined;
    try {
      await helper.testRawQuery(selector, await helper.getAddress(), "0x");
    } catch (error: any) {
      failure = error.data ?? error.info?.error?.data;
    }
    expect(failure).to.equal("0x");
  });

  it("preserves query failures in FailedCall", async () => {
    const helper = await deploy("TestCommandCalls");
    const target = await helper.getAddress();
    const selector = helper.interface.getFunction("failBytes")!.selector;
    const input = "0x010203";
    const reason = helper.interface.encodeErrorResult("TargetFailure", [3n]);
    const errors = new ethers.Interface([
      "error FailedCall(address addr, bytes4 selector, bytes err)",
    ]);

    let failureData: string | undefined;
    try {
      await helper.testRawQuery(selector, target, input);
    } catch (error: any) {
      failureData = error.data ?? error.info?.error?.data;
    }
    expect(errors.parseError(failureData!)?.args)
      .to.deep.equal([target, selector, reason]);
  });

  it("reports the separate selector when a raw call fails", async () => {
    const helper = await deploy("TestCommandCalls");
    const selector = helper.interface.getFunction("failBytes")!.selector;
    const target = await helper.getAddress();
    const input = "0x010203";
    const reason = helper.interface.encodeErrorResult("TargetFailure", [3n]);
    const errors = new ethers.Interface([
      "error FailedCall(address addr, bytes4 selector, bytes err)",
    ]);

    let data: string | undefined;
    try {
      await helper.testRawCall(selector, target, 0n, input, false);
    } catch (error: any) {
      data = error.data ?? error.info?.error?.data;
    }

    const failure = errors.parseError(data!);
    expect(failure?.name).to.equal("FailedCall");
    expect(failure?.args).to.deep.equal([target, selector, reason]);
  });

  it("rejects successful calls with invalid bytes return data", async () => {
    const helper = await deploy("TestCommandCalls");

    let data: string | undefined;
    try {
      await helper.testRawCall(
        helper.interface.getFunction("malformed")!.selector,
        await helper.getAddress(),
        0n,
        "0x",
        false,
      );
    } catch (error: any) {
      data = error.data ?? error.info?.error?.data;
    }

    expect(data).to.equal("0x");
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
