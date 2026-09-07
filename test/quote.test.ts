import { expect } from "chai";
import { ethers } from "ethers";
import { deploy } from "./helpers/setup.js";
import { concat, encodePositionBlock, encodeQuoteBlock, encodeUserAccount } from "./helpers/blocks.js";
import "./helpers/matchers.js";

describe("Quote codec", () => {
  const asset = ethers.zeroPadValue("0x11", 32);
  const liability = ethers.zeroPadValue("0x22", 32);
  const counterparty = encodeUserAccount("0x0000000000000000000000000000000000000033");
  const quote = [asset, 123n, liability, ethers.MaxUint256, counterparty];
  const encoded = encodeQuoteBlock(asset, 123n, liability, ethers.MaxUint256, counterparty);
  const state = encodePositionBlock(liability, 99n, asset, 77n);
  let helper: Awaited<ReturnType<typeof deploy>>;

  before(async () => { helper = await deploy("TestQuote"); });

  it("checks inclusive limits and exact counterparty, and advances exactly one quote", async () => {
    const first = encodeQuoteBlock(asset, 123n, liability, 456n, counterparty);
    expect(Array.from(await helper.check(concat(first, encoded), [asset, 123n, liability, 456n, counterparty])))
      .to.deep.equal(quote);
  });

  for (const [position, error] of [
    [[asset, 122n, liability, 456n, ethers.ZeroHash], "AmountOutOfRange"],
    [[asset, 123n, liability, 457n, ethers.ZeroHash], "AmountOutOfRange"],
    [[liability, 123n, liability, 456n, ethers.ZeroHash], "UnexpectedValue"],
    [[asset, 123n, asset, 456n, ethers.ZeroHash], "UnexpectedValue"],
  ] as const) {
    it(`rejects a result outside its quote: ${position.join(",")}`, async () => {
      await expect(helper.check(concat(encodeQuoteBlock(asset, 123n, liability, 456n), encoded), position))
        .to.be.revertedWithCustomError(helper, error);
    });
  }

  for (const [requested, actual] of [[ethers.ZeroHash, counterparty], [counterparty, ethers.ZeroHash],
    [counterparty, encodeUserAccount("0x0000000000000000000000000000000000000044")]]) {
    it(`rejects counterparty mismatch ${requested} -> ${actual}`, async () => {
      const input = concat(encodeQuoteBlock(asset, 123n, liability, 456n, requested), encoded);
      await expect(helper.check(input, [asset, 123n, liability, 456n, actual]))
        .to.be.revertedWithCustomError(helper, "UnexpectedValue");
    });
  }

  it("accepts Rootzero as an exact counterparty", async () => {
    const input = concat(encodeQuoteBlock(asset, 123n, liability, 456n), encoded);
    expect(Array.from(await helper.check(input, [asset, 123n, liability, 456n, ethers.ZeroHash])))
      .to.deep.equal(quote);
  });

  it("encodes five words including the requested counterparty", async () => {
    expect(ethers.dataLength(encoded)).to.equal(168);
    expect(await helper.create(quote)).to.equal(encoded);
  });

  for (const scalar of [true, false]) {
    it(`roundtrips ${scalar ? "scalar" : "struct"} writer and decoder fields`, async () => {
      expect(await helper.write(quote, scalar)).to.equal(encoded);
      expect(Array.from(await helper.decode(encoded, scalar))).to.deep.equal(quote);
    });

    it(`consumes quotes from input independently of position state (${scalar})`, async () => {
      const second = encodeQuoteBlock(liability, 0n, asset, 0n);
      expect(await helper.execute(concat(state, state), concat(encoded, second), scalar))
        .to.equal(concat(encoded, second));
    });

    it(`rejects truncated quotes (${scalar})`, async () => {
      await expect(helper.decode(ethers.dataSlice(encoded, 0, 167), scalar))
        .to.be.revertedWithCustomError(helper, "OutOfBounds");
    });

    it(`rejects a position in place of a quote (${scalar})`, async () => {
      await expect(helper.decode(state, scalar)).to.be.revertedWithCustomError(helper, "InvalidBlock");
    });

    it(`rejects the quote key with an incorrect payload length (${scalar})`, async () => {
      const malformed = concat(ethers.dataSlice(encoded, 0, 4), ethers.toBeHex(128, 4), ethers.dataSlice(encoded, 8));
      await expect(helper.decode(malformed, scalar)).to.be.revertedWithCustomError(helper, "InvalidBlock");
    });
  }
});
