import { expect } from "chai";
import { ethers } from "ethers";
import { deploy } from "./helpers/setup.js";
import "./helpers/matchers.js";
import {
  Keys,
  encodeAmountBlock,
  encodeAuthBlock,
  encodeAssetBlock,
  encodeBalanceBlock,
  encodeBalanceLimitBlock,
  encodeBountyBlock,
  encodeRelayBlock,
  encodeDispatchBlock,
  encodeListBlock,
  encodeCustodyBlock,
  encodeCustodyLimitBlock,
  encodeFeeBlock,
  encodeAccountBlock,
  encodeAccountAssetBlock,
  encodeContextBlock,
  encodeRecoverBlock,
  encodeHostAccountAssetBlock,
  encodeBlock,
  encodeLabelBlock,
  encodeSchemaBlock,
  encodeStringBlock,
  encodeStepBlock,
  encodeTxBlock,
  encodeUserAccount,
  exactSpec,
  concat,
  localKey,
} from "./helpers/blocks.js";

describe("Cursors", () => {
  let helper: Awaited<ReturnType<typeof deploy>>;
  let blocksHelper: Awaited<ReturnType<typeof deploy>>;
  let stringHelper: Awaited<ReturnType<typeof deploy>>;
  let erc20Helper: Awaited<ReturnType<typeof deploy>>;
  let operation: Awaited<ReturnType<typeof deploy>>;
  let utils: Awaited<ReturnType<typeof deploy>>;

  before(async () => {
    helper = await deploy("TestCursorHelper");
    blocksHelper = await deploy("TestBlocksHelper");
    stringHelper = await deploy("TestStringCursorHelper");
    erc20Helper = await deploy("TestErc20CursorHelper");
    operation = await deploy("TestOperation");
    utils = await deploy("TestUtils");
  });

  describe("Writers", () => {
    const asset = ethers.zeroPadValue("0x01", 32);
    const amount = 12345n;

    it("writeBalanceBlock round-trips", async () => {
      const data: string = await helper.testWriteBalanceBlock(asset, amount);
      expect(ethers.getBytes(data).length).to.equal(72);
      expect(data.slice(0, 10)).to.equal(Keys.Balance);
      expect(data.slice(10, 18)).to.equal("00000040");
      expect(await helper.testUnpackBalance(data)).to.deep.equal([asset, amount]);
    });

    it("hostAccountAsset block round-trips", async () => {
      const host = 1234n;
      const account = encodeUserAccount("0x03");
      const data = encodeHostAccountAssetBlock(host, account, asset);
      expect(ethers.getBytes(data).length).to.equal(104);
      expect(data.slice(0, 10)).to.equal(Keys.HostAccountAsset);
      expect(await helper.testUnpackHostAccountAsset(data)).to.deep.equal([host, account, asset]);
    });

    it("accountAsset block round-trips", async () => {
      const account = encodeUserAccount("0x03");
      const data = encodeAccountAssetBlock(account, asset);
      expect(ethers.getBytes(data).length).to.equal(72);
      expect(data.slice(0, 10)).to.equal(Keys.AccountAsset);
      expect(await helper.testUnpackAccountAsset(data)).to.deep.equal([account, asset]);
    });

    it("writeCustodyBlock produces 104 bytes", async () => {
      const data: string = await helper.testWriteCustodyBlock(1234n, asset, amount);
      expect(ethers.getBytes(data).length).to.equal(104);
    });

    it("writeTxBlock round-trips", async () => {
      const from_ = encodeUserAccount("0x03");
      const to_ = encodeUserAccount("0x04");
      const data: string = await helper.testWriteTxBlock(from_, to_, asset, amount);
      expect(ethers.getBytes(data).length).to.equal(136);
      expect(await helper.testToTxValue(data)).to.deep.equal([from_, to_, asset, amount]);
    });

    it("transaction struct overload matches separate fields", async () => {
      const from_ = encodeUserAccount("0x03");
      const to_ = encodeUserAccount("0x04");
      const fields: string = await helper.testWriteTxBlock(from_, to_, asset, amount);
      const value: string = await helper.testWriteTxStructBlock(from_, to_, asset, amount);
      expect(value).to.equal(fields);
    });

    it("writeStringBlock round-trips UTF-8 payloads", async () => {
      const label = "credit account";
      const data: string = await stringHelper.testWriteStringBlock(label);
      expect(data).to.equal(encodeStringBlock(label));
      expect(data.slice(0, 10)).to.equal(Keys.String);
      expect(data.slice(10, 18)).to.equal("0000000e");
      expect(await stringHelper.testUnpackString(data)).to.deep.equal([label, BigInt(ethers.getBytes(data).length)]);
    });

    it("balance returns a valid encoded BALANCE block", async () => {
      const data: string = await helper.testToBalanceBlock(asset, amount);
      expect(ethers.getBytes(data).length).to.equal(72);
      expect(data.slice(0, 10)).to.equal(Keys.Balance);
      expect(await helper.testUnpackBalance(data)).to.deep.equal([asset, amount]);
    });

    it("writeBalance writes the specialized encoding at the requested offset", async () => {
      const offset = 5n;
      const [data, next] = await blocksHelper.writeBalance(offset, asset, amount);
      expect(data).to.equal(ethers.concat([new Uint8Array(Number(offset)), encodeBalanceBlock(asset, amount)]));
      expect(next).to.equal(offset + 72n);
    });

    it("custody returns a valid encoded CUSTODY block", async () => {
      const data: string = await helper.testToCustodyBlock(1234n, asset, amount);
      expect(ethers.getBytes(data).length).to.equal(104);
      expect(data.slice(0, 10)).to.equal(Keys.Custody);
    });

    it("transaction returns a valid encoded TRANSACTION block", async () => {
      const from_ = encodeUserAccount("0x03");
      const to_ = encodeUserAccount("0x04");
      const data: string = await helper.testToTransactionBlock(from_, to_, asset, amount);
      expect(ethers.getBytes(data).length).to.equal(136);
      expect(data.slice(0, 10)).to.equal(Keys.Transaction);
      expect(await helper.testToTxValue(data)).to.deep.equal([from_, to_, asset, amount]);
    });

    it("writeTransaction writes the specialized encoding at the requested offset", async () => {
      const from_ = encodeUserAccount("0x03");
      const to_ = encodeUserAccount("0x04");
      const offset = 5n;
      const [data, next] = await blocksHelper.writeTransaction(offset, from_, to_, asset, amount);
      expect(data).to.equal(ethers.concat([new Uint8Array(Number(offset)), encodeTxBlock(from_, to_, asset, amount)]));
      expect(next).to.equal(offset + 136n);
    });

    it("stores the transaction header at the start of its word-aligned spec", async () => {
      const spec: string = await blocksHelper.transactionSpec();
      expect(spec.slice(0, 18)).to.equal(encodeTxBlock(ethers.ZeroHash, ethers.ZeroHash, ethers.ZeroHash, 0n).slice(0, 18));
    });

    it("derives fixed bounds and stores dynamic bounds in specs", async () => {
      expect(await blocksHelper.specRanges()).to.deep.equal([128n, 128n, 72n, 0n]);
    });

    it("derives a grouped container descriptor lane from a spec", async () => {
      expect(await blocksHelper.listAssetDescriptor()).to.deep.equal([Keys.List, Keys.Asset, 3n]);
    });

    it("retains the complete output writer spec in its descriptor lane", async () => {
      expect(await blocksHelper.balanceOutputDescriptor())
        .to.equal(exactSpec(Keys.Balance, 64));
      expect(await blocksHelper.groupedBalanceOutputDescriptor())
        .to.deep.equal([exactSpec(Keys.Balance, 64) | (3n << 120n), 3n]);
    });

    it("rejects containers on state and output descriptor lanes", async () => {
      await expect(blocksHelper.rejectLaneContainer(false))
        .to.be.revertedWithCustomError(blocksHelper, "InvalidContainer");
      await expect(blocksHelper.rejectLaneContainer(true))
        .to.be.revertedWithCustomError(blocksHelper, "InvalidContainer");
    });

    it("grow returns an adequate buffer and preserves only written bytes", async () => {
      const grown: string = await blocksHelper.grow("0x010203040506", 3, 200);
      const bytes = ethers.getBytes(grown);
      expect(bytes.length).to.be.at.least(200);
      expect(ethers.hexlify(bytes.slice(0, 3))).to.equal("0x010203");
      expect(bytes.slice(3).every((byte) => byte === 0)).to.equal(true);
    });

    it("grow returns an unchanged buffer when it already has capacity", async () => {
      expect(await blocksHelper.grow("0x010203040506", 3, 6)).to.equal("0x010203040506");
    });

    it("bounty returns a valid encoded BOUNTY block", async () => {
      const relayer = ethers.zeroPadValue("0x05", 32);
      const data: string = await helper.testToBountyBlock(amount, relayer);
      const bytes = ethers.getBytes(data);
      expect(bytes.length).to.equal(72);
      expect(data.slice(0, 10)).to.equal(Keys.Bounty);
      expect(ethers.hexlify(bytes.slice(4, 8))).to.equal("0x00000040");
    });

    it("text returns a valid encoded STRING block", async () => {
      const label = "relayPayable";
      const data: string = await stringHelper.testToStringBlock(label);
      expect(data).to.equal(encodeStringBlock(label));
      expect(data.slice(0, 10)).to.equal(Keys.String);
    });

    it("finish returns empty bytes when writer is unused", async () => {
      expect(await helper.testWriterFinishEmpty()).to.equal("0x");
    });

    it("finish truncates to actual written length", async () => {
      const data: string = await helper.testWriterFinish(asset, amount);
      expect(ethers.getBytes(data).length).to.equal(72);
    });

    it("allocates an initialized writer on its first write", async () => {
      const data: string = await blocksHelper.lazyBalance(asset, amount);
      expect(data).to.equal(encodeBalanceBlock(asset, amount));
    });

    it("returns an inert empty writer for a zero block count", async () => {
      expect(await blocksHelper.emptyWriter()).to.deep.equal([0n, 0n, false, 0n]);
    });

    it("reverts when appending past logical writer capacity", async () => {
      await expect(blocksHelper.rejectSecond32(asset))
        .to.be.revertedWithCustomError(blocksHelper, "BufferOverflow");
    });

    it("rejects a payload that does not match a fixed spec", async () => {
      const oversized = ethers.concat([asset, asset]);
      await expect(blocksHelper.rejectOversizedDynamic(oversized))
        .to.be.revertedWithCustomError(blocksHelper, "InvalidSpec");
    });

    it("rejects dynamic payloads outside their spec range", async () => {
      await expect(blocksHelper.rejectOutOfRange("0x01"))
        .to.be.revertedWithCustomError(blocksHelper, "InvalidSpec");
      await expect(blocksHelper.rejectOutOfRange("0x0102030405"))
        .to.be.revertedWithCustomError(blocksHelper, "InvalidSpec");
    });
  });

  describe("Readers", () => {
    const asset = ethers.zeroPadValue("0xaa", 32);
    const otherAsset = ethers.zeroPadValue("0xbb", 32);
    const from = encodeUserAccount("0x01");
    const to = encodeUserAccount("0x02");

    it("unpacks a balance and advances to the end", async () => {
      const source = encodeBalanceBlock(asset, 123n);
      expect(await helper.testReaderUnpackBalance(source)).to.deep.equal([
        asset,
        123n,
        72n,
        true,
      ]);
    });

    it("unpacks a transaction and advances to the end", async () => {
      const source = encodeTxBlock(from, to, asset, 456n);
      expect(await helper.testReaderUnpackTransaction(source)).to.deep.equal([
        from,
        to,
        asset,
        456n,
        136n,
        true,
      ]);
    });

    it("unpacks sequential blocks and reports completion", async () => {
      const source = concat(
        encodeBalanceBlock(asset, 123n),
        encodeBalanceBlock(otherAsset, 456n),
      );
      expect(await helper.testReaderUnpackTwoBalances(source)).to.deep.equal([
        asset,
        123n,
        otherAsset,
        456n,
        144n,
        true,
      ]);
    });

    it("rejects a block with the wrong key", async () => {
      await expect(helper.testReaderUnpackBalance(encodeAmountBlock(asset, 123n)))
        .to.be.revertedWithCustomError(helper, "InvalidBlock");
    });

    it("rejects a payload below the minimum length", async () => {
      const source = encodeBlock(Keys.Balance, asset);
      await expect(helper.testReaderUnpackBalance(source))
        .to.be.revertedWithCustomError(helper, "InvalidBlock");
    });

    it("rejects a payload above the maximum length", async () => {
      const source = encodeBlock(Keys.Balance, ethers.concat([asset, asset, asset]));
      await expect(helper.testReaderUnpackBalance(source))
        .to.be.revertedWithCustomError(helper, "InvalidBlock");
    });

    it("rejects a truncated header", async () => {
      const source = ethers.dataSlice(encodeBalanceBlock(asset, 123n), 0, 7);
      await expect(helper.testReaderUnpackBalance(source))
        .to.be.revertedWithCustomError(helper, "InvalidBlock");
    });

    it("rejects a truncated payload", async () => {
      const complete = ethers.getBytes(encodeBalanceBlock(asset, 123n));
      const source = ethers.hexlify(complete.slice(0, -1));
      await expect(helper.testReaderUnpackBalance(source))
        .to.be.revertedWithCustomError(helper, "InvalidBlock");
    });
  });

  describe("Cursor helpers", () => {
    const asset = ethers.zeroPadValue("0xaa", 32);
    const otherAsset = ethers.zeroPadValue("0xbb", 32);
    const amount = 9999n;

    it("pairs tagged lanes, updates the selected lane, and restores input orientation", async () => {
      const input = 1n | (2n << 32n) | (10n << 64n);
      const state = 3n | (4n << 32n) | (20n << 64n);
      const stateTag = 1n << 120n;
      const updatedState = 7n | (4n << 32n) | (20n << 64n) | stateTag;

      const [selected, restored] = await helper.testCursorLanes(input, state, 7n);

      expect(selected & ((1n << 128n) - 1n)).to.equal(updatedState);
      expect(selected >> 128n).to.equal(input);
      expect(restored & ((1n << 128n) - 1n)).to.equal(input);
      expect(restored >> 128n).to.equal(updatedState);
    });

    it("selects creator-defined cursor tags", async () => {
      const lower = 11n;
      const higher = 22n;
      const selected = await helper.testSelectTag(lower, 7, higher, 42, 42);

      expect(selected & ((1n << 128n) - 1n)).to.equal((higher << 64n) | (42n << 120n));
      expect(selected >> 128n).to.equal((lower << 64n) | (7n << 120n));
    });

    it("packs groups, consumer flags, and tag into span metadata", async () => {
      const [cur, groups, flags, tag] = await helper.testSpanMeta(0x1234, 0x56, 0x78);

      expect(cur).to.equal((0x1234n << 96n) | (0x56n << 112n) | (0x78n << 120n));
      expect(groups).to.equal(0x1234n);
      expect(flags).to.equal(0x56n);
      expect(tag).to.equal(0x78n);
    });

    it("detects whether both packed spans remain at their initial positions", async () => {
      const metadata = (10n << 64n) | ((20n << 64n) << 128n);

      expect(await helper.testSpanInitial(metadata)).to.be.true;
      expect(await helper.testSpanInitial(metadata | 1n)).to.be.false;
      expect(await helper.testSpanInitial(metadata | (1n << 128n))).to.be.false;
    });

    it("reverts MissingTag when a cursor pair does not contain the requested tag", async () => {
      await expect(helper.testSelectTag(11n, 7, 22n, 42, 9))
        .to.be.revertedWithCustomError(helper, "MissingTag");
    });

    it("unpackBalanceForHost scopes a consumed BALANCE to the supplied host", async () => {
      const host = 1234n;
      const source = encodeBalanceBlock(asset, amount);
      const [outHost, outAsset, outAmount, i] = await helper.testUnpackBalanceForHost(source, host);
      expect(outHost).to.equal(host);
      expect(outAsset).to.equal(asset);
      expect(outAmount).to.equal(amount);
      expect(i).to.equal(BigInt(ethers.getBytes(source).length));
    });

    it("scope returns key and groups, and truncates len to the matching run", async () => {
      const a = encodeAmountBlock(asset, 1n);
      const b = encodeAmountBlock(asset, 2n);
      const c = encodeBalanceBlock(asset, 3n);
      const source = concat(a, b, c);
      const [key, groups, offset, i, len] = await helper.testScope(source, 1n);
      expect(key).to.equal(Keys.Amount);
      expect(groups).to.equal(2n);
      expect(offset).to.equal(0n);
      expect(i).to.equal(0n);
      expect(len).to.equal(BigInt(ethers.getBytes(concat(a, b)).length));
    });

    it("scope reverts ZeroGroup when group is 0", async () => {
      const source = encodeAmountBlock(asset, amount);
      await expect(helper.testScope(source, 0n))
        .to.be.revertedWithCustomError(helper, "ZeroGroup");
    });

    it("scope reverts MalformedBlocks when the first header is truncated", async () => {
      await expect(helper.testScope("0x" + Keys.Amount.slice(2), 1n))
        .to.be.revertedWithCustomError(helper, "MalformedBlocks");
    });

    it("open(source, i) creates a cursor over the source tail", async () => {
      const a = encodeAmountBlock(asset, 1n);
      const b = encodeBalanceBlock(asset, 2n);
      const source = concat(a, b);
      const i = BigInt(ethers.getBytes(a).length);
      const [offset, cursorI, len] = await helper.testOpenAt(source, i);
      expect(offset).to.equal(i);
      expect(cursorI).to.equal(0n);
      expect(len).to.equal(BigInt(ethers.getBytes(b).length));
    });

    it("init(source, group) creates a cursor over the matching first run", async () => {
      const a = encodeAmountBlock(asset, 1n);
      const b = encodeAmountBlock(asset, 2n);
      const c = encodeBalanceBlock(asset, 3n);
      const source = concat(a, b, c);
      const run = concat(a, b);
      const [offset, cursorI, len, groups] = await helper.testInit(source, 1n, 0n);
      expect(offset).to.equal(0n);
      expect(cursorI).to.equal(0n);
      expect(len).to.equal(BigInt(ethers.getBytes(run).length));
      expect(groups).to.equal(2n);
    });

    it("init reconciles the discovered groups with expected", async () => {
      const source = concat(
        encodeAmountBlock(asset, 1n),
        encodeAmountBlock(asset, 2n),
      );
      expect((await helper.testInit(source, 1n, 2n))[3]).to.equal(2n);
      await expect(helper.testInit(source, 1n, 1n))
        .to.be.revertedWithCustomError(helper, "BadRatio");
    });

    it("init(source, 0) returns an empty cursor for an empty source", async () => {
      const [offset, cursorI, len, groups] = await helper.testInit("0x", 0n, 0n);
      expect(offset).to.equal(0n);
      expect(cursorI).to.equal(0n);
      expect(len).to.equal(0n);
      expect(groups).to.equal(0n);
    });

    it("init(source, 0) inherits expected for an empty source", async () => {
      expect((await helper.testInit("0x", 0n, 3n))[3]).to.equal(3n);
    });

    it("init(source, 0) reverts IncompleteCursor for a non-empty source", async () => {
      await expect(helper.testInit(encodeAmountBlock(asset, amount), 0n, 0n))
        .to.be.revertedWithCustomError(helper, "IncompleteCursor");
    });

    it("peek returns the next key and payload length", async () => {
      const source = encodeBalanceBlock(asset, amount);
      expect(await helper.testPeek(source, 0n)).to.deep.equal([Keys.Balance, 64n]);
    });

    it("past returns the offset immediately past the current block without advancing", async () => {
      const source = encodeBalanceBlock(asset, amount);
      expect(await helper.testPastCurrent(source)).to.equal(72n);
    });

    it("isAt returns true for a matching well-formed block at the current cursor position", async () => {
      const source = encodeBalanceBlock(asset, amount);
      expect(await helper.testIsAtCurrent(source, Keys.Balance)).to.equal(true);
    });

    it("isAt returns false when the key does not match", async () => {
      const source = encodeBalanceBlock(asset, amount);
      expect(await helper.testIsAtCurrent(source, Keys.Amount)).to.equal(false);
    });

    it("isAt returns true for a truncated block when the current header key matches", async () => {
      const source = "0x" + Keys.Balance.slice(2) + "00000040";
      expect(await helper.testIsAtCurrent(source, Keys.Balance)).to.equal(true);
    });

    it("hasAt checks a block key at an arbitrary source position", async () => {
      const a = encodeAmountBlock(asset, 1n);
      const b = encodeBalanceBlock(asset, 2n);
      const source = concat(a, b);
      const i = BigInt(ethers.getBytes(a).length);
      expect(await helper.testHasAt(source, i, Keys.Balance)).to.equal(true);
      expect(await helper.testHasAt(source, i, Keys.Amount)).to.equal(false);
      expect(await helper.testHasAt(source, BigInt(ethers.getBytes(source).length), Keys.Balance)).to.equal(false);
    });

    it("run counts consecutive matching blocks from i", async () => {
      const a = encodeAmountBlock(asset, 1n);
      const b = encodeAmountBlock(asset, 2n);
      const c = encodeBalanceBlock(asset, 3n);
      const [count, next] = await helper.testRun(concat(a, b, c), 0n, Keys.Amount);
      expect(count).to.equal(2n);
      expect(next).to.equal(BigInt(ethers.getBytes(concat(a, b)).length));
    });

    it("slice creates a subcursor over the requested range", async () => {
      const a = encodeAssetBlock(asset);
      const b = encodeAccountBlock(encodeUserAccount("0x12"));
      const source = concat(a, b);
      const from = BigInt(ethers.getBytes(a).length);
      const to = BigInt(ethers.getBytes(source).length);
      const [offset, i, len] = await helper.testSlice(source, from, to);
      expect(offset).to.equal(from);
      expect(i).to.equal(0n);
      expect(len).to.equal(BigInt(ethers.getBytes(b).length));
    });

    it("slice reverts OutOfBounds when the requested range is invalid", async () => {
      const source = concat(encodeAssetBlock(asset), encodeAccountBlock(encodeUserAccount("0x12")));
      await expect(helper.testSlice(source, 10n, 9n))
        .to.be.revertedWithCustomError(helper, "OutOfBounds");
      await expect(helper.testSlice(source, 0n, BigInt(ethers.getBytes(source).length + 1)))
        .to.be.revertedWithCustomError(helper, "OutOfBounds");
    });

    it("raw returns the full cursor region as calldata", async () => {
      const source = concat(encodeAssetBlock(asset), encodeAccountBlock(encodeUserAccount("0x12")));
      expect(await helper.testRaw(source)).to.equal(source);
    });

    it("raw returns a sliced cursor region as calldata", async () => {
      const a = encodeAssetBlock(asset);
      const b = encodeAccountBlock(encodeUserAccount("0x12"));
      const source = concat(a, b);
      const from = BigInt(ethers.getBytes(a).length);
      const to = BigInt(ethers.getBytes(source).length);
      expect(await helper.testRawSlice(source, from, to)).to.equal(b);
    });

    it("maybeOnly returns false for an empty cursor", async () => {
      expect(await helper.testMaybeOnly("0x", Keys.Fee)).to.equal(false);
    });

    it("maybeOnly returns true when exactly one matching block remains", async () => {
      expect(await helper.testMaybeOnly(encodeFeeBlock(3n), Keys.Fee)).to.equal(true);
    });

    it("maybeOnly reverts InvalidBlock when the remaining block has another key", async () => {
      await expect(helper.testMaybeOnly(encodeAccountBlock(encodeUserAccount("0x12")), Keys.Fee))
        .to.be.revertedWithCustomError(helper, "InvalidBlock");
    });

    it("maybeOnly reverts IncompleteCursor when trailing bytes remain", async () => {
      const source = concat(encodeFeeBlock(3n), encodeAccountBlock(encodeUserAccount("0x12")));
      await expect(helper.testMaybeOnly(source, Keys.Fee))
        .to.be.revertedWithCustomError(helper, "IncompleteCursor");
    });

    it("skipTo moves the cursor to the provided end offset", async () => {
      const source = concat(encodeAssetBlock(asset), encodeAssetBlock(otherAsset));
      expect(await helper.testSkipTo(source, BigInt(ethers.getBytes(source).length))).to.equal(BigInt(ethers.getBytes(source).length));
    });

    it("skipTo reverts IncompleteCursor when the cursor has passed the end offset", async () => {
      const source = concat(encodeAssetBlock(asset), encodeAssetBlock(otherAsset));
      const end = BigInt(ethers.getBytes(source).length - ethers.getBytes(encodeAssetBlock(otherAsset)).length);
      await expect(helper.testSkipToPastEnd(source, end))
        .to.be.revertedWithCustomError(helper, "IncompleteCursor");
    });

    it("ensureAt succeeds when the cursor is exactly at the requested position", async () => {
      const source = concat(encodeAssetBlock(asset), encodeAssetBlock(otherAsset));
      const pos = BigInt(ethers.getBytes(source).length);
      expect(await helper.testEnsureAt(source, pos)).to.equal(pos);
    });

    it("ensureAt reverts UnexpectedPosition when the cursor is not exactly at the requested position", async () => {
      const source = concat(encodeAssetBlock(asset), encodeAssetBlock(otherAsset));
      const pos = BigInt(ethers.getBytes(encodeAssetBlock(asset)).length);
      await expect(helper.testEnsureAtMismatch(source, pos))
        .to.be.revertedWithCustomError(helper, "UnexpectedPosition");
    });

    it("list consumes the list and returns a cursor scoped to its payload", async () => {
      const item1 = encodeAssetBlock(asset);
      const item2 = encodeAssetBlock(otherAsset);
      const list = encodeListBlock(item1, item2);
      const [itemsOffset, itemsI, itemsLen, inputI] = await helper.testList(list);
      expect(itemsOffset).to.equal(8n);
      expect(itemsI).to.equal(0n);
      expect(itemsLen).to.equal(BigInt(ethers.getBytes(item1).length + ethers.getBytes(item2).length));
      expect(inputI).to.equal(BigInt(ethers.getBytes(list).length));
    });

    it("custom local blocks carry merged payload fields without child headers", async () => {
      const custom = localKey(1);
      const payload = ethers.concat([
        asset,
        otherAsset,
        ethers.zeroPadValue(ethers.toBeHex(amount), 32),
        ethers.zeroPadValue(ethers.toBeHex(77n), 32),
      ]);
      const data = encodeBlock(custom, payload);

      expect(data.slice(0, 10)).to.equal(custom);
      expect(await helper.testPeek(data, 0n)).to.deep.equal([custom, 128n]);
      expect(ethers.getBytes(data).length).to.equal(136);
      expect(data).to.not.include(Keys.Amount.slice(2));
      expect(data).to.not.include(Keys.Fee.slice(2));
    });

    it("take returns a sliced cursor over the full matching block and advances the source cursor", async () => {
      const custom = localKey(1);
      const payload = encodeAccountBlock(encodeUserAccount("0x12"));
      const data = encodeBlock(custom, payload);
      const [outOffset, outI, outLen, inputI] = await helper.testTake(data, custom);
      expect(outOffset).to.equal(0n);
      expect(outI).to.equal(0n);
      expect(outLen).to.equal(BigInt(ethers.getBytes(data).length));
      expect(inputI).to.equal(BigInt(ethers.getBytes(data).length));
    });

    it("take reverts when the current block key does not match", async () => {
      const custom = localKey(1);
      const source = encodeBalanceBlock(asset, amount);
      await expect(helper.testTake(source, custom))
        .to.be.revertedWithCustomError(helper, "InvalidBlock");
    });

    it("maybeTake returns a sliced cursor and advances when the current block matches", async () => {
      const custom = localKey(1);
      const payload = encodeAccountBlock(encodeUserAccount("0x34"));
      const data = encodeBlock(custom, payload);
      const [outOffset, outI, outLen, inputI] = await helper.testMaybeTake(data, custom);
      expect(outOffset).to.equal(0n);
      expect(outI).to.equal(0n);
      expect(outLen).to.equal(BigInt(ethers.getBytes(data).length));
      expect(inputI).to.equal(BigInt(ethers.getBytes(data).length));
    });

    it("maybeTake returns an empty cursor and does not advance when the current block does not match", async () => {
      const custom = localKey(1);
      const source = encodeBalanceBlock(asset, amount);
      const [outOffset, outI, outLen, inputI] = await helper.testMaybeTake(source, custom);
      expect(outOffset).to.equal(0n);
      expect(outI).to.equal(0n);
      expect(outLen).to.equal(0n);
      expect(inputI).to.equal(0n);
    });

    it("unpackStep consumes the block and returns the trailing request", async () => {
      const req = encodeAmountBlock(asset, amount);
      const step = encodeStepBlock(7n, 55n, req);
      const [target, value, outReq, i] = await helper.testUnpackStep(step);
      expect(target).to.equal(7n);
      expect(value).to.equal(55n);
      expect(outReq).to.equal(req);
      expect(i).to.equal(BigInt(ethers.getBytes(step).length));
    });

    it("unpackContext consumes account, state, and request bytes", async () => {
      const account = encodeUserAccount("0x12");
      const state = encodeBalanceBlock(asset, amount);
      const request = encodeAmountBlock(asset, 7n);
      const context = encodeContextBlock(account, state, request);
      const [outAccount, outState, outRequest, i] = await helper.testUnpackContext(context);
      expect(outAccount).to.equal(account);
      expect(outState).to.equal(state);
      expect(outRequest).to.equal(request);
      expect(i).to.equal(BigInt(ethers.getBytes(context).length));
    });

    it("unpackRecover consumes handler, resources, key, and witness bytes", async () => {
      const handler = 42n;
      const key = ethers.zeroPadValue("0x1234", 32);
      const account = encodeUserAccount("0x12");
      const state = encodeBalanceBlock(asset, amount);
      const request = encodeAmountBlock(asset, 7n);
      const witness = encodeContextBlock(account, state, request);
      const resources = 55n;
      const recovery = encodeRecoverBlock(handler, resources, key, witness);
      const [outHandler, outResources, outKey, outWitness, i] = await helper.testUnpackRecover(recovery);
      expect(outHandler).to.equal(handler);
      expect(outResources).to.equal(resources);
      expect(outKey).to.equal(key);
      expect(outWitness).to.equal(witness);
      expect(i).to.equal(BigInt(ethers.getBytes(recovery).length));
    });

    it("unpackRelay consumes portal, resources, and request bytes", async () => {
      const portal: bigint = await utils.testLocalChainId();
      const request = encodeStepBlock(0n, 0n, encodeAmountBlock(asset, 7n));
      const relay = encodeRelayBlock(portal, 55n, request);
      const [outPortal, resources, outRequest, i] = await helper.testUnpackRelay(relay);
      expect(outPortal).to.equal(portal);
      expect(resources).to.equal(55n);
      expect(outRequest).to.equal(request);
      expect(i).to.equal(BigInt(ethers.getBytes(relay).length));
    });

    it("unpackDispatch consumes portal, resources, and payload bytes", async () => {
      const portal: bigint = await utils.testLocalChainId();
      const payload = ethers.hexlify(ethers.toUtf8Bytes("ready-to-send"));
      const dispatch = encodeDispatchBlock(portal, 89n, payload);
      const [outPortal, resources, outPayload, i] = await helper.testUnpackDispatch(dispatch);
      expect(outPortal).to.equal(portal);
      expect(resources).to.equal(89n);
      expect(outPayload).to.equal(payload);
      expect(i).to.equal(BigInt(ethers.getBytes(dispatch).length));
    });

    it("unpackString consumes a STRING block and returns the decoded string", async () => {
      const label = "label schema";
      const source = encodeStringBlock(label);
      const [out, i] = await stringHelper.testUnpackString(source);
      expect(out).to.equal(label);
      expect(i).to.equal(BigInt(ethers.getBytes(source).length));
    });

    it("unpackLabel consumes a LABEL block and returns its fields", async () => {
      const id = 789n;
      const namespace = ethers.encodeBytes32String("peer");
      const name = "portDispatchPayable";
      const source = encodeLabelBlock(id, namespace, name);
      const [outId, outNamespace, outName, i] = await stringHelper.testUnpackLabel(source);
      expect(outId).to.equal(id);
      expect(outNamespace).to.equal(namespace);
      expect(outName).to.equal(name);
      expect(i).to.equal(BigInt(ethers.getBytes(source).length));
    });

    it("unpackSchema consumes a SCHEMA block and returns its fields", async () => {
      const spec = exactSpec(Keys.Amount, 64);
      const name = ethers.encodeBytes32String("amount");
      const body = "{ bytes32 asset, uint amount }";
      const source = encodeSchemaBlock(spec, body, name);
      const [outSpec, outBody, outName, i] = await stringHelper.testUnpackSchema(source);
      expect(outSpec).to.equal(spec);
      expect(outBody).to.equal(body);
      expect(outName).to.equal(name);
      expect(i).to.equal(BigInt(ethers.getBytes(source).length));
    });

    it("unpackFee returns the fee amount", async () => {
      const source = encodeFeeBlock(77n);
      expect(await helper.testUnpackFee(source)).to.equal(77n);
    });

    it("unpackAccount returns the account word", async () => {
      const account = encodeUserAccount("0x12");
      const source = encodeAccountBlock(account);
      expect(await helper.testUnpackAccount(source)).to.equal(account);
    });

    it("requireAmount validates and advances by one fixed-size block", async () => {
      const source = encodeAmountBlock(asset, amount);
      const [out, i] = await helper.testRequireAmount(source, asset);
      expect(out).to.equal(amount);
      expect(i).to.equal(72n);
    });

    it("ensureBalanceLimit validates all fields and advances by one limit block", async () => {
      const source = encodeBalanceLimitBlock(asset, 10n, amount);
      expect(await helper.testEnsureBalanceLimit(source, asset, amount)).to.equal(104n);
    });

    it("ensureBalanceLimit reverts UnexpectedValue when the balance is outside the range", async () => {
      const source = encodeBalanceLimitBlock(asset, 10n, 20n);
      await expect(helper.testEnsureBalanceLimit(source, asset, 21n))
        .to.be.revertedWithCustomError(helper, "UnexpectedValue");
    });

    it("ensureBalanceLimit reverts UnexpectedValue when asset fields differ", async () => {
      const source = encodeBalanceLimitBlock(asset, 10n, 20n);
      await expect(helper.testEnsureBalanceLimit(source, ethers.zeroPadValue("0xcc", 32), 15n))
        .to.be.revertedWithCustomError(helper, "UnexpectedValue");
    });

    it("ensureCustodyLimit validates all fields and advances by one limit block", async () => {
      const source = encodeCustodyLimitBlock(123n, asset, 10n, amount);
      expect(await helper.testEnsureCustodyLimit(source, 123n, asset, amount)).to.equal(136n);
    });

    it("ensureCustodyLimit reverts UnexpectedValue when the custody is outside the range", async () => {
      const source = encodeCustodyLimitBlock(123n, asset, 10n, 20n);
      await expect(helper.testEnsureCustodyLimit(source, 123n, asset, 21n))
        .to.be.revertedWithCustomError(helper, "UnexpectedValue");
    });

    it("ensureCustodyLimit reverts UnexpectedValue when host differs", async () => {
      const source = encodeCustodyLimitBlock(123n, asset, 10n, 20n);
      await expect(helper.testEnsureCustodyLimit(source, 321n, asset, 15n))
        .to.be.revertedWithCustomError(helper, "UnexpectedValue");
    });

    it("requireAuth validates and advances by the auth block size", async () => {
      const proof = ethers.concat(["0x" + "11".repeat(20), "0x" + "22".repeat(65)]);
      const source = encodeAuthBlock(77n, 123456n, proof);
      const [deadline, outProof, i] = await helper.testRequireAuth(source, 77n);
      expect(deadline).to.equal(123456n);
      expect(outProof).to.equal(proof);
      expect(i).to.equal(165n);
    });

    it("complete reverts ZeroCursor when run is empty", async () => {
      await expect(helper.testCursorCompleteRunEmpty("0x", 1n))
        .to.be.revertedWithCustomError(helper, "ZeroCursor");
    });

    it("complete reverts IncompleteCursor when run input remains", async () => {
      const source = concat(encodeBalanceBlock(asset, 1n), encodeBalanceBlock(asset, 2n));
      await expect(helper.testCursorCompleteRunPartial(source, 1n))
        .to.be.revertedWithCustomError(helper, "IncompleteCursor");
    });

    it("complete succeeds after the run is consumed", async () => {
      const source = concat(encodeBalanceBlock(asset, 1n), encodeBalanceBlock(asset, 2n));
      expect(await helper.testCursorCompleteRunConsumed(source, 1n)).to.equal(true);
    });

    it("complete reverts IncompleteCursor when bytes remain in the cursor region", async () => {
      const source = concat(encodeBalanceBlock(asset, 1n), encodeBalanceBlock(asset, 2n));
      await expect(helper.testCursorCompletePartial(source))
        .to.be.revertedWithCustomError(helper, "IncompleteCursor");
    });

    it("complete succeeds after the full cursor region is consumed", async () => {
      const source = concat(encodeBalanceBlock(asset, 1n), encodeBalanceBlock(asset, 2n));
      expect(await helper.testCursorCompleteConsumed(source)).to.equal(true);
    });

    it("expectErc20Amount returns the token and amount from a local ERC20 amount block", async () => {
      const token = "0x00000000000000000000000000000000000000a0";
      const assetId = await utils.testToErc20Asset(token);
      const source = encodeAmountBlock(assetId, 66n);

      expect(await erc20Helper.testExpectErc20Amount(source, 0n)).to.deep.equal([token, 66n]);
    });

    it("requireErc20Amount returns the token and amount and advances by one amount block", async () => {
      const token = "0x00000000000000000000000000000000000000a0";
      const assetId = await utils.testToErc20Asset(token);
      const source = encodeAmountBlock(assetId, 66n);

      expect(await erc20Helper.testRequireErc20Amount(source)).to.deep.equal([token, 66n, 72n]);
    });

    it("expectErc20Balance returns the token and amount from a local ERC20 balance block", async () => {
      const token = "0x00000000000000000000000000000000000000a0";
      const assetId = await utils.testToErc20Asset(token);
      const source = encodeBalanceBlock(assetId, 67n);

      expect(await erc20Helper.testExpectErc20Balance(source, 0n)).to.deep.equal([token, 67n]);
    });

    it("requireErc20Balance returns the token and amount and advances by one balance block", async () => {
      const token = "0x00000000000000000000000000000000000000a0";
      const assetId = await utils.testToErc20Asset(token);
      const source = encodeBalanceBlock(assetId, 67n);

      expect(await erc20Helper.testRequireErc20Balance(source)).to.deep.equal([token, 67n, 72n]);
    });

    it("expectErc20Custody returns the token and amount from a local ERC20 custody block", async () => {
      const token = "0x00000000000000000000000000000000000000a0";
      const assetId = await utils.testToErc20Asset(token);
      const source = encodeCustodyBlock(123n, assetId, 68n);

      expect(await erc20Helper.testExpectErc20Custody(source, 0n, 123n)).to.deep.equal([token, 68n]);
    });

    it("requireErc20Custody returns the token, amount, and advances by one custody block", async () => {
      const token = "0x00000000000000000000000000000000000000a0";
      const assetId = await utils.testToErc20Asset(token);
      const source = encodeCustodyBlock(123n, assetId, 68n);

      expect(await erc20Helper.testRequireErc20Custody(source, 123n)).to.deep.equal([token, 68n, 104n]);
    });

    it("expectErc20Custody reverts UnexpectedValue when the host does not match", async () => {
      const token = "0x00000000000000000000000000000000000000a0";
      const assetId = await utils.testToErc20Asset(token);
      const source = encodeCustodyBlock(123n, assetId, 68n);

      await expect(erc20Helper.testExpectErc20Custody(source, 0n, 321n))
        .to.be.revertedWithCustomError(erc20Helper, "UnexpectedValue");
    });

    it("expectErc20Amount reverts InvalidAsset when the asset is not a local ERC20", async () => {
      const assetId = await utils.testToNativeAsset();
      const source = encodeAmountBlock(assetId, 77n);

      await expect(erc20Helper.testExpectErc20Amount(source, 0n))
        .to.be.revertedWithCustomError(erc20Helper, "InvalidAsset");
    });

    it("accepts matching 2:1 ratio between state and request runs", async () => {
      const state = concat(
        encodeBalanceBlock(asset, 1n),
        encodeBalanceBlock(asset, 2n),
      );
      const request = encodeAmountBlock(asset, 3n);

      expect(await operation.testCheckCursorRatio(state, 2n, request, 1n)).to.equal(true);
    });

    it("reverts BadRatio when state and request runs break the expected ratio", async () => {
      const state = concat(
        encodeBalanceBlock(asset, 1n),
        encodeBalanceBlock(asset, 2n),
        encodeBalanceBlock(asset, 3n),
      );
      const request = encodeAmountBlock(asset, 4n);

      await expect(operation.testCheckCursorRatio(state, 2n, request, 1n))
        .to.be.revertedWithCustomError(operation, "BadRatio");
    });
  });

});
