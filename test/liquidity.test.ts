import { expect } from "chai";
import { ethers } from "ethers";
import {
  concat,
  encodeBalanceBlock,
  encodeBundleBlock,
  encodeBundleBlockWithMinimum,
  encodeCustodyBlock,
  encodeRouteBlock,
  encodeMinimumBlock,
  pad32,
} from "./helpers/blocks.js";
import { deploy, getSigner } from "./helpers/setup.js";
import "./helpers/matchers.js";

describe("Liquidity Commands", () => {
  let host: Awaited<ReturnType<typeof deploy>>;
  let userAccount: string;

  const addCustodiesMethod = "addLiquidityFromCustodiesToBalances((uint256,bytes32,bytes,bytes))";
  const removeCustodyMethod = "removeLiquidityFromCustodyToBalances((uint256,bytes32,bytes,bytes))";
  const addBalancesMethod = "addLiquidityFromBalancesToBalances((uint256,bytes32,bytes,bytes))";
  const removeBalanceMethod = "removeLiquidityFromBalanceToBalances((uint256,bytes32,bytes,bytes))";

  const META = ethers.ZeroHash;
  const HOST_ID = 77n;
  const LP_FROM_CUSTODIES_ASSET = ethers.zeroPadValue("0xaaa1", 32);
  const LP_FROM_BALANCES_ASSET = ethers.zeroPadValue("0xaaa2", 32);
  const REDEEM_FROM_CUSTODY_ASSET = ethers.zeroPadValue("0xbbb1", 32);
  const REDEEM_FROM_BALANCE_ASSET = ethers.zeroPadValue("0xbbb2", 32);
  const MIN_ASSET = ethers.zeroPadValue("0xcc01", 32);
  const MIN_META = ethers.zeroPadValue("0xdd01", 32);
  const MIN_AMOUNT = 33n;

  before(async () => {
    const signer = await getSigner(0);
    const commander = await signer.getAddress();
    host = await deploy("TestLiquidityHost", commander);

    const USER_PREFIX = 0x20010102n;
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
    return (host.connect(signer) as any)[method](...args);
  }

  async function logGas(label: string, tx: Awaited<ReturnType<typeof callAs>>) {
    const receipt = await tx.wait();
    console.log(`${label}: ${receipt!.gasUsed.toString()} gas`);
  }

  it("addLiquidityFromCustodiesToBalances maps a custody pair and parses bundled minimum data", async () => {
    const assetA = ethers.zeroPadValue("0xa1", 32);
    const assetB = ethers.zeroPadValue("0xa2", 32);
    const state = concat(
      encodeCustodyBlock(HOST_ID, assetA, META, 10n),
      encodeCustodyBlock(HOST_ID + 1n, assetB, META, 20n),
    );
    const route = "0x1234";
    const bundleData = concat(
      encodeRouteBlock(route),
      encodeMinimumBlock(MIN_ASSET, MIN_META, MIN_AMOUNT),
    );
    const request = encodeBundleBlockWithMinimum(route, MIN_ASSET, MIN_META, MIN_AMOUNT);
    const bundleLen = BigInt(ethers.getBytes(bundleData).length);

    const tx = await callAs(0, addCustodiesMethod, ctx({ state, request }));
    await logGas("addLiquidityFromCustodiesToBalances single", tx);
    await expect(tx).to.emit(host, "AddCustodiesMapped")
      .withArgs(userAccount, assetA, 10n, assetB, 20n, bundleData);
    await expect(tx).to.emit(host, "MinimumObserved")
      .withArgs(MIN_ASSET, MIN_META, MIN_AMOUNT);

    const result: string = await (host as any)[addCustodiesMethod].staticCall(ctx({ state, request }));
    expect(result).to.equal(concat(
      encodeBalanceBlock(assetA, META, 10n + bundleLen),
      encodeBalanceBlock(assetB, META, 21n + bundleLen),
      encodeBalanceBlock(LP_FROM_CUSTODIES_ASSET, pad32(bundleLen), 30n),
    ));
  });

  it("addLiquidityFromCustodiesToBalances batches multiple custody pairs", async () => {
    const assetA = ethers.zeroPadValue("0xa3", 32);
    const assetB = ethers.zeroPadValue("0xa4", 32);
    const assetC = ethers.zeroPadValue("0xa5", 32);
    const assetD = ethers.zeroPadValue("0xa6", 32);
    const state = concat(
      encodeCustodyBlock(HOST_ID, assetA, META, 10n),
      encodeCustodyBlock(HOST_ID + 1n, assetB, META, 20n),
      encodeCustodyBlock(HOST_ID + 2n, assetC, META, 30n),
      encodeCustodyBlock(HOST_ID + 3n, assetD, META, 40n),
    );
    const bundleDataA = encodeRouteBlock("0x11");
    const bundleDataB = encodeRouteBlock("0x2233");
    const bundleLenA = BigInt(ethers.getBytes(bundleDataA).length);
    const bundleLenB = BigInt(ethers.getBytes(bundleDataB).length);
    const request = concat(
      encodeBundleBlock(bundleDataA),
      encodeBundleBlock(bundleDataB),
    );

    const tx = await callAs(0, addCustodiesMethod, ctx({ state, request }));
    await logGas("addLiquidityFromCustodiesToBalances batch", tx);

    const result: string = await (host as any)[addCustodiesMethod].staticCall(ctx({ state, request }));
    expect(result).to.equal(concat(
      encodeBalanceBlock(assetA, META, 10n + bundleLenA),
      encodeBalanceBlock(assetB, META, 21n + bundleLenA),
      encodeBalanceBlock(LP_FROM_CUSTODIES_ASSET, pad32(bundleLenA), 30n),
      encodeBalanceBlock(assetC, META, 30n + bundleLenB),
      encodeBalanceBlock(assetD, META, 41n + bundleLenB),
      encodeBalanceBlock(LP_FROM_CUSTODIES_ASSET, pad32(bundleLenB), 70n),
    ));
  });

  it("removeLiquidityFromCustodyToBalances maps a custody input and returns two balances", async () => {
    const asset = ethers.zeroPadValue("0xb1", 32);
    const state = encodeCustodyBlock(HOST_ID, asset, META, 15n);
    const route = "0xaabb";
    const bundleData = concat(
      encodeRouteBlock(route),
      encodeMinimumBlock(MIN_ASSET, MIN_META, MIN_AMOUNT),
    );
    const request = encodeBundleBlockWithMinimum(route, MIN_ASSET, MIN_META, MIN_AMOUNT);
    const bundleLen = BigInt(ethers.getBytes(bundleData).length);

    const tx = await callAs(0, removeCustodyMethod, ctx({ state, request }));
    await logGas("removeLiquidityFromCustodyToBalances single", tx);
    await expect(tx).to.emit(host, "RemoveCustodyMapped")
      .withArgs(userAccount, asset, 15n, bundleData);
    await expect(tx).to.emit(host, "MinimumObserved")
      .withArgs(MIN_ASSET, MIN_META, MIN_AMOUNT);

    const result: string = await (host as any)[removeCustodyMethod].staticCall(ctx({ state, request }));
    expect(result).to.equal(concat(
      encodeBalanceBlock(asset, META, 15n + bundleLen),
      encodeBalanceBlock(REDEEM_FROM_CUSTODY_ASSET, pad32(bundleLen), 25n),
    ));
  });

  it("removeLiquidityFromCustodyToBalances batches multiple custody inputs", async () => {
    const assetA = ethers.zeroPadValue("0xb2", 32);
    const assetB = ethers.zeroPadValue("0xb3", 32);
    const state = concat(
      encodeCustodyBlock(HOST_ID, assetA, META, 15n),
      encodeCustodyBlock(HOST_ID + 1n, assetB, META, 25n),
    );
    const bundleDataA = encodeRouteBlock("0x01");
    const bundleDataB = encodeRouteBlock("0x0203");
    const bundleLenA = BigInt(ethers.getBytes(bundleDataA).length);
    const bundleLenB = BigInt(ethers.getBytes(bundleDataB).length);
    const request = concat(
      encodeBundleBlock(bundleDataA),
      encodeBundleBlock(bundleDataB),
    );

    const tx = await callAs(0, removeCustodyMethod, ctx({ state, request }));
    await logGas("removeLiquidityFromCustodyToBalances batch", tx);

    const result: string = await (host as any)[removeCustodyMethod].staticCall(ctx({ state, request }));
    expect(result).to.equal(concat(
      encodeBalanceBlock(assetA, META, 15n + bundleLenA),
      encodeBalanceBlock(REDEEM_FROM_CUSTODY_ASSET, pad32(bundleLenA), 25n),
      encodeBalanceBlock(assetB, META, 25n + bundleLenB),
      encodeBalanceBlock(REDEEM_FROM_CUSTODY_ASSET, pad32(bundleLenB), 35n),
    ));
  });

  it("addLiquidityFromBalancesToBalances maps a balance pair", async () => {
    const assetA = ethers.zeroPadValue("0xc1", 32);
    const assetB = ethers.zeroPadValue("0xc2", 32);
    const state = concat(
      encodeBalanceBlock(assetA, META, 9n),
      encodeBalanceBlock(assetB, META, 19n),
    );
    const route = "0x99";
    const bundleData = concat(
      encodeRouteBlock(route),
      encodeMinimumBlock(MIN_ASSET, MIN_META, MIN_AMOUNT),
    );
    const request = encodeBundleBlockWithMinimum(route, MIN_ASSET, MIN_META, MIN_AMOUNT);
    const bundleLen = BigInt(ethers.getBytes(bundleData).length);

    const tx = await callAs(0, addBalancesMethod, ctx({ state, request }));
    await logGas("addLiquidityFromBalancesToBalances single", tx);
    await expect(tx).to.emit(host, "AddBalancesMapped")
      .withArgs(userAccount, assetA, 9n, assetB, 19n, bundleData);
    await expect(tx).to.emit(host, "MinimumObserved")
      .withArgs(MIN_ASSET, MIN_META, MIN_AMOUNT);

    const result: string = await (host as any)[addBalancesMethod].staticCall(ctx({ state, request }));
    expect(result).to.equal(concat(
      encodeBalanceBlock(assetA, META, 9n + bundleLen),
      encodeBalanceBlock(assetB, META, 21n + bundleLen),
      encodeBalanceBlock(LP_FROM_BALANCES_ASSET, pad32(bundleLen), 28n),
    ));
  });

  it("addLiquidityFromBalancesToBalances batches multiple balance pairs", async () => {
    const assetA = ethers.zeroPadValue("0xc3", 32);
    const assetB = ethers.zeroPadValue("0xc4", 32);
    const assetC = ethers.zeroPadValue("0xc5", 32);
    const assetD = ethers.zeroPadValue("0xc6", 32);
    const state = concat(
      encodeBalanceBlock(assetA, META, 9n),
      encodeBalanceBlock(assetB, META, 19n),
      encodeBalanceBlock(assetC, META, 29n),
      encodeBalanceBlock(assetD, META, 39n),
    );
    const bundleDataA = encodeRouteBlock("0x55");
    const bundleDataB = encodeRouteBlock("0x6677");
    const bundleLenA = BigInt(ethers.getBytes(bundleDataA).length);
    const bundleLenB = BigInt(ethers.getBytes(bundleDataB).length);
    const request = concat(
      encodeBundleBlock(bundleDataA),
      encodeBundleBlock(bundleDataB),
    );

    const tx = await callAs(0, addBalancesMethod, ctx({ state, request }));
    await logGas("addLiquidityFromBalancesToBalances batch", tx);

    const result: string = await (host as any)[addBalancesMethod].staticCall(ctx({ state, request }));
    expect(result).to.equal(concat(
      encodeBalanceBlock(assetA, META, 9n + bundleLenA),
      encodeBalanceBlock(assetB, META, 21n + bundleLenA),
      encodeBalanceBlock(LP_FROM_BALANCES_ASSET, pad32(bundleLenA), 28n),
      encodeBalanceBlock(assetC, META, 29n + bundleLenB),
      encodeBalanceBlock(assetD, META, 41n + bundleLenB),
      encodeBalanceBlock(LP_FROM_BALANCES_ASSET, pad32(bundleLenB), 68n),
    ));
  });

  it("removeLiquidityFromBalanceToBalances maps a balance input and returns two balances", async () => {
    const asset = ethers.zeroPadValue("0xd1", 32);
    const state = encodeBalanceBlock(asset, META, 17n);
    const route = "0xabcd";
    const bundleData = concat(
      encodeRouteBlock(route),
      encodeMinimumBlock(MIN_ASSET, MIN_META, MIN_AMOUNT),
    );
    const request = encodeBundleBlockWithMinimum(route, MIN_ASSET, MIN_META, MIN_AMOUNT);
    const bundleLen = BigInt(ethers.getBytes(bundleData).length);

    const tx = await callAs(0, removeBalanceMethod, ctx({ state, request }));
    await logGas("removeLiquidityFromBalanceToBalances single", tx);
    await expect(tx).to.emit(host, "RemoveBalanceMapped")
      .withArgs(userAccount, asset, 17n, bundleData);
    await expect(tx).to.emit(host, "MinimumObserved")
      .withArgs(MIN_ASSET, MIN_META, MIN_AMOUNT);

    const result: string = await (host as any)[removeBalanceMethod].staticCall(ctx({ state, request }));
    expect(result).to.equal(concat(
      encodeBalanceBlock(asset, META, 17n + bundleLen),
      encodeBalanceBlock(REDEEM_FROM_BALANCE_ASSET, pad32(bundleLen), 37n),
    ));
  });

  it("removeLiquidityFromBalanceToBalances batches multiple balance inputs", async () => {
    const assetA = ethers.zeroPadValue("0xd2", 32);
    const assetB = ethers.zeroPadValue("0xd3", 32);
    const state = concat(
      encodeBalanceBlock(assetA, META, 17n),
      encodeBalanceBlock(assetB, META, 27n),
    );
    const bundleDataA = encodeRouteBlock("0x01");
    const bundleDataB = encodeRouteBlock("0x0203");
    const bundleLenA = BigInt(ethers.getBytes(bundleDataA).length);
    const bundleLenB = BigInt(ethers.getBytes(bundleDataB).length);
    const request = concat(
      encodeBundleBlock(bundleDataA),
      encodeBundleBlock(bundleDataB),
    );

    const tx = await callAs(0, removeBalanceMethod, ctx({ state, request }));
    await logGas("removeLiquidityFromBalanceToBalances batch", tx);

    const result: string = await (host as any)[removeBalanceMethod].staticCall(ctx({ state, request }));
    expect(result).to.equal(concat(
      encodeBalanceBlock(assetA, META, 17n + bundleLenA),
      encodeBalanceBlock(REDEEM_FROM_BALANCE_ASSET, pad32(bundleLenA), 37n),
      encodeBalanceBlock(assetB, META, 27n + bundleLenB),
      encodeBalanceBlock(REDEEM_FROM_BALANCE_ASSET, pad32(bundleLenB), 47n),
    ));
  });

  it("accepts explicit target ids for all liquidity commands", async () => {
    const addCustodyTarget = await (host as any).getAddLiquidityFromCustodiesToBalancesId();
    const removeCustodyTarget = await (host as any).getRemoveLiquidityFromCustodyToBalancesId();
    const addBalanceTarget = await (host as any).getAddLiquidityFromBalancesToBalancesId();
    const removeBalanceTarget = await (host as any).getRemoveLiquidityFromBalanceToBalancesId();

    await expect(callAs(0, addCustodiesMethod, ctx({
      target: addCustodyTarget,
      state: concat(
        encodeCustodyBlock(HOST_ID, ethers.zeroPadValue("0xe1", 32), META, 5n),
        encodeCustodyBlock(HOST_ID + 1n, ethers.zeroPadValue("0xe2", 32), META, 6n),
      ),
      request: encodeBundleBlock(encodeRouteBlock("0x01")),
    }))).to.emit(host, "AddCustodiesMapped");

    await expect(callAs(0, removeCustodyMethod, ctx({
      target: removeCustodyTarget,
      state: encodeCustodyBlock(HOST_ID, ethers.zeroPadValue("0xe3", 32), META, 7n),
      request: encodeBundleBlock(encodeRouteBlock("0x01")),
    }))).to.emit(host, "RemoveCustodyMapped");

    await expect(callAs(0, addBalancesMethod, ctx({
      target: addBalanceTarget,
      state: concat(
        encodeBalanceBlock(ethers.zeroPadValue("0xe4", 32), META, 8n),
        encodeBalanceBlock(ethers.zeroPadValue("0xe5", 32), META, 9n),
      ),
      request: encodeBundleBlock(encodeRouteBlock("0x01")),
    }))).to.emit(host, "AddBalancesMapped");

    await expect(callAs(0, removeBalanceMethod, ctx({
      target: removeBalanceTarget,
      state: encodeBalanceBlock(ethers.zeroPadValue("0xe6", 32), META, 10n),
      request: encodeBundleBlock(encodeRouteBlock("0x01")),
    }))).to.emit(host, "RemoveBalanceMapped");
  });
});
