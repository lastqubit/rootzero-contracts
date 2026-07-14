import { expect } from "chai";
import { ethers } from "ethers";
import { deploy, getSigner } from "./helpers/setup.js";
import "./helpers/matchers.js";
import { concat, encodeBlock, encodeFeeBlock, encodeUserAccount, localKey, pad32 } from "./helpers/blocks.js";

const Payment = localKey(1);

describe("Examples", () => {
  describe("7-CustomInput", () => {
    it("decodes a data input with the custom unpack helper", async () => {
      const signer = await getSigner(0);
      const commander = await signer.getAddress();
      const host = await deploy("TestFrameExampleHost", commander);

      const account = encodeUserAccount(commander);
      const asset = ethers.zeroPadValue("0x01", 32);
      const amount = 123n;
      const fee = 4n;
      const request = encodeBlock(Payment, concat(asset, pad32(amount), encodeFeeBlock(fee)));

      await expect(host.myCommand({ account, state: "0x", input: request }))
        .to.emit(host, "PaymentSeen")
        .withArgs(asset, amount, fee);
    });
  });
});
