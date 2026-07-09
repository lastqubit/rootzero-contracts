import { expect } from "chai";
import { ethers } from "ethers";
import { deploy, queryId } from "./helpers/setup.js";
import "./helpers/matchers.js";
import {
  concat,
  encodeBlock,
  endpointDescriptor,
  localKey,
  pad32,
} from "./helpers/blocks.js";

const Value = localKey(1);

describe("Queries", () => {
  let query: Awaited<ReturnType<typeof deploy>>;

  before(async () => {
    query = await deploy("TestQuery");
  });

  async function qry(method: string) {
    return queryId(query.interface.getFunction(method)!.selector, query);
  }

  it("emits Endpoint discovery events with query id as the second argument", async () => {
    const tx = query.deploymentTransaction();
    expect(tx).to.not.equal(null);

    await expect(tx!)
      .to.emit(query, "Endpoint")
      .withArgs(
        await query.host(),
        await qry("incrementQuery"),
        endpointDescriptor({ input: Value, output: Value }),
      );
    await expect(tx!)
      .to.emit(query, "Labeled")
      .withArgs(await qry("incrementQuery"), ethers.ZeroHash, "incrementQuery");
  });

  describe("incrementQuery", () => {
    it("accepts custom value blocks and returns custom value blocks", async () => {
      const request = encodeBlock(Value, pad32(7n));

      const result: string = await query.incrementQuery.staticCall(request);

      expect(result).to.equal(encodeBlock(Value, pad32(8n)));
    });

    it("maps multiple custom query blocks into matching response blocks", async () => {
      const request = concat(
        encodeBlock(Value, pad32(11n)),
        encodeBlock(Value, pad32(22n)),
      );

      const result: string = await query.incrementQuery.staticCall(request);

      expect(result).to.equal(concat(
        encodeBlock(Value, pad32(12n)),
        encodeBlock(Value, pad32(23n)),
      ));
    });
  });
});
