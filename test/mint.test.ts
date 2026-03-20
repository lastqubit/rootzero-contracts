import { expect } from "chai";
import { ethers } from "ethers";
import { deploy, getSigner } from "./helpers/setup.js";
import { concat, encodeBalanceBlock, encodeRouteBlock } from "./helpers/blocks.js";
import "./helpers/matchers.js";

describe("Mint", () => {
  let host: Awaited<ReturnType<typeof deploy>>;
  let userAccount: string;
  const mintMethod = "mint((uint256,bytes32,bytes,bytes))";

  const ASSET  = ethers.zeroPadValue("0xa1", 32);
  const META   = ethers.ZeroHash;
  const AMOUNT = 500n;

  before(async () => {
    const signer = await getSigner(0);
    const commander = await signer.getAddress();
    host = await deploy("TestMintHost", commander);

    const USER_PREFIX = 0x20010202n;
    userAccount = ethers.zeroPadValue(
      ethers.toBeHex((USER_PREFIX << 224n) | (BigInt(commander) << 32n)),
      32
    );

    // Configure the fixed return value used by the test mint implementation
    await (host as any).setReturn(ASSET, META, AMOUNT);
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
    return (host.connect(signer) as any)[mintMethod](...args);
  }

  // ── Happy path ─────────────────────────────────────────────────────────────

  it("emits MintCalled for a single ROUTE block", async () => {
    const route = "0x1234";
    const request = encodeRouteBlock(route);
    const tx = await callAs(0, ctx({ request }));
    await expect(tx).to.emit(host, "MintCalled").withArgs(userAccount, route);
  });

  it("returns one BALANCE block for a single ROUTE block", async () => {
    const request = encodeRouteBlock("0x01");
    const result: string = await (host as any)[mintMethod].staticCall(ctx({ request }));
    expect(result).to.equal(encodeBalanceBlock(ASSET, META, AMOUNT));
  });

  it("emits MintCalled for each ROUTE block when multiple are present", async () => {
    const route1 = "0xaaaa";
    const route2 = "0xbbbb";
    const request = concat(encodeRouteBlock(route1), encodeRouteBlock(route2));
    const tx = await callAs(0, ctx({ request }));
    await expect(tx).to.emit(host, "MintCalled").withArgs(userAccount, route1);
    await expect(tx).to.emit(host, "MintCalled").withArgs(userAccount, route2);
  });

  it("returns one BALANCE block per ROUTE block", async () => {
    const request = concat(encodeRouteBlock("0x01"), encodeRouteBlock("0x02"));
    const result: string = await (host as any)[mintMethod].staticCall(ctx({ request }));
    expect(result).to.equal(concat(
      encodeBalanceBlock(ASSET, META, AMOUNT),
      encodeBalanceBlock(ASSET, META, AMOUNT)
    ));
  });

  // ── Target / access guards ─────────────────────────────────────────────────

  it("accepts the explicit mint command id as the target", async () => {
    const target = await host.getMintId();
    const request = encodeRouteBlock("0x99");
    const tx = await callAs(0, ctx({ target, request }));
    await expect(tx).to.emit(host, "MintCalled");
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

  it("reverts EmptyRequest when request has no ROUTE blocks", async () => {
    await expect(callAs(0, ctx()))
      .to.be.revertedWithCustomError(host, "EmptyRequest");
  });
});
