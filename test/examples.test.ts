import { expect } from "chai";
import { ethers } from "ethers";
import { deploy, getSigner } from "./helpers/setup.js";
import "./helpers/matchers.js";
import { encodeFrameBlock, encodeUserAccount, pad32 } from "./helpers/blocks.js";

describe("Examples", () => {
  describe("7-Frame", () => {
    it("decodes a frame input with the custom unpack helper", async () => {
      const signer = await getSigner(0);
      const commander = await signer.getAddress();
      const host = await deploy("TestFrameExampleHost", commander);

      const account = encodeUserAccount(commander);
      const asset = ethers.zeroPadValue("0x01", 32);
      const meta = ethers.zeroPadValue("0x02", 32);
      const amount = 123n;
      const fee = 4n;
      const request = encodeFrameBlock(asset, meta, pad32(amount), pad32(fee));

      await expect(host.myCommand({ account, state: "0x", request }))
        .to.emit(host, "PaymentSeen")
        .withArgs(asset, meta, amount, fee);
    });
  });
});
