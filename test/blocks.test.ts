import { expect } from "chai";
import { ethers } from "ethers";
import { deploy } from "./helpers/setup.js";
import "./helpers/matchers.js";
import {
  Keys,
  encodeAmountBlock,
  encodeAuthBlock,
  encodeBalanceBlock,
  encodeBundleBlock,
  encodeCustodyBlock,
  encodeMinimumBlock,
  encodeNodeBlock,
  encodeRecipientBlock,
  encodeStepBlock,
  encodeTxBlock,
  concat,
} from "./helpers/blocks.js";

describe("Cursors", () => {
  let helper: Awaited<ReturnType<typeof deploy>>;

  before(async () => {
    helper = await deploy("TestCursorHelper");
  });

  describe("Writers", () => {
    const asset = ethers.zeroPadValue("0x01", 32);
    const meta = ethers.zeroPadValue("0x02", 32);
    const amount = 12345n;

    it("toBlockHeader packs key and payloadLen", async () => {
      const header: bigint = await helper.testBlockHeader(Keys.Balance, 96n);
      expect((header >> 224n) & 0xffffffffn).to.equal(BigInt(Keys.Balance));
      expect((header >> 192n) & 0xffffffffn).to.equal(96n);
    });

    it("toBlockHeader reverts BlockLengthOverflow when payloadLen exceeds uint32", async () => {
      await expect(helper.testBlockHeader(Keys.Balance, 0x1_0000_0000n))
        .to.be.revertedWithCustomError(helper, "BlockLengthOverflow");
    });

    it("writeBalanceBlock round-trips", async () => {
      const data: string = await helper.testWriteBalanceBlock(asset, meta, amount);
      expect(ethers.getBytes(data).length).to.equal(104);
      expect(data.slice(0, 10)).to.equal(Keys.Balance);
      expect(await helper.testUnpackBalance(data)).to.deep.equal([asset, meta, amount]);
    });

    it("writeCustodyBlock produces 136 bytes", async () => {
      const data: string = await helper.testWriteCustodyBlock(1234n, asset, meta, amount);
      expect(ethers.getBytes(data).length).to.equal(136);
    });

    it("writeTxBlock round-trips", async () => {
      const from_ = ethers.zeroPadValue("0x03", 32);
      const to_ = ethers.zeroPadValue("0x04", 32);
      const data: string = await helper.testWriteTxBlock(from_, to_, asset, meta, amount);
      expect(ethers.getBytes(data).length).to.equal(168);
      expect(await helper.testToTxValue(data)).to.deep.equal([from_, to_, asset, meta, amount]);
    });

    it("finish reverts EmptyRequest when writer is unused", async () => {
      await expect(helper.testWriterFinishIncomplete()).to.be.revertedWithCustomError(helper, "EmptyRequest");
    });

    it("finish truncates to actual written length", async () => {
      const data: string = await helper.testWriterFinish(asset, meta, amount);
      expect(ethers.getBytes(data).length).to.equal(104);
    });
  });

  describe("Cursor helpers", () => {
    const asset = ethers.zeroPadValue("0xaa", 32);
    const meta = ethers.zeroPadValue("0xbb", 32);
    const amount = 9999n;

    it("primeRun sets key, count, len, and bound for a prime run", async () => {
      const a = encodeAmountBlock(asset, meta, 1n);
      const b = encodeAmountBlock(asset, meta, 2n);
      const c = encodeBalanceBlock(asset, meta, 3n);
      const source = concat(a, b, c);
      const [key, count, offset, i, len, bound] = await helper.testPrimeRun(source, 1n);
      expect(key).to.equal(Keys.Amount);
      expect(count).to.equal(2n);
      expect(offset).to.equal(0n);
      expect(i).to.equal(0n);
      expect(len).to.equal(BigInt(ethers.getBytes(source).length));
      expect(bound).to.equal(BigInt(ethers.getBytes(concat(a, b)).length));
    });

    it("primeRun reverts ZeroGroup when group is 0", async () => {
      const source = encodeAmountBlock(asset, meta, amount);
      await expect(helper.testPrimeRun(source, 0n))
        .to.be.revertedWithCustomError(helper, "ZeroGroup");
    });

    it("peek returns the next key and payload length", async () => {
      const source = encodeBalanceBlock(asset, meta, amount);
      expect(await helper.testPeek(source, 0n)).to.deep.equal([Keys.Balance, 96n]);
    });

    it("countRun counts consecutive matching blocks from i", async () => {
      const a = encodeAmountBlock(asset, meta, 1n);
      const b = encodeAmountBlock(asset, meta, 2n);
      const c = encodeBalanceBlock(asset, meta, 3n);
      const [count, next] = await helper.testCountRun(concat(a, b, c), 0n, Keys.Amount);
      expect(count).to.equal(2n);
      expect(next).to.equal(BigInt(ethers.getBytes(concat(a, b)).length));
    });

    it("bundle returns a relative subcursor and advances the source cursor", async () => {
      const route = encodeRecipientBlock(ethers.zeroPadValue("0x12", 32));
      const minimum = encodeMinimumBlock(asset, meta, amount);
      const bundle = encodeBundleBlock(route, minimum);
      const [inputI, offset, len] = await helper.testBundle(bundle);
      expect(inputI).to.equal(BigInt(ethers.getBytes(bundle).length));
      expect(offset).to.equal(8n);
      expect(len).to.equal(BigInt(ethers.getBytes(route).length + ethers.getBytes(minimum).length));
    });

    it("unpackStep consumes the block and returns the trailing request", async () => {
      const req = encodeAmountBlock(asset, meta, amount);
      const step = encodeStepBlock(7n, 55n, req);
      const [target, value, outReq, i] = await helper.testUnpackStep(step);
      expect(target).to.equal(7n);
      expect(value).to.equal(55n);
      expect(outReq).to.equal(req);
      expect(i).to.equal(BigInt(ethers.getBytes(step).length));
    });

    it("requireAmount validates and advances by one fixed-size block", async () => {
      const source = encodeAmountBlock(asset, meta, amount);
      const [out, i] = await helper.testRequireAmount(source, asset, meta);
      expect(out).to.equal(amount);
      expect(i).to.equal(104n);
    });

    it("requireAuth validates and advances by the auth block size", async () => {
      const proof = ethers.concat(["0x" + "11".repeat(20), "0x" + "22".repeat(65)]);
      const source = encodeAuthBlock(77n, 123456n, proof);
      const [deadline, outProof, i] = await helper.testRequireAuth(source, 77n);
      expect(deadline).to.equal(123456n);
      expect(outProof).to.equal(proof);
      expect(i).to.equal(149n);
    });

    it("complete reverts ZeroCursor when bound is not initialized", async () => {
      await expect(helper.testCursorCompleteEmpty("0x", 0n))
        .to.be.revertedWithCustomError(helper, "ZeroCursor");
    });

    it("complete reverts ZeroCursor when prime input remains", async () => {
      const source = concat(encodeBalanceBlock(asset, meta, 1n), encodeBalanceBlock(asset, meta, 2n));
      await expect(helper.testCursorCompletePartial(source, 1n))
        .to.be.revertedWithCustomError(helper, "ZeroCursor");
    });

    it("complete succeeds after the prime run is consumed", async () => {
      const source = concat(encodeBalanceBlock(asset, meta, 1n), encodeBalanceBlock(asset, meta, 2n));
      expect(await helper.testCursorCompleteConsumed(source, 1n)).to.equal(true);
    });

    it("recipientAfter returns the tail recipient or backup", async () => {
      const backup = ethers.zeroPadValue("0x99", 32);
      const recipient = ethers.zeroPadValue("0x12", 32);
      const source = concat(
        encodeAmountBlock(asset, meta, amount),
        encodeRecipientBlock(recipient)
      );
      expect(await helper.testRecipientAfter(source, 1n, backup)).to.equal(recipient);
      expect(await helper.testRecipientAfter(encodeAmountBlock(asset, meta, amount), 1n, backup)).to.equal(backup);
    });

    it("nodeAfter returns the tail node or backup", async () => {
      const source = concat(
        encodeAmountBlock(asset, meta, amount),
        encodeNodeBlock(42n)
      );
      expect(await helper.testNodeAfter(source, 1n, 7n)).to.equal(42n);
      expect(await helper.testNodeAfter(encodeAmountBlock(asset, meta, amount), 1n, 7n)).to.equal(7n);
    });

    it("authLast returns hash, deadline, and proof for a valid trailing auth", async () => {
      const cid = 77n;
      const deadline = 123456n;
      const proof = ethers.concat(["0x" + "11".repeat(20), "0x" + "22".repeat(65)]);
      const amountBlock = encodeAmountBlock(asset, meta, amount);
      const auth = encodeAuthBlock(cid, deadline, proof);
      const source = concat(amountBlock, auth);

      const [hash, outDeadline, outProof] = await helper.testAuthLast(source, 1n, cid);
      expect(outDeadline).to.equal(deadline);
      expect(outProof).to.equal(proof);

      const sourceBytes = ethers.getBytes(source);
      const expectedHash = ethers.keccak256(sourceBytes.slice(0, sourceBytes.length - 85));
      expect(hash).to.equal(expectedHash);
    });

    it("authLast reverts UnexpectedValue when cid mismatches", async () => {
      const proof = ethers.concat(["0x" + "11".repeat(20), "0x" + "22".repeat(65)]);
      const source = concat(encodeAmountBlock(asset, meta, amount), encodeAuthBlock(77n, 123456n, proof));
      await expect(helper.testAuthLast(source, 1n, 88n))
        .to.be.revertedWithCustomError(helper, "UnexpectedValue");
    });

    it("authLast reverts MalformedBlocks when trailing auth is missing", async () => {
      await expect(helper.testAuthLast(encodeAmountBlock(asset, meta, amount), 1n, 77n))
        .to.be.revertedWithCustomError(helper, "MalformedBlocks");
    });
  });

  describe("Mem library", () => {
    const asset = ethers.zeroPadValue("0xcc", 32);
    const meta = ethers.zeroPadValue("0xdd", 32);
    const amount = 7777n;

    it("unpackBalance from memory block", async () => {
      const data = encodeBalanceBlock(asset, meta, amount);
      expect(await helper.testMemParseBalance(data, 0n)).to.deep.equal([asset, meta, amount]);
    });

    it("toCustodyValue from memory block", async () => {
      const data = encodeCustodyBlock(99n, asset, meta, amount);
      const [h, a, m, v] = await helper.testMemParseCustody(data, 0n);
      expect(h).to.equal(99n);
      expect(a).to.equal(asset);
      expect(m).to.equal(meta);
      expect(v).to.equal(amount);
    });

    it("slice extracts a sub-array", async () => {
      const data = encodeBalanceBlock(asset, meta, amount);
      const full = ethers.getBytes(data);
      const sliced: string = await helper.testMemSlice(data, 8n, BigInt(full.length));
      expect(ethers.getBytes(sliced).length).to.equal(full.length - 8);
    });

    it("slice reverts MalformedBlocks for invalid bounds", async () => {
      const data = encodeBalanceBlock(asset, meta, amount);
      await expect(helper.testMemSlice(data, 10n, 9n))
        .to.be.revertedWithCustomError(helper, "MalformedBlocks");
    });

    it("count works in memory", async () => {
      const source = concat(encodeBalanceBlock(asset, meta, 1n), encodeBalanceBlock(asset, meta, 2n));
      const [count] = await helper.testMemCount(source, 0n, Keys.Balance);
      expect(count).to.equal(2n);
    });

    it("from reverts MalformedBlocks for truncated input", async () => {
      await expect(helper.testMemParseBalance("0xdeadbeef", 0n))
        .to.be.revertedWithCustomError(helper, "MalformedBlocks");
    });
  });
});
