import { expect } from "chai";
import { deploy, getProvider, getSigner } from "./helpers/setup.js";
import { concat, encodeAmountBlock, encodeRouteBlock, encodeTxBlock, encodeUserAccount } from "./helpers/blocks.js";
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
    method: "peerAssetPull(bytes)" | "peerPull(bytes)" | "peerPush(bytes)" | "peerSettle(bytes)",
    request = "0x"
  ) {
    const signer = await getSigner(signerIndex);
    return (host.connect(signer) as any)[method](request);
  }

  async function callerHost(signerIndex: number) {
    const signer = await getSigner(signerIndex);
    const addr = await signer.getAddress();
    const provider = await getProvider();
    const network = await provider.getNetwork();
    const HOST_PREFIX = 0x20010201n;
    return (HOST_PREFIX << 224n) | (network.chainId << 192n) | BigInt(addr);
  }

  describe("peerAssetPull", () => {
    const method = "peerAssetPull(bytes)";
    const asset = ethers.zeroPadValue("0xaa", 32);
    const meta = ethers.zeroPadValue("0xbb", 32);

    it("emits PeerAssetPullCalled for a single AMOUNT block", async () => {
      const peer = await callerHost(0);
      const tx = await callAs(0, method, encodeAmountBlock(asset, meta, 123n));
      await expect(tx).to.emit(host, "PeerAssetPullCalled").withArgs(peer, asset, meta, 123n);
    });

    it("emits PeerAssetPullCalled for each AMOUNT block when multiple are present", async () => {
      const peer = await callerHost(0);
      const asset2 = ethers.zeroPadValue("0xcc", 32);
      const tx = await callAs(
        0,
        method,
        concat(
          encodeAmountBlock(asset, meta, 123n),
          encodeAmountBlock(asset2, meta, 456n),
        )
      );
      await expect(tx).to.emit(host, "PeerAssetPullCalled").withArgs(peer, asset, meta, 123n);
      await expect(tx).to.emit(host, "PeerAssetPullCalled").withArgs(peer, asset2, meta, 456n);
    });

    it("returns empty bytes after processing amount blocks", async () => {
      const result: string = await (host as any)[method].staticCall(encodeAmountBlock(asset, meta, 123n));
      expect(result).to.equal("0x");
    });

    it("reverts UnauthorizedCaller for an untrusted caller", async () => {
      await expect(callAs(1, method, encodeAmountBlock(asset, meta, 123n)))
        .to.be.revertedWithCustomError(host, "UnauthorizedCaller");
    });

    it("reverts ZeroCursor when request is empty", async () => {
      await expect(callAs(0, method))
        .to.be.revertedWithCustomError(host, "ZeroCursor");
    });
  });

  describe("peerPull", () => {
    const method = "peerPull(bytes)";

    it("emits PeerPullCalled for a single input block", async () => {
      const inputData = "0xabcd";
      const peer = await callerHost(0);
      const tx = await callAs(0, method, encodeRouteBlock(inputData));
      await expect(tx).to.emit(host, "PeerPullCalled").withArgs(peer, inputData);
    });

    it("emits PeerPullCalled for each input block when multiple are present", async () => {
      const input1 = "0x1111";
      const input2 = "0x2222";
      const peer = await callerHost(0);
      const tx = await callAs(0, method, concat(encodeRouteBlock(input1), encodeRouteBlock(input2)));
      await expect(tx).to.emit(host, "PeerPullCalled").withArgs(peer, input1);
      await expect(tx).to.emit(host, "PeerPullCalled").withArgs(peer, input2);
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
      const peer = await callerHost(0);
      const tx = await callAs(0, method, encodeRouteBlock(inputData));
      await expect(tx).to.emit(host, "PeerPushCalled").withArgs(peer, inputData);
    });

    it("emits PeerPushCalled for each input block when multiple are present", async () => {
      const input1 = "0x3333";
      const input2 = "0x4444";
      const peer = await callerHost(0);
      const tx = await callAs(0, method, concat(encodeRouteBlock(input1), encodeRouteBlock(input2)));
      await expect(tx).to.emit(host, "PeerPushCalled").withArgs(peer, input1);
      await expect(tx).to.emit(host, "PeerPushCalled").withArgs(peer, input2);
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


