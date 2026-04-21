import { expect } from "chai";
import { ethers } from "ethers";
import { deploy, getSigner } from "./helpers/setup.js";
import { concat, encodeCustodyAtBlock } from "./helpers/blocks.js";
import "./helpers/matchers.js";

describe("Supply", () => {
  let host: Awaited<ReturnType<typeof deploy>>;
  let userAccount: string;
  const supplyMethod = "supply((bytes32,bytes,bytes))";

  before(async () => {
    const signer = await getSigner(0);
    const commander = await signer.getAddress();
    host = await deploy("TestSupplyHost", commander);

    const USER_PREFIX = 0x20010102n;
    userAccount = ethers.zeroPadValue(
      ethers.toBeHex((USER_PREFIX << 224n) | (BigInt(commander) << 32n)),
      32
    );
  });

  function ctx(overrides: Partial<{ account: string; state: string; request: string }> = {}) {
    return {
      account: overrides.account ?? userAccount,
      state: overrides.state ?? "0x",
      request: overrides.request ?? "0x",
    };
  }

  async function callAs(signerIndex: number, ...args: unknown[]) {
    const signer = await getSigner(signerIndex);
    return (host.connect(signer) as any)[supplyMethod](...args);
  }

  it("emits SupplyCalled for a single CUSTODY block in state", async () => {
    const asset = ethers.zeroPadValue("0xa1", 32);
    const meta = ethers.ZeroHash;
    const state = encodeCustodyAtBlock(7n, asset, meta, 100n);
    const tx = await callAs(0, ctx({ state }));
    await expect(tx).to.emit(host, "SupplyCalled").withArgs(userAccount, 7n, asset, meta, 100n);
  });

  it("emits SupplyCalled for each CUSTODY block when multiple are present", async () => {
    const asset1 = ethers.zeroPadValue("0xb1", 32);
    const asset2 = ethers.zeroPadValue("0xb2", 32);
    const meta = ethers.ZeroHash;
    const state = concat(
      encodeCustodyAtBlock(1n, asset1, meta, 10n),
      encodeCustodyAtBlock(2n, asset2, meta, 20n)
    );
    const tx = await callAs(0, ctx({ state }));
    await expect(tx).to.emit(host, "SupplyCalled").withArgs(userAccount, 1n, asset1, meta, 10n);
    await expect(tx).to.emit(host, "SupplyCalled").withArgs(userAccount, 2n, asset2, meta, 20n);
  });

  it("returns empty bytes after processing CUSTODY blocks", async () => {
    const state = encodeCustodyAtBlock(3n, ethers.zeroPadValue("0xc1", 32), ethers.ZeroHash, 50n);
    const result: string = await (host as any)[supplyMethod].staticCall(ctx({ state }));
    expect(result).to.equal("0x");
  });

  it("reverts UnauthorizedCaller for an untrusted caller", async () => {
    const state = encodeCustodyAtBlock(6n, ethers.zeroPadValue("0xf1", 32), ethers.ZeroHash, 1n);
    await expect(callAs(1, ctx({ state })))
      .to.be.revertedWithCustomError(host, "UnauthorizedCaller");
  });

  it("reverts ZeroCursor when state is empty", async () => {
    await expect((host as any)[supplyMethod].staticCall(ctx()))
      .to.be.revertedWithCustomError(host, "ZeroCursor");
  });
});
