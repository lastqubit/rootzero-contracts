import { expect } from "chai";
import { ethers } from "ethers";
import { deploy, getSigner, getProvider } from "./helpers/setup.js";
import {
  encodeNodeBlock, encodeAssetBlock, encodeAllocationBlock,
  encodeFundingBlock, encodeRouteBlock, concat
} from "./helpers/blocks.js";

describe("Admin Commands", () => {
  let host: Awaited<ReturnType<typeof deploy>>;
  let commander: string;
  let adminAccount: string;

  before(async () => {
    const signer = await getSigner(0);
    commander = await signer.getAddress();
    host = await deploy("TestHost", commander);
    adminAccount = await host.getAdminAccount();
  });

  function adminCtx(request: string, target = 0n) {
    return { target, account: adminAccount, state: "0x", request };
  }

  function userCtx(userAcc: string, request: string) {
    return { target: 0n, account: userAcc, state: "0x", request };
  }

  async function callAs(signerIndex: number, method: string, ...args: unknown[]) {
    const signer = await getSigner(signerIndex);
    return (host.connect(signer) as any)[method](...args);
  }

  // ── Authorize ─────────────────────────────────────────────────────────────

  describe("authorize", () => {
    it("authorizes a node and emits Access event", async () => {
      const nodeId = 0xaaa000n;
      const request = encodeNodeBlock(nodeId);
      await expect(callAs(0, "authorize", adminCtx(request)))
        .to.emit(host, "Access")
        .withArgs(await host.host(), nodeId, true);
      expect(await host.isAuthorized(nodeId)).to.be.true;
    });

    it("authorizes multiple nodes from multiple NODE blocks", async () => {
      const node1 = 0xbbb001n;
      const node2 = 0xbbb002n;
      const request = concat(encodeNodeBlock(node1), encodeNodeBlock(node2));
      await callAs(0, "authorize", adminCtx(request));
      expect(await host.isAuthorized(node1)).to.be.true;
      expect(await host.isAuthorized(node2)).to.be.true;
    });

    it("reverts NotAdmin for non-admin account", async () => {
      const fakeAdmin = ethers.zeroPadValue("0x01", 32);
      const request = encodeNodeBlock(1n);
      await expect(callAs(0, "authorize", userCtx(fakeAdmin, request)))
        .to.be.revertedWithCustomError(host, "NotAdmin");
    });

    it("reverts ZeroCursor for empty request", async () => {
      await expect(callAs(0, "authorize", adminCtx("0x")))
        .to.be.revertedWithCustomError(host, "ZeroCursor");
    });
  });

  describe("init", () => {
    it("emits InitCalled for a single input block", async () => {
      const inputData = "0x1234";
      await expect(callAs(0, "init", adminCtx(encodeRouteBlock(inputData))))
        .to.emit(host, "InitCalled")
        .withArgs(inputData);
    });

    it("accepts the explicit init command id as the target", async () => {
      const target = await host.getInitId();
      await expect(callAs(0, "init", adminCtx(encodeRouteBlock("0xab"), target)))
        .to.emit(host, "InitCalled");
    });

    it("reverts NotAdmin for non-admin account", async () => {
      const fakeAdmin = ethers.zeroPadValue("0x11", 32);
      await expect(callAs(0, "init", userCtx(fakeAdmin, encodeRouteBlock("0x01"))))
        .to.be.revertedWithCustomError(host, "NotAdmin");
    });

    it("reverts MalformedBlocks for empty request", async () => {
      await expect(callAs(0, "init", adminCtx("0x")))
        .to.be.revertedWithCustomError(host, "MalformedBlocks");
    });
  });

  // ── Unauthorize ───────────────────────────────────────────────────────────

  describe("unauthorize", () => {
    it("revokes node and emits Access event with false", async () => {
      const nodeId = 0xccc001n;
      // authorize first
      await callAs(0, "authorize", adminCtx(encodeNodeBlock(nodeId)));
      // then unauthorize
      await expect(callAs(0, "unauthorize", adminCtx(encodeNodeBlock(nodeId))))
        .to.emit(host, "Access")
        .withArgs(await host.host(), nodeId, false);
      expect(await host.isAuthorized(nodeId)).to.be.false;
    });

    it("reverts NotAdmin for non-admin account", async () => {
      const fakeAdmin = ethers.zeroPadValue("0x02", 32);
      const request = encodeNodeBlock(1n);
      await expect(callAs(0, "unauthorize", userCtx(fakeAdmin, request)))
        .to.be.revertedWithCustomError(host, "NotAdmin");
    });

    it("reverts ZeroCursor for empty request", async () => {
      await expect(callAs(0, "unauthorize", adminCtx("0x")))
        .to.be.revertedWithCustomError(host, "ZeroCursor");
    });
  });

  // ── AllowAssets ───────────────────────────────────────────────────────────

  describe("allowAssets", () => {
    it("emits AllowAssetCalled for each ASSET block", async () => {
      const asset = ethers.zeroPadValue("0x01", 32);
      const meta  = ethers.zeroPadValue("0x02", 32);
      const request = encodeAssetBlock(asset, meta);
      await expect(callAs(0, "allowAssets", adminCtx(request)))
        .to.emit(host, "AllowAssetCalled")
        .withArgs(asset, meta);
    });

    it("processes multiple ASSET blocks", async () => {
      const a1 = ethers.zeroPadValue("0xA1", 32);
      const a2 = ethers.zeroPadValue("0xA2", 32);
      const m  = ethers.ZeroHash;
      const request = concat(encodeAssetBlock(a1, m), encodeAssetBlock(a2, m));
      const tx = await callAs(0, "allowAssets", adminCtx(request));
      await expect(tx).to.emit(host, "AllowAssetCalled").withArgs(a1, m);
      await expect(tx).to.emit(host, "AllowAssetCalled").withArgs(a2, m);
    });

    it("reverts NotAdmin for non-admin account", async () => {
      const fakeAdmin = ethers.zeroPadValue("0x03", 32);
      await expect(callAs(0, "allowAssets", userCtx(fakeAdmin, encodeAssetBlock(ethers.zeroPadValue("0x01", 32), ethers.ZeroHash))))
        .to.be.revertedWithCustomError(host, "NotAdmin");
    });

    it("reverts ZeroCursor for empty request", async () => {
      await expect(callAs(0, "allowAssets", adminCtx("0x")))
        .to.be.revertedWithCustomError(host, "ZeroCursor");
    });
  });

  // ── DenyAssets ────────────────────────────────────────────────────────────

  describe("denyAssets", () => {
    it("emits DenyAssetCalled for each ASSET block", async () => {
      const asset = ethers.zeroPadValue("0x03", 32);
      const meta  = ethers.ZeroHash;
      await expect(callAs(0, "denyAssets", adminCtx(encodeAssetBlock(asset, meta))))
        .to.emit(host, "DenyAssetCalled")
        .withArgs(asset, meta);
    });

    it("reverts NotAdmin for non-admin", async () => {
      const fakeAdmin = ethers.zeroPadValue("0x04", 32);
      await expect(callAs(0, "denyAssets", userCtx(fakeAdmin, encodeAssetBlock(ethers.zeroPadValue("0x01", 32), ethers.ZeroHash))))
        .to.be.revertedWithCustomError(host, "NotAdmin");
    });

    it("reverts ZeroCursor for empty request", async () => {
      await expect(callAs(0, "denyAssets", adminCtx("0x")))
        .to.be.revertedWithCustomError(host, "ZeroCursor");
    });
  });

  // ── Allocate ─────────────────────────────────────────────────────────────

  describe("allocate", () => {
    it("emits AllocateCalled for each ALLOCATION block", async () => {
      const hostId = 9999n;
      const asset  = ethers.zeroPadValue("0x05", 32);
      const meta   = ethers.ZeroHash;
      const amount = 1000n;
      const request = encodeAllocationBlock(hostId, asset, meta, amount);
      await expect(callAs(0, "allocate", adminCtx(request)))
        .to.emit(host, "AllocateCalled")
        .withArgs(hostId, asset, meta, amount);
    });

    it("reverts NotAdmin for non-admin", async () => {
      const fakeAdmin = ethers.zeroPadValue("0x05", 32);
      const request = encodeAllocationBlock(1n, ethers.zeroPadValue("0x01", 32), ethers.ZeroHash, 1n);
      await expect(callAs(0, "allocate", userCtx(fakeAdmin, request)))
        .to.be.revertedWithCustomError(host, "NotAdmin");
    });

    it("reverts ZeroCursor for empty request", async () => {
      await expect(callAs(0, "allocate", adminCtx("0x")))
        .to.be.revertedWithCustomError(host, "ZeroCursor");
    });
  });

  // ── Relocate ──────────────────────────────────────────────────────────────

  describe("relocate", () => {
    it("reverts NotAdmin for non-admin account", async () => {
      const fakeAdmin = ethers.zeroPadValue("0x06", 32);
      const request = encodeFundingBlock(1n, 0n);
      await expect(callAs(0, "relocate", userCtx(fakeAdmin, request)))
        .to.be.revertedWithCustomError(host, "NotAdmin");
    });

    it("calls target host with ETH when authorized", async () => {
      // Deploy a second host as the relocation target
      const target = await deploy("TestHost", commander);
      const targetAddr = await target.getAddress();

      // Compute host ID for target
      const CHAIN_ID = 31337n; // Hardhat default
      const HOST_PREFIX = 0x20010201n;
      const targetHostId = (HOST_PREFIX << 224n) | (CHAIN_ID << 192n) | BigInt(targetAddr);

      // Authorize the target
      await callAs(0, "authorize", adminCtx(encodeNodeBlock(targetHostId)));

      const amount = ethers.parseEther("0.001");
      const request = encodeFundingBlock(targetHostId, amount);

      const provider = await getProvider();
      const tx = await callAs(0, "relocate", adminCtx(request), { value: amount });
      const receipt = await tx.wait();
      if (!receipt || receipt.status === 0) throw new Error("relocate tx reverted");
      const blockNum = receipt.blockNumber;
      const before = await provider.getBalance(targetAddr, blockNum - 1);
      const after = await provider.getBalance(targetAddr, blockNum);
      expect(after - before).to.equal(amount);
    });

    it("reverts UnauthorizedNode when target node not authorized", async () => {
      const unauthorizedNode = 0xdeaddeadn;
      const request = encodeFundingBlock(unauthorizedNode, 0n);
      await expect(callAs(0, "relocate", adminCtx(request)))
        .to.be.revertedWithCustomError(host, "UnauthorizedNode");
    });

    it("reverts FailedCall when the authorized target rejects ETH", async () => {
      const rejector = await deploy("TestRejectEther");
      const rejectorAddr = await rejector.getAddress();
      const provider = await getProvider();
      const network = await provider.getNetwork();
      const HOST_PREFIX = 0x20010201n;
      const rejectorHostId = (HOST_PREFIX << 224n) | (network.chainId << 192n) | BigInt(rejectorAddr);

      await callAs(0, "authorize", adminCtx(encodeNodeBlock(rejectorHostId)));

      const amount = 1n;
      await expect(
        callAs(0, "relocate", adminCtx(encodeFundingBlock(rejectorHostId, amount)), { value: amount })
      ).to.be.revertedWithCustomError(host, "FailedCall");
    });
  });

  describe("destroy", () => {
    it("emits DestroyCalled for a single input block", async () => {
      const inputData = "0xdead";
      await expect(callAs(0, "destroy", adminCtx(encodeRouteBlock(inputData))))
        .to.emit(host, "DestroyCalled")
        .withArgs(inputData);
    });

    it("accepts the explicit destroy command id as the target", async () => {
      const target = await host.getDestroyId();
      await expect(callAs(0, "destroy", adminCtx(encodeRouteBlock("0xcd"), target)))
        .to.emit(host, "DestroyCalled");
    });

    it("reverts NotAdmin for non-admin account", async () => {
      const fakeAdmin = ethers.zeroPadValue("0x12", 32);
      await expect(callAs(0, "destroy", userCtx(fakeAdmin, encodeRouteBlock("0x01"))))
        .to.be.revertedWithCustomError(host, "NotAdmin");
    });

    it("reverts MalformedBlocks for empty request", async () => {
      await expect(callAs(0, "destroy", adminCtx("0x")))
        .to.be.revertedWithCustomError(host, "MalformedBlocks");
    });
  });
});


