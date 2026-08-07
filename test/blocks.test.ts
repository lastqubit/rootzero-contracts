import { expect } from "chai";
import { ethers } from "ethers";
import { deploy } from "./helpers/setup.js";
import "./helpers/matchers.js";
import {
  Keys,
  encodeActionBlock,
  encodeAccountAmountBlock,
  encodeAllocationBlock,
  encodeAllowanceBlock,
  encodeAmountBlock,
  encodeAssetBlock,
  encodeBalanceBlock,
  encodeBytesBlock,
  encodeCallBlock,
  encodeRelayBlock,
  encodeDispatchBlock,
  encodeEvmBlock,
  encodeListBlock,
  encodeCustodyBlock,
  encodeAccountBlock,
  encodeAccountAssetBlock,
  encodeContextBlock,
  encodeRecoverBlock,
  encodeHostAccountAssetBlock,
  encodeBlock,
  encodeLabelBlock,
  encodeNodeBlock,
  encodeSchemaBlock,
  encodeStatusBlock,
  encodeStringBlock,
  encodeStepBlock,
  encodeTxBlock,
  encodeUserAccount,
  exactSpec,
  concat,
  localKey,
  pad32,
  rangedSpec,
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

    it("reads raw words from absolute calldata positions", async () => {
      const prefix = "0xaabbcc";
      const word = pad32(amount);
      const source = concat(prefix, word);

      expect(await blocksHelper.read32(source, 3)).to.equal(word);
      expect(await blocksHelper.readUint(source, 3)).to.equal(amount);
    });

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
      const data = await blocksHelper.writeBalance(offset, asset, amount);
      expect(data).to.equal(ethers.concat([new Uint8Array(Number(offset)), encodeBalanceBlock(asset, amount)]));
    });

    it("unpackBalance decodes a block from an absolute calldata position", async () => {
      expect(await blocksHelper.unpackBalance(encodeBalanceBlock(asset, amount)))
        .to.deep.equal([asset, amount]);
    });

    it("unpackBalance rejects the wrong key or payload length", async () => {
      await expect(blocksHelper.unpackBalance(encodeAmountBlock(asset, amount)))
        .to.be.revertedWithCustomError(blocksHelper, "InvalidBlock");
      await expect(blocksHelper.unpackBalance(encodeBlock(Keys.Balance, asset)))
        .to.be.revertedWithCustomError(blocksHelper, "InvalidBlock");
    });

    it("decodes every fixed-width block through its semantic helper", async () => {
      const account = encodeUserAccount("0x03");
      const other = encodeUserAccount("0x04");
      const host = 1234n;

      expect(await blocksHelper.unpackAccount(encodeAccountBlock(account))).to.equal(account);
      expect(await blocksHelper.unpackAsset(encodeAssetBlock(asset))).to.equal(asset);
      expect(await blocksHelper.unpackNode(encodeNodeBlock(host))).to.equal(host);
      expect(await blocksHelper.unpackStatus(encodeStatusBlock(7n))).to.equal(7n);

      expect(await blocksHelper.unpackAmount(encodeAmountBlock(asset, amount))).to.deep.equal([asset, amount]);
      expect(await blocksHelper.unpackBalance(encodeBalanceBlock(asset, amount))).to.deep.equal([asset, amount]);
      expect(await blocksHelper.unpackAccountAsset(encodeAccountAssetBlock(account, asset)))
        .to.deep.equal([account, asset]);

      expect(await blocksHelper.unpackAllocation(encodeAllocationBlock(host, asset, amount)))
        .to.deep.equal([host, asset, amount]);
      expect(await blocksHelper.unpackAllowance(encodeAllowanceBlock(host, asset, amount)))
        .to.deep.equal([host, asset, amount]);
      expect(await blocksHelper.unpackCustody(encodeCustodyBlock(host, asset, amount)))
        .to.deep.equal([host, asset, amount]);
      expect(await blocksHelper.unpackAccountAmount(encodeAccountAmountBlock(account, asset, amount)))
        .to.deep.equal([account, asset, amount]);
      expect(await blocksHelper.unpackHostAmount(
        encodeBlock(Keys.HostAmount, concat(pad32(host), pad32(asset), pad32(amount)))
      )).to.deep.equal([host, asset, amount]);
      expect(await blocksHelper.unpackHostAccountAsset(encodeHostAccountAssetBlock(host, account, asset)))
        .to.deep.equal([host, account, asset]);

      expect(await blocksHelper.unpackTransaction(encodeTxBlock(account, other, asset, amount)))
        .to.deep.equal([account, other, asset, amount]);
      expect(await blocksHelper.unpackHostAccountAmount(
        encodeBlock(Keys.HostAccountAmount, concat(pad32(host), pad32(account), pad32(asset), pad32(amount)))
      )).to.deep.equal([host, account, asset, amount]);
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
      const data = await blocksHelper.writeTransaction(offset, from_, to_, asset, amount);
      expect(data).to.equal(ethers.concat([new Uint8Array(Number(offset)), encodeTxBlock(from_, to_, asset, amount)]));
    });

    it("writes every dynamic block at the requested offset", async () => {
      const offset = 5n;
      const raw = "0x0102030405";
      const cmd = 7n;
      const target = 7n;
      const resources = 11n;
      const account = encodeUserAccount("0x03");
      const state = encodeAssetBlock(asset);
      const input = "0xaabbcc";
      const namespace = pad32("0x99");
      const recoveryKey = pad32("0x77");
      const spec = exactSpec(Keys.Asset, 32);
      const name = pad32("0x55");
      const expected = (block: string) =>
        ethers.concat([new Uint8Array(Number(offset)), block]);

      expect(await blocksHelper.writeList(offset, raw))
        .to.equal(expected(encodeListBlock(raw)));
      expect(await blocksHelper.writeEvm(offset, raw))
        .to.equal(expected(encodeEvmBlock(raw)));
      expect(await blocksHelper.writeBytes(offset, raw))
        .to.equal(expected(encodeBytesBlock(raw)));
      expect(await blocksHelper.writeString(offset, "rootzero"))
        .to.equal(expected(encodeStringBlock("rootzero")));
      expect(await blocksHelper.writeStep(offset, cmd, resources, input))
        .to.equal(expected(encodeStepBlock(cmd, resources, input)));
      expect(await blocksHelper.writeCall(offset, target, resources, raw))
        .to.equal(expected(encodeCallBlock(target, resources, raw)));
      expect(await blocksHelper.writeRelay(offset, target, resources, input))
        .to.equal(expected(encodeRelayBlock(target, resources, input)));
      expect(await blocksHelper.writeDispatch(offset, target, resources, raw))
        .to.equal(expected(encodeDispatchBlock(target, resources, raw)));
      expect(await blocksHelper.writeContext(offset, account, state, input))
        .to.equal(expected(encodeContextBlock(account, state, input)));
      expect(await blocksHelper.writeRecover(offset, target, resources, recoveryKey, raw))
        .to.equal(expected(encodeRecoverBlock(target, resources, recoveryKey, raw)));
      expect(await blocksHelper.writeLabel(offset, namespace, "rootzero"))
        .to.equal(expected(encodeLabelBlock(namespace, "rootzero")));
      expect(await blocksHelper.writeSchema(offset, spec, "bytes32 asset", name))
        .to.equal(expected(encodeSchemaBlock(spec, "bytes32 asset", name)));
    });

    it("unpacks dynamic leaf blocks using their absolute end positions", async () => {
      const raw = "0x0102030405";
      const text = "rootzero";
      const stringdata = ethers.hexlify(ethers.toUtf8Bytes(text));
      const list = encodeListBlock(raw);
      const evm = encodeEvmBlock(raw);
      const data = encodeBytesBlock(raw);
      const string = encodeStringBlock(text);

      expect(await blocksHelper.unpackList(list))
        .to.deep.equal([raw, BigInt(ethers.getBytes(list).length)]);
      expect(await blocksHelper.unpackEvm(evm))
        .to.deep.equal([raw, BigInt(ethers.getBytes(evm).length)]);
      expect(await blocksHelper.unpackBytes(data))
        .to.deep.equal([raw, BigInt(ethers.getBytes(data).length)]);
      expect(await blocksHelper.unpackString(string))
        .to.deep.equal([stringdata, BigInt(ethers.getBytes(string).length)]);
    });

    it("rejects the wrong dynamic leaf key", async () => {
      await expect(blocksHelper.unpackBytes(encodeStringBlock("rootzero")))
        .to.be.revertedWithCustomError(blocksHelper, "InvalidBlock");
    });

    it("expects a spec at an absolute calldata position", async () => {
      const raw = "0x0102030405";
      const block = encodeBytesBlock(raw);
      const spec = exactSpec(Keys.Bytes, ethers.getBytes(raw).length);

      expect(await blocksHelper.headerAbsolute(block))
        .to.deep.equal([Keys.Bytes, BigInt(ethers.getBytes(raw).length)]);
      expect(await blocksHelper["headerAbsolute(bytes,bytes4)"](block, Keys.Bytes))
        .to.equal(BigInt(ethers.getBytes(raw).length));
      expect(await blocksHelper.expectAbsolute(block, spec))
        .to.deep.equal([8n, BigInt(ethers.getBytes(block).length)]);
    });

    it("rejects absolute blocks outside the expected spec shape", async () => {
      const raw = "0x0102030405";
      const block = encodeBytesBlock(raw);

      await expect(blocksHelper.expectAbsolute(block, exactSpec(Keys.String, 5)))
        .to.be.revertedWithCustomError(blocksHelper, "InvalidBlock");
      await expect(blocksHelper.expectAbsolute(block, exactSpec(Keys.Bytes, 4)))
        .to.be.revertedWithCustomError(blocksHelper, "InvalidBlock");
      await expect(blocksHelper["headerAbsolute(bytes,bytes4)"](block, Keys.String))
        .to.be.revertedWithCustomError(blocksHelper, "InvalidBlock");
    });

    it("stores the transaction header at the start of its word-aligned spec", async () => {
      const spec: string = await blocksHelper.transactionSpec();
      expect(spec.slice(0, 18)).to.equal(encodeTxBlock(ethers.ZeroHash, ethers.ZeroHash, ethers.ZeroHash, 0n).slice(0, 18));
    });

    it("derives fixed bounds and stores dynamic bounds in specs", async () => {
      expect(await blocksHelper.specRanges()).to.deep.equal([128n, 128n, 72n, 0n]);
    });

    it("stores allocation hints in three bytes", async () => {
      expect(await blocksHelper.specHint(0xffffff)).to.equal(0xffffffn);
      await expect(blocksHelper.specHint(0x1000000))
        .to.be.revertedWithCustomError(blocksHelper, "ValueOverflow");
    });

    it("label factory matches the canonical LABEL encoding", async () => {
      const namespace = pad32("0x1234");
      expect(await helper.testToLabelBlock(namespace, "rootzero"))
        .to.equal(encodeLabelBlock(namespace, "rootzero"));
    });

    it("action factory matches the canonical ACTION encoding", async () => {
      expect(await helper.testToActionBlock(4n)).to.equal(encodeActionBlock(4n));
    });

    it("publishes an action annotation", async () => {
      await expect(blocksHelper.publishAction(123n, 4n))
        .to.emit(blocksHelper, "Annotation")
        .withArgs(123n, encodeActionBlock(4n));
    });

    it("schema factory matches the canonical SCHEMA encoding", async () => {
      const spec = exactSpec(Keys.Asset, 32);
      const name = pad32("0x55");
      expect(await helper.testToSchemaBlock(spec, "bytes32 asset", name))
        .to.equal(encodeSchemaBlock(spec, "bytes32 asset", name));
    });

    it("creates exact specs from a numeric key and size", async () => {
      const key = 1n;
      const size = 64n;
      const spec = (key << 224n) | (size << 192n) | (size << 160n) | (size << 136n);
      expect(await blocksHelper.exactSpec(key, size)).to.equal(spec);
    });

    it("derives initial byte capacity from spec groups and hints", async () => {
      expect(await blocksHelper.groupedCapacity()).to.equal(6n * 72n);
    });

    it("derives fixed, growable, and transaction allocations from descriptor lanes", async () => {
      const balance = exactSpec(Keys.Balance, 64);
      const bytes = rangedSpec(Keys.Bytes, 0, 0, 128);

      expect(await blocksHelper.descriptorAllocation(balance, 0, 3, 3))
        .to.deep.equal([3n * 72n, false]);
      expect(await blocksHelper.descriptorAllocation(bytes, 0, 3, 2))
        .to.deep.equal([2n * 136n, true]);
      expect(await blocksHelper.descriptorAllocation(0, 2, 4, 3))
        .to.deep.equal([6n * 136n, false]);
      await expect(blocksHelper.descriptorAllocation(balance, 0, 1, 1))
        .to.be.revertedWithCustomError(blocksHelper, "InvalidLane");
    });

    it("derives a grouped container descriptor lane from a spec", async () => {
      expect(await blocksHelper.listAssetDescriptor()).to.deep.equal([Keys.List, Keys.Asset, 3n]);
    });

    it("retains the complete output writer spec in its descriptor lane", async () => {
      expect(await blocksHelper.balanceOutputDescriptor())
        .to.equal(exactSpec(Keys.Balance, 64) | (1n << 128n));
      expect(await blocksHelper.groupedBalanceOutputDescriptor())
        .to.deep.equal([exactSpec(Keys.Balance, 64) | (3n << 128n), 3n]);
    });

    it("rejects containers on state and output descriptor lanes", async () => {
      await expect(blocksHelper.rejectLaneContainer(false))
        .to.be.revertedWithCustomError(blocksHelper, "InvalidContainer");
      await expect(blocksHelper.rejectLaneContainer(true))
        .to.be.revertedWithCustomError(blocksHelper, "InvalidContainer");
    });

    it("packs and checks composable descriptor flags", async () => {
      expect(await blocksHelper.descriptorFlags()).to.deep.equal([true, true]);
    });

    it("stores the transactions per batch alongside the output spec", async () => {
      expect(await blocksHelper.descriptorTransactions()).to.equal(3n);
    });

    it("returns the effective key for every descriptor lane", async () => {
      expect(await blocksHelper.descriptorKey(1)).to.equal(Keys.List);
      expect(await blocksHelper.descriptorKey(2)).to.equal(Keys.Balance);
      expect(await blocksHelper.descriptorKey(3)).to.equal(Keys.Amount);
      expect(await blocksHelper.descriptorKey(4)).to.equal(Keys.Transaction);
      await expect(blocksHelper.descriptorKey(0))
        .to.be.revertedWithCustomError(blocksHelper, "InvalidLane");
    });

    it("reserves grouped transaction capacity plus one refund slot", async () => {
      const transactions = await blocksHelper.executionTransactions(2, 3, 7);
      expect(ethers.getBytes(transactions).length).to.equal(7 * 136);
      await expect(blocksHelper.executionTransactions(2, 3, 8))
        .to.be.revertedWithCustomError(blocksHelper, "OutOfBounds");
    });

    it("omits the transaction writer when its declared count is zero", async () => {
      expect(await blocksHelper.executionTransactions(0, 3, 0)).to.equal("0x");
      await expect(blocksHelper.executionTransactions(0, 3, 1))
        .to.be.revertedWithCustomError(blocksHelper, "MissingCursor");
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

    it("lazily allocates a buffer while preserving cursor metadata", async () => {
      expect(await blocksHelper.reserveBuffer(33, 7, true, 9, 2, 32))
        .to.deep.equal([0n, 2n, 33n, 7n, 1n, 9n, 96n]);
    });

    it("uses touch for capacity and advance for the logical position", async () => {
      expect(await blocksHelper.reserveBuffer(16, 1, true, 0, 2, 32))
        .to.deep.equal([0n, 2n, 32n, 1n, 1n, 0n, 64n]);
    });

    it("grows an allocated buffer and preserves its written prefix", async () => {
      const first = ethers.zeroPadValue("0x11", 32);
      const second = ethers.zeroPadValue("0x22", 32);
      expect(await blocksHelper.growBuffer(first, second))
        .to.equal(concat(first, second));
    });

    it("rejects growth when the buffer cursor is fixed", async () => {
      await expect(blocksHelper.reserveBuffer(8, 1, false, 0, 16, 16))
        .to.be.revertedWithCustomError(blocksHelper, "OutOfBounds");
    });

    it("opens, spends, drains, and detaches standalone value budgets", async () => {
      const resources = (123n << 128n) | 3n;
      expect(await blocksHelper.budgetUse.staticCall(resources, { value: 5n }))
        .to.deep.equal([3n, 2n]);
      expect(await blocksHelper.budgetDrain.staticCall({ value: 5n }))
        .to.deep.equal([5n, 0n]);
      expect(await blocksHelper.takeBudget.staticCall({ value: 5n }))
        .to.deep.equal([0n, 5n]);
      await expect(blocksHelper.budgetUse.staticCall(6n, { value: 5n }))
        .to.be.revertedWithCustomError(blocksHelper, "InsufficientValue");
    });

    it("reverts when appending past logical writer capacity", async () => {
      await expect(blocksHelper.rejectSecond32(asset))
        .to.be.revertedWithCustomError(blocksHelper, "OutOfBounds");
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
      const taggedInput = input | (1n << 120n);
      const stateTag = 2n << 120n;
      const updatedState = 7n | (4n << 32n) | (20n << 64n) | stateTag;

      const [selected, restored] = await helper.testCursorLanes(input, state, 7n);

      expect(selected & ((1n << 128n) - 1n)).to.equal(updatedState);
      expect(selected >> 128n).to.equal(taggedInput);
      expect(restored & ((1n << 128n) - 1n)).to.equal(taggedInput);
      expect(restored >> 128n).to.equal(updatedState);
    });

    it("selects creator-defined cursor tags", async () => {
      const lower = 11n;
      const higher = 22n;
      const selected = await helper.testSelectTag(lower, 7, higher, 42, 42);

      expect(selected & ((1n << 128n) - 1n)).to.equal((higher << 64n) | (42n << 120n));
      expect(selected >> 128n).to.equal((lower << 64n) | (7n << 120n));
    });

    it("treats a zero cursor as absent when pairing", async () => {
      const cur = 10n << 64n;

      expect(await helper.testPair(0, 0)).to.equal(0n);
      expect(await helper.testPair(cur, 0)).to.equal(cur);
      expect(await helper.testPair(0, cur)).to.equal(cur);
      await expect(helper.testPair(0, 1)).to.be.revertedWithCustomError(helper, "OutOfBounds");
    });

    it("finds only nonzero cursor tags", async () => {
      const cur = (10n << 64n) | (7n << 120n);

      expect(await helper.testContains(cur, 7)).to.be.true;
      expect(await helper.testContains(cur, 0)).to.be.false;
      expect(await helper.testContains(0, 0)).to.be.false;
    });

    it("packs groups, consumer flags, and tag into cursor metadata", async () => {
      const [cur, groups, flags, tag] = await helper.testSpanMeta(0x1234, 0x56, 0x78);

      expect(cur).to.equal((0x1234n << 96n) | (0x56n << 112n) | (0x78n << 120n));
      expect(groups).to.equal(0x1234n);
      expect(flags).to.equal(0x56n);
      expect(tag).to.equal(0x78n);
    });

    it("returns the active cursor frame without its position or paired cursor", async () => {
      const frame = (10n << 32n) | (20n << 64n) | (3n << 96n) | (4n << 112n) | (1n << 120n);
      expect(await helper.testFrame()).to.equal(frame);
    });

    it("matches an upper cursor by frame and reports whether it is before a mark", async () => {
      const [matched, pending] = await helper.testMarkBefore(8n, 12n, false);
      expect(matched & 0xffffffffn).to.equal(8n);
      expect((matched >> 120n) & 0xffn).to.equal(2n);
      expect(pending).to.be.true;
    });

    it("ignores the upper 128 bits of a mark and returns false exactly at it", async () => {
      const [, pending] = await helper.testMarkBefore(12n, 12n, true);
      expect(pending).to.be.false;
    });

    it("reverts after a mark or when no cursor frame matches it", async () => {
      await expect(helper.testMarkBefore(13n, 12n, false))
        .to.be.revertedWithCustomError(helper, "OutOfBounds");
      await expect(helper.testMissingMark())
        .to.be.revertedWithCustomError(helper, "MissingCursor");
    });

    it("locates an empty cursor and treats its zero mark as reached", async () => {
      const cur = (10n << 64n) | (1n << 120n);
      expect(await helper.testZeroMark(0)).to.equal(0n);
      expect(await helper.testZeroMark(cur)).to.equal(cur << 128n);
      expect(await helper.testZeroBefore(0)).to.be.false;
      expect(await helper.testZeroBefore(cur)).to.be.false;
    });

    it("detects whether both packed cursors remain at their initial positions", async () => {
      const metadata = (10n << 64n) | ((20n << 64n) << 128n);

      expect(await helper.testSpanInitial(metadata)).to.be.true;
      expect(await helper.testSpanInitial(metadata | 1n)).to.be.false;
      expect(await helper.testSpanInitial(metadata | (1n << 128n))).to.be.false;
    });

    it("advances packed cursors while returning the pre-advance absolute position", async () => {
      expect(await helper.testCursorNavigation(100n, 10n, 3n, 4n))
        .to.deep.equal([7n, 103n, true]);
      expect(await helper.testCursorNavigation(100n, 10n, 3n, 7n))
        .to.deep.equal([10n, 103n, false]);
      await expect(helper.testCursorNavigation(100n, 10n, 3n, 8n))
        .to.be.revertedWithCustomError(helper, "OutOfBounds");
    });

    it("allows cursor capacity to shrink to its position but not below it", async () => {
      expect(await helper.testCursorResize(10n, 6n, 6n)).to.deep.equal([6n, 6n]);
      expect(await helper.testCursorResize(10n, 6n, 20n)).to.deep.equal([6n, 20n]);
      await expect(helper.testCursorResize(10n, 6n, 5n))
        .to.be.revertedWithCustomError(helper, "OutOfBounds");
    });

    it("reports remaining data across either cursor lane", async () => {
      expect(await helper.testCursorAny(10n, 10n, 20n, 19n)).to.be.true;
      expect(await helper.testCursorAny(10n, 10n, 20n, 20n)).to.be.false;
    });

    it("reconciles optional cursor group counts with an expected batch count", async () => {
      expect(await helper.testReconcile(2n, 2n, 0n)).to.equal(2n);
      expect(await helper.testReconcile(0n, 3n, 3n)).to.equal(3n);
      expect(await helper.testReconcile(0n, 0n, 4n)).to.equal(4n);
      await expect(helper.testReconcile(2n, 3n, 0n))
        .to.be.revertedWithCustomError(helper, "BadRatio");
      await expect(helper.testReconcile(2n, 2n, 3n))
        .to.be.revertedWithCustomError(helper, "BadRatio");
    });

    it("selects and consumes a tagged cursor without losing the other lane", async () => {
      const [updated, abs] = await helper.testConsumeTag(10n, 8n, 100n, 12n, 2, 5n);
      const laneMask = (1n << 128n) - 1n;
      const selected = updated & laneMask;
      const other = updated >> 128n;

      expect(abs).to.equal(100n);
      expect(selected & 0xffffffffn).to.equal(5n);
      expect((selected >> 32n) & 0xffffffffn).to.equal(100n);
      expect((selected >> 120n) & 0xffn).to.equal(2n);
      expect((other >> 32n) & 0xffffffffn).to.equal(10n);
      expect((other >> 120n) & 0xffn).to.equal(1n);
    });

    it("reverts MissingCursor when a cursor pair does not contain the requested tag", async () => {
      await expect(helper.testSelectTag(11n, 7, 22n, 42, 9))
        .to.be.revertedWithCustomError(helper, "MissingCursor");
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

    it("wrap(source, i) creates a cursor over the source tail", async () => {
      const a = encodeAmountBlock(asset, 1n);
      const b = encodeBalanceBlock(asset, 2n);
      const source = concat(a, b);
      const i = BigInt(ethers.getBytes(a).length);
      const [offset, cursorI, len] = await helper.testWrapAt(source, i);
      expect(offset).to.equal(i);
      expect(cursorI).to.equal(0n);
      expect(len).to.equal(BigInt(ethers.getBytes(b).length));
    });

    it("open(source, stride) creates a cursor over the matching first run", async () => {
      const a = encodeAmountBlock(asset, 1n);
      const b = encodeAmountBlock(asset, 2n);
      const c = encodeBalanceBlock(asset, 3n);
      const source = concat(a, b, c);
      const run = concat(a, b);
      const [offset, cursorI, len, groups] = await helper.testOpen(source, 1n);
      expect(offset).to.equal(0n);
      expect(cursorI).to.equal(0n);
      expect(len).to.equal(BigInt(ethers.getBytes(run).length));
      expect(groups).to.equal(2n);
    });

    it("open(source, 0) returns an empty cursor for an empty source", async () => {
      const [offset, cursorI, len, groups] = await helper.testOpen("0x", 0n);
      expect(offset).to.equal(0n);
      expect(cursorI).to.equal(0n);
      expect(len).to.equal(0n);
      expect(groups).to.equal(0n);
    });

    it("open(source, 0) reverts ZeroStride for a non-empty source", async () => {
      await expect(helper.testOpen(encodeAmountBlock(asset, amount), 0n))
        .to.be.revertedWithCustomError(helper, "ZeroStride");
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

    it("seek moves the cursor to the provided end offset", async () => {
      const source = concat(encodeAssetBlock(asset), encodeAssetBlock(otherAsset));
      expect(await helper.testSeek(source, BigInt(ethers.getBytes(source).length))).to.equal(BigInt(ethers.getBytes(source).length));
    });

    it("seek reverts OutOfBounds when moving the cursor backwards", async () => {
      const source = concat(encodeAssetBlock(asset), encodeAssetBlock(otherAsset));
      const end = BigInt(ethers.getBytes(source).length - ethers.getBytes(encodeAssetBlock(otherAsset)).length);
      await expect(helper.testSeekBackward(source, end))
        .to.be.revertedWithCustomError(helper, "OutOfBounds");
    });

    it("expect succeeds when the cursor is exactly at the requested position", async () => {
      const source = concat(encodeAssetBlock(asset), encodeAssetBlock(otherAsset));
      const pos = BigInt(ethers.getBytes(source).length);
      expect(await helper.testExpectPosition(source, pos)).to.equal(pos);
    });

    it("expect reverts UnexpectedPosition when the cursor is not exactly at the requested position", async () => {
      const source = concat(encodeAssetBlock(asset), encodeAssetBlock(otherAsset));
      const pos = BigInt(ethers.getBytes(encodeAssetBlock(asset)).length);
      await expect(helper.testExpectPositionMismatch(source, pos))
        .to.be.revertedWithCustomError(helper, "UnexpectedPosition");
    });

    it("expectAbs succeeds at the cursor's absolute position", async () => {
      const source = concat(encodeAssetBlock(asset), encodeAssetBlock(otherAsset));
      expect(await helper.testExpectAbsolute(source, 1n)).to.be.greaterThan(1n);
    });

    it("expectAbs reverts UnexpectedPosition for a different absolute position", async () => {
      const source = encodeAssetBlock(asset);
      await expect(helper.testExpectAbsoluteMismatch(source))
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

    it("unpackStep consumes the block and returns the trailing input", async () => {
      const req = encodeAmountBlock(asset, amount);
      const step = encodeStepBlock(7n, 55n, req);
      const [cmd, value, outReq, i] = await helper.testUnpackStep(step);
      expect(cmd).to.equal(7n);
      expect(value).to.equal(55n);
      expect(outReq).to.equal(req);
      expect(i).to.equal(BigInt(ethers.getBytes(step).length));
    });

    it("unpackContext consumes account, state, and input bytes", async () => {
      const account = encodeUserAccount("0x12");
      const state = encodeBalanceBlock(asset, amount);
      const input = encodeAmountBlock(asset, 7n);
      const context = encodeContextBlock(account, state, input);
      const [outAccount, outState, outInput, i] = await helper.testUnpackContext(context);
      expect(outAccount).to.equal(account);
      expect(outState).to.equal(state);
      expect(outInput).to.equal(input);
      expect(i).to.equal(BigInt(ethers.getBytes(context).length));
    });

    it("unpackRecover consumes handler, resources, key, and witness bytes", async () => {
      const handler = 42n;
      const key = ethers.zeroPadValue("0x1234", 32);
      const account = encodeUserAccount("0x12");
      const state = encodeBalanceBlock(asset, amount);
      const input = encodeAmountBlock(asset, 7n);
      const witness = encodeContextBlock(account, state, input);
      const resources = 55n;
      const recovery = encodeRecoverBlock(handler, resources, key, witness);
      const [outHandler, outResources, outKey, outWitness, i] = await helper.testUnpackRecover(recovery);
      expect(outHandler).to.equal(handler);
      expect(outResources).to.equal(resources);
      expect(outKey).to.equal(key);
      expect(outWitness).to.equal(witness);
      expect(i).to.equal(BigInt(ethers.getBytes(recovery).length));
    });

    it("unpackRelay consumes portal, resources, and input bytes", async () => {
      const portal: bigint = await utils.testLocalChainId();
      const input = encodeStepBlock(0n, 0n, encodeAmountBlock(asset, 7n));
      const relay = encodeRelayBlock(portal, 55n, input);
      const [outPortal, resources, outInput, i] = await helper.testUnpackRelay(relay);
      expect(outPortal).to.equal(portal);
      expect(resources).to.equal(55n);
      expect(outInput).to.equal(input);
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
      const namespace = ethers.encodeBytes32String("peer");
      const name = "portDispatchPayable";
      const source = encodeLabelBlock(namespace, name);
      const [outNamespace, outName, i] = await stringHelper.testUnpackLabel(source);
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

    it("unpackAccount returns the account word", async () => {
      const account = encodeUserAccount("0x12");
      const source = encodeAccountBlock(account);
      expect(await helper.testUnpackAccount(source)).to.equal(account);
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

    it("accepts matching 2:1 ratio between state and input runs", async () => {
      const state = concat(
        encodeBalanceBlock(asset, 1n),
        encodeBalanceBlock(asset, 2n),
      );
      const input = encodeAmountBlock(asset, 3n);

      expect(await operation.testCheckCursorRatio(state, 2n, input, 1n)).to.equal(true);
    });

    it("reverts BadRatio when state and input runs break the expected ratio", async () => {
      const state = concat(
        encodeBalanceBlock(asset, 1n),
        encodeBalanceBlock(asset, 2n),
        encodeBalanceBlock(asset, 3n),
      );
      const input = encodeAmountBlock(asset, 4n);

      await expect(operation.testCheckCursorRatio(state, 2n, input, 1n))
        .to.be.revertedWithCustomError(operation, "BadRatio");
    });
  });

});
