import { expect } from "chai";
import { ethers } from "ethers";
import { deploy, getSigner } from "./helpers/setup.js";
import "./helpers/matchers.js";
import {
  Keys,
  concat,
  encodeAssetBlock,
  encodeAmountBlock,
  encodeBalanceBlock,
  encodeBlock,
  encodeCustodyBlock,
  encodeContextBlock,
  encodeStatusBlock,
  encodeBytesBlock,
  encodeListBlock,
  encodePositionBlock,
  encodeTxBlock,
  encodeUserAccount,
  localKey,
  pad32,
} from "./helpers/blocks.js";

const Payment = localKey(1);
const Swap = localKey(1);
const SwapHop = localKey(2);

function uint32(value: bigint): string {
  return ethers.toBeHex(value, 4);
}

function int32(value: bigint): string {
  return ethers.toBeHex(ethers.toTwos(value, 32), 4);
}

describe("Examples", () => {
  describe("Commands barrel", () => {
    it("builds and runs the single-input command example", async () => {
      const signer = await getSigner(0);
      const commander = await signer.getAddress();
      const host = await deploy("TestBasicCommandExampleHost", commander);
      const account = encodeUserAccount(commander);
      const asset = ethers.zeroPadValue("0x01", 32);

      const [output, transactions] = await host.myCommand.staticCall(
        encodeContextBlock(account, "0x", encodeAmountBlock(asset, 12n)),
      );

      expect(output).to.equal(encodeBalanceBlock(asset, 12n));
      expect(transactions).to.equal("0x");
    });

    it("builds and runs the batch command example", async () => {
      const signer = await getSigner(0);
      const commander = await signer.getAddress();
      const host = await deploy("TestBatchCommandExampleHost", commander);
      const account = encodeUserAccount(commander);
      const first = ethers.zeroPadValue("0x11", 32);
      const second = ethers.zeroPadValue("0x22", 32);

      const [output, transactions] = await host.myCommand.staticCall(
        encodeContextBlock(
          account,
          "0x",
          concat(encodeAmountBlock(first, 10n), encodeAmountBlock(second, 20n)),
        ),
      );

      expect(output).to.equal(concat(
        encodeBalanceBlock(first, 10n),
        encodeBalanceBlock(second, 20n),
      ));
      expect(transactions).to.equal("0x");
    });

    it("builds and runs the custom-data command example", async () => {
      const signer = await getSigner(0);
      const commander = await signer.getAddress();
      const host = await deploy("TestDataCommandExampleHost", commander);
      const account = encodeUserAccount(commander);
      const asset = ethers.zeroPadValue("0x33", 32);
      const target = 77n;
      const input = encodeBlock(Payment, concat(pad32(target), encodeAmountBlock(asset, 30n)));

      const context = encodeContextBlock(account, "0x", input);
      const [output, transactions] = await host.myCommand.staticCall(context);
      expect(output).to.equal(encodeCustodyBlock(target, asset, 30n));
      expect(transactions).to.equal("0x");
      await expect(host.myCommand(context))
        .to.emit(host, "SentToHost")
        .withArgs(target, asset, 30n);
    });

    it("builds and runs the custom-keyed top-level list example", async () => {
      const signer = await getSigner(0);
      const commander = await signer.getAddress();
      const host = await deploy("TestListCommandExampleHost", commander);
      const account = encodeUserAccount(commander);
      const first = ethers.zeroPadValue("0x44", 32);
      const second = ethers.zeroPadValue("0x55", 32);
      const listKey = localKey(1);
      const input = concat(
        encodeBlock(listKey, concat(encodeAssetBlock(first), encodeAssetBlock(second))),
        encodeBlock(listKey, encodeAssetBlock(first)),
      );

      const tx = host.myCommand(encodeContextBlock(account, "0x", input));
      await expect(tx).to.emit(host, "AssetSeen").withArgs(0n, first);
      await expect(tx).to.emit(host, "AssetSeen").withArgs(0n, second);
      await expect(tx).to.emit(host, "AssetSeen").withArgs(1n, first);
    });

  });

  describe("7-CustomInput", () => {
    it("decodes populated and empty child blocks with the custom unpack helper", async () => {
      const signer = await getSigner(0);
      const commander = await signer.getAddress();
      const host = await deploy("TestFrameExampleHost", commander);

      const account = encodeUserAccount(commander);
      const asset = ethers.zeroPadValue("0x01", 32);
      const amount = 123n;
      const status = 4n;
      const input = encodeBlock(Payment, concat(asset, pad32(amount), encodeStatusBlock(status)));

      await expect(host.myCommand(encodeContextBlock(account, "0x", input)))
        .to.emit(host, "PaymentSeen")
        .withArgs(asset, amount, status);

      const emptyStatus = encodeBlock(Payment, concat(asset, pad32(amount), encodeBlock(Keys.Status, "0x")));
      await expect(host.myCommand(encodeContextBlock(account, "0x", emptyStatus)))
        .to.emit(host, "PaymentSeen")
        .withArgs(asset, amount, 0n);

      const missingStatus = encodeBlock(Payment, concat(asset, pad32(amount)));
      await expect(host.myCommand(encodeContextBlock(account, "0x", missingStatus)))
        .to.be.revertedWithCustomError(host, "InvalidBlock");
    });
  });

  describe("8-Transactions", () => {
    it("returns one credit transaction for each input batch", async () => {
      const signer = await getSigner(0);
      const commander = await signer.getAddress();
      const host = await deploy("TestTransactionsExampleHost", commander);

      const account = encodeUserAccount(commander);
      const firstAsset = ethers.zeroPadValue("0x11", 32);
      const secondAsset = ethers.zeroPadValue("0x22", 32);
      const input = concat(
        encodeAmountBlock(firstAsset, 10n),
        encodeAmountBlock(secondAsset, 20n),
      );

      const [output, transactions] = await host.myCommand.staticCall(
        encodeContextBlock(account, "0x", input),
      );

      expect(output).to.equal("0x");
      expect(transactions).to.equal(concat(
        encodeTxBlock(ethers.ZeroHash, account, firstAsset, 10n),
        encodeTxBlock(ethers.ZeroHash, account, secondAsset, 20n),
      ));
    });
  });

  describe("9-Swap", () => {
    it("decodes swap configuration and its nested hop list", async () => {
      const signer = await getSigner(0);
      const commander = await signer.getAddress();
      const host = await deploy("TestSwapExampleHost", commander);
      const account = encodeUserAccount(commander);

      const asset = ethers.zeroPadValue("0x10", 32);
      const liability = ethers.zeroPadValue("0x20", 32);
      const firstHopAsset = ethers.zeroPadValue("0x30", 32);
      const secondHopAsset = ethers.zeroPadValue("0x40", 32);
      const hookData = "0xaabb";
      const firstHopData = "0xcc";

      const firstHop = encodeBlock(SwapHop, concat(
        firstHopAsset,
        uint32(500n),
        int32(-10n),
        pad32(11n),
        encodeBytesBlock(firstHopData),
      ));
      const secondHop = encodeBlock(SwapHop, concat(
        secondHopAsset,
        uint32(3000n),
        int32(60n),
        pad32(12n),
        encodeBytesBlock("0x"),
      ));
      const input = encodeBlock(Swap, concat(
        uint32(100n),
        int32(-5n),
        pad32(9n),
        encodeBytesBlock(hookData),
        encodePositionBlock(asset, 100n, liability, 25n),
        encodeListBlock(firstHop, secondHop),
      ));

      const [output, transactions] = await host.swap.staticCall(
        encodeContextBlock(account, "0x", input),
      );
      expect(output).to.equal("0x");
      expect(transactions).to.equal("0x");
    });
  });
});
