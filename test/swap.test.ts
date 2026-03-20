import { expect } from "chai";
import { ethers } from "ethers";
import {
  concat,
  encodeBalanceBlock,
  encodeRouteBlock,
  encodeRouteBlockWithMinimum,
  pad32,
} from "./helpers/blocks.js";
import { deploy, getSigner } from "./helpers/setup.js";
import "./helpers/matchers.js";

describe("SwapExactBalanceToBalance", () => {
  let host: Awaited<ReturnType<typeof deploy>>;
  let userAccount: string;
  const swapMethod = "swapExactBalanceToBalance((uint256,bytes32,bytes,bytes))";

  before(async () => {
    const signer = await getSigner(0);
    const commander = await signer.getAddress();
    host = await deploy("TestSwapHost", commander);

    const USER_PREFIX = 0x20010202n;
    userAccount = ethers.zeroPadValue(
      ethers.toBeHex((USER_PREFIX << 224n) | (BigInt(commander) << 32n)),
      32
    );
  });

  function ctx(overrides: Partial<{ target: bigint; account: string; state: string; request: string }> = {}) {
    return {
      target: overrides.target ?? 0n,
      account: overrides.account ?? userAccount,
      state: overrides.state ?? "0x",
      request: overrides.request ?? "0x",
    };
  }

  async function callAs(signerIndex: number, method: string, ...args: unknown[]) {
    const signer = await getSigner(signerIndex);
    return (host.connect(signer) as ethers.Contract)[method](...args);
  }

  it("maps each BALANCE block using its paired ROUTE block", async () => {
    const asset1 = ethers.zeroPadValue("0xa1", 32);
    const asset2 = ethers.zeroPadValue("0xa2", 32);
    const meta = ethers.ZeroHash;
    const route1 = "0x1234";
    const route2 = "0xaabbcc";
    const state = concat(
      encodeBalanceBlock(asset1, meta, 10n),
      encodeBalanceBlock(asset2, meta, 20n)
    );
    const request = concat(
      encodeRouteBlock(route1),
      encodeRouteBlock(route2)
    );

    const result = await (host as ethers.Contract)[swapMethod].staticCall(ctx({ state, request }));
    expect(result).to.equal(concat(
      encodeBalanceBlock(asset1, pad32(2n), 12n),
      encodeBalanceBlock(asset2, pad32(3n), 23n)
    ));
  });

  it("emits the raw route bytes that were paired with each balance", async () => {
    const asset = ethers.zeroPadValue("0xb1", 32);
    const route = "0xfeed";
    const tx = await callAs(0, swapMethod, ctx({
      state: encodeBalanceBlock(asset, ethers.ZeroHash, 5n),
      request: encodeRouteBlock(route),
    }));

    await expect(tx).to.emit(host, "SwapMapped")
      .withArgs(userAccount, asset, ethers.ZeroHash, 5n, route);
  });

  it("reverts InvalidBlock when a balance is missing its route block", async () => {
    const state = concat(
      encodeBalanceBlock(ethers.zeroPadValue("0xc1", 32), ethers.ZeroHash, 1n),
      encodeBalanceBlock(ethers.zeroPadValue("0xc2", 32), ethers.ZeroHash, 2n)
    );
    const request = encodeRouteBlock("0x01");

    await expect(callAs(0, swapMethod, ctx({ state, request })))
      .to.be.revertedWithCustomError(host, "InvalidBlock");
  });

  it("reverts UnexpectedEndpoint for a mismatched explicit target", async () => {
    const request = encodeRouteBlock("0x01");
    const state = encodeBalanceBlock(ethers.zeroPadValue("0xd1", 32), ethers.ZeroHash, 1n);

    await expect(callAs(0, swapMethod, ctx({ target: 1n, state, request })))
      .to.be.revertedWithCustomError(host, "UnexpectedEndpoint");
  });

  it("accepts the explicit swap command id as the target", async () => {
    const state = encodeBalanceBlock(ethers.zeroPadValue("0xe1", 32), ethers.ZeroHash, 4n);
    const request = encodeRouteBlock("0x99");
    const target = await host.getSwapExactInAsset32Id();

    await expect(callAs(0, swapMethod, ctx({ target, state, request })))
      .to.emit(host, "SwapMapped");
  });

  it("emits the minimum parsed from the route's child block", async () => {
    const asset = ethers.zeroPadValue("0xb2", 32);
    const meta = ethers.ZeroHash;
    const minAsset = ethers.zeroPadValue("0xcc", 32);
    const minMeta = ethers.zeroPadValue("0xdd", 32);
    const minAmount = 500n;
    const tx = await callAs(0, swapMethod, ctx({
      state: encodeBalanceBlock(asset, meta, 10n),
      request: encodeRouteBlockWithMinimum("0xab", minAsset, minMeta, minAmount),
    }));

    await expect(tx).to.emit(host, "SwapMinimum")
      .withArgs(minAsset, minMeta, minAmount);
  });

  it("reverts UnauthorizedCaller for an untrusted caller", async () => {
    const state = encodeBalanceBlock(ethers.zeroPadValue("0xf1", 32), ethers.ZeroHash, 1n);
    const request = encodeRouteBlock("0x01");

    await expect(callAs(1, swapMethod, ctx({ state, request })))
      .to.be.revertedWithCustomError(host, "UnauthorizedCaller");
  });
});
