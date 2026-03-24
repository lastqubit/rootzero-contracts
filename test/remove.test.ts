import { expect } from "chai";
import { ethers } from "ethers";
import { deploy, getSigner } from "./helpers/setup.js";
import { concat, encodeRouteBlock } from "./helpers/blocks.js";
import "./helpers/matchers.js";

describe("Remove", () => {
  let host: Awaited<ReturnType<typeof deploy>>;
  let userAccount: string;
  const removeMethod = "remove((uint256,bytes32,bytes,bytes))";

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
    return (host.connect(signer) as any)[removeMethod](...args);
  }

  // ── Happy path ─────────────────────────────────────────────────────────────

  it("emits RemoveCalled for a single ROUTE block", async () => {
    const route = "0xdead";
    const request = encodeRouteBlock(route);
    const tx = await callAs(0, ctx({ request }));
    await expect(tx).to.emit(host, "RemoveCalled").withArgs(userAccount, route);
  });

  it("emits RemoveCalled for each ROUTE block when multiple are present", async () => {
    const route1 = "0x1111";
    const route2 = "0x2222";
    const request = concat(encodeRouteBlock(route1), encodeRouteBlock(route2));
    const tx = await callAs(0, ctx({ request }));
    await expect(tx).to.emit(host, "RemoveCalled").withArgs(userAccount, route1);
    await expect(tx).to.emit(host, "RemoveCalled").withArgs(userAccount, route2);
  });

  it("returns empty bytes after processing ROUTE blocks", async () => {
    const request = encodeRouteBlock("0x01");
    const result: string = await (host as any)[removeMethod].staticCall(ctx({ request }));
    expect(result).to.equal("0x");
  });

  // ── Target / access guards ─────────────────────────────────────────────────

  it("accepts the explicit remove command id as the target", async () => {
    const target = await host.getRemoveId();
    const request = encodeRouteBlock("0x99");
    const tx = await callAs(0, ctx({ target, request }));
    await expect(tx).to.emit(host, "RemoveCalled");
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

  // ── Error cases ────────────────────────────────────────────────────────────

  it("reverts NoOperation when request is empty", async () => {
    await expect(callAs(0, ctx()))
      .to.be.revertedWithCustomError(host, "NoOperation");
  });
});
