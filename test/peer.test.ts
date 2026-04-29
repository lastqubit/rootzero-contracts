import { expect } from "chai";
import { deploy, getProvider, getSigner } from "./helpers/setup.js";
import {
  concat,
  encodeAmountBlock,
  encodeNodeBlock,
  encodeTxBlock,
  encodeUserAccount,
} from "./helpers/blocks.js";
import { ethers } from "ethers";
import "./helpers/matchers.js";

describe("Peer Commands", () => {
  let host: Awaited<ReturnType<typeof deploy>>;

  before(async () => {
    const signer = await getSigner(0);
    const commander = await signer.getAddress();
    host = await deploy("TestPeerHost", commander);
    const trustedPeer = await callerHost(1);
    const adminAccount: string = await host.getAdminAccount();
    await host.authorize({ account: adminAccount, meta: ethers.ZeroHash, state: "0x", request: encodeNodeBlock(trustedPeer) });
  });

  it("emits Peer discovery events with id as the second argument", async () => {
    const tx = host.deploymentTransaction();
    expect(tx).to.not.equal(null);

    await expect(tx!)
      .to.emit(host, "Peer")
      .withArgs(
        await host.host(),
        await host.getPeerAllowanceId(),
        "peerAllowance",
        "amount(bytes32 asset, bytes32 meta, uint amount)",
        false,
      );
  });

  async function callAs(
    signerIndex: number,
    method: "peerAllowance(bytes)" | "peerAssetPull(bytes)" | "peerSettle(bytes)",
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

  describe("peerAllowance", () => {
    const method = "peerAllowance(bytes)";
    const asset = ethers.zeroPadValue("0xa0", 32);
    const meta = ethers.zeroPadValue("0xb0", 32);

    it("emits PeerAllowanceCalled for a single AMOUNT block scoped to the caller host", async () => {
      const peer = await callerHost(1);
      const tx = await callAs(1, method, encodeAmountBlock(asset, meta, 123n));
      await expect(tx).to.emit(host, "PeerAllowanceCalled").withArgs(peer, asset, meta, 123n);
    });

    it("emits PeerAllowanceCalled for each AMOUNT block when multiple are present", async () => {
      const peer = await callerHost(1);
      const asset2 = ethers.zeroPadValue("0xc0", 32);
      const tx = await callAs(
        1,
        method,
        concat(
          encodeAmountBlock(asset, meta, 123n),
          encodeAmountBlock(asset2, meta, 456n),
        )
      );
      await expect(tx).to.emit(host, "PeerAllowanceCalled").withArgs(peer, asset, meta, 123n);
      await expect(tx).to.emit(host, "PeerAllowanceCalled").withArgs(peer, asset2, meta, 456n);
    });

    it("returns empty bytes after processing amount blocks", async () => {
      const signer = await getSigner(1);
      const result: string = await (host.connect(signer) as any)[method].staticCall(encodeAmountBlock(asset, meta, 123n));
      expect(result).to.equal("0x");
    });

    it("reverts CommanderNotAllowed for the commander", async () => {
      await expect(callAs(0, method, encodeAmountBlock(asset, meta, 123n)))
        .to.be.revertedWithCustomError(host, "CommanderNotAllowed");
    });

    it("reverts UnauthorizedCaller for an untrusted caller", async () => {
      await expect(callAs(2, method, encodeAmountBlock(asset, meta, 123n)))
        .to.be.revertedWithCustomError(host, "UnauthorizedCaller");
    });

    it("reverts ZeroCursor when request is empty", async () => {
      await expect(callAs(1, method))
        .to.be.revertedWithCustomError(host, "ZeroCursor");
    });
  });

  describe("peerAssetPull", () => {
    const method = "peerAssetPull(bytes)";
    const asset = ethers.zeroPadValue("0xaa", 32);
    const meta = ethers.zeroPadValue("0xbb", 32);

    it("emits PeerAssetPullCalled for a single AMOUNT block", async () => {
      const peer = await callerHost(1);
      const tx = await callAs(1, method, encodeAmountBlock(asset, meta, 123n));
      await expect(tx).to.emit(host, "PeerAssetPullCalled").withArgs(peer, asset, meta, 123n);
    });

    it("emits PeerAssetPullCalled for each AMOUNT block when multiple are present", async () => {
      const peer = await callerHost(1);
      const asset2 = ethers.zeroPadValue("0xcc", 32);
      const tx = await callAs(
        1,
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
      const signer = await getSigner(1);
      const result: string = await (host.connect(signer) as any)[method].staticCall(encodeAmountBlock(asset, meta, 123n));
      expect(result).to.equal("0x");
    });

    it("reverts CommanderNotAllowed for the commander", async () => {
      await expect(callAs(0, method, encodeAmountBlock(asset, meta, 123n)))
        .to.be.revertedWithCustomError(host, "CommanderNotAllowed");
    });

    it("reverts UnauthorizedCaller for an untrusted caller", async () => {
      await expect(callAs(2, method, encodeAmountBlock(asset, meta, 123n)))
        .to.be.revertedWithCustomError(host, "UnauthorizedCaller");
    });

    it("reverts ZeroCursor when request is empty", async () => {
      await expect(callAs(1, method))
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
      const tx = await callAs(1, method, encodeTxBlock(from_, to_, asset, meta, 123n));
      await expect(tx).to.emit(host, "PeerSettleCalled").withArgs(from_, to_, asset, meta, 123n);
    });

    it("emits PeerSettleCalled for each TX block when multiple are present", async () => {
      const from2 = encodeUserAccount("0x33");
      const tx = await callAs(
        1,
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
      const signer = await getSigner(1);
      const result: string = await (host.connect(signer) as any)[method].staticCall(encodeTxBlock(from_, to_, asset, meta, 123n));
      expect(result).to.equal("0x");
    });

    it("reverts UnauthorizedCaller for an untrusted caller", async () => {
      await expect(callAs(2, method, encodeTxBlock(from_, to_, asset, meta, 123n)))
        .to.be.revertedWithCustomError(host, "UnauthorizedCaller");
    });

    it("reverts ZeroCursor when request is empty", async () => {
      await expect(callAs(1, method))
        .to.be.revertedWithCustomError(host, "ZeroCursor");
    });
  });
});


