import { expect } from "chai";
import { deploy } from "./helpers/setup.js";
import {
  concat,
  pad32,
  encodeQueryBlock,
  encodeResponseBlock,
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
        "incrementQuery",
        "query(uint foo)",
        "response(uint bar)",
      );
  });

  describe("incrementQuery", () => {
    it("accepts `query(uint foo)` and returns `response(uint bar)`", async () => {
      const request = encodeQueryBlock(pad32(7n));

      const result: string = await query.incrementQuery.staticCall(request);

      expect(result).to.equal(encodeResponseBlock(pad32(8n)));
    });

    it("maps multiple typed QUERY blocks into matching RESPONSE blocks", async () => {
      const request = concat(
        encodeQueryBlock(pad32(11n)),
        encodeQueryBlock(pad32(22n)),
      );

      const result: string = await query.incrementQuery.staticCall(request);

      expect(result).to.equal(concat(
        encodeResponseBlock(pad32(12n)),
        encodeResponseBlock(pad32(23n)),
      ));
    });
  });
});
