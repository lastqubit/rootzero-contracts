import { expect } from "chai";
import { deploy, getSigner } from "./helpers/setup.js";
import { concat, encodeRouteBlock } from "./helpers/blocks.js";
import "./helpers/matchers.js";

describe("Peer Commands", () => {
  let host: Awaited<ReturnType<typeof deploy>>;

  before(async () => {
    const signer = await getSigner(0);
    const commander = await signer.getAddress();
    host = await deploy("TestPeerHost", commander);
  });

  async function callAs(signerIndex: number, method: "peerPull(bytes)" | "peerPush(bytes)", request = "0x") {
    const signer = await getSigner(signerIndex);
    return (host.connect(signer) as any)[method](request);
  }

  describe("peerPull", () => {
    const method = "peerPull(bytes)";

    it("emits PeerPullCalled for a single ROUTE block", async () => {
      const route = "0xabcd";
      const tx = await callAs(0, method, encodeRouteBlock(route));
      await expect(tx).to.emit(host, "PeerPullCalled").withArgs(route);
    });

    it("emits PeerPullCalled for each ROUTE block when multiple are present", async () => {
      const route1 = "0x1111";
      const route2 = "0x2222";
      const tx = await callAs(0, method, concat(encodeRouteBlock(route1), encodeRouteBlock(route2)));
      await expect(tx).to.emit(host, "PeerPullCalled").withArgs(route1);
      await expect(tx).to.emit(host, "PeerPullCalled").withArgs(route2);
    });

    it("returns empty bytes after processing ROUTE blocks", async () => {
      const result: string = await (host as any)[method].staticCall(encodeRouteBlock("0x01"));
      expect(result).to.equal("0x");
    });

    it("reverts UnauthorizedCaller for an untrusted caller", async () => {
      await expect(callAs(1, method, encodeRouteBlock("0x01")))
        .to.be.revertedWithCustomError(host, "UnauthorizedCaller");
    });

    it("reverts NoResponse when request is empty", async () => {
      await expect(callAs(0, method))
        .to.be.revertedWithCustomError(host, "NoResponse");
    });
  });

  describe("peerPush", () => {
    const method = "peerPush(bytes)";

    it("emits PeerPushCalled for a single ROUTE block", async () => {
      const route = "0xbeef";
      const tx = await callAs(0, method, encodeRouteBlock(route));
      await expect(tx).to.emit(host, "PeerPushCalled").withArgs(route);
    });

    it("emits PeerPushCalled for each ROUTE block when multiple are present", async () => {
      const route1 = "0x3333";
      const route2 = "0x4444";
      const tx = await callAs(0, method, concat(encodeRouteBlock(route1), encodeRouteBlock(route2)));
      await expect(tx).to.emit(host, "PeerPushCalled").withArgs(route1);
      await expect(tx).to.emit(host, "PeerPushCalled").withArgs(route2);
    });

    it("returns empty bytes after processing ROUTE blocks", async () => {
      const result: string = await (host as any)[method].staticCall(encodeRouteBlock("0x01"));
      expect(result).to.equal("0x");
    });

    it("reverts UnauthorizedCaller for an untrusted caller", async () => {
      await expect(callAs(1, method, encodeRouteBlock("0x01")))
        .to.be.revertedWithCustomError(host, "UnauthorizedCaller");
    });

    it("reverts NoResponse when request is empty", async () => {
      await expect(callAs(0, method))
        .to.be.revertedWithCustomError(host, "NoResponse");
    });
  });
});
