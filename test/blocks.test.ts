import { expect } from "chai";
import { ethers } from "ethers";
import { deploy } from "./helpers/setup.js";
import "./helpers/matchers.js";
import {
  Keys,
  encodeAmountBlock, encodeBalanceBlock, encodeCustodyBlock,
  encodeRecipientBlock, encodeNodeBlock, encodeFundingBlock,
  encodeAssetBlock, encodeAllocationBlock, encodeTxBlock, encodeQuantityBlock, encodeMinimumBlock, encodeMaximumBlock,
  encodeAuthBlock, encodeBundleBlock, encodeRouteBlock,
  pad32, concat
} from "./helpers/blocks.js";

function encodeUint32(value: number): string {
  return ethers.toBeHex(value, 4);
}

describe("Cursors", () => {
  let helper: Awaited<ReturnType<typeof deploy>>;

  before(async () => {
    helper = await deploy("TestBlockHelper");
  });

  // ── Writers ───────────────────────────────────────────────────────────────

  describe("Writers", () => {
    const asset = ethers.zeroPadValue("0x01", 32);
    const meta  = ethers.zeroPadValue("0x02", 32);
    const amount = 12345n;

    it("toBlockHeader packs key/payloadLen into upper bits", async () => {
      const key = Keys.Balance;
      const header: bigint = await helper.testBlockHeader(key, 96n);
      // Key in bits 224-255
      const keyFromHeader = (header >> 224n) & 0xffffffffn;
      expect(keyFromHeader.toString(16)).to.equal(key.slice(2).toLowerCase());
      // payloadLen in bits 192-223
      const payloadLen = (header >> 192n) & 0xffffffffn;
      expect(payloadLen).to.equal(96n);
    });

    it("toBlockHeader reverts MalformedBlocks when payloadLen exceeds uint32", async () => {
      await expect(helper.testBlockHeader(Keys.Balance, 0x1_0000_0000n))
        .to.be.revertedWithCustomError(helper, "MalformedBlocks");
    });

    it("writeBalanceBlock produces 104-byte output", async () => {
      const data: string = await helper.testWriteBalanceBlock(asset, meta, amount);
      expect(ethers.getBytes(data).length).to.equal(104);
    });

    it("writeBalanceBlock starts with Keys.Balance", async () => {
      const data: string = await helper.testWriteBalanceBlock(asset, meta, amount);
      expect(data.slice(0, 10)).to.equal(Keys.Balance);
    });

    it("writeBalanceBlock encodes asset, meta, amount correctly", async () => {
      const data: string = await helper.testWriteBalanceBlock(asset, meta, amount);
      // Parse back via testUnpackBalance
      const [a, m, v] = await helper.testUnpackBalance(data, 0n);
      expect(a).to.equal(asset);
      expect(m).to.equal(meta);
      expect(v).to.equal(amount);
    });

    it("writeCustodyBlock produces 136-byte output", async () => {
      const hostId = 1234n;
      const data: string = await helper.testWriteCustodyBlock(hostId, asset, meta, amount);
      expect(ethers.getBytes(data).length).to.equal(136);
    });

    it("writeTxBlock produces 168-byte output", async () => {
      const from_ = ethers.zeroPadValue("0x03", 32);
      const to_   = ethers.zeroPadValue("0x04", 32);
      const data: string = await helper.testWriteTxBlock(from_, to_, asset, meta, amount);
      expect(ethers.getBytes(data).length).to.equal(168);
    });

    it("writeTxBlock round-trips correctly", async () => {
      const from_ = ethers.zeroPadValue("0xaa", 32);
      const to_   = ethers.zeroPadValue("0xbb", 32);
      const data: string = await helper.testWriteTxBlock(from_, to_, asset, meta, amount);
      const [f, t, a2, m2, v] = await helper.testToTxValue(data, 0n);
      expect(f).to.equal(from_);
      expect(t).to.equal(to_);
      expect(a2).to.equal(asset);
      expect(m2).to.equal(meta);
      expect(v).to.equal(amount);
    });

    it("done reverts IncompleteWriter when writer is not full", async () => {
      await expect(helper.testWriterDone()).to.be.revertedWithCustomError(helper, "IncompleteWriter");
    });

    it("finish truncates to actual written length", async () => {
      const data: string = await helper.testWriterFinish(asset, meta, amount);
      expect(ethers.getBytes(data).length).to.equal(104); // one balance block
    });
  });

  // ── Blocks (calldata parsing) ─────────────────────────────────────────────

  describe("Cursors library", () => {
    const asset = ethers.zeroPadValue("0xAA", 32);
    const meta  = ethers.zeroPadValue("0xBB", 32);
    const amount = 9999n;

    it("count counts consecutive same-key blocks", async () => {
      const b1 = encodeAmountBlock(asset, meta, 1n);
      const b2 = encodeAmountBlock(asset, meta, 2n);
      const b3 = encodeBalanceBlock(asset, meta, 3n); // different key
      const data = concat(b1, b2, b3);
      const [count, next] = await helper.testCountBlocks(data, 0n, Keys.Amount);
      expect(count).to.equal(2n);
      expect(next).to.equal(BigInt(ethers.getBytes(concat(b1, b2)).length));
    });

    it("resolveRecipient returns RECIPIENT block when present", async () => {
      const account = ethers.zeroPadValue("0x1234", 32);
      const data = encodeRecipientBlock(account);
      const result = await helper.testResolveRecipient(data, 0n, BigInt(ethers.getBytes(data).length), ethers.ZeroHash);
      expect(result).to.equal(account);
    });

    it("resolveRecipient uses backup when no RECIPIENT block", async () => {
      const backup = ethers.zeroPadValue("0x9999", 32);
      const result = await helper.testResolveRecipient("0x", 0n, 0n, backup);
      expect(result).to.equal(backup);
    });

    it("resolveRecipient finds a RECIPIENT block after unrelated blocks", async () => {
      const backup = ethers.zeroPadValue("0x9999", 32);
      const recipient = ethers.zeroPadValue("0x1234", 32);
      const data = concat(
        encodeAmountBlock(asset, meta, amount),
        encodeRecipientBlock(recipient)
      );
      const result = await helper.testResolveRecipient(data, 0n, BigInt(ethers.getBytes(data).length), backup);
      expect(result).to.equal(recipient);
    });

    it("resolveRecipient reverts ZeroRecipient when both are zero", async () => {
      await expect(helper.testResolveRecipient("0x", 0n, 0n, ethers.ZeroHash))
        .to.be.revertedWithCustomError(helper, "ZeroRecipient");
    });

    it("resolveRecipient does not find block beyond limit", async () => {
      const backup = ethers.zeroPadValue("0x9999", 32);
      const recipient = ethers.zeroPadValue("0x1234", 32);
      const data = concat(
        encodeAmountBlock(asset, meta, amount),
        encodeRecipientBlock(recipient)
      );
      const amountLen = BigInt(ethers.getBytes(encodeAmountBlock(asset, meta, amount)).length);
      const result = await helper.testResolveRecipient(data, 0n, amountLen, backup);
      expect(result).to.equal(backup);
    });

    it("resolveNode uses backup when no NODE block", async () => {
      const result = await helper.testResolveNode("0x", 0n, 0n, 42n);
      expect(result).to.equal(42n);
    });

    it("resolveNode reverts ZeroNode when backup is 0 and no block", async () => {
      await expect(helper.testResolveNode("0x", 0n, 0n, 0n))
        .to.be.revertedWithCustomError(helper, "ZeroNode");
    });

    it("resolveNode finds a NODE block after unrelated blocks", async () => {
      const data = concat(
        encodeAmountBlock(asset, meta, amount),
        encodeNodeBlock(42n)
      );
      const result = await helper.testResolveNode(data, 0n, BigInt(ethers.getBytes(data).length), 0n);
      expect(result).to.equal(42n);
    });

    it("verifyAuth returns hash, deadline, proof, and next for valid trailing AUTH", async () => {
      const cid = 77n;
      const deadline = 123456n;
      const signer = "0x" + "11".repeat(20);
      const sig = "0x" + "22".repeat(65);
      const proof = ethers.concat([signer, sig]);
      const auth = encodeAuthBlock(cid, deadline, proof);
      const parent = encodeBundleBlock(
        encodeAmountBlock(asset, meta, amount),
        auth
      );

      const [hash, outDeadline, outProof] = await helper.testVerifyAuth(parent, 0n, cid);
      expect(outDeadline).to.equal(deadline);
      expect(outProof).to.equal(proof);

      const memberStream = concat(encodeAmountBlock(asset, meta, amount), auth);
      const parentBytes = ethers.getBytes(memberStream);
      const expectedHash = ethers.keccak256(parentBytes.slice(0, parentBytes.length - 85));
      expect(hash).to.equal(expectedHash);
    });

    it("verifyAuth reverts UnexpectedValue when cid mismatches", async () => {
      const proof = ethers.concat(["0x" + "11".repeat(20), "0x" + "22".repeat(65)]);
      const auth = encodeAuthBlock(77n, 123456n, proof);
      const parent = encodeBundleBlock(
        encodeAmountBlock(asset, meta, amount),
        auth
      );

      await expect(helper.testVerifyAuth(parent, 0n, 88n))
        .to.be.revertedWithCustomError(helper, "UnexpectedValue");
    });

    it("verifyAuth reverts MalformedBlocks when trailing auth is missing", async () => {
      const parent = encodeBundleBlock(encodeAmountBlock(asset, meta, amount));

      await expect(helper.testVerifyAuth(parent, 0n, 77n))
        .to.be.revertedWithCustomError(helper, "MalformedBlocks");
    });

    it("verifyAuth reverts MalformedBlocks when trailing bytes are too short for AUTH", async () => {
      const truncatedAuthTail = ethers.hexlify(ethers.getBytes(encodeAuthBlock(77n, 123456n, ethers.concat(["0x" + "11".repeat(20), "0x" + "22".repeat(65)]))).slice(0, 100));
      const parent = encodeBundleBlock(
        encodeAmountBlock(asset, meta, amount),
        truncatedAuthTail
      );

      await expect(helper.testVerifyAuth(parent, 0n, 77n))
        .to.be.revertedWithCustomError(helper, "MalformedBlocks");
    });

    it("count returns 0 for empty source", async () => {
      const [count] = await helper.testCountBlocks("0x", 0n, Keys.Amount);
      expect(count).to.equal(0n);
    });

    describe("cursor helpers", () => {
      it("open creates a cursor over one block", async () => {
        const a = encodeBalanceBlock(asset, meta, 1n);
        const [start, end, cursor] = await helper.testCursorFrom(a, 0n);
        expect(start).to.equal(0n);
        expect(end).to.equal(BigInt(ethers.getBytes(a).length));
        expect(cursor).to.equal(end);
      });

      it("open with n creates a cursor over n consecutive blocks", async () => {
        const a = encodeBalanceBlock(asset, meta, 1n);
        const b = encodeBalanceBlock(asset, meta, 2n);
        const c = encodeBalanceBlock(asset, meta, 3n);
        const source = concat(a, b, c);
        const [start, end, cursor] = await helper.testCursorFromN(source, 0n, 2n);
        expect(start).to.equal(0n);
        expect(end).to.equal(BigInt(ethers.getBytes(concat(a, b)).length));
        expect(cursor).to.equal(end);
      });

      it("take returns a source-relative cursor for a range that starts after offset 0", async () => {
        const prefix = encodeRecipientBlock(ethers.zeroPadValue("0x1234", 32));
        const a = encodeBalanceBlock(asset, meta, 1n);
        const b = encodeBalanceBlock(asset, meta, 2n);
        const source = concat(prefix, a, b);
        const offset = BigInt(ethers.getBytes(prefix).length);
        const aLen = BigInt(ethers.getBytes(a).length);
        const [start, end, cursor, next] = await helper.testTake(source, offset, 2n);
        expect(start).to.equal(offset);
        expect(end).to.equal(offset + aLen);
        expect(cursor).to.equal(offset + aLen);
        expect(next).to.equal(offset + aLen);
      });

      it("take keeps bundle cursors relative to the original source", async () => {
        const prefix = encodeRecipientBlock(ethers.zeroPadValue("0x1234", 32));
        const route = encodeRouteBlock("0x12345678");
        const minimum = encodeMinimumBlock(asset, meta, amount);
        const bundle = encodeBundleBlock(route, minimum);
        const source = concat(prefix, bundle);
        const offset = BigInt(ethers.getBytes(prefix).length);
        const endOfSource = BigInt(ethers.getBytes(source).length);
        const [start, end, cursor, next] = await helper.testTake(source, offset, 1n);
        expect(start).to.equal(offset + 8n);
        expect(end).to.equal(endOfSource);
        expect(cursor).to.equal(endOfSource);
        expect(next).to.equal(endOfSource);
      });

      it("done reverts ZeroCursor for an empty cursor", async () => {
        await expect(helper.testCursorDoneEmpty("0x"))
          .to.be.revertedWithCustomError(helper, "ZeroCursor");
      });

      it("done reverts ZeroCursor when a cursor has not advanced and still has remaining input", async () => {
        const a = encodeBalanceBlock(asset, meta, 1n);
        await expect(helper.testCursorDoneOpen(a))
          .to.be.revertedWithCustomError(helper, "ZeroCursor");
      });

      it("done reverts ZeroCursor when a cursor advanced but did not reach the end", async () => {
        const a = encodeBalanceBlock(asset, meta, 1n);
        const b = encodeBalanceBlock(asset, meta, 2n);
        await expect(helper.testCursorDoneAdvanced(concat(a, b)))
          .to.be.revertedWithCustomError(helper, "ZeroCursor");
      });

      it("done allows a cursor that fully consumed a non-empty range", async () => {
        const a = encodeBalanceBlock(asset, meta, 1n);
        const b = encodeBalanceBlock(asset, meta, 2n);
        expect(await helper.testCursorDoneConsumed(concat(a, b))).to.equal(true);
      });
    });
  });

  // ── Mem library ───────────────────────────────────────────────────────────

  describe("Mem library", () => {
    const asset = ethers.zeroPadValue("0xCC", 32);
    const meta  = ethers.zeroPadValue("0xDD", 32);
    const amount = 7777n;

    it("unpackBalance from memory block", async () => {
      const data = encodeBalanceBlock(asset, meta, amount);
      const [a, m, v] = await helper.testMemParseBalance(data, 0n);
      expect(a).to.equal(asset);
      expect(m).to.equal(meta);
      expect(v).to.equal(amount);
    });

    it("toCustodyValue from memory block", async () => {
      const hostId = 99n;
      const data = encodeCustodyBlock(hostId, asset, meta, amount);
      const [h, a, m, v] = await helper.testMemParseCustody(data, 0n);
      expect(h).to.equal(hostId);
      expect(a).to.equal(asset);
      expect(m).to.equal(meta);
      expect(v).to.equal(amount);
    });

    it("slice extracts sub-array", async () => {
      const data = encodeBalanceBlock(asset, meta, amount);
      const fullBytes = ethers.getBytes(data);
      const sliced: string = await helper.testMemSlice(data, 8n, BigInt(fullBytes.length));
      expect(ethers.getBytes(sliced).length).to.equal(fullBytes.length - 8);
    });

    it("slice reverts MalformedBlocks for invalid bounds", async () => {
      const data = encodeBalanceBlock(asset, meta, amount);
      await expect(helper.testMemSlice(data, 10n, 9n))
        .to.be.revertedWithCustomError(helper, "MalformedBlocks");
    });

    it("count works in memory", async () => {
      const b1 = encodeBalanceBlock(asset, meta, 1n);
      const b2 = encodeBalanceBlock(asset, meta, 2n);
      const combined = concat(b1, b2);
      const [count] = await helper.testMemCount(combined, 0n, Keys.Balance);
      expect(count).to.equal(2n);
    });

    it("from reverts MalformedBlocks for 4-byte memory source", async () => {
      await expect(helper.testMemParseBalance("0xdeadbeef", 0n))
        .to.be.revertedWithCustomError(helper, "MalformedBlocks");
    });

    it("from reverts MalformedBlocks when Mem payloadLen exceeds source", async () => {
      const data = encodeBalanceBlock(asset, meta, amount);
      const bytes_ = ethers.getBytes(data);
      // bytes [4..7] = payloadLen; set to 9999 so ref.end > source.length
      bytes_[4] = 0x00; bytes_[5] = 0x00; bytes_[6] = 0x27; bytes_[7] = 0x0F;
      await expect(helper.testMemParseBalance(ethers.hexlify(bytes_), 0n))
        .to.be.revertedWithCustomError(helper, "MalformedBlocks");
    });
  });
});


