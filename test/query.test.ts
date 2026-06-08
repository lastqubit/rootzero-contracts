import { expect } from "chai";
import { ethers } from "ethers";
import { deploy } from "./helpers/setup.js";
import {
  concat,
  pad32,
  encodeDataBlock,
} from "./helpers/blocks.js";

describe("Queries", () => {
  let query: Awaited<ReturnType<typeof deploy>>;

  before(async () => {
    query = await deploy("TestQuery");
  });

  it("emits Query discovery events with id as the second argument", async () => {
    const tx = query.deploymentTransaction();
    expect(tx).to.not.equal(null);

    await expect(tx!)
      .to.emit(query, "Query")
      .withArgs(
        await query.host(),
        await query.incrementQueryId(),
        ethers.encodeBytes32String("1:1"),
        "uint foo",
        "uint bar",
      );
    await expect(tx!)
      .to.emit(query, "Labeled")
      .withArgs(await query.incrementQueryId(), ethers.ZeroHash, "incrementQuery");
  });

  describe("incrementQuery", () => {
    it("accepts `uint foo` DATA blocks and returns `uint bar` DATA blocks", async () => {
      const request = encodeDataBlock(pad32(7n));

      const result: string = await query.incrementQuery.staticCall(request);

      expect(result).to.equal(encodeDataBlock(pad32(8n)));
    });

    it("maps multiple typed DATA query blocks into matching DATA response blocks", async () => {
      const request = concat(
        encodeDataBlock(pad32(11n)),
        encodeDataBlock(pad32(22n)),
      );

      const result: string = await query.incrementQuery.staticCall(request);

      expect(result).to.equal(concat(
        encodeDataBlock(pad32(12n)),
        encodeDataBlock(pad32(23n)),
      ));
    });
  });
});
