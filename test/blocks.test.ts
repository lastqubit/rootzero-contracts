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
  encodePipeBlock,
  encodeRelayBlock,
  encodeDispatchBlock,
  encodeListBlock,
  encodeCustodyBlock,
  encodeCustodyLimitBlock,
  encodeFeeBlock,
  encodeAccountBlock,
  encodeAccountAssetBlock,
  encodeContextBlock,
  encodeHostAccountAssetBlock,
  encodeDataBlock,
  encodeStepBlock,
  encodeTxBlock,
  encodeUserAccount,
  concat,
} from "./helpers/blocks.js";

describe("Cursors", () => {
  let helper: Awaited<ReturnType<typeof deploy>>;
  let erc20Helper: Awaited<ReturnType<typeof deploy>>;
  let erc1155Helper: Awaited<ReturnType<typeof deploy>>;
  let erc721Helper: Awaited<ReturnType<typeof deploy>>;
  let operation: Awaited<ReturnType<typeof deploy>>;
  let utils: Awaited<ReturnType<typeof deploy>>;

  before(async () => {
    helper = await deploy("TestCursorHelper");
    erc20Helper = await deploy("TestErc20CursorHelper");
    erc1155Helper = await deploy("TestErc1155CursorHelper");
    erc721Helper = await deploy("TestErc721CursorHelper");
    operation = await deploy("TestOperation");
    utils = await deploy("TestUtils");
  });

  describe("Writers", () => {
    const asset = ethers.zeroPadValue("0x01", 32);
    const meta = ethers.zeroPadValue("0x02", 32);
    const amount = 12345n;

    it("writeBalanceBlock round-trips", async () => {
      const data: string = await helper.testWriteBalanceBlock(asset, meta, amount);
      expect(ethers.getBytes(data).length).to.equal(104);
      expect(data.slice(0, 10)).to.equal(Keys.Balance);
      expect(data.slice(10, 18)).to.equal("00000060");
      expect(await helper.testUnpackBalance(data)).to.deep.equal([asset, meta, amount]);
    });

    it("hostAccountAsset block round-trips", async () => {
      const host = 1234n;
      const account = encodeUserAccount("0x03");
      const data = encodeHostAccountAssetBlock(host, account, asset, meta);
      expect(ethers.getBytes(data).length).to.equal(136);
      expect(data.slice(0, 10)).to.equal(Keys.HostAccountAsset);
      expect(await helper.testUnpackHostAccountAsset(data)).to.deep.equal([host, account, asset, meta]);
    });

    it("accountAsset block round-trips", async () => {
      const account = encodeUserAccount("0x03");
      const data = encodeAccountAssetBlock(account, asset, meta);
      expect(ethers.getBytes(data).length).to.equal(104);
      expect(data.slice(0, 10)).to.equal(Keys.AccountAsset);
      expect(await helper.testUnpackAccountAsset(data)).to.deep.equal([account, asset, meta]);
    });

    it("writeCustodyBlock produces 136 bytes", async () => {
      const data: string = await helper.testWriteCustodyBlock(1234n, asset, meta, amount);
      expect(ethers.getBytes(data).length).to.equal(136);
    });

    it("writeTxBlock round-trips", async () => {
      const from_ = encodeUserAccount("0x03");
      const to_ = encodeUserAccount("0x04");
      const data: string = await helper.testWriteTxBlock(from_, to_, asset, meta, amount);
      expect(ethers.getBytes(data).length).to.equal(168);
      expect(await helper.testToTxValue(data)).to.deep.equal([from_, to_, asset, meta, amount]);
    });

    it("writePipeBlock matches the canonical pipe encoding", async () => {
      const account = encodeUserAccount("0x12");
      const state = encodeBalanceBlock(asset, meta, amount);
      const request = encodeAmountBlock(asset, meta, 7n);
      const data: string = await helper.testWritePipeBlock(55n, account, state, request);
      expect(data).to.equal(encodePipeBlock(55n, account, state, request));
    });

    it("toBalanceBlock returns a valid encoded BALANCE block", async () => {
      const data: string = await helper.testToBalanceBlock(asset, meta, amount);
      expect(ethers.getBytes(data).length).to.equal(104);
      expect(data.slice(0, 10)).to.equal(Keys.Balance);
      expect(await helper.testUnpackBalance(data)).to.deep.equal([asset, meta, amount]);
    });

    it("toCustodyBlock returns a valid encoded CUSTODY block", async () => {
      const data: string = await helper.testToCustodyBlock(1234n, asset, meta, amount);
      expect(ethers.getBytes(data).length).to.equal(136);
      expect(data.slice(0, 10)).to.equal(Keys.Custody);
    });

    it("toBountyBlock returns a valid encoded BOUNTY block", async () => {
      const relayer = ethers.zeroPadValue("0x05", 32);
      const data: string = await helper.testToBountyBlock(amount, relayer);
      const bytes = ethers.getBytes(data);
      expect(bytes.length).to.equal(72);
      expect(data.slice(0, 10)).to.equal(Keys.Bounty);
      expect(ethers.hexlify(bytes.slice(4, 8))).to.equal("0x00000040");
    });

    it("finish reverts EmptyRequest when writer is unused", async () => {
      await expect(helper.testWriterFinishIncomplete()).to.be.revertedWithCustomError(helper, "EmptyRequest");
    });

    it("finish truncates to actual written length", async () => {
      const data: string = await helper.testWriterFinish(asset, meta, amount);
      expect(ethers.getBytes(data).length).to.equal(104);
    });

    it("reverts when appending past logical writer capacity", async () => {
      await expect(helper.testWriterRejectsSecond32Block(asset))
        .to.be.revertedWithCustomError(helper, "WriterOverflow");
    });

    it("reverts when a dynamic block exceeds allocated payload size", async () => {
      const oversized = ethers.concat([asset, meta]);
      await expect(helper.testWriterRejectsOversizedDynamicBlock(oversized))
        .to.be.revertedWithCustomError(helper, "WriterOverflow");
    });
  });

  describe("Cursor helpers", () => {
    const asset = ethers.zeroPadValue("0xaa", 32);
    const meta = ethers.zeroPadValue("0xbb", 32);
    const amount = 9999n;

    it("run returns key and groups, and truncates len to the matching run", async () => {
      const a = encodeAmountBlock(asset, meta, 1n);
      const b = encodeAmountBlock(asset, meta, 2n);
      const c = encodeBalanceBlock(asset, meta, 3n);
      const source = concat(a, b, c);
      const [key, groups, offset, i, len] = await helper.testRun(source, 1n);
      expect(key).to.equal(Keys.Amount);
      expect(groups).to.equal(2n);
      expect(offset).to.equal(0n);
      expect(i).to.equal(0n);
      expect(len).to.equal(BigInt(ethers.getBytes(concat(a, b)).length));
    });

    it("run reverts ZeroGroup when group is 0", async () => {
      const source = encodeAmountBlock(asset, meta, amount);
      await expect(helper.testRun(source, 0n))
        .to.be.revertedWithCustomError(helper, "ZeroGroup");
    });

    it("run reverts MalformedBlocks when the first header is truncated", async () => {
      await expect(helper.testRun("0x" + Keys.Amount.slice(2), 1n))
        .to.be.revertedWithCustomError(helper, "MalformedBlocks");
    });

    it("open(source, i) creates a cursor over the source tail", async () => {
      const a = encodeAmountBlock(asset, meta, 1n);
      const b = encodeBalanceBlock(asset, meta, 2n);
      const source = concat(a, b);
      const i = BigInt(ethers.getBytes(a).length);
      const [offset, cursorI, len] = await helper.testOpenAt(source, i);
      expect(offset).to.equal(i);
      expect(cursorI).to.equal(0n);
      expect(len).to.equal(BigInt(ethers.getBytes(b).length));
    });

    it("init(source, i, group) creates a cursor over the matching tail run", async () => {
      const a = encodeAmountBlock(asset, meta, 1n);
      const b = encodeBalanceBlock(asset, meta, 2n);
      const c = encodeBalanceBlock(asset, meta, 3n);
      const source = concat(a, b, c);
      const i = BigInt(ethers.getBytes(a).length);
      const [offset, cursorI, len, groups, next] = await helper.testInitAt(source, i, 1n);
      expect(offset).to.equal(i);
      expect(cursorI).to.equal(0n);
      expect(len).to.equal(BigInt(ethers.getBytes(concat(b, c)).length));
      expect(groups).to.equal(2n);
      expect(next).to.equal(BigInt(ethers.getBytes(source).length));
    });

    it("init expected-groups overload returns the matching run cursor", async () => {
      const source = concat(
        encodeAmountBlock(asset, meta, 1n),
        encodeAmountBlock(asset, meta, 2n),
      );
      const [i, len, next] = await helper.testInitExpected(source, 1n, 2n);
      expect(i).to.equal(0n);
      expect(len).to.equal(BigInt(ethers.getBytes(source).length));
      expect(next).to.equal(BigInt(ethers.getBytes(source).length));
    });

    it("init expected-groups overload reverts BadRatio on count mismatch", async () => {
      const source = concat(
        encodeAmountBlock(asset, meta, 1n),
        encodeAmountBlock(asset, meta, 2n),
      );
      await expect(helper.testInitExpected(source, 1n, 1n))
        .to.be.revertedWithCustomError(helper, "BadRatio");
    });

    it("init(source, i, group, expectedGroups) checks the matching tail run", async () => {
      const a = encodeAmountBlock(asset, meta, 1n);
      const b = encodeBalanceBlock(asset, meta, 2n);
      const c = encodeBalanceBlock(asset, meta, 3n);
      const source = concat(a, b, c);
      const offset = BigInt(ethers.getBytes(a).length);
      const [cursorOffset, i, len, next] = await helper.testInitAtExpected(source, offset, 1n, 2n);
      expect(cursorOffset).to.equal(offset);
      expect(i).to.equal(0n);
      expect(len).to.equal(BigInt(ethers.getBytes(concat(b, c)).length));
      expect(next).to.equal(BigInt(ethers.getBytes(source).length));
    });

    it("peek returns the next key and payload length", async () => {
      const source = encodeBalanceBlock(asset, meta, amount);
      expect(await helper.testPeek(source, 0n)).to.deep.equal([Keys.Balance, 96n]);
    });

    it("past returns the offset immediately past the current block without advancing", async () => {
      const source = encodeBalanceBlock(asset, meta, amount);
      expect(await helper.testPastCurrent(source)).to.equal(104n);
    });

    it("isAt returns true for a matching well-formed block at the current cursor position", async () => {
      const source = encodeBalanceBlock(asset, meta, amount);
      expect(await helper.testIsAtCurrent(source, Keys.Balance)).to.equal(true);
    });

    it("isAt returns false when the key does not match", async () => {
      const source = encodeBalanceBlock(asset, meta, amount);
      expect(await helper.testIsAtCurrent(source, Keys.Amount)).to.equal(false);
    });

    it("isAt returns true for a truncated block when the current header key matches", async () => {
      const source = "0x" + Keys.Balance.slice(2) + "00000060";
      expect(await helper.testIsAtCurrent(source, Keys.Balance)).to.equal(true);
    });

    it("hasAt checks a block key at an arbitrary source position", async () => {
      const a = encodeAmountBlock(asset, meta, 1n);
      const b = encodeBalanceBlock(asset, meta, 2n);
      const source = concat(a, b);
      const i = BigInt(ethers.getBytes(a).length);
      expect(await helper.testHasAt(source, i, Keys.Balance)).to.equal(true);
      expect(await helper.testHasAt(source, i, Keys.Amount)).to.equal(false);
      expect(await helper.testHasAt(source, BigInt(ethers.getBytes(source).length), Keys.Balance)).to.equal(false);
    });

    it("countRun counts consecutive matching blocks from i", async () => {
      const a = encodeAmountBlock(asset, meta, 1n);
      const b = encodeAmountBlock(asset, meta, 2n);
      const c = encodeBalanceBlock(asset, meta, 3n);
      const [count, next] = await helper.testCountRun(concat(a, b, c), 0n, Keys.Amount);
      expect(count).to.equal(2n);
      expect(next).to.equal(BigInt(ethers.getBytes(concat(a, b)).length));
    });

    it("slice creates a subcursor over the requested range", async () => {
      const a = encodeAssetBlock(asset, meta);
      const b = encodeAccountBlock(encodeUserAccount("0x12"));
      const source = concat(a, b);
      const from = BigInt(ethers.getBytes(a).length);
      const to = BigInt(ethers.getBytes(source).length);
      const [offset, i, len] = await helper.testSlice(source, from, to);
      expect(offset).to.equal(from);
      expect(i).to.equal(0n);
      expect(len).to.equal(BigInt(ethers.getBytes(b).length));
    });

    it("slice reverts MalformedBlocks when the requested range is invalid", async () => {
      const source = concat(encodeAssetBlock(asset, meta), encodeAccountBlock(encodeUserAccount("0x12")));
      await expect(helper.testSlice(source, 10n, 9n))
        .to.be.revertedWithCustomError(helper, "MalformedBlocks");
      await expect(helper.testSlice(source, 0n, BigInt(ethers.getBytes(source).length + 1)))
        .to.be.revertedWithCustomError(helper, "MalformedBlocks");
    });

    it("raw returns the full cursor region as calldata", async () => {
      const source = concat(encodeAssetBlock(asset, meta), encodeAccountBlock(encodeUserAccount("0x12")));
      expect(await helper.testRaw(source)).to.equal(source);
    });

    it("raw returns a sliced cursor region as calldata", async () => {
      const a = encodeAssetBlock(asset, meta);
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
      const source = concat(encodeAssetBlock(asset, meta), encodeAssetBlock(meta, asset));
      expect(await helper.testSkipTo(source, BigInt(ethers.getBytes(source).length))).to.equal(BigInt(ethers.getBytes(source).length));
    });

    it("skipTo reverts IncompleteCursor when the cursor has passed the end offset", async () => {
      const source = concat(encodeAssetBlock(asset, meta), encodeAssetBlock(meta, asset));
      const end = BigInt(ethers.getBytes(source).length - ethers.getBytes(encodeAssetBlock(meta, asset)).length);
      await expect(helper.testSkipToPastEnd(source, end))
        .to.be.revertedWithCustomError(helper, "IncompleteCursor");
    });

    it("exit succeeds when the cursor is exactly at the requested offset", async () => {
      const source = concat(encodeAssetBlock(asset, meta), encodeAssetBlock(meta, asset));
      const at = BigInt(ethers.getBytes(source).length);
      expect(await helper.testExit(source, at)).to.equal(at);
    });

    it("exit reverts IncompleteCursor when the cursor is not exactly at the requested offset", async () => {
      const source = concat(encodeAssetBlock(asset, meta), encodeAssetBlock(meta, asset));
      const at = BigInt(ethers.getBytes(encodeAssetBlock(asset, meta)).length);
      await expect(helper.testExitMismatch(source, at))
        .to.be.revertedWithCustomError(helper, "IncompleteCursor");
    });

    it("list returns the next offset and advances past the list header", async () => {
      const item1 = encodeAssetBlock(asset, meta);
      const item2 = encodeAssetBlock(meta, asset);
      const list = encodeListBlock(item1, item2);
      const [inputI, next] = await helper.testList(list);
      expect(inputI).to.equal(8n);
      expect(next).to.equal(BigInt(ethers.getBytes(list).length));
    });

    it("data uses a shared key and carries merged payload fields without child headers", async () => {
      const payload = ethers.concat([
        asset,
        meta,
        ethers.zeroPadValue(ethers.toBeHex(amount), 32),
        ethers.zeroPadValue(ethers.toBeHex(77n), 32),
      ]);
      const data = encodeDataBlock(payload);

      expect(data.slice(0, 10)).to.equal(Keys.Data);
      expect(await helper.testPeek(data, 0n)).to.deep.equal([Keys.Data, 128n]);
      expect(ethers.getBytes(data).length).to.equal(136);
      expect(data).to.not.include(Keys.Amount.slice(2));
      expect(data).to.not.include(Keys.Fee.slice(2));
    });

    it("take returns a sliced cursor over the full matching block and advances the source cursor", async () => {
      const payload = encodeAccountBlock(encodeUserAccount("0x12"));
      const data = encodeDataBlock(payload);
      const [outOffset, outI, outLen, inputI] = await helper.testTake(data, Keys.Data);
      expect(outOffset).to.equal(0n);
      expect(outI).to.equal(0n);
      expect(outLen).to.equal(BigInt(ethers.getBytes(data).length));
      expect(inputI).to.equal(BigInt(ethers.getBytes(data).length));
    });

    it("take reverts when the current block key does not match", async () => {
      const source = encodeBalanceBlock(asset, meta, amount);
      await expect(helper.testTake(source, Keys.Data))
        .to.be.revertedWithCustomError(helper, "InvalidBlock");
    });

    it("maybeTake returns a sliced cursor and advances when the current block matches", async () => {
      const payload = encodeAccountBlock(encodeUserAccount("0x34"));
      const data = encodeDataBlock(payload);
      const [outOffset, outI, outLen, inputI] = await helper.testMaybeTake(data, Keys.Data);
      expect(outOffset).to.equal(0n);
      expect(outI).to.equal(0n);
      expect(outLen).to.equal(BigInt(ethers.getBytes(data).length));
      expect(inputI).to.equal(BigInt(ethers.getBytes(data).length));
    });

    it("maybeTake returns an empty cursor and does not advance when the current block does not match", async () => {
      const source = encodeBalanceBlock(asset, meta, amount);
      const [outOffset, outI, outLen, inputI] = await helper.testMaybeTake(source, Keys.Data);
      expect(outOffset).to.equal(0n);
      expect(outI).to.equal(0n);
      expect(outLen).to.equal(0n);
      expect(inputI).to.equal(0n);
    });

    it("maybeData returns an empty cursor and does not advance when the current block is not DATA", async () => {
      const source = encodeBalanceBlock(asset, meta, amount);
      const [outOffset, outI, outLen, inputI] = await helper.testMaybeData(source);
      expect(outOffset).to.equal(0n);
      expect(outI).to.equal(0n);
      expect(outLen).to.equal(0n);
      expect(inputI).to.equal(0n);
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

    it("unpackContext consumes account, state, and request bytes", async () => {
      const account = encodeUserAccount("0x12");
      const state = encodeBalanceBlock(asset, meta, amount);
      const request = encodeAmountBlock(asset, meta, 7n);
      const context = encodeContextBlock(account, state, request);
      const [outAccount, outState, outRequest, i] = await helper.testUnpackContext(context);
      expect(outAccount).to.equal(account);
      expect(outState).to.equal(state);
      expect(outRequest).to.equal(request);
      expect(i).to.equal(BigInt(ethers.getBytes(context).length));
    });

    it("unpackPipe consumes value and nested context bytes", async () => {
      const account = encodeUserAccount("0x12");
      const state = encodeBalanceBlock(asset, meta, amount);
      const request = encodeAmountBlock(asset, meta, 7n);
      const pipe = encodePipeBlock(55n, account, state, request);
      const [value, outAccount, outState, outRequest, i] = await helper.testUnpackPipe(pipe);
      expect(value).to.equal(55n);
      expect(outAccount).to.equal(account);
      expect(outState).to.equal(state);
      expect(outRequest).to.equal(request);
      expect(i).to.equal(BigInt(ethers.getBytes(pipe).length));
    });

    it("unpackRelay consumes chain, endowment, and step bytes", async () => {
      const chain: bigint = await utils.testLocalChainId();
      const steps = encodeStepBlock(0n, 0n, encodeAmountBlock(asset, meta, 7n));
      const relay = encodeRelayBlock(chain, 55n, steps);
      const [outChain, endowment, outSteps, i] = await helper.testUnpackRelay(relay);
      expect(outChain).to.equal(chain);
      expect(endowment).to.equal(55n);
      expect(outSteps).to.equal(steps);
      expect(i).to.equal(BigInt(ethers.getBytes(relay).length));
    });

    it("unpackDispatch consumes chain, endowment, and payload bytes", async () => {
      const chain: bigint = await utils.testLocalChainId();
      const payload = ethers.hexlify(ethers.toUtf8Bytes("ready-to-send"));
      const dispatch = encodeDispatchBlock(chain, 89n, payload);
      const [outChain, endowment, outPayload, i] = await helper.testUnpackDispatch(dispatch);
      expect(outChain).to.equal(chain);
      expect(endowment).to.equal(89n);
      expect(outPayload).to.equal(payload);
      expect(i).to.equal(BigInt(ethers.getBytes(dispatch).length));
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
      const source = encodeAmountBlock(asset, meta, amount);
      const [out, i] = await helper.testRequireAmount(source, asset, meta);
      expect(out).to.equal(amount);
      expect(i).to.equal(104n);
    });

    it("ensureBalanceLimit validates all fields and advances by one limit block", async () => {
      const source = encodeBalanceLimitBlock(asset, meta, 10n, amount);
      expect(await helper.testEnsureBalanceLimit(source, asset, meta, amount)).to.equal(136n);
    });

    it("ensureBalanceLimit reverts UnexpectedValue when the balance is outside the range", async () => {
      const source = encodeBalanceLimitBlock(asset, meta, 10n, 20n);
      await expect(helper.testEnsureBalanceLimit(source, asset, meta, 21n))
        .to.be.revertedWithCustomError(helper, "UnexpectedValue");
    });

    it("ensureBalanceLimit reverts UnexpectedValue when asset fields differ", async () => {
      const source = encodeBalanceLimitBlock(asset, meta, 10n, 20n);
      await expect(helper.testEnsureBalanceLimit(source, ethers.zeroPadValue("0xcc", 32), meta, 15n))
        .to.be.revertedWithCustomError(helper, "UnexpectedValue");
    });

    it("ensureCustodyLimit validates all fields and advances by one limit block", async () => {
      const source = encodeCustodyLimitBlock(123n, asset, meta, 10n, amount);
      expect(await helper.testEnsureCustodyLimit(source, 123n, asset, meta, amount)).to.equal(168n);
    });

    it("ensureCustodyLimit reverts UnexpectedValue when the custody is outside the range", async () => {
      const source = encodeCustodyLimitBlock(123n, asset, meta, 10n, 20n);
      await expect(helper.testEnsureCustodyLimit(source, 123n, asset, meta, 21n))
        .to.be.revertedWithCustomError(helper, "UnexpectedValue");
    });

    it("ensureCustodyLimit reverts UnexpectedValue when host differs", async () => {
      const source = encodeCustodyLimitBlock(123n, asset, meta, 10n, 20n);
      await expect(helper.testEnsureCustodyLimit(source, 321n, asset, meta, 15n))
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
      const source = concat(encodeBalanceBlock(asset, meta, 1n), encodeBalanceBlock(asset, meta, 2n));
      await expect(helper.testCursorCompleteRunPartial(source, 1n))
        .to.be.revertedWithCustomError(helper, "IncompleteCursor");
    });

    it("complete succeeds after the run is consumed", async () => {
      const source = concat(encodeBalanceBlock(asset, meta, 1n), encodeBalanceBlock(asset, meta, 2n));
      expect(await helper.testCursorCompleteRunConsumed(source, 1n)).to.equal(true);
    });

    it("complete reverts IncompleteCursor when bytes remain in the cursor region", async () => {
      const source = concat(encodeBalanceBlock(asset, meta, 1n), encodeBalanceBlock(asset, meta, 2n));
      await expect(helper.testCursorCompletePartial(source))
        .to.be.revertedWithCustomError(helper, "IncompleteCursor");
    });

    it("complete succeeds after the full cursor region is consumed", async () => {
      const source = concat(encodeBalanceBlock(asset, meta, 1n), encodeBalanceBlock(asset, meta, 2n));
      expect(await helper.testCursorCompleteConsumed(source)).to.equal(true);
    });

    it("expectErc20Amount returns the token and amount from a local ERC20 amount block", async () => {
      const token = "0x00000000000000000000000000000000000000a0";
      const assetId = await utils.testToErc20Asset(token);
      const source = encodeAmountBlock(assetId, ethers.ZeroHash, 66n);

      expect(await erc20Helper.testExpectErc20Amount(source, 0n)).to.deep.equal([token, 66n]);
    });

    it("requireErc20Amount returns the token and amount and advances by one amount block", async () => {
      const token = "0x00000000000000000000000000000000000000a0";
      const assetId = await utils.testToErc20Asset(token);
      const source = encodeAmountBlock(assetId, ethers.ZeroHash, 66n);

      expect(await erc20Helper.testRequireErc20Amount(source)).to.deep.equal([token, 66n, 104n]);
    });

    it("expectErc20Balance returns the token and amount from a local ERC20 balance block", async () => {
      const token = "0x00000000000000000000000000000000000000a0";
      const assetId = await utils.testToErc20Asset(token);
      const source = encodeBalanceBlock(assetId, ethers.ZeroHash, 67n);

      expect(await erc20Helper.testExpectErc20Balance(source, 0n)).to.deep.equal([token, 67n]);
    });

    it("requireErc20Balance returns the token and amount and advances by one balance block", async () => {
      const token = "0x00000000000000000000000000000000000000a0";
      const assetId = await utils.testToErc20Asset(token);
      const source = encodeBalanceBlock(assetId, ethers.ZeroHash, 67n);

      expect(await erc20Helper.testRequireErc20Balance(source)).to.deep.equal([token, 67n, 104n]);
    });

    it("expectErc20Custody returns the token and amount from a local ERC20 custody block", async () => {
      const token = "0x00000000000000000000000000000000000000a0";
      const assetId = await utils.testToErc20Asset(token);
      const source = encodeCustodyBlock(123n, assetId, ethers.ZeroHash, 68n);

      expect(await erc20Helper.testExpectErc20Custody(source, 0n, 123n)).to.deep.equal([token, 68n]);
    });

    it("requireErc20Custody returns the token, amount, and advances by one custody block", async () => {
      const token = "0x00000000000000000000000000000000000000a0";
      const assetId = await utils.testToErc20Asset(token);
      const source = encodeCustodyBlock(123n, assetId, ethers.ZeroHash, 68n);

      expect(await erc20Helper.testRequireErc20Custody(source, 123n)).to.deep.equal([token, 68n, 136n]);
    });

    it("expectErc20Custody reverts UnexpectedValue when the host does not match", async () => {
      const token = "0x00000000000000000000000000000000000000a0";
      const assetId = await utils.testToErc20Asset(token);
      const source = encodeCustodyBlock(123n, assetId, ethers.ZeroHash, 68n);

      await expect(erc20Helper.testExpectErc20Custody(source, 0n, 321n))
        .to.be.revertedWithCustomError(erc20Helper, "UnexpectedValue");
    });

    it("expectErc20Amount reverts InvalidAsset when the asset is not a local ERC20", async () => {
      const assetId = await utils.testToNativeAsset();
      const source = encodeAmountBlock(assetId, ethers.ZeroHash, 77n);

      await expect(erc20Helper.testExpectErc20Amount(source, 0n))
        .to.be.revertedWithCustomError(erc20Helper, "InvalidAsset");
    });

    it("expectErc1155Amount returns meta and amount from a matching local ERC1155 amount block", async () => {
      const collection = "0x00000000000000000000000000000000000000d0";
      const assetId = await utils.testToErc1155Asset(collection);
      const meta = ethers.zeroPadValue("0x11", 32);
      const source = encodeAmountBlock(assetId, meta, 66n);

      expect(await erc1155Helper.testExpectErc1155Amount(source, 0n, assetId)).to.deep.equal([meta, 66n]);
    });

    it("requireErc1155Amount returns meta, amount, and advances by one amount block", async () => {
      const collection = "0x00000000000000000000000000000000000000d0";
      const assetId = await utils.testToErc1155Asset(collection);
      const meta = ethers.zeroPadValue("0x11", 32);
      const source = encodeAmountBlock(assetId, meta, 66n);

      expect(await erc1155Helper.testRequireErc1155Amount(source, assetId)).to.deep.equal([meta, 66n, 104n]);
    });

    it("expectErc1155Balance returns meta and amount from a matching local ERC1155 balance block", async () => {
      const collection = "0x00000000000000000000000000000000000000d0";
      const assetId = await utils.testToErc1155Asset(collection);
      const meta = ethers.zeroPadValue("0x12", 32);
      const source = encodeBalanceBlock(assetId, meta, 67n);

      expect(await erc1155Helper.testExpectErc1155Balance(source, 0n, assetId)).to.deep.equal([meta, 67n]);
    });

    it("requireErc1155Balance returns meta, amount, and advances by one balance block", async () => {
      const collection = "0x00000000000000000000000000000000000000d0";
      const assetId = await utils.testToErc1155Asset(collection);
      const meta = ethers.zeroPadValue("0x12", 32);
      const source = encodeBalanceBlock(assetId, meta, 67n);

      expect(await erc1155Helper.testRequireErc1155Balance(source, assetId)).to.deep.equal([meta, 67n, 104n]);
    });

    it("expectErc1155Custody returns meta and amount from a matching local ERC1155 custody block", async () => {
      const collection = "0x00000000000000000000000000000000000000d0";
      const assetId = await utils.testToErc1155Asset(collection);
      const meta = ethers.zeroPadValue("0x15", 32);
      const source = encodeCustodyBlock(123n, assetId, meta, 68n);

      expect(await erc1155Helper.testExpectErc1155Custody(source, 0n, 123n, assetId)).to.deep.equal([meta, 68n]);
    });

    it("requireErc1155Custody returns meta, amount, and advances by one custody block", async () => {
      const collection = "0x00000000000000000000000000000000000000d0";
      const assetId = await utils.testToErc1155Asset(collection);
      const meta = ethers.zeroPadValue("0x15", 32);
      const source = encodeCustodyBlock(123n, assetId, meta, 68n);

      expect(await erc1155Helper.testRequireErc1155Custody(source, 123n, assetId)).to.deep.equal([meta, 68n, 136n]);
    });

    it("expectErc1155Custody reverts UnexpectedValue when the host does not match", async () => {
      const collection = "0x00000000000000000000000000000000000000d0";
      const assetId = await utils.testToErc1155Asset(collection);
      const meta = ethers.zeroPadValue("0x15", 32);
      const source = encodeCustodyBlock(123n, assetId, meta, 68n);

      await expect(erc1155Helper.testExpectErc1155Custody(source, 0n, 321n, assetId))
        .to.be.revertedWithCustomError(erc1155Helper, "UnexpectedValue");
    });

    it("expectErc1155Amount reverts UnexpectedValue when the source asset does not match the expected ERC1155 asset", async () => {
      const assetId = await utils.testToNativeAsset();
      const source = encodeAmountBlock(assetId, ethers.zeroPadValue("0x11", 32), 77n);

      const expectedAsset = await utils.testToErc1155Asset("0x00000000000000000000000000000000000000d0");

      await expect(erc1155Helper.testExpectErc1155Amount(source, 0n, expectedAsset))
        .to.be.revertedWithCustomError(erc1155Helper, "UnexpectedValue");
    });

    it("expectErc721Balance returns meta from a matching local ERC721 balance block", async () => {
      const collection = "0x00000000000000000000000000000000000000c0";
      const assetId = await utils.testToErc721Asset(collection);
      const meta = ethers.zeroPadValue("0x02", 32);
      const source = encodeBalanceBlock(assetId, meta, 1n);

      expect(await erc721Helper.testExpectErc721Balance(source, 0n, collection)).to.equal(meta);
    });

    it("requireErc721Balance returns meta and advances by one balance block", async () => {
      const collection = "0x00000000000000000000000000000000000000c0";
      const assetId = await utils.testToErc721Asset(collection);
      const meta = ethers.zeroPadValue("0x02", 32);
      const source = encodeBalanceBlock(assetId, meta, 1n);

      expect(await erc721Helper.testRequireErc721Balance(source, collection)).to.deep.equal([meta, 104n]);
    });

    it("expectErc721Custody returns meta from a matching local ERC721 custody block", async () => {
      const collection = "0x00000000000000000000000000000000000000c0";
      const assetId = await utils.testToErc721Asset(collection);
      const meta = ethers.zeroPadValue("0x03", 32);
      const source = encodeCustodyBlock(321n, assetId, meta, 1n);

      expect(await erc721Helper.testExpectErc721Custody(source, 0n, 321n, collection)).to.equal(meta);
    });

    it("requireErc721Custody returns meta and advances by one custody block", async () => {
      const collection = "0x00000000000000000000000000000000000000c0";
      const assetId = await utils.testToErc721Asset(collection);
      const meta = ethers.zeroPadValue("0x03", 32);
      const source = encodeCustodyBlock(321n, assetId, meta, 1n);

      expect(await erc721Helper.testRequireErc721Custody(source, 321n, collection)).to.deep.equal([meta, 136n]);
    });

    it("expectErc721Custody reverts UnexpectedValue when the host does not match", async () => {
      const collection = "0x00000000000000000000000000000000000000c0";
      const assetId = await utils.testToErc721Asset(collection);
      const meta = ethers.zeroPadValue("0x03", 32);
      const source = encodeCustodyBlock(321n, assetId, meta, 1n);

      await expect(erc721Helper.testExpectErc721Custody(source, 0n, 123n, collection))
        .to.be.revertedWithCustomError(erc721Helper, "UnexpectedValue");
    });
    it("expectErc721Balance reverts InvalidAsset when the asset is not a local ERC721", async () => {
      const assetId = await utils.testToNativeAsset();
      const source = encodeBalanceBlock(assetId, ethers.zeroPadValue("0x01", 32), 1n);

      await expect(erc721Helper.testExpectErc721Balance(source, 0n, "0x00000000000000000000000000000000000000c0"))
        .to.be.revertedWithCustomError(erc721Helper, "InvalidAsset");
    });

    it("expectErc721Balance reverts UnexpectedValue when amount is not 1", async () => {
      const collection = "0x00000000000000000000000000000000000000c0";
      const assetId = await utils.testToErc721Asset(collection);
      const source = encodeBalanceBlock(assetId, ethers.zeroPadValue("0x02", 32), 2n);

      await expect(erc721Helper.testExpectErc721Balance(source, 0n, collection))
        .to.be.revertedWithCustomError(erc721Helper, "UnexpectedValue");
    });

    it("expectErc721Custody reverts UnexpectedValue when amount is not 1", async () => {
      const collection = "0x00000000000000000000000000000000000000c0";
      const assetId = await utils.testToErc721Asset(collection);
      const source = encodeCustodyBlock(321n, assetId, ethers.zeroPadValue("0x03", 32), 2n);

      await expect(erc721Helper.testExpectErc721Custody(source, 0n, 321n, collection))
        .to.be.revertedWithCustomError(erc721Helper, "UnexpectedValue");
    });

    it("accepts matching 2:1 ratio between state and request runs", async () => {
      const state = concat(
        encodeBalanceBlock(asset, meta, 1n),
        encodeBalanceBlock(asset, meta, 2n),
      );
      const request = encodeAmountBlock(asset, meta, 3n);

      expect(await operation.testCheckCursorRatio(state, 2n, request, 1n)).to.equal(true);
    });

    it("reverts BadRatio when state and request runs break the expected ratio", async () => {
      const state = concat(
        encodeBalanceBlock(asset, meta, 1n),
        encodeBalanceBlock(asset, meta, 2n),
        encodeBalanceBlock(asset, meta, 3n),
      );
      const request = encodeAmountBlock(asset, meta, 4n);

      await expect(operation.testCheckCursorRatio(state, 2n, request, 1n))
        .to.be.revertedWithCustomError(operation, "BadRatio");
    });
  });

});
