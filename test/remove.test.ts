import { expect } from "chai";
import { ethers } from "ethers";
import { deploy, getSigner } from "./helpers/setup.js";
import { concat, encodeRouteBlock } from "./helpers/blocks.js";
import "./helpers/matchers.js";

describe("Remove", () => {
  let host: Awaited<ReturnType<typeof deploy>>;
  let userAccount: string;
  const removeMethod = "remove((bytes32,bytes,bytes))";

  before(async () => {
    const signer = await getSigner(0);
    const commander = await signer.getAddress();
    host = await deploy("TestRemoveHost", commander);

    const USER_PREFIX = 0x20010102n;
    userAccount = ethers.zeroPadValue(
      ethers.toBeHex((USER_PREFIX << 224n) | (BigInt(commander) << 32n)),
      32
    );
  });

  function ctx(overrides: Partial<{ account: string; state: string; request: string }> = {}) {
    return {
      account: overrides.account ?? userAccount,
      state:   overrides.state   ?? "0x",
      request: overrides.request ?? "0x",
    };
  }

  async function callAs(signerIndex: number, ...args: unknown[]) {
    const signer = await getSigner(signerIndex);
    return (host.connect(signer) as any)[removeMethod](...args);
  }

  it("emits RemoveCalled for a single input block", async () => {
    const inputData = "0xdead";
    const request = encodeRouteBlock(inputData);
    const tx = await callAs(0, ctx({ request }));
    await expect(tx).to.emit(host, "RemoveCalled").withArgs(userAccount, inputData);
  });

  it("emits RemoveCalled for each input block when multiple are present", async () => {
    const input1 = "0x1111";
    const input2 = "0x2222";
    const request = concat(encodeRouteBlock(input1), encodeRouteBlock(input2));
    const tx = await callAs(0, ctx({ request }));
    await expect(tx).to.emit(host, "RemoveCalled").withArgs(userAccount, input1);
    await expect(tx).to.emit(host, "RemoveCalled").withArgs(userAccount, input2);
  });

  it("returns empty bytes after processing input blocks", async () => {
    const request = encodeRouteBlock("0x01");
    const result: string = await (host as any)[removeMethod].staticCall(ctx({ request }));
    expect(result).to.equal("0x");
  });

  it("reverts UnauthorizedCaller for an untrusted caller", async () => {
    const request = encodeRouteBlock("0x01");
    await expect(callAs(1, ctx({ request })))
      .to.be.revertedWithCustomError(host, "UnauthorizedCaller");
  });

  it("reverts ZeroCursor when request is empty", async () => {
    await expect(callAs(0, ctx()))
      .to.be.revertedWithCustomError(host, "ZeroCursor");
  });
});


