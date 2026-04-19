import { expect } from "chai";
import { ethers } from "ethers";
import { deploy } from "./helpers/setup.js";
import "./helpers/matchers.js";
import {
  Keys,
  encodeAllocationBlock,
  encodeAmountBlock,
  encodeAuthBlock,
  encodeAssetBlock,
  encodeBalanceBlock,
  encodeBoundsBlock,
  encodeBountyBlock,
  encodeBundleBlock,
  encodeListBlock,
  encodeCustodyBlock,
  encodeFeeBlock,
  encodeFundingBlock,
  encodeListingBlock,
  encodeMaximumsBlock,
  encodeMaximumBlock,
  encodeMinimumsBlock,
  encodeMinimumBlock,
  encodeNodeBlock,
  encodePathBlock,
  encodeRecipientBlock,
  encodeRouteBlock,
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
      const from_ = encodeUserAccount("0x03");
      const to_ = encodeUserAccount("0x04");
      const data: string = await helper.testWriteTxBlock(from_, to_, asset, meta, amount);
      expect(ethers.getBytes(data).length).to.equal(168);
      expect(await helper.testToTxValue(data)).to.deep.equal([from_, to_, asset, meta, amount]);
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
      const [key, count, quotient, offset, i, len, bound] = await helper.testPrimeRun(source, 1n);
      expect(key).to.equal(Keys.Amount);
      expect(count).to.equal(2n);
      expect(quotient).to.equal(2n);
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

    it("slice creates a subcursor over the requested range", async () => {
      const a = encodeAssetBlock(asset, meta);
      const b = encodeRecipientBlock(encodeUserAccount("0x12"));
      const source = concat(a, b);
      const from = BigInt(ethers.getBytes(a).length);
      const to = BigInt(ethers.getBytes(source).length);
      const [offset, i, len, bound] = await helper.testSlice(source, from, to);
      expect(offset).to.equal(from);
      expect(i).to.equal(0n);
      expect(len).to.equal(BigInt(ethers.getBytes(b).length));
      expect(bound).to.equal(0n);
    });

    it("slice reverts MalformedBlocks when the requested range is invalid", async () => {
      const source = concat(encodeAssetBlock(asset, meta), encodeRecipientBlock(encodeUserAccount("0x12")));
      await expect(helper.testSlice(source, 10n, 9n))
        .to.be.revertedWithCustomError(helper, "MalformedBlocks");
      await expect(helper.testSlice(source, 0n, BigInt(ethers.getBytes(source).length + 1)))
        .to.be.revertedWithCustomError(helper, "MalformedBlocks");
    });

    it("bundle returns a relative subcursor and advances the source cursor", async () => {
      const route = encodeRecipientBlock(encodeUserAccount("0x12"));
      const minimum = encodeMinimumBlock(asset, meta, amount);
      const bundle = encodeBundleBlock(route, minimum);
      const [inputI, end] = await helper.testBundle(bundle);
      expect(inputI).to.equal(8n);
      expect(end).to.equal(BigInt(ethers.getBytes(bundle).length));
    });

    it("resume moves the cursor to the provided end offset", async () => {
      const source = concat(encodeAssetBlock(asset, meta), encodeAssetBlock(meta, asset));
      expect(await helper.testResume(source, BigInt(ethers.getBytes(source).length))).to.equal(BigInt(ethers.getBytes(source).length));
    });

    it("resume reverts IncompleteCursor when the cursor has passed the end offset", async () => {
      const source = concat(encodeAssetBlock(asset, meta), encodeAssetBlock(meta, asset));
      const end = BigInt(ethers.getBytes(source).length - ethers.getBytes(encodeAssetBlock(meta, asset)).length);
      await expect(helper.testResumePastEnd(source, end))
        .to.be.revertedWithCustomError(helper, "IncompleteCursor");
    });

    it("ensure succeeds when the cursor is exactly at the requested offset", async () => {
      const source = concat(encodeAssetBlock(asset, meta), encodeAssetBlock(meta, asset));
      const at = BigInt(ethers.getBytes(source).length);
      expect(await helper.testEnsure(source, at)).to.equal(at);
    });

    it("ensure reverts IncompleteCursor when the cursor is not exactly at the requested offset", async () => {
      const source = concat(encodeAssetBlock(asset, meta), encodeAssetBlock(meta, asset));
      const at = BigInt(ethers.getBytes(encodeAssetBlock(asset, meta)).length);
      await expect(helper.testEnsureMismatch(source, at))
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

    it("list(group) primes the list payload on the same cursor", async () => {
      const item1 = encodeAssetBlock(asset, meta);
      const item2 = encodeAssetBlock(meta, asset);
      const list = encodeListBlock(item1, item2);
      const [inputI, bound, count, next] = await helper.testListPrime(list, 1n);
      expect(inputI).to.equal(8n);
      expect(bound).to.equal(BigInt(ethers.getBytes(list).length));
      expect(count).to.equal(2n);
      expect(next).to.equal(BigInt(ethers.getBytes(list).length));
    });

    it("list(group, requiredCount) succeeds when the raw count matches", async () => {
      const item1 = encodeAssetBlock(asset, meta);
      const item2 = encodeAssetBlock(meta, asset);
      const list = encodeListBlock(item1, item2);
      const [inputI, bound, next] = await helper.testListPrimeRequired(list, 1n, 2n);
      expect(inputI).to.equal(8n);
      expect(bound).to.equal(BigInt(ethers.getBytes(list).length));
      expect(next).to.equal(BigInt(ethers.getBytes(list).length));
    });

    it("list(group, requiredCount) reverts BadRatio when the count mismatches", async () => {
      const item1 = encodeAssetBlock(asset, meta);
      const item2 = encodeAssetBlock(meta, asset);
      const list = encodeListBlock(item1, item2);
      await expect(helper.testListPrimeRequired(list, 1n, 1n))
        .to.be.revertedWithCustomError(helper, "BadRatio");
    });

    it("list(group) reverts IncompleteCursor when trailing blocks remain in the list payload", async () => {
      const item1 = encodeAssetBlock(asset, meta);
      const item2 = encodeAssetBlock(meta, asset);
      const extra = encodeRecipientBlock(encodeUserAccount("0x12"));
      const list = encodeListBlock(item1, item2, extra);
      await expect(helper.testListPrime(list, 1n))
        .to.be.revertedWithCustomError(helper, "IncompleteCursor");
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

    it("unpackBounds preserves signed min and max values", async () => {
      const source = encodeBoundsBlock(-5n, 42n);
      expect(await helper.testUnpackBounds(source)).to.deep.equal([-5n, 42n]);
    });

    it("unpackMinimums returns the two minimum amounts", async () => {
      const source = encodeMinimumsBlock(11n, 22n);
      expect(await helper.testUnpackMinimums(source)).to.deep.equal([11n, 22n]);
    });

    it("unpackMaximums returns the two maximum amounts", async () => {
      const source = encodeMaximumsBlock(33n, 44n);
      expect(await helper.testUnpackMaximums(source)).to.deep.equal([33n, 44n]);
    });

    it("unpackFee returns the fee amount", async () => {
      const source = encodeFeeBlock(77n);
      expect(await helper.testUnpackFee(source)).to.equal(77n);
    });

    it("unpackPath returns the raw path payload", async () => {
      const path = "0x1234567890abcdef";
      const source = encodePathBlock(path);
      expect(await helper.testUnpackPath(source)).to.equal(path);
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

    it("complete reverts ZeroCursor when prime run is empty", async () => {
      await expect(helper.testCursorCompleteEmpty("0x", 1n))
        .to.be.revertedWithCustomError(helper, "ZeroCursor");
    });

    it("complete reverts IncompleteCursor when prime input remains", async () => {
      const source = concat(encodeBalanceBlock(asset, meta, 1n), encodeBalanceBlock(asset, meta, 2n));
      await expect(helper.testCursorCompletePartial(source, 1n))
        .to.be.revertedWithCustomError(helper, "IncompleteCursor");
    });

    it("complete succeeds after the prime run is consumed", async () => {
      const source = concat(encodeBalanceBlock(asset, meta, 1n), encodeBalanceBlock(asset, meta, 2n));
      expect(await helper.testCursorCompleteConsumed(source, 1n)).to.equal(true);
    });

    it("end reverts IncompleteCursor when bytes remain in the cursor region", async () => {
      const source = concat(encodeBalanceBlock(asset, meta, 1n), encodeBalanceBlock(asset, meta, 2n));
      await expect(helper.testCursorEndPartial(source))
        .to.be.revertedWithCustomError(helper, "IncompleteCursor");
    });

    it("end succeeds after the full cursor region is consumed", async () => {
      const source = concat(encodeBalanceBlock(asset, meta, 1n), encodeBalanceBlock(asset, meta, 2n));
      expect(await helper.testCursorEndConsumed(source)).to.equal(true);
    });

    it("recipientAfter returns the tail recipient or backup", async () => {
      const backup = encodeUserAccount("0x99");
      const recipient = encodeUserAccount("0x12");
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

    it("expectErc20Minimum returns the token and amount from a local ERC20 minimum block", async () => {
      const token = "0x00000000000000000000000000000000000000a0";
      const assetId = await utils.testToErc20Asset(token);
      const source = encodeMinimumBlock(assetId, ethers.ZeroHash, 88n);

      expect(await erc20Helper.testExpectErc20Minimum(source, 0n)).to.deep.equal([token, 88n]);
    });

    it("requireErc20Minimum returns the token and amount and advances by one minimum block", async () => {
      const token = "0x00000000000000000000000000000000000000a0";
      const assetId = await utils.testToErc20Asset(token);
      const source = encodeMinimumBlock(assetId, ethers.ZeroHash, 88n);

      expect(await erc20Helper.testRequireErc20Minimum(source)).to.deep.equal([token, 88n, 104n]);
    });

    it("expectErc20Maximum returns the token and amount from a local ERC20 maximum block", async () => {
      const token = "0x00000000000000000000000000000000000000a0";
      const assetId = await utils.testToErc20Asset(token);
      const source = encodeMaximumBlock(assetId, ethers.ZeroHash, 89n);

      expect(await erc20Helper.testExpectErc20Maximum(source, 0n)).to.deep.equal([token, 89n]);
    });

    it("requireErc20Maximum returns the token and amount and advances by one maximum block", async () => {
      const token = "0x00000000000000000000000000000000000000a0";
      const assetId = await utils.testToErc20Asset(token);
      const source = encodeMaximumBlock(assetId, ethers.ZeroHash, 89n);

      expect(await erc20Helper.testRequireErc20Maximum(source)).to.deep.equal([token, 89n, 104n]);
    });

    it("expectErc20Minimum ignores metadata", async () => {
      const token = "0x00000000000000000000000000000000000000a0";
      const assetId = await utils.testToErc20Asset(token);
      const source = encodeMinimumBlock(assetId, ethers.zeroPadValue("0x01", 32), 77n);

      expect(await erc20Helper.testExpectErc20Minimum(source, 0n)).to.deep.equal([token, 77n]);
    });

    it("expectErc20Minimum reverts InvalidAsset when the asset is not a local ERC20", async () => {
      const assetId = await utils.testToValueAsset();
      const source = encodeMinimumBlock(assetId, ethers.ZeroHash, 77n);

      await expect(erc20Helper.testExpectErc20Minimum(source, 0n))
        .to.be.revertedWithCustomError(erc20Helper, "InvalidAsset");
    });

    it("expectErc20Amount reverts InvalidAsset when the asset is not a local ERC20", async () => {
      const assetId = await utils.testToValueAsset();
      const source = encodeAmountBlock(assetId, ethers.ZeroHash, 77n);

      await expect(erc20Helper.testExpectErc20Amount(source, 0n))
        .to.be.revertedWithCustomError(erc20Helper, "InvalidAsset");
    });

    it("expectErc1155Amount returns meta and amount from a matching local ERC1155 amount block", async () => {
      const collection = "0x00000000000000000000000000000000000000d0";
      const assetId = await utils.testToErc1155Asset(collection);
      const meta = ethers.zeroPadValue("0x11", 32);
      const source = encodeAmountBlock(assetId, meta, 66n);

      expect(await erc1155Helper.testExpectErc1155Amount(source, 0n, collection)).to.deep.equal([meta, 66n]);
    });

    it("requireErc1155Amount returns meta, amount, and advances by one amount block", async () => {
      const collection = "0x00000000000000000000000000000000000000d0";
      const assetId = await utils.testToErc1155Asset(collection);
      const meta = ethers.zeroPadValue("0x11", 32);
      const source = encodeAmountBlock(assetId, meta, 66n);

      expect(await erc1155Helper.testRequireErc1155Amount(source, collection)).to.deep.equal([meta, 66n, 104n]);
    });

    it("expectErc1155Balance returns meta and amount from a matching local ERC1155 balance block", async () => {
      const collection = "0x00000000000000000000000000000000000000d0";
      const assetId = await utils.testToErc1155Asset(collection);
      const meta = ethers.zeroPadValue("0x12", 32);
      const source = encodeBalanceBlock(assetId, meta, 67n);

      expect(await erc1155Helper.testExpectErc1155Balance(source, 0n, collection)).to.deep.equal([meta, 67n]);
    });

    it("requireErc1155Balance returns meta, amount, and advances by one balance block", async () => {
      const collection = "0x00000000000000000000000000000000000000d0";
      const assetId = await utils.testToErc1155Asset(collection);
      const meta = ethers.zeroPadValue("0x12", 32);
      const source = encodeBalanceBlock(assetId, meta, 67n);

      expect(await erc1155Helper.testRequireErc1155Balance(source, collection)).to.deep.equal([meta, 67n, 104n]);
    });

    it("expectErc1155Minimum returns meta and amount from a matching local ERC1155 minimum block", async () => {
      const collection = "0x00000000000000000000000000000000000000d0";
      const assetId = await utils.testToErc1155Asset(collection);
      const meta = ethers.zeroPadValue("0x13", 32);
      const source = encodeMinimumBlock(assetId, meta, 88n);

      expect(await erc1155Helper.testExpectErc1155Minimum(source, 0n, collection)).to.deep.equal([meta, 88n]);
    });

    it("requireErc1155Minimum returns meta, amount, and advances by one minimum block", async () => {
      const collection = "0x00000000000000000000000000000000000000d0";
      const assetId = await utils.testToErc1155Asset(collection);
      const meta = ethers.zeroPadValue("0x13", 32);
      const source = encodeMinimumBlock(assetId, meta, 88n);

      expect(await erc1155Helper.testRequireErc1155Minimum(source, collection)).to.deep.equal([meta, 88n, 104n]);
    });

    it("expectErc1155Maximum returns meta and amount from a matching local ERC1155 maximum block", async () => {
      const collection = "0x00000000000000000000000000000000000000d0";
      const assetId = await utils.testToErc1155Asset(collection);
      const meta = ethers.zeroPadValue("0x14", 32);
      const source = encodeMaximumBlock(assetId, meta, 89n);

      expect(await erc1155Helper.testExpectErc1155Maximum(source, 0n, collection)).to.deep.equal([meta, 89n]);
    });

    it("requireErc1155Maximum returns meta, amount, and advances by one maximum block", async () => {
      const collection = "0x00000000000000000000000000000000000000d0";
      const assetId = await utils.testToErc1155Asset(collection);
      const meta = ethers.zeroPadValue("0x14", 32);
      const source = encodeMaximumBlock(assetId, meta, 89n);

      expect(await erc1155Helper.testRequireErc1155Maximum(source, collection)).to.deep.equal([meta, 89n, 104n]);
    });

    it("expectErc1155Custody returns meta and amount from a matching local ERC1155 custody block", async () => {
      const collection = "0x00000000000000000000000000000000000000d0";
      const assetId = await utils.testToErc1155Asset(collection);
      const meta = ethers.zeroPadValue("0x15", 32);
      const source = encodeCustodyBlock(123n, assetId, meta, 68n);

      expect(await erc1155Helper.testExpectErc1155Custody(source, 0n, 123n, collection)).to.deep.equal([meta, 68n]);
    });

    it("requireErc1155Custody returns meta, amount, and advances by one custody block", async () => {
      const collection = "0x00000000000000000000000000000000000000d0";
      const assetId = await utils.testToErc1155Asset(collection);
      const meta = ethers.zeroPadValue("0x15", 32);
      const source = encodeCustodyBlock(123n, assetId, meta, 68n);

      expect(await erc1155Helper.testRequireErc1155Custody(source, 123n, collection)).to.deep.equal([meta, 68n, 136n]);
    });

    it("expectErc1155Custody reverts UnexpectedValue when the host does not match", async () => {
      const collection = "0x00000000000000000000000000000000000000d0";
      const assetId = await utils.testToErc1155Asset(collection);
      const meta = ethers.zeroPadValue("0x15", 32);
      const source = encodeCustodyBlock(123n, assetId, meta, 68n);

      await expect(erc1155Helper.testExpectErc1155Custody(source, 0n, 321n, collection))
        .to.be.revertedWithCustomError(erc1155Helper, "UnexpectedValue");
    });

    it("expectErc1155Amount reverts InvalidAsset when the asset is not a local ERC1155", async () => {
      const assetId = await utils.testToValueAsset();
      const source = encodeAmountBlock(assetId, ethers.zeroPadValue("0x11", 32), 77n);

      await expect(erc1155Helper.testExpectErc1155Amount(source, 0n, "0x00000000000000000000000000000000000000d0"))
        .to.be.revertedWithCustomError(erc1155Helper, "InvalidAsset");
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
      const assetId = await utils.testToValueAsset();
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

    it("accepts matching 2:1 ratio between state and request prime runs", async () => {
      const state = concat(
        encodeBalanceBlock(asset, meta, 1n),
        encodeBalanceBlock(asset, meta, 2n),
      );
      const request = encodeAmountBlock(asset, meta, 3n);

      expect(await operation.testCheckCursorRatio(state, 2n, request, 1n)).to.equal(true);
    });

    it("reverts BadRatio when state and request prime runs break the expected ratio", async () => {
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
