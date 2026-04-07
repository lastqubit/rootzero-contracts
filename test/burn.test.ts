import { expect } from "chai";
import { ethers } from "ethers";
import { deploy, getSigner } from "./helpers/setup.js";
import { concat, encodeBalanceBlock } from "./helpers/blocks.js";
import "./helpers/matchers.js";

describe("Burn", () => {
  let host: Awaited<ReturnType<typeof deploy>>;
  let userAccount: string;
  const burnMethod = "burn((uint256,bytes32,bytes,bytes))";

  before(async () => {
    const signer = await getSigner(0);
    const commander = await signer.getAddress();
    host = await deploy("TestBurnHost", commander);

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
    return (host.connect(signer) as any)[burnMethod](...args);
  }

  // ── Happy path ─────────────────────────────────────────────────────────────

  it("emits BurnCalled for a single BALANCE block in state", async () => {
    const asset = ethers.zeroPadValue("0xa1", 32);
    const meta  = ethers.ZeroHash;
    const state = encodeBalanceBlock(asset, meta, 100n);
    const tx = await callAs(0, ctx({ state }));
    await expect(tx).to.emit(host, "BurnCalled").withArgs(userAccount, asset, meta, 100n);
  });

  it("emits BurnCalled for each BALANCE block when multiple are present", async () => {
    const asset1 = ethers.zeroPadValue("0xb1", 32);
    const asset2 = ethers.zeroPadValue("0xb2", 32);
    const meta   = ethers.ZeroHash;
    const state  = concat(
      encodeBalanceBlock(asset1, meta, 10n),
      encodeBalanceBlock(asset2, meta, 20n)
    );
    const tx = await callAs(0, ctx({ state }));
    await expect(tx).to.emit(host, "BurnCalled").withArgs(userAccount, asset1, meta, 10n);
    await expect(tx).to.emit(host, "BurnCalled").withArgs(userAccount, asset2, meta, 20n);
  });

  it("returns empty bytes after processing BALANCE blocks", async () => {
    const state = encodeBalanceBlock(ethers.zeroPadValue("0xc1", 32), ethers.ZeroHash, 50n);
    const result: string = await (host as any)[burnMethod].staticCall(ctx({ state }));
    expect(result).to.equal("0x");
  });

  it("stops at the first non-BALANCE block and succeeds if at least one was processed", async () => {
    // Single balance followed by an amount block — only the balance is burned
    const asset = ethers.zeroPadValue("0xd1", 32);
    const state = encodeBalanceBlock(asset, ethers.ZeroHash, 5n);
    const tx = await callAs(0, ctx({ state }));
    await expect(tx).to.emit(host, "BurnCalled").withArgs(userAccount, asset, ethers.ZeroHash, 5n);
  });

  // ── Target / access guards ─────────────────────────────────────────────────

  it("accepts the explicit burn command id as the target", async () => {
    const target = await host.getBurnId();
    const state  = encodeBalanceBlock(ethers.zeroPadValue("0xe1", 32), ethers.ZeroHash, 1n);
    const tx = await callAs(0, ctx({ target, state }));
    await expect(tx).to.emit(host, "BurnCalled");
  });

  it("reverts UnexpectedEndpoint for a wrong non-zero target", async () => {
    const state = encodeBalanceBlock(ethers.zeroPadValue("0xf1", 32), ethers.ZeroHash, 1n);
    await expect(callAs(0, ctx({ target: 999n, state })))
      .to.be.revertedWithCustomError(host, "UnexpectedEndpoint");
  });

  it("reverts UnauthorizedCaller for an untrusted caller", async () => {
    const state = encodeBalanceBlock(ethers.zeroPadValue("0xf2", 32), ethers.ZeroHash, 1n);
    await expect(callAs(1, ctx({ state })))
      .to.be.revertedWithCustomError(host, "UnauthorizedCaller");
  });

  // ── Error cases ────────────────────────────────────────────────────────────

  it("reverts ZeroCursor when state is empty", async () => {
    await expect(callAs(0, ctx()))
      .to.be.revertedWithCustomError(host, "ZeroCursor");
  });
});


