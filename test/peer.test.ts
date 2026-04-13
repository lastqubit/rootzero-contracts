import { expect } from "chai";
import { deploy, getSigner } from "./helpers/setup.js";
import { concat, encodeRouteBlock, encodeTxBlock, encodeUserAccount } from "./helpers/blocks.js";
import { ethers } from "ethers";
import "./helpers/matchers.js";

describe("Peer Commands", () => {
  let host: Awaited<ReturnType<typeof deploy>>;

  before(async () => {
    const signer = await getSigner(0);
    const commander = await signer.getAddress();
    host = await deploy("TestPeerHost", commander);
  });

  async function callAs(
    signerIndex: number,
    method: "peerPull(bytes)" | "peerPush(bytes)" | "peerSettle(bytes)",
    request = "0x"
  ) {
    const signer = await getSigner(signerIndex);
    return (host.connect(signer) as any)[method](request);
  }

  describe("peerPull", () => {
    const method = "peerPull(bytes)";

    it("emits PeerPullCalled for a single input block", async () => {
      const inputData = "0xabcd";
      const tx = await callAs(0, method, encodeRouteBlock(inputData));
      await expect(tx).to.emit(host, "PeerPullCalled").withArgs(inputData);
    });

    it("emits PeerPullCalled for each input block when multiple are present", async () => {
      const input1 = "0x1111";
      const input2 = "0x2222";
      const tx = await callAs(0, method, concat(encodeRouteBlock(input1), encodeRouteBlock(input2)));
      await expect(tx).to.emit(host, "PeerPullCalled").withArgs(input1);
      await expect(tx).to.emit(host, "PeerPullCalled").withArgs(input2);
    });

    it("returns empty bytes after processing input blocks", async () => {
      const result: string = await (host as any)[method].staticCall(encodeRouteBlock("0x01"));
      expect(result).to.equal("0x");
    });

    it("reverts UnauthorizedCaller for an untrusted caller", async () => {
      await expect(callAs(1, method, encodeRouteBlock("0x01")))
        .to.be.revertedWithCustomError(host, "UnauthorizedCaller");
    });

    it("reverts ZeroCursor when request is empty", async () => {
      await expect(callAs(0, method))
        .to.be.revertedWithCustomError(host, "ZeroCursor");
    });
  });

  describe("peerPush", () => {
    const method = "peerPush(bytes)";

    it("emits PeerPushCalled for a single input block", async () => {
      const inputData = "0xbeef";
      const tx = await callAs(0, method, encodeRouteBlock(inputData));
      await expect(tx).to.emit(host, "PeerPushCalled").withArgs(inputData);
    });

    it("emits PeerPushCalled for each input block when multiple are present", async () => {
      const input1 = "0x3333";
      const input2 = "0x4444";
      const tx = await callAs(0, method, concat(encodeRouteBlock(input1), encodeRouteBlock(input2)));
      await expect(tx).to.emit(host, "PeerPushCalled").withArgs(input1);
      await expect(tx).to.emit(host, "PeerPushCalled").withArgs(input2);
    });

    it("returns empty bytes after processing input blocks", async () => {
      const result: string = await (host as any)[method].staticCall(encodeRouteBlock("0x01"));
      expect(result).to.equal("0x");
    });

    it("reverts UnauthorizedCaller for an untrusted caller", async () => {
      await expect(callAs(1, method, encodeRouteBlock("0x01")))
        .to.be.revertedWithCustomError(host, "UnauthorizedCaller");
    });

    it("reverts ZeroCursor when request is empty", async () => {
      await expect(callAs(0, method))
        .to.be.revertedWithCustomError(host, "ZeroCursor");
    });
  });

  describe("peerSettle", () => {
    const method = "peerSettle(bytes)";
    const from_ = encodeUserAccount("0x11");
    const to_ = encodeUserAccount("0x22");
    const asset = ethers.zeroPadValue("0xaa", 32);
    const meta = ethers.zeroPadValue("0xbb", 32);

    it("emits PeerSettleCalled for a single TX block", async () => {
      const tx = await callAs(0, method, encodeTxBlock(from_, to_, asset, meta, 123n));
      await expect(tx).to.emit(host, "PeerSettleCalled").withArgs(from_, to_, asset, meta, 123n);
    });

    it("emits PeerSettleCalled for each TX block when multiple are present", async () => {
      const from2 = encodeUserAccount("0x33");
      const tx = await callAs(
        0,
        method,
        concat(
          encodeTxBlock(from_, to_, asset, meta, 123n),
          encodeTxBlock(from2, to_, asset, meta, 456n),
        )
      );
      await expect(tx).to.emit(host, "PeerSettleCalled").withArgs(from_, to_, asset, meta, 123n);
      await expect(tx).to.emit(host, "PeerSettleCalled").withArgs(from2, to_, asset, meta, 456n);
    });

    it("returns empty bytes after processing tx blocks", async () => {
      const result: string = await (host as any)[method].staticCall(encodeTxBlock(from_, to_, asset, meta, 123n));
      expect(result).to.equal("0x");
    });

    it("reverts UnauthorizedCaller for an untrusted caller", async () => {
      await expect(callAs(1, method, encodeTxBlock(from_, to_, asset, meta, 123n)))
        .to.be.revertedWithCustomError(host, "UnauthorizedCaller");
    });

    it("reverts ZeroCursor when request is empty", async () => {
      await expect(callAs(0, method))
        .to.be.revertedWithCustomError(host, "ZeroCursor");
    });
  });
});


