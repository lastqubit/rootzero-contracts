import { expect } from "chai";
import { deploy } from "./helpers/setup.js";
import {
  concat,
  encodeAssetBlock,
  encodeStatusBlock,
  pad32,
} from "./helpers/blocks.js";

describe("AssetStatus", () => {
  it("returns one status block for one asset query", async () => {
    const query = await deploy("TestAssetStatusQuery");
    const asset = await query.allowedAssetId();
    const meta = await query.allowedMeta();

    const result: string = await query["assetStatus(bytes)"].staticCall(
      encodeAssetBlock(asset, meta),
    );

    expect(result).to.equal(encodeStatusBlock(1n));
  });

  it("maps multiple asset blocks into matching status codes in order", async () => {
    const query = await deploy("TestAssetStatusQuery");
    const asset = await query.allowedAssetId();
    const meta = await query.allowedMeta();
    const otherAsset = pad32(0xDEADn);
    const otherMeta = pad32(0xBEEFn);

    const request = concat(
      encodeAssetBlock(asset, meta),
      encodeAssetBlock(otherAsset, otherMeta),
    );

    const result: string = await query["assetStatus(bytes)"].staticCall(request);

    expect(result).to.equal(concat(
      encodeStatusBlock(1n),
      encodeStatusBlock(0n),
    ));
  });
});
