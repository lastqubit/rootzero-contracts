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

function blockWithChildren(key: string, payload: string, children: string): string {
  const payloadBytes = ethers.getBytes(payload);
  const childrenBytes = ethers.getBytes(children);
  const selfLen = payloadBytes.length;
  const totalLen = selfLen + childrenBytes.length;
  return ethers.concat([key, encodeUint32(selfLen), encodeUint32(totalLen), payload, children]);
}

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
      const key = Keys.Balance;
      const header: bigint = await helper.testBlockHeader(key, 96n, 96n);
      // Key in bits 224-255
      const keyFromHeader = (header >> 224n) & 0xffffffffn;
      expect(keyFromHeader.toString(16)).to.equal(key.slice(2).toLowerCase());
      // selfLen in bits 192-223
      const selfLen = (header >> 192n) & 0xffffffffn;
      expect(selfLen).to.equal(96n);
    });

    it("toBlockHeader reverts MalformedBlocks when selfLen > totalLen", async () => {
      await expect(helper.testBlockHeader(Keys.Balance, 96n, 64n))
        .to.be.revertedWithCustomError(helper, "MalformedBlocks");
    });

    it("writeBalanceBlock produces 108-byte output", async () => {
      const data: string = await helper.testWriteBalanceBlock(asset, meta, amount);
      expect(ethers.getBytes(data).length).to.equal(108);
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
      expect(key).to.equal(Keys.Amount);
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

    it("unpackCustody reverts InvalidBlock for BALANCE block", async () => {
      const data = encodeBalanceBlock(asset, meta, amount);
      await expect(helper.testUnpackCustody(data, 0n))
        .to.be.revertedWithCustomError(helper, "InvalidBlock");
    });

    it("unpackRecipient reverts InvalidBlock for AMOUNT block", async () => {
      const data = encodeAmountBlock(asset, meta, amount);
      await expect(helper.testUnpackRecipient(data, 0n))
        .to.be.revertedWithCustomError(helper, "InvalidBlock");
    });

    it("unpackNode reverts InvalidBlock for BALANCE block", async () => {
      const data = encodeBalanceBlock(asset, meta, amount);
      await expect(helper.testUnpackNode(data, 0n))
        .to.be.revertedWithCustomError(helper, "InvalidBlock");
    });

    it("unpackFunding reverts InvalidBlock for AMOUNT block", async () => {
      const data = encodeAmountBlock(asset, meta, amount);
      await expect(helper.testUnpackFunding(data, 0n))
        .to.be.revertedWithCustomError(helper, "InvalidBlock");
    });

    it("unpackAsset reverts InvalidBlock for BALANCE block", async () => {
      const data = encodeBalanceBlock(asset, meta, amount);
      await expect(helper.testUnpackAsset(data, 0n))
        .to.be.revertedWithCustomError(helper, "InvalidBlock");
    });

    it("unpackAllocation reverts InvalidBlock for AMOUNT block", async () => {
      const data = encodeAmountBlock(asset, meta, amount);
      await expect(helper.testUnpackAllocation(data, 0n))
        .to.be.revertedWithCustomError(helper, "InvalidBlock");
    });

    it("toTxValue reverts InvalidBlock for BALANCE block", async () => {
      const data = encodeBalanceBlock(asset, meta, amount);
      await expect(helper.testToTxValue(data, 0n))
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

    it("unpackQuantity extracts scalar amount from QUANTITY block", async () => {
      const data = encodeQuantityBlock(777n);
      const result = await helper.testUnpackQuantity(data, 0n);
      expect(result).to.equal(777n);
    });

    it("unpackQuantity reverts InvalidBlock for AMOUNT block", async () => {
      const data = encodeAmountBlock(asset, meta, amount);
      await expect(helper.testUnpackQuantity(data, 0n))
        .to.be.revertedWithCustomError(helper, "InvalidBlock");
    });

    it("expectMinimum returns only the minimum amount when asset/meta match", async () => {
      const data = encodeMinimumBlock(asset, meta, amount);
      const result = await helper.testExpectMinimum(data, 0n, asset, meta);
      expect(result).to.equal(amount);
    });

    it("expectAmount returns only the amount when asset/meta match", async () => {
      const data = encodeAmountBlock(asset, meta, amount);
      const result = await helper.testExpectAmount(data, 0n, asset, meta);
      expect(result).to.equal(amount);
    });

    it("expectBalance returns only the amount when asset/meta match", async () => {
      const data = encodeBalanceBlock(asset, meta, amount);
      const result = await helper.testExpectBalance(data, 0n, asset, meta);
      expect(result).to.equal(amount);
    });

    it("expectMaximum returns only the maximum amount when asset/meta match", async () => {
      const data = encodeMaximumBlock(asset, meta, amount);
      const result = await helper.testExpectMaximum(data, 0n, asset, meta);
      expect(result).to.equal(amount);
    });

    it("expectMinimum reverts UnexpectedValue for wrong asset", async () => {
      const data = encodeMinimumBlock(asset, meta, amount);
      const otherAsset = ethers.zeroPadValue("0xAB", 32);
      await expect(helper.testExpectMinimum(data, 0n, otherAsset, meta))
        .to.be.revertedWithCustomError(helper, "UnexpectedValue");
    });

    it("expectMinimum reverts UnexpectedValue for wrong meta", async () => {
      const data = encodeMinimumBlock(asset, meta, amount);
      const otherMeta = ethers.zeroPadValue("0xCC", 32);
      await expect(helper.testExpectMinimum(data, 0n, asset, otherMeta))
        .to.be.revertedWithCustomError(helper, "UnexpectedValue");
    });

    it("expectAmount reverts UnexpectedValue for wrong asset", async () => {
      const data = encodeAmountBlock(asset, meta, amount);
      const otherAsset = ethers.zeroPadValue("0xAB", 32);
      await expect(helper.testExpectAmount(data, 0n, otherAsset, meta))
        .to.be.revertedWithCustomError(helper, "UnexpectedValue");
    });

    it("expectBalance reverts UnexpectedValue for wrong meta", async () => {
      const data = encodeBalanceBlock(asset, meta, amount);
      const otherMeta = ethers.zeroPadValue("0xCC", 32);
      await expect(helper.testExpectBalance(data, 0n, asset, otherMeta))
        .to.be.revertedWithCustomError(helper, "UnexpectedValue");
    });

    it("expectMaximum reverts UnexpectedValue for wrong asset", async () => {
      const data = encodeMaximumBlock(asset, meta, amount);
      const otherAsset = ethers.zeroPadValue("0xAB", 32);
      await expect(helper.testExpectMaximum(data, 0n, otherAsset, meta))
        .to.be.revertedWithCustomError(helper, "UnexpectedValue");
    });

    it("expectCustody returns AssetAmount when host matches", async () => {
      const hostId = 42n;
      const data = encodeCustodyBlock(hostId, asset, meta, amount);
      const [a, m, v] = await helper.testExpectCustody(data, 0n, hostId);
      expect(a).to.equal(asset);
      expect(m).to.equal(meta);
      expect(v).to.equal(amount);
    });

    it("expectCustody reverts UnexpectedValue for wrong host", async () => {
      const data = encodeCustodyBlock(42n, asset, meta, amount);
      await expect(helper.testExpectCustody(data, 0n, 99n))
        .to.be.revertedWithCustomError(helper, "UnexpectedValue");
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
      const parent = blockWithChildren(
        Keys.Amount,
        ethers.concat([pad32(asset), pad32(meta), pad32(amount)]),
        auth
      );

      const [hash, outDeadline, outProof] = await helper.testVerifyAuth(parent, 0n, cid);
      expect(outDeadline).to.equal(deadline);
      expect(outProof).to.equal(proof);

      const parentBytes = ethers.getBytes(parent);
      const expectedHash = ethers.keccak256(parentBytes.slice(0, parentBytes.length - 85));
      expect(hash).to.equal(expectedHash);
    });

    it("verifyAuth reverts MalformedBlocks when cid mismatches", async () => {
      const proof = ethers.concat(["0x" + "11".repeat(20), "0x" + "22".repeat(65)]);
      const auth = encodeAuthBlock(77n, 123456n, proof);
      const parent = blockWithChildren(
        Keys.Amount,
        ethers.concat([pad32(asset), pad32(meta), pad32(amount)]),
        auth
      );

      await expect(helper.testVerifyAuth(parent, 0n, 88n))
        .to.be.revertedWithCustomError(helper, "MalformedBlocks");
    });

    it("verifyAuth reverts MalformedBlocks when trailing auth is missing", async () => {
      const parent = encodeAmountBlock(asset, meta, amount);

      await expect(helper.testVerifyAuth(parent, 0n, 77n))
        .to.be.revertedWithCustomError(helper, "MalformedBlocks");
    });

    it("verifyAuth reverts MalformedBlocks when trailing bytes are too short for AUTH", async () => {
      const truncatedAuthTail = ethers.hexlify(ethers.getBytes(encodeAuthBlock(77n, 123456n, ethers.concat(["0x" + "11".repeat(20), "0x" + "22".repeat(65)]))).slice(0, 100));
      const parent = blockWithChildren(
        Keys.Amount,
        ethers.concat([pad32(asset), pad32(meta), pad32(amount)]),
        truncatedAuthTail
      );

      await expect(helper.testVerifyAuth(parent, 0n, 77n))
        .to.be.revertedWithCustomError(helper, "MalformedBlocks");
    });

    it("count returns 0 for empty source", async () => {
      const [count] = await helper.testCountBlocks("0x", 0n, Keys.Amount);
      expect(count).to.equal(0n);
    });

    it("from reverts MalformedBlocks for 4-byte source (header too short)", async () => {
      await expect(helper.testParseBlock("0xdeadbeef", 0n))
        .to.be.revertedWithCustomError(helper, "MalformedBlocks");
    });

    it("from reverts MalformedBlocks for 8-byte source (header incomplete)", async () => {
      await expect(helper.testParseBlock("0x0000000100000060", 0n))
        .to.be.revertedWithCustomError(helper, "MalformedBlocks");
    });

    it("from reverts MalformedBlocks when selfLen > totalLen in parsed block", async () => {
      const data = encodeAmountBlock(asset, meta, amount);
      const bytes_ = ethers.getBytes(data);
      // bytes [4..7] = selfLen; set to 200 while totalLen stays 96 → selfLen > totalLen
      bytes_[4] = 0x00; bytes_[5] = 0x00; bytes_[6] = 0x00; bytes_[7] = 0xC8;
      await expect(helper.testParseBlock(ethers.hexlify(bytes_), 0n))
        .to.be.revertedWithCustomError(helper, "MalformedBlocks");
    });

    it("from reverts MalformedBlocks when totalLen exceeds source length", async () => {
      const data = encodeAmountBlock(asset, meta, amount);
      const bytes_ = ethers.getBytes(data);
      // bytes [8..11] = totalLen; set to 9999 so ref.end = 12 + 9999 > source.length
      bytes_[8] = 0x00; bytes_[9] = 0x00; bytes_[10] = 0x27; bytes_[11] = 0x0F;
      await expect(helper.testParseBlock(ethers.hexlify(bytes_), 0n))
        .to.be.revertedWithCustomError(helper, "MalformedBlocks");
    });

    it("from reverts MalformedBlocks when second block in sequence has truncated payload", async () => {
      const b1 = encodeAmountBlock(asset, meta, 1n);
      const b2 = encodeAmountBlock(asset, meta, 2n);
      const truncated = ethers.hexlify(ethers.getBytes(concat(b1, b2)).slice(0, -1));
      const b1End = BigInt(ethers.getBytes(b1).length);
      await expect(helper.testParseBlock(truncated, b1End))
        .to.be.revertedWithCustomError(helper, "MalformedBlocks");
    });

    describe("bundle helpers", () => {
      it("bundleFrom parses a BUNDLE block and preserves inner stream bounds", async () => {
        const memberA = encodeRouteBlock("0x1234");
        const memberB = encodeMinimumBlock(asset, meta, amount);
        const bundle = encodeBundleBlock(memberA, memberB);
        const [key, start, bound, end, cursor] = await helper.testBundleFrom(bundle, 0n);
        expect(key).to.equal(Keys.Bundle);
        expect(start).to.equal(12n);
        expect(bound).to.equal(BigInt(ethers.getBytes(bundle).length));
        expect(end).to.equal(bound);
        expect(cursor).to.equal(BigInt(ethers.getBytes(bundle).length));
      });

      it("viewFrom creates a BundleView over n consecutive blocks", async () => {
        const a = encodeBalanceBlock(asset, meta, 1n);
        const b = encodeBalanceBlock(asset, meta, 2n);
        const c = encodeBalanceBlock(asset, meta, 3n);
        const source = concat(a, b, c);
        const [key, start, bound, end, cursor] = await helper.testViewFrom(source, 0n, 2n);
        expect(key).to.equal(Keys.BundleView);
        expect(start).to.equal(0n);
        expect(bound).to.equal(BigInt(ethers.getBytes(concat(a, b)).length));
        expect(end).to.equal(bound);
        expect(cursor).to.equal(bound);
      });

      it("member returns the indexed member inside a bundle", async () => {
        const memberA = encodeRouteBlock("0x1234");
        const memberB = encodeMinimumBlock(asset, meta, amount);
        const bundle = encodeBundleBlock(memberA, memberB);
        const [key, start, bound, end, cursor] = await helper.testMember(bundle, 0n, 1n);
        const expectedBlockStart = BigInt(ethers.getBytes(memberA).length) + 12n;
        const expectedStart = expectedBlockStart + 12n;
        expect(key).to.equal(Keys.Minimum);
        expect(start).to.equal(expectedStart);
        expect(bound).to.equal(expectedStart + 96n);
        expect(end).to.equal(bound);
        expect(cursor).to.equal(bound);
      });

      it("memberAt returns the member at an exact inner position", async () => {
        const memberA = encodeRouteBlock("0x1234");
        const memberB = encodeMinimumBlock(asset, meta, amount);
        const bundle = encodeBundleBlock(memberA, memberB);
        const secondStart = BigInt(ethers.getBytes(memberA).length) + 12n;
        const [key, start, bound, end, cursor] = await helper.testMemberAt(bundle, 0n, secondStart);
        const expectedStart = secondStart + 12n;
        expect(key).to.equal(Keys.Minimum);
        expect(start).to.equal(expectedStart);
        expect(bound).to.equal(expectedStart + 96n);
        expect(end).to.equal(bound);
        expect(cursor).to.equal(bound);
      });

      it("member reverts MalformedBlocks when the indexed member is out of range", async () => {
        const bundle = encodeBundleBlock(encodeRouteBlock("0x1234"));
        await expect(helper.testMember(bundle, 0n, 1n))
          .to.be.revertedWithCustomError(helper, "MalformedBlocks");
      });

      it("memberAt reverts InvalidBlock when called on a non-bundle block", async () => {
        const amountBlock = encodeAmountBlock(asset, meta, amount);
        await expect(helper.testMemberAt(amountBlock, 0n, 12n))
          .to.be.revertedWithCustomError(helper, "InvalidBlock");
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
      const [count] = await helper.testMemCount(combined, 0n, Keys.Balance);
      expect(count).to.equal(2n);
    });

    it("from reverts MalformedBlocks for 4-byte memory source", async () => {
      await expect(helper.testMemParseBalance("0xdeadbeef", 0n))
        .to.be.revertedWithCustomError(helper, "MalformedBlocks");
    });

    it("from reverts MalformedBlocks when Mem totalLen exceeds source", async () => {
      const data = encodeBalanceBlock(asset, meta, amount);
      const bytes_ = ethers.getBytes(data);
      // bytes [8..11] = totalLen; set to 9999 so ref.end > source.length
      bytes_[8] = 0x00; bytes_[9] = 0x00; bytes_[10] = 0x27; bytes_[11] = 0x0F;
      await expect(helper.testMemParseBalance(ethers.hexlify(bytes_), 0n))
        .to.be.revertedWithCustomError(helper, "MalformedBlocks");
    });
  });
});
