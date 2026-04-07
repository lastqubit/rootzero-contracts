import { expect } from "chai";
import { ethers } from "ethers";
import { deploy, getSigner } from "./helpers/setup.js";
import { concat, encodeRouteBlock } from "./helpers/blocks.js";
import "./helpers/matchers.js";

describe("Create", () => {
  let host: Awaited<ReturnType<typeof deploy>>;
  let userAccount: string;
  const createMethod = "create((uint256,bytes32,bytes,bytes))";

  before(async () => {
    const signer = await getSigner(0);
    const commander = await signer.getAddress();
    host = await deploy("TestCreateHost", commander);

    const USER_PREFIX = 0x20010102n;
    userAccount = ethers.zeroPadValue(
      ethers.toBeHex((USER_PREFIX << 224n) | (BigInt(commander) << 32n)),
      32
    );
  });

  function ctx(overrides: Partial<{ target: bigint; account: string; state: string; request: string }> = {}) {
    return {
      target:  overrides.target  ?? 0n,
      account: overrides.account ?? userAccount,
      state:   overrides.state   ?? "0x",
      request: overrides.request ?? "0x",
    };
  }

  async function callAs(signerIndex: number, ...args: unknown[]) {
    const signer = await getSigner(signerIndex);
    return (host.connect(signer) as any)[createMethod](...args);
  }

  it("emits CreateCalled for a single input block", async () => {
    const inputData = "0xabcd";
    const request = encodeRouteBlock(inputData);
    const tx = await callAs(0, ctx({ request }));
    await expect(tx).to.emit(host, "CreateCalled").withArgs(userAccount, inputData);
  });

  it("emits CreateCalled for each input block when multiple are present", async () => {
    const input1 = "0x1111";
    const input2 = "0x2222";
    const request = concat(encodeRouteBlock(input1), encodeRouteBlock(input2));
    const tx = await callAs(0, ctx({ request }));
    await expect(tx).to.emit(host, "CreateCalled").withArgs(userAccount, input1);
    await expect(tx).to.emit(host, "CreateCalled").withArgs(userAccount, input2);
  });

  it("returns empty bytes after processing input blocks", async () => {
    const request = encodeRouteBlock("0x01");
    const result: string = await (host as any)[createMethod].staticCall(ctx({ request }));
    expect(result).to.equal("0x");
  });

  it("processes all input blocks in the request stream", async () => {
    const request = concat(encodeRouteBlock("0xff"), encodeRouteBlock("0xee"));
    const tx = await callAs(0, ctx({ request }));
    await expect(tx).to.emit(host, "CreateCalled").withArgs(userAccount, "0xff");
    await expect(tx).to.emit(host, "CreateCalled").withArgs(userAccount, "0xee");
  });

  it("accepts the explicit create command id as the target", async () => {
    const target = await host.getCreateId();
    const request = encodeRouteBlock("0x99");
    const tx = await callAs(0, ctx({ target, request }));
    await expect(tx).to.emit(host, "CreateCalled");
  });

  it("reverts UnexpectedEndpoint for a wrong non-zero target", async () => {
    const request = encodeRouteBlock("0x01");
    await expect(callAs(0, ctx({ target: 999n, request })))
      .to.be.revertedWithCustomError(host, "UnexpectedEndpoint");
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


