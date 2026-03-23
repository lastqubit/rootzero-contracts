import { expect } from "chai";
import { ethers } from "ethers";
import { deploy, getSigner } from "./helpers/setup.js";
import { concat, encodeBalanceBlock, encodeCustodyBlock, encodeRouteBlock } from "./helpers/blocks.js";
import "./helpers/matchers.js";

describe("BorrowAgainstCustodyToBalance", () => {
  let host: Awaited<ReturnType<typeof deploy>>;
  let userAccount: string;
  const borrowMethod = "borrowAgainstCustodyToBalance((uint256,bytes32,bytes,bytes))";

  const ASSET  = ethers.zeroPadValue("0xa1", 32);
  const META   = ethers.ZeroHash;
  const AMOUNT = 500n;
  const HOST_ID = 77n;

  before(async () => {
    const signer = await getSigner(0);
    const commander = await signer.getAddress();
    host = await deploy("TestBorrowHost", commander);

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
    return (host.connect(signer) as any)[borrowMethod](...args);
  }

  function custodyState(
    asset: string = ASSET,
    meta: string = META,
    amount: bigint = 100n,
    hostId: bigint = HOST_ID,
  ) {
    return encodeCustodyBlock(hostId, asset, meta, amount);
  }

  // ── Happy path ─────────────────────────────────────────────────────────────

  it("emits BorrowCalled with the account and custody amount", async () => {
    const route = "0x1234";
    const state = custodyState(ASSET, META, 100n);
    const request = encodeRouteBlock(route);
    const tx = await callAs(0, ctx({ state, request }));
    await expect(tx).to.emit(host, "BorrowCalled")
      .withArgs(userAccount, ASSET, META, 100n, route);
  });

  it("returns one BALANCE block for a single CUSTODY block", async () => {
    const state = custodyState(ASSET, META, 100n);
    const request = encodeRouteBlock("0x01");
    const result: string = await (host as any)[borrowMethod].staticCall(ctx({ state, request }));
    expect(result).to.equal(encodeBalanceBlock(ASSET, META, AMOUNT));
  });

  it("emits BorrowCalled for each custody-route pair when multiple are present", async () => {
    const asset1 = ethers.zeroPadValue("0xa1", 32);
    const asset2 = ethers.zeroPadValue("0xa2", 32);
    const state = concat(
      custodyState(asset1, META, 100n, HOST_ID),
      custodyState(asset2, META, 200n, HOST_ID + 1n),
    );
    const request = concat(
      encodeRouteBlock("0xaaaa"),
      encodeRouteBlock("0xbbbb"),
    );
    const tx = await callAs(0, ctx({ state, request }));
    await expect(tx).to.emit(host, "BorrowCalled").withArgs(userAccount, asset1, META, 100n, "0xaaaa");
    await expect(tx).to.emit(host, "BorrowCalled").withArgs(userAccount, asset2, META, 200n, "0xbbbb");
  });

  it("returns one BALANCE block per custody-route pair", async () => {
    const state = concat(
      custodyState(ASSET, META, 100n, HOST_ID),
      custodyState(ASSET, META, 200n, HOST_ID + 1n),
    );
    const request = concat(
      encodeRouteBlock("0x01"),
      encodeRouteBlock("0x02"),
    );
    const result: string = await (host as any)[borrowMethod].staticCall(ctx({ state, request }));
    expect(result).to.equal(concat(
      encodeBalanceBlock(ASSET, META, AMOUNT),
      encodeBalanceBlock(ASSET, META, AMOUNT),
    ));
  });

  it("reverts EmptyRequest when all borrow outputs are zero", async () => {
    await (host as any).setReturn(ASSET, META, 0n);
    const state = custodyState(ASSET, META, 100n);
    const request = encodeRouteBlock("0x01");
    await expect(callAs(0, ctx({ state, request })))
      .to.be.revertedWithCustomError(host, "EmptyRequest");
    await (host as any).setReturn(ASSET, META, AMOUNT);
  });

  // ── Target / access guards ─────────────────────────────────────────────────

  it("accepts the explicit borrow command id as the target", async () => {
    const target = await (host as any).getBorrowId();
    const state = custodyState(ASSET, META, 100n);
    const request = encodeRouteBlock("0x99");
    const tx = await callAs(0, ctx({ target, state, request }));
    await expect(tx).to.emit(host, "BorrowCalled");
  });

  it("reverts UnexpectedEndpoint for a wrong non-zero target", async () => {
    const state = custodyState(ASSET, META, 100n);
    const request = encodeRouteBlock("0x01");
    await expect(callAs(0, ctx({ target: 999n, state, request })))
      .to.be.revertedWithCustomError(host, "UnexpectedEndpoint");
  });

  it("reverts UnauthorizedCaller for an untrusted caller", async () => {
    const state = custodyState(ASSET, META, 100n);
    const request = encodeRouteBlock("0x01");
    await expect(callAs(1, ctx({ state, request })))
      .to.be.revertedWithCustomError(host, "UnauthorizedCaller");
  });

  // ── Error cases ────────────────────────────────────────────────────────────

  it("reverts EmptyRequest when state has no CUSTODY blocks", async () => {
    const request = encodeRouteBlock("0x01");
    await expect(callAs(0, ctx({ request })))
      .to.be.revertedWithCustomError(host, "EmptyRequest");
  });

  it("reverts InvalidBlock when a custody is missing a matching ROUTE block", async () => {
    const state = custodyState(ASSET, META, 100n);
    await expect(callAs(0, ctx({ state })))
      .to.be.revertedWithCustomError(host, "InvalidBlock");
  });

  it("reverts InvalidBlock when request does not start with a ROUTE block", async () => {
    const state = custodyState(ASSET, META, 100n);
    const request = encodeBalanceBlock(ASSET, META, 100n);
    await expect(callAs(0, ctx({ state, request })))
      .to.be.revertedWithCustomError(host, "InvalidBlock");
  });
});
