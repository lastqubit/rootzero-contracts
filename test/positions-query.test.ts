import { expect } from "chai";
import { deploy } from "./helpers/setup.js";
import {
  concat,
  encodeAccountAssetBlock,
  encodeDataBlock,
  pad32,
} from "./helpers/blocks.js";

describe("GetPosition", () => {
  it("returns one response block for one asset query", async () => {
    const query = await deploy("TestGetPositionQuery");
    const asset = await query.firstAsset();
    const account = pad32(0n);

    const result: string = await query.getPosition.staticCall(
      encodeAccountAssetBlock(account, asset),
    );

    expect(result).to.equal(encodeDataBlock(pad32(11n)));
  });

  it("maps multiple asset blocks into matching response blocks in order", async () => {
    const query = await deploy("TestGetPositionQuery");
    const firstAsset = await query.firstAsset();
    const secondAsset = await query.secondAsset();
    const account = pad32(0n);

    const request = concat(
      encodeAccountAssetBlock(account, firstAsset),
      encodeAccountAssetBlock(account, secondAsset),
    );

    const result: string = await query.getPosition.staticCall(request);

    expect(result).to.equal(concat(
      encodeDataBlock(pad32(11n)),
      encodeDataBlock(pad32(22n)),
    ));
  });
});
