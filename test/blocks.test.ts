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
  encodePositionBlock,
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
  encodeHostAssetBlock,
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
      expect(await blocksHelper.read32AsUint(source, 3)).to.equal(amount);
    });

    it("writeBalanceBlock round-trips", async () => {
      const data: string = await helper.testWriteBalanceBlock(asset, amount);
      expect(ethers.getBytes(data).length).to.equal(72);
      expect(data.slice(0, 10)).to.equal(Keys.Balance);
      expect(data.slice(10, 18)).to.equal("00000040");
      expect(await helper.testUnpackBalance(data)).to.deep.equal([asset, amount]);
    });

    it("encodes empty blocks through factories, writers, and executions", async () => {
      const expected = encodeBlock(Keys.Balance, "0x");
      expect(await helper.testToEmptyBlock(Keys.Balance)).to.equal(expected);
      expect(await helper.testWriteEmptyBlock(Keys.Balance)).to.equal(expected);
      expect(await blocksHelper.executionOutputEmpty(Keys.Balance)).to.equal(expected);
    });

    it("position block round-trips through writers and decoders", async () => {
      const liability = ethers.zeroPadValue("0x02", 32);
      const positionAmount = 500n;
      const debt = 300n;
      const expected = encodePositionBlock(asset, positionAmount, liability, debt);

      expect(ethers.getBytes(expected).length).to.equal(136);
      expect(expected.slice(0, 10)).to.equal(Keys.Position);
      expect(expected.slice(10, 18)).to.equal("00000080");
      expect(await helper.testWritePositionBlock(asset, positionAmount, liability, debt)).to.equal(expected);
      expect(await helper.testWritePositionStructBlock(asset, positionAmount, liability, debt)).to.equal(expected);
      expect(await helper.testToPositionBlock(asset, positionAmount, liability, debt)).to.equal(expected);
      expect(await blocksHelper.writePosition(5n, asset, positionAmount, liability, debt)).to.equal(
        ethers.concat([new Uint8Array(5), expected]),
      );
      expect(await blocksHelper.executionOutputPosition(asset, positionAmount, liability, debt)).to.equal(expected);
      expect(await blocksHelper.executionUnpackPosition(expected)).to.deep.equal([
        asset, positionAmount, liability, debt,
      ]);
      expect(await helper.testUnpackPosition(expected)).to.deep.equal([asset, positionAmount, liability, debt]);
      expect(await helper.testUnpackPositionValue(expected)).to.deep.equal([asset, positionAmount, liability, debt]);
      expect(await helper.testReaderUnpackPosition(expected)).to.deep.equal([
        asset, positionAmount, liability, debt, 136n, true,
      ]);
    });

    it("position decoder rejects another four-word block", async () => {
      const account = encodeUserAccount("0x03");
      const other = encodeUserAccount("0x04");
      await expect(blocksHelper.unpackPosition(encodeTxBlock(account, other, asset, amount)))
        .to.be.revertedWithCustomError(blocksHelper, "InvalidBlock");
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

    it("hostAsset block round-trips", async () => {
      const host = 1234n;
      const data = encodeHostAssetBlock(host, asset);
      expect(ethers.getBytes(data).length).to.equal(72);
      expect(data.slice(0, 10)).to.equal(Keys.HostAsset);
      expect(await helper.testUnpackHostAsset(data)).to.deep.equal([host, asset]);
      expect(await blocksHelper.unpackHostAsset(data)).to.deep.equal([host, asset]);
      expect(await blocksHelper.writeHostAsset(3n, host, asset)).to.equal(
        ethers.concat([new Uint8Array(3), data]),
      );
      expect(await blocksHelper.appendHostAsset(host, asset)).to.equal(data);
      expect(await blocksHelper.executionOutputHostAsset(host, asset)).to.equal(data);
      expect(await helper.testReaderUnpackHostAsset(data)).to.deep.equal([host, asset, 72n, true]);
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
      expect(await blocksHelper.unpackHostAsset(encodeHostAssetBlock(host, asset)))
        .to.deep.equal([host, asset]);

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

      expect(await blocksHelper.unpackPosition(encodePositionBlock(asset, amount, other, 99n)))
        .to.deep.equal([asset, amount, other, 99n]);
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
      expect(await helper["testToSchemaBlock(uint256,string,bytes32)"](spec, "bytes32 asset", name))
        .to.equal(encodeSchemaBlock(spec, "bytes32 asset", name));
      expect(await helper["testToSchemaBlock(uint256,string)"](spec, "bytes32 asset"))
        .to.equal(encodeSchemaBlock(spec, "bytes32 asset", ethers.ZeroHash));
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

    it("retains the complete output writer spec in its descriptor lane", async () => {
      expect(await blocksHelper.balanceOutputDescriptor())
        .to.equal(exactSpec(Keys.Balance, 64) | (1n << 128n));
      expect(await blocksHelper.groupedBalanceOutputDescriptor())
        .to.deep.equal([exactSpec(Keys.Balance, 64) | (3n << 128n), 3n]);
    });

    it("packs and checks composable descriptor flags", async () => {
      expect(await blocksHelper.descriptorFlags()).to.deep.equal([true, true]);
    });

    it("stores the transactions per batch alongside the output spec", async () => {
      expect(await blocksHelper.descriptorTransactions()).to.equal(3n);
    });

    it("returns the effective key for every descriptor lane", async () => {
      expect(await blocksHelper.descriptorKey(1)).to.equal(Keys.Asset);
      expect(await blocksHelper.descriptorKey(2)).to.equal(Keys.Balance);
      expect(await blocksHelper.descriptorKey(3)).to.equal(Keys.Amount);
      expect(await blocksHelper.descriptorKey(4)).to.equal(Keys.Transaction);
      await expect(blocksHelper.descriptorKey(0))
        .to.be.revertedWithCustomError(blocksHelper, "InvalidLane");
    });

    it("enters a parent on one execution lane and preserves the paired lane", async () => {
      const stateAsset = ethers.zeroPadValue("0x31", 32);
      const inputAsset = ethers.zeroPadValue("0x32", 32);
      const state = encodeBalanceBlock(stateAsset, 41n);
      const input = encodeListBlock(encodeAmountBlock(inputAsset, 42n));

      expect(await blocksHelper.executionEnterAmount(state, input))
        .to.deep.equal([stateAsset, 41n, inputAsset, 42n]);
    });

    it("next32 consumes raw words from an entered execution parent", async () => {
      const first = ethers.zeroPadValue("0x41", 32);
      const second = ethers.zeroPadValue("0x42", 32);
      const input = encodeListBlock(first, second);

      expect(await blocksHelper.executionEnterWords(input)).to.deep.equal([first, second]);
    });

    it("consumes power-of-two byte widths from an entered execution parent", async () => {
      const fields = [
        "0x01",
        "0x0203",
        "0x04050607",
        "0x08090a0b0c0d0e0f",
        "0x101112131415161718191a1b1c1d1e1f",
        "0x202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f",
      ];
      const input = encodeListBlock(...fields);

      expect(await blocksHelper.executionEnterSized(input)).to.deep.equal(fields);
    });

    it("copies calldata payloads through factories, writers, and executions", async () => {
      for (const value of ["0x", "0x123456"]) {
        const expected = concat(
          encodeBlock(localKey(1), value),
          encodeListBlock(value),
          encodeEvmBlock(value),
          encodeBytesBlock(value),
          encodeStepBlock(1n, 2n, value),
          encodeCallBlock(3n, 4n, value),
          encodeRelayBlock(5n, 6n, value),
          encodeDispatchBlock(7n, 8n, value),
          encodeContextBlock(ethers.zeroPadValue("0x09", 32), value, value),
          encodeRecoverBlock(10n, 11n, ethers.zeroPadValue("0x0c", 32), value),
        );

        expect(await blocksHelper.factoryCopies(value)).to.equal(expected);
        expect(await blocksHelper.writerCopies(value)).to.equal(expected);
        expect(await blocksHelper.executionCopies(value)).to.equal(expected);
      }
    });

    it("copies raw calldata into buffers and writers", async () => {
      for (const value of ["0x", "0x123456"]) {
        expect(await blocksHelper.writerCopy(value)).to.equal(concat("0xaa", value, "0xbb"));
      }

      expect(await blocksHelper.bufferCopy(7, 2, "0x123456"))
        .to.deep.equal(["0x00001234560000", 5n]);
      await expect(blocksHelper.bufferCopy(4, 2, "0x123456"))
        .to.be.revertedWithCustomError(blocksHelper, "BufferOverflow");
    });

    it("copies calldata strings through factories, writers, and executions", async () => {
      for (const value of ["", "rootzero ⚡"]) {
        const expected = encodeStringBlock(value);
        expect(await blocksHelper.stringCopies(value)).to.deep.equal([expected, expected, expected]);
      }
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
      const label = "relayBalancePayable";
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
      expect(await blocksHelper.budgetUseResourceValue.staticCall(resources, { value: 5n }))
        .to.deep.equal([3n, 2n]);
      expect(await blocksHelper.budgetUseValue.staticCall(3n, { value: 5n }))
        .to.deep.equal([3n, 2n]);
      expect(await blocksHelper.budgetDrain.staticCall({ value: 5n }))
        .to.deep.equal([5n, 0n]);
      expect(await blocksHelper.takeBudget.staticCall({ value: 5n }))
        .to.deep.equal([0n, 5n]);
      await expect(blocksHelper.budgetUseResourceValue.staticCall(6n, { value: 5n }))
        .to.be.revertedWithCustomError(blocksHelper, "InsufficientValue");
      await expect(blocksHelper.budgetUseValue.staticCall(1n << 128n))
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

    it("detects and conditionally consumes empty blocks", async () => {
      const empty = encodeBlock(Keys.Balance, "0x");
      const balance = encodeBalanceBlock(asset, 123n);
      expect(await helper.testReaderIsEmpty(empty, Keys.Balance)).to.equal(true);
      expect(await helper.testReaderIsEmpty(empty, Keys.Amount)).to.equal(false);
      expect(await helper.testReaderIsEmpty(balance, Keys.Balance)).to.equal(false);
      expect(await helper.testReaderTryConsumeEmpty(empty, Keys.Balance)).to.deep.equal([true, 8n, true]);
      expect(await helper.testReaderTryConsumeEmpty(empty, Keys.Amount)).to.deep.equal([false, 0n, false]);
      expect(await helper.testReaderTryConsumeEmpty(balance, Keys.Balance)).to.deep.equal([false, 0n, false]);

      const malformed = "0x" + Keys.Balance.slice(2) + "00000040";
      await expect(helper.testReaderTryConsumeEmpty(malformed, Keys.Balance))
        .to.be.revertedWithCustomError(helper, "InvalidBlock");
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

    it("packs count, consumer flags, and tag into cursor metadata", async () => {
      const [cur, count, flags, tag] = await helper.testSpanMeta(0x1234, 0x56, 0x78);

      expect(cur).to.equal((0x1234n << 96n) | (0x56n << 112n) | (0x78n << 120n));
      expect(count).to.equal(0x1234n);
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

    it("open(source) creates a counted cursor over the matching first run", async () => {
      const a = encodeAmountBlock(asset, 1n);
      const b = encodeAmountBlock(asset, 2n);
      const c = encodeBalanceBlock(asset, 3n);
      const source = concat(a, b, c);
      const run = concat(a, b);
      const [offset, cursorI, len, count] = await helper.testOpen(source);
      expect(offset).to.equal(0n);
      expect(cursorI).to.equal(0n);
      expect(len).to.equal(BigInt(ethers.getBytes(run).length));
      expect(count).to.equal(2n);
    });

    it("open(source) reverts EmptyRun for an empty source", async () => {
      await expect(helper.testOpen("0x"))
        .to.be.revertedWithCustomError(helper, "EmptyRun");
    });

    it("peek returns the next key and payload length", async () => {
      const source = encodeBalanceBlock(asset, amount);
      expect(await helper.testPeek(source, 0n)).to.deep.equal([Keys.Balance, 64n]);
    });

    it("enter advances into a parent payload so child blocks can be unpacked", async () => {
      const child = encodeAmountBlock(asset, amount);
      const source = encodeListBlock(child);

      expect(await helper.testEnterAmount(source, exactSpec(Keys.List, ethers.getBytes(child).length)))
        .to.deep.equal([
          asset,
          amount,
          BigInt(ethers.getBytes(source).length),
          BigInt(ethers.getBytes(source).length),
        ]);
    });

    it("next32 consumes raw words from an entered decoder parent", async () => {
      const first = ethers.zeroPadValue("0x51", 32);
      const second = ethers.zeroPadValue("0x52", 32);
      const source = encodeListBlock(first, second);

      expect(await helper.testEnterWords(source, exactSpec(Keys.List, 64)))
        .to.deep.equal([first, second]);
    });

    it("consumes power-of-two byte widths from an entered decoder parent", async () => {
      const fields = [
        "0x01",
        "0x0203",
        "0x04050607",
        "0x08090a0b0c0d0e0f",
        "0x101112131415161718191a1b1c1d1e1f",
        "0x202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f",
      ];
      const source = encodeListBlock(...fields);

      expect(await helper.testEnterSized(source, exactSpec(Keys.List, 63)))
        .to.deep.equal(fields);
    });

    it("enter validates the parent specification", async () => {
      const child = encodeAmountBlock(asset, amount);
      const source = encodeListBlock(child);

      await expect(helper.testEnterAmount(source, exactSpec(Keys.Bytes, ethers.getBytes(child).length)))
        .to.be.revertedWithCustomError(helper, "InvalidBlock");
    });

    it("enter advances over a fixed parent prefix without crossing its payload", async () => {
      const parent = encodeListBlock(ethers.hexlify(ethers.randomBytes(64)));
      const source = concat(parent, encodeAssetBlock(asset));
      const spec = exactSpec(Keys.List, 64);

      expect(await helper.testEnterAdvance(source, spec, 32n)).to.deep.equal([8n, 40n, 72n]);
      await expect(helper.testEnterAdvance(source, spec, 65n))
        .to.be.revertedWithCustomError(helper, "InvalidBlock");
    });

    it("reports the absolute position separately from advancing over raw bytes", async () => {
      const first = ethers.zeroPadValue("0x41", 32);
      const second = ethers.zeroPadValue("0x42", 32);

      expect(await helper.testAdvance(concat(first, second), 32n)).to.deep.equal([0n, 32n, first]);
      await expect(helper.testAdvance(first, 33n)).to.be.revertedWithCustomError(helper, "OutOfBounds");

      const input = encodeListBlock(first, second);
      expect(await blocksHelper.executionAdvance(input, 64n)).to.deep.equal([8n, first, true]);
      await expect(blocksHelper.executionAdvance(input, 65n))
        .to.be.revertedWithCustomError(blocksHelper, "OutOfBounds");
    });

    it("takes raw bytes and returns their starting absolute position", async () => {
      const first = ethers.zeroPadValue("0x41", 32);
      const second = ethers.zeroPadValue("0x42", 32);

      expect(await helper.testTakeRaw(concat(first, second), 32n)).to.deep.equal([0n, 32n, first]);
      await expect(helper.testTakeRaw(first, 33n)).to.be.revertedWithCustomError(helper, "OutOfBounds");

      const input = encodeListBlock(first, second);
      expect(await blocksHelper.executionTake(input, 64n)).to.deep.equal([8n, first, true]);
      await expect(blocksHelper.executionTake(input, 65n))
        .to.be.revertedWithCustomError(blocksHelper, "OutOfBounds");
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

    it("detects an empty block without consuming it", async () => {
      const empty = encodeBlock(Keys.Balance, "0x");
      expect(await helper.testIsEmptyCurrent(empty, Keys.Balance)).to.equal(true);
      expect(await helper.testIsEmptyCurrent(empty, Keys.Amount)).to.equal(false);
      expect(await helper.testIsEmptyCurrent(encodeBalanceBlock(asset, amount), Keys.Balance)).to.equal(false);
      expect(await helper.testIsEmptyCurrent(Keys.Balance, Keys.Balance)).to.equal(false);
    });

    it("conditionally consumes an empty block header", async () => {
      const empty = encodeBlock(Keys.Balance, "0x");
      const balance = encodeBalanceBlock(asset, amount);
      expect(await helper.testTryConsumeEmpty(empty, Keys.Balance)).to.deep.equal([true, 8n, false]);
      expect(await helper.testTryConsumeEmpty(empty, Keys.Amount)).to.deep.equal([false, 0n, true]);
      expect(await helper.testTryConsumeEmpty(balance, Keys.Balance)).to.deep.equal([false, 0n, true]);

      const malformed = "0x" + Keys.Balance.slice(2) + "00000040";
      await expect(helper.testTryConsumeEmpty(malformed, Keys.Balance))
        .to.be.revertedWithCustomError(helper, "MalformedBlocks");
      await expect(helper.testUnpackBalance(empty))
        .to.be.revertedWithCustomError(helper, "OutOfBounds");
    });

    it("detects and consumes empty blocks through execution lanes", async () => {
      const empty = encodeBlock(Keys.Balance, "0x");
      expect(await blocksHelper.executionIsEmpty(empty, exactSpec(Keys.Balance, 64), Keys.Balance))
        .to.equal(true);
      expect(await blocksHelper.executionTryConsumeEmpty(empty, exactSpec(Keys.Balance, 64), Keys.Balance))
        .to.deep.equal([true, false]);
      expect(await blocksHelper.executionTryConsumeEmpty(empty, exactSpec(Keys.Balance, 64), Keys.Amount))
        .to.deep.equal([false, true]);
      expect(
        await blocksHelper.executionTryConsumeEmpty(
          encodeBalanceBlock(asset, amount),
          exactSpec(Keys.Balance, 64),
          Keys.Balance,
        ),
      ).to.deep.equal([false, true]);
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

    it("run counts consecutive matching blocks without advancing", async () => {
      const first = encodeAmountBlock(asset, 1n);
      const second = encodeAmountBlock(asset, 2n);
      const balance = encodeBalanceBlock(asset, 3n);
      const source = concat(first, second, balance);
      const balanceAt = BigInt(ethers.getBytes(first).length + ethers.getBytes(second).length);

      expect(await helper.testRun(source, 0n, Keys.Amount)).to.deep.equal([2n, 0n]);
      expect(await helper.testRun(source, 0n, Keys.Balance)).to.deep.equal([0n, 0n]);
      expect(await helper.testRun(source, balanceAt, Keys.Balance)).to.deep.equal([1n, balanceAt]);
    });

    it("exact run requires every source block to have the expected key", async () => {
      const first = encodeAmountBlock(asset, 1n);
      const second = encodeAmountBlock(asset, 2n);
      const amounts = concat(first, second);

      expect(await helper.testRunExact(amounts, Keys.Amount))
        .to.deep.equal([2n, BigInt(ethers.getBytes(amounts).length)]);

      await expect(helper.testRunExact(concat(amounts, encodeBalanceBlock(asset, 3n)), Keys.Amount))
        .to.be.revertedWithCustomError(helper, "InvalidBlock");
    });

    it("run rejects a matching block that exceeds the cursor boundary", async () => {
      const truncated = "0x" + Keys.Amount.slice(2) + "00000040";

      await expect(helper.testRun(truncated, 0n, Keys.Amount))
        .to.be.revertedWithCustomError(helper, "MalformedBlocks");
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

    it("treats an empty list block as a present list with no items", async () => {
      const list = encodeListBlock();
      const [itemsOffset, itemsI, itemsLen, inputI] = await helper.testList(list);
      expect([itemsOffset, itemsI, itemsLen, inputI]).to.deep.equal([8n, 0n, 0n, 8n]);
    });

    it("list accepts custom keyed list specifications", async () => {
      const key = localKey(77);
      const item1 = encodeAssetBlock(asset);
      const item2 = encodeAssetBlock(otherAsset);
      const payload = concat(item1, item2);
      const list = encodeBlock(key, payload);
      const spec = exactSpec(key, ethers.getBytes(payload).length);

      const [itemsOffset, itemsI, itemsLen, inputI] = await helper.testListSpec(list, spec);
      expect(itemsOffset).to.equal(8n);
      expect(itemsI).to.equal(0n);
      expect(itemsLen).to.equal(BigInt(ethers.getBytes(payload).length));
      expect(inputI).to.equal(BigInt(ethers.getBytes(list).length));
      expect(await blocksHelper.executionList(list, spec))
        .to.deep.equal([BigInt(ethers.getBytes(payload).length), true]);
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

    it("takeBlock returns a cursor over the full matching block and advances the source cursor", async () => {
      const custom = localKey(1);
      const payload = encodeAccountBlock(encodeUserAccount("0x12"));
      const data = encodeBlock(custom, payload);
      const [outOffset, outI, outLen, inputI] = await helper.testTakeBlock(data, custom);
      expect(outOffset).to.equal(0n);
      expect(outI).to.equal(0n);
      expect(outLen).to.equal(BigInt(ethers.getBytes(data).length));
      expect(inputI).to.equal(BigInt(ethers.getBytes(data).length));
    });

    it("takeBlock reverts when the current block key does not match", async () => {
      const custom = localKey(1);
      const source = encodeBalanceBlock(asset, amount);
      await expect(helper.testTakeBlock(source, custom))
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
