import { expect } from "chai";
import { ethers } from "ethers";
import { deploy, getSigner } from "./helpers/setup.js";
import "./helpers/matchers.js";
import {
  concat,
  encodeAssetBlock,
  encodeAmountBlock,
  encodeBalanceBlock,
  encodeBlock,
  encodeCustodyBlock,
  encodeListBlock,
  encodeStatusBlock,
  encodeTxBlock,
  encodeUserAccount,
  localKey,
  pad32,
} from "./helpers/blocks.js";

const Payment = localKey(1);

describe("Examples", () => {
  describe("Commands barrel", () => {
    it("builds and runs the single-input command example", async () => {
      const signer = await getSigner(0);
      const commander = await signer.getAddress();
      const host = await deploy("TestBasicCommandExampleHost", commander);
      const account = encodeUserAccount(commander);
      const asset = ethers.zeroPadValue("0x01", 32);

      const [output, transactions] = await host.myCommand.staticCall(
        account,
        "0x",
        encodeAmountBlock(asset, 12n),
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
        account,
        "0x",
        concat(encodeAmountBlock(first, 10n), encodeAmountBlock(second, 20n)),
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

      const [output, transactions] = await host.myCommand.staticCall(account, "0x", input);
      expect(output).to.equal(encodeCustodyBlock(target, asset, 30n));
      expect(transactions).to.equal("0x");
      await expect(host.myCommand(account, "0x", input))
        .to.emit(host, "SentToHost")
        .withArgs(target, asset, 30n);
    });

    it("builds and runs the nested-list command example", async () => {
      const signer = await getSigner(0);
      const commander = await signer.getAddress();
      const host = await deploy("TestListCommandExampleHost", commander);
      const account = encodeUserAccount(commander);
      const first = ethers.zeroPadValue("0x44", 32);
      const second = ethers.zeroPadValue("0x55", 32);
      const input = concat(
        encodeListBlock(concat(encodeAssetBlock(first), encodeAssetBlock(second))),
        encodeListBlock(encodeAssetBlock(first)),
      );

      const tx = host.myCommand(account, "0x", input);
      await expect(tx).to.emit(host, "AssetSeen").withArgs(0n, first);
      await expect(tx).to.emit(host, "AssetSeen").withArgs(0n, second);
      await expect(tx).to.emit(host, "AssetSeen").withArgs(1n, first);
    });
  });

  describe("7-CustomInput", () => {
    it("decodes a data input with the custom unpack helper", async () => {
      const signer = await getSigner(0);
      const commander = await signer.getAddress();
      const host = await deploy("TestFrameExampleHost", commander);

      const account = encodeUserAccount(commander);
      const asset = ethers.zeroPadValue("0x01", 32);
      const amount = 123n;
      const status = 4n;
      const input = encodeBlock(Payment, concat(asset, pad32(amount), encodeStatusBlock(status)));

      await expect(host.myCommand(account, "0x", input))
        .to.emit(host, "PaymentSeen")
        .withArgs(asset, amount, status);
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

      const [output, transactions] = await host.myCommand.staticCall(account, "0x", input);

      expect(output).to.equal("0x");
      expect(transactions).to.equal(concat(
        encodeTxBlock(ethers.ZeroHash, account, firstAsset, 10n),
        encodeTxBlock(ethers.ZeroHash, account, secondAsset, 20n),
      ));
    });
  });
});
