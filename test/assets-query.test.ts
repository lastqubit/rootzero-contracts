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

    const result: string = await query["assetStatus(bytes)"].staticCall(
      encodeAssetBlock(asset),
    );

    expect(result).to.equal(encodeStatusBlock(1n));
  });

  it("maps multiple asset blocks into matching status codes in order", async () => {
    const query = await deploy("TestAssetStatusQuery");
    const asset = await query.allowedAssetId();
    const otherAsset = pad32(0xDEADn);

    const input = concat(
      encodeAssetBlock(asset),
      encodeAssetBlock(otherAsset),
    );

    const result: string = await query["assetStatus(bytes)"].staticCall(input);

    expect(result).to.equal(concat(
      encodeStatusBlock(1n),
      encodeStatusBlock(0n),
    ));
  });
});
