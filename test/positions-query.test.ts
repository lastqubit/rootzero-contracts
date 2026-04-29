import { expect } from "chai";
import { deploy } from "./helpers/setup.js";
import {
  concat,
  encodeAccountAssetBlock,
  encodeResponseBlock,
  pad32,
} from "./helpers/blocks.js";

describe("GetPosition", () => {
  it("returns one response block for one asset query", async () => {
    const query = await deploy("TestGetPositionQuery");
    const asset = await query.firstAsset();
    const meta = await query.firstMeta();
    const account = pad32(0n);

    const result: string = await query.getPosition.staticCall(
      encodeAccountAssetBlock(account, asset, meta),
    );

    expect(result).to.equal(encodeResponseBlock(pad32(11n)));
  });

  it("maps multiple asset blocks into matching response blocks in order", async () => {
    const query = await deploy("TestGetPositionQuery");
    const firstAsset = await query.firstAsset();
    const firstMeta = await query.firstMeta();
    const secondAsset = await query.secondAsset();
    const secondMeta = await query.secondMeta();
    const account = pad32(0n);

    const request = concat(
      encodeAccountAssetBlock(account, firstAsset, firstMeta),
      encodeAccountAssetBlock(account, secondAsset, secondMeta),
    );

    const result: string = await query.getPosition.staticCall(request);

    expect(result).to.equal(concat(
      encodeResponseBlock(pad32(11n)),
      encodeResponseBlock(pad32(22n)),
    ));
  });
});
