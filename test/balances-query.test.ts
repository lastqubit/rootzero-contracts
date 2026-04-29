import { expect } from "chai";
import { ethers } from "ethers";
import { deploy, getProvider, getSigner } from "./helpers/setup.js";
import {
  concat,
  encodeAccountAssetBlock,
  encodeAccountAmountBlock,
  encodeUserAccount,
} from "./helpers/blocks.js";

describe("BalancesQuery", () => {
  it("returns an entry block for one ERC-20 position query", async () => {
    const query = await deploy("TestBalancesQuery");
    const account = await getSigner(1);
    const accountId = encodeUserAccount(await account.getAddress());
    const tokenAsset = await query.tokenAsset();
    const meta = ethers.ZeroHash;

    await query.mint(await account.getAddress(), 123n);

    const request = encodeAccountAssetBlock(accountId, tokenAsset, meta);
    const result: string = await query.getBalances.staticCall(request);

    expect(result).to.equal(encodeAccountAmountBlock(accountId, tokenAsset, meta, 123n));
  });

  it("maps multiple position blocks into matching entry blocks in order", async () => {
    const query = await deploy("TestBalancesQuery");
    const provider = await getProvider();
    const account = await getSigner(1);
    const accountAddr = await account.getAddress();
    const accountId = encodeUserAccount(accountAddr);
    const tokenAsset = await query.tokenAsset();
    const valueAsset = await query.valueAssetId();
    const meta = ethers.ZeroHash;

    await query.mint(accountAddr, 456n);
    const nativeBalance = await provider.getBalance(accountAddr);

    const request = concat(
      encodeAccountAssetBlock(accountId, tokenAsset, meta),
      encodeAccountAssetBlock(accountId, valueAsset, meta),
    );

    const result: string = await query.getBalances.staticCall(request);

    expect(result).to.equal(concat(
      encodeAccountAmountBlock(accountId, tokenAsset, meta, 456n),
      encodeAccountAmountBlock(accountId, valueAsset, meta, nativeBalance),
    ));
  });
});
