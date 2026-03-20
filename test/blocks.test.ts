import { expect } from "chai";
import { ethers } from "ethers";
import { deploy } from "./helpers/setup.js";
import "./helpers/matchers.js";
import {
  AMOUNT_KEY, BALANCE_KEY, CUSTODY_KEY, RECIPIENT_KEY, NODE_KEY,
  FUNDING_KEY, ASSET_KEY, ALLOCATION_KEY, TX_KEY, BOUNTY_KEY,
  encodeAmountBlock, encodeBalanceBlock, encodeCustodyBlock,
  encodeRecipientBlock, encodeNodeBlock, encodeFundingBlock,
  encodeAssetBlock, encodeAllocationBlock, encodeTxBlock,
  pad32, concat
} from "./helpers/blocks.js";

describe("Blocks", () => {
  let helper: Awaited<ReturnType<typeof deploy>>;

  before(async () => {
    helper = await deploy("TestBlockHelper");
  });

  // ── Writers ───────────────────────────────────────────────────────────────

  describe("Writers", () => {
    const asset = ethers.zeroPadValue("0x01", 32);
    const meta  = ethers.zeroPadValue("0x02", 32);
    const amount = 12345n;

    it("toBlockHeader packs key/selfLen/totalLen into upper bits", async () => {
      const key = BALANCE_KEY;
      const header: bigint = await helper.testBlockHeader(key, 96n, 96n);
      // Key in bits 224-255
      const keyFromHeader = (header >> 224n) & 0xffffffffn;
      expect(keyFromHeader.toString(16)).to.equal(key.slice(2).toLowerCase());
      // selfLen in bits 192-223
      const selfLen = (header >> 192n) & 0xffffffffn;
      expect(selfLen).to.equal(96n);
    });

    it("toBlockHeader reverts MalformedBlocks when selfLen > totalLen", async () => {
      await expect(helper.testBlockHeader(BALANCE_KEY, 96n, 64n))
        .to.be.revertedWithCustomError(helper, "MalformedBlocks");
    });

    it("writeBalanceBlock produces 108-byte output", async () => {
      const data: string = await helper.testWriteBalanceBlock(asset, meta, amount);
      expect(ethers.getBytes(data).length).to.equal(108);
    });

    it("writeBalanceBlock starts with BALANCE_KEY", async () => {
      const data: string = await helper.testWriteBalanceBlock(asset, meta, amount);
      expect(data.slice(0, 10)).to.equal(BALANCE_KEY);
    });

    it("writeBalanceBlock encodes asset, meta, amount correctly", async () => {
      const data: string = await helper.testWriteBalanceBlock(asset, meta, amount);
      // Parse back via testUnpackBalance
      const [a, m, v] = await helper.testUnpackBalance(data, 0n);
      expect(a).to.equal(asset);
      expect(m).to.equal(meta);
      expect(v).to.equal(amount);
    });

    it("writeCustodyBlock produces 140-byte output", async () => {
      const hostId = 1234n;
      const data: string = await helper.testWriteCustodyBlock(hostId, asset, meta, amount);
      expect(ethers.getBytes(data).length).to.equal(140);
    });

    it("writeTxBlock produces 172-byte output", async () => {
      const from_ = ethers.zeroPadValue("0x03", 32);
      const to_   = ethers.zeroPadValue("0x04", 32);
      const data: string = await helper.testWriteTxBlock(from_, to_, asset, meta, amount);
      expect(ethers.getBytes(data).length).to.equal(172);
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
      expect(ethers.getBytes(data).length).to.equal(108); // one balance block
    });
  });

  // ── Blocks (calldata parsing) ─────────────────────────────────────────────

  describe("Blocks library", () => {
    const asset = ethers.zeroPadValue("0xAA", 32);
    const meta  = ethers.zeroPadValue("0xBB", 32);
    const amount = 9999n;

    it("from returns zero-key at end of data", async () => {
      const [key] = await helper.testParseBlock("0x", 0n);
      expect(key).to.equal("0x00000000");
    });

    it("from reverts MalformedBlocks when i > source.length", async () => {
      const data = encodeAmountBlock(asset, meta, amount);
      await expect(helper.testParseBlock(data, 999n))
        .to.be.revertedWithCustomError(helper, "MalformedBlocks");
    });

    it("from parses block key, bound, end correctly", async () => {
      const data = encodeAmountBlock(asset, meta, amount);
      const [key, bound, end] = await helper.testParseBlock(data, 0n);
      expect(key).to.equal(AMOUNT_KEY);
      expect(end).to.equal(BigInt(ethers.getBytes(data).length));
      expect(bound).to.equal(end); // no children
    });

    it("from reverts MalformedBlocks when total length runs past the source", async () => {
      const data = encodeAmountBlock(asset, meta, amount);
      const truncated = ethers.hexlify(ethers.getBytes(data).slice(0, -1));
      await expect(helper.testParseBlock(truncated, 0n))
        .to.be.revertedWithCustomError(helper, "MalformedBlocks");
    });

    it("unpackAmount extracts asset/meta/amount from AMOUNT block", async () => {
      const data = encodeAmountBlock(asset, meta, amount);
      const [a, m, v] = await helper.testUnpackAmount(data, 0n);
      expect(a).to.equal(asset);
      expect(m).to.equal(meta);
      expect(v).to.equal(amount);
    });

    it("unpackAmount reverts InvalidBlock for BALANCE block", async () => {
      const data = encodeBalanceBlock(asset, meta, amount);
      await expect(helper.testUnpackAmount(data, 0n))
        .to.be.revertedWithCustomError(helper, "InvalidBlock");
    });

    it("unpackBalance extracts from BALANCE block", async () => {
      const data = encodeBalanceBlock(asset, meta, amount);
      const [a, m, v] = await helper.testUnpackBalance(data, 0n);
      expect(a).to.equal(asset);
      expect(m).to.equal(meta);
      expect(v).to.equal(amount);
    });

    it("unpackCustody extracts host/asset/meta/amount", async () => {
      const hostId = 42n;
      const data = encodeCustodyBlock(hostId, asset, meta, amount);
      const [h, a, m, v] = await helper.testUnpackCustody(data, 0n);
      expect(h).to.equal(hostId);
      expect(a).to.equal(asset);
      expect(m).to.equal(meta);
      expect(v).to.equal(amount);
    });

    it("unpackRecipient extracts account from RECIPIENT block", async () => {
      const account = ethers.zeroPadValue("0xdeadbeef", 32);
      const data = encodeRecipientBlock(account);
      const result = await helper.testUnpackRecipient(data, 0n);
      expect(result).to.equal(account);
    });

    it("unpackNode extracts id from NODE block", async () => {
      const nodeId = 777n;
      const data = encodeNodeBlock(nodeId);
      const result = await helper.testUnpackNode(data, 0n);
      expect(result).to.equal(nodeId);
    });

    it("unpackFunding extracts host/amount from FUNDING block", async () => {
      const hostId = 555n;
      const data = encodeFundingBlock(hostId, 100n);
      const [h, v] = await helper.testUnpackFunding(data, 0n);
      expect(h).to.equal(hostId);
      expect(v).to.equal(100n);
    });

    it("unpackAsset extracts asset/meta from ASSET block", async () => {
      const a = ethers.zeroPadValue("0x01", 32);
      const m = ethers.zeroPadValue("0x02", 32);
      const data = encodeAssetBlock(a, m);
      const [ra, rm] = await helper.testUnpackAsset(data, 0n);
      expect(ra).to.equal(a);
      expect(rm).to.equal(m);
    });

    it("unpackAllocation extracts host/asset/meta/amount", async () => {
      const h = 111n;
      const a = ethers.zeroPadValue("0x01", 32);
      const m = ethers.zeroPadValue("0x02", 32);
      const v = 5000n;
      const data = encodeAllocationBlock(h, a, m, v);
      const [rh, ra, rm, rv] = await helper.testUnpackAllocation(data, 0n);
      expect(rh).to.equal(h);
      expect(ra).to.equal(a);
      expect(rm).to.equal(m);
      expect(rv).to.equal(v);
    });

    it("count counts consecutive same-key blocks", async () => {
      const b1 = encodeAmountBlock(asset, meta, 1n);
      const b2 = encodeAmountBlock(asset, meta, 2n);
      const b3 = encodeBalanceBlock(asset, meta, 3n); // different key
      const data = concat(b1, b2, b3);
      const [count, next] = await helper.testCountBlocks(data, 0n, AMOUNT_KEY);
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

    it("create32 produces correct 44-byte block", async () => {
      const key = RECIPIENT_KEY;
      const val = ethers.zeroPadValue("0x0abc", 32);
      const data: string = await helper.testCreate32(key, val);
      expect(ethers.getBytes(data).length).to.equal(44);
      expect(data.slice(0, 10)).to.equal(key);
    });

    it("create64 produces correct 76-byte block", async () => {
      const key = ASSET_KEY;
      const a = ethers.zeroPadValue("0x01", 32);
      const b = ethers.zeroPadValue("0x02", 32);
      const data: string = await helper.testCreate64(key, a, b);
      expect(ethers.getBytes(data).length).to.equal(76);
    });

    it("create96 produces correct 108-byte block", async () => {
      const key = AMOUNT_KEY;
      const a = ethers.zeroPadValue("0x01", 32);
      const b = ethers.zeroPadValue("0x02", 32);
      const c = ethers.zeroPadValue("0x03", 32);
      const data: string = await helper.testCreate96(key, a, b, c);
      expect(ethers.getBytes(data).length).to.equal(108);
    });

    it("toBountyBlock produces correct BOUNTY block", async () => {
      const relayer = ethers.zeroPadValue("0xdd", 32);
      const data: string = await helper.testToBounty(500n, relayer);
      expect(ethers.getBytes(data).length).to.equal(76);
      expect(data.slice(0, 10)).to.equal(BOUNTY_KEY);
    });

    it("count returns 0 for empty source", async () => {
      const [count] = await helper.testCountBlocks("0x", 0n, AMOUNT_KEY);
      expect(count).to.equal(0n);
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
      const sliced: string = await helper.testMemSlice(data, 12n, BigInt(fullBytes.length));
      expect(ethers.getBytes(sliced).length).to.equal(fullBytes.length - 12);
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
      const [count] = await helper.testMemCount(combined, 0n, BALANCE_KEY);
      expect(count).to.equal(2n);
    });
  });
});
