import { expect } from "chai";
import { ethers } from "ethers";
import { deploy, getSigner } from "./helpers/setup.js";
import { concat, encodeBalanceBlock, encodeRouteBlockWithAmount } from "./helpers/blocks.js";
import "./helpers/matchers.js";

describe("ReclaimToBalances", () => {
  let host: Awaited<ReturnType<typeof deploy>>;
  let userAccount: string;
  const reclaimMethod = "reclaimToBalances((uint256,bytes32,bytes,bytes))";

  const ASSET  = ethers.zeroPadValue("0xa1", 32);
  const META   = ethers.ZeroHash;
  const AMOUNT = 500n;

  before(async () => {
    const signer = await getSigner(0);
    const commander = await signer.getAddress();
    host = await deploy("TestReclaimHost", commander);

    const USER_PREFIX = 0x20010102n;
    userAccount = ethers.zeroPadValue(
      ethers.toBeHex((USER_PREFIX << 224n) | (BigInt(commander) << 32n)),
      32
    );

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
    return (host.connect(signer) as any)[reclaimMethod](...args);
  }

  // ── Happy path ─────────────────────────────────────────────────────────────

  it("emits ReclaimCalled with the account and embedded amount", async () => {
    const route = "0x1234";
    const request = encodeRouteBlockWithAmount(route, ASSET, META, 100n);
    const tx = await callAs(0, ctx({ request }));
    await expect(tx).to.emit(host, "ReclaimCalled")
      .withArgs(userAccount, ASSET, META, 100n, route);
  });

  it("returns one BALANCE block for a single ROUTE block", async () => {
    const request = encodeRouteBlockWithAmount("0x01", ASSET, META, 100n);
    const result: string = await (host as any)[reclaimMethod].staticCall(ctx({ request }));
    expect(result).to.equal(encodeBalanceBlock(ASSET, META, AMOUNT));
  });

  it("emits ReclaimCalled for each ROUTE block when multiple are present", async () => {
    const asset1 = ethers.zeroPadValue("0xa1", 32);
    const asset2 = ethers.zeroPadValue("0xa2", 32);
    const request = concat(
      encodeRouteBlockWithAmount("0xaaaa", asset1, META, 100n),
      encodeRouteBlockWithAmount("0xbbbb", asset2, META, 200n),
    );
    const tx = await callAs(0, ctx({ request }));
    await expect(tx).to.emit(host, "ReclaimCalled").withArgs(userAccount, asset1, META, 100n, "0xaaaa");
    await expect(tx).to.emit(host, "ReclaimCalled").withArgs(userAccount, asset2, META, 200n, "0xbbbb");
  });

  it("returns one BALANCE block per ROUTE block", async () => {
    const request = concat(
      encodeRouteBlockWithAmount("0x01", ASSET, META, 100n),
      encodeRouteBlockWithAmount("0x02", ASSET, META, 200n),
    );
    const result: string = await (host as any)[reclaimMethod].staticCall(ctx({ request }));
    expect(result).to.equal(concat(
      encodeBalanceBlock(ASSET, META, AMOUNT),
      encodeBalanceBlock(ASSET, META, AMOUNT),
    ));
  });

  it("reverts EmptyRequest when all reclaim outputs are zero", async () => {
    await (host as any).setReturn(ASSET, META, 0n);
    const request = encodeRouteBlockWithAmount("0x01", ASSET, META, 100n);
    await expect(callAs(0, ctx({ request })))
      .to.be.revertedWithCustomError(host, "EmptyRequest");
    await (host as any).setReturn(ASSET, META, AMOUNT);
  });

  // ── Target / access guards ─────────────────────────────────────────────────

  it("accepts the explicit reclaim command id as the target", async () => {
    const target = await (host as any).getReclaimBalanceId();
    const request = encodeRouteBlockWithAmount("0x99", ASSET, META, 100n);
    const tx = await callAs(0, ctx({ target, request }));
    await expect(tx).to.emit(host, "ReclaimCalled");
  });

  it("reverts UnexpectedEndpoint for a wrong non-zero target", async () => {
    const request = encodeRouteBlockWithAmount("0x01", ASSET, META, 100n);
    await expect(callAs(0, ctx({ target: 999n, request })))
      .to.be.revertedWithCustomError(host, "UnexpectedEndpoint");
  });

  it("reverts UnauthorizedCaller for an untrusted caller", async () => {
    const request = encodeRouteBlockWithAmount("0x01", ASSET, META, 100n);
    await expect(callAs(1, ctx({ request })))
      .to.be.revertedWithCustomError(host, "UnauthorizedCaller");
  });

  // ── Error cases ────────────────────────────────────────────────────────────

  it("reverts EmptyRequest when request has no ROUTE blocks", async () => {
    await expect(callAs(0, ctx()))
      .to.be.revertedWithCustomError(host, "EmptyRequest");
  });
});
