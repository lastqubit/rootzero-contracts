import { expect } from "chai";
import { ethers } from "ethers";
import { commandId, deploy, getSigner, getProvider } from "./helpers/setup.js";
import "./helpers/matchers.js";
import {
  Keys,
  endpointDescriptor,
  exactSpec,
  rangedSpec,
  encodeNodeBlock, encodeAccountBlock, encodeAssetBlock, encodeAllowanceBlock,
  encodeCallBlock, encodeLabelBlock, encodeSchemaBlock, concat
} from "./helpers/blocks.js";

describe("Admin Commands", () => {
  let host: Awaited<ReturnType<typeof deploy>>;
  let utils: Awaited<ReturnType<typeof deploy>>;
  let commander: string;
  let adminAccount: string;

  before(async () => {
    const signer = await getSigner(0);
    commander = await signer.getAddress();
    host = await deploy("TestHost", commander);
    utils = await deploy("TestUtils");
    adminAccount = await host.getAdminAccount();
  });

  function adminCtx(input: string) {
    return [adminAccount, "0x", input] as const;
  }

  function userCtx(userAcc: string, input: string) {
    return [userAcc, "0x", input] as const;
  }

  async function callAs(signerIndex: number, method: string, ...args: unknown[]) {
    const signer = await getSigner(signerIndex);
    const callArgs = Array.isArray(args[0]) ? [...args[0], ...args.slice(1)] : args;
    return (host.connect(signer) as any)[method](...callArgs);
  }

  async function hostIdFor(addr: string) {
    const provider = await getProvider();
    const network = await provider.getNetwork();
    const HOST_PREFIX = 0x01200202n;
    return (HOST_PREFIX << 224n) | (network.chainId << 192n) | BigInt(addr);
  }

  async function cmd(method: string) {
    return commandId(host.interface.getFunction(method)!.selector, host);
  }

  // â”€â”€ Authorize â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  describe("authorize", () => {
    it("exposes its command id internally", async () => {
      expect(await host.testAuthorizeId()).to.equal(await cmd("authorize"));
    });

    it("authorizes a node and emits Node event", async () => {
      const nodeId = 0xaaa000n;
      const request = encodeNodeBlock(nodeId);
      await expect(callAs(0, "authorize", adminCtx(request)))
        .to.emit(host, "Node")
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

    it("reverts AccessDenied when a trusted non-commander tries to authorize", async () => {
      const trustedSigner = await getSigner(1);
      const trustedAddress = await trustedSigner.getAddress();
      await callAs(0, "authorize", adminCtx(encodeNodeBlock(await hostIdFor(trustedAddress))));

      await expect(callAs(1, "authorize", adminCtx(encodeNodeBlock(0xddd001n))))
        .to.be.revertedWithCustomError(host, "AccessDenied");
    });

    it("reverts AccessDenied for non-admin account", async () => {
      const fakeAdmin = ethers.zeroPadValue("0x01", 32);
      const request = encodeNodeBlock(1n);
      await expect(callAs(0, "authorize", userCtx(fakeAdmin, request)))
        .to.be.revertedWithCustomError(host, "AccessDenied");
    });

    it("reverts ZeroCursor for empty request", async () => {
      await expect(callAs(0, "authorize", adminCtx("0x")))
        .to.be.revertedWithCustomError(host, "ZeroCursor");
    });
  });

  // â”€â”€ Unauthorize â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  describe("unauthorize", () => {
    it("exposes its command id internally", async () => {
      expect(await host.testUnauthorizeId()).to.equal(await cmd("unauthorize"));
    });

    it("revokes node and emits Node event with false", async () => {
      const nodeId = 0xccc001n;
      // authorize first
      await callAs(0, "authorize", adminCtx(encodeNodeBlock(nodeId)));
      // then unauthorize
      await expect(callAs(0, "unauthorize", adminCtx(encodeNodeBlock(nodeId))))
        .to.emit(host, "Node")
        .withArgs(await host.host(), nodeId, false);
      expect(await host.isAuthorized(nodeId)).to.be.false;
    });

    it("reverts AccessDenied for non-admin account", async () => {
      const fakeAdmin = ethers.zeroPadValue("0x02", 32);
      const request = encodeNodeBlock(1n);
      await expect(callAs(0, "unauthorize", userCtx(fakeAdmin, request)))
        .to.be.revertedWithCustomError(host, "AccessDenied");
    });

    it("reverts ZeroCursor for empty request", async () => {
      await expect(callAs(0, "unauthorize", adminCtx("0x")))
        .to.be.revertedWithCustomError(host, "ZeroCursor");
    });
  });

  describe("appoint", () => {
    it("enables guardian account and emits Guardian event", async () => {
      const guardianAddress = await (await getSigner(2)).getAddress();
      const guardianAccount = await utils.testToGuardianAccount(guardianAddress);
      const request = encodeAccountBlock(guardianAccount);

      await expect(callAs(0, "appoint", adminCtx(request)))
        .to.emit(host, "Guardian")
        .withArgs(await host.host(), guardianAccount, true);

      expect(await host.isGuardianAddress(guardianAddress)).to.be.true;
    });

    it("reverts AccessDenied for non-admin account", async () => {
      const fakeAdmin = ethers.zeroPadValue("0x13", 32);
      const guardianAccount = await utils.testToGuardianAccount(await (await getSigner(2)).getAddress());

      await expect(callAs(0, "appoint", userCtx(fakeAdmin, encodeAccountBlock(guardianAccount))))
        .to.be.revertedWithCustomError(host, "AccessDenied");
    });

    it("reverts InvalidAccount for non-guardian account blocks", async () => {
      const userAccount = await utils.testToUserAccount(await (await getSigner(2)).getAddress());

      await expect(callAs(0, "appoint", adminCtx(encodeAccountBlock(userAccount))))
        .to.be.revertedWithCustomError(host, "InvalidAccount");
    });

    it("reverts ZeroCursor for empty request", async () => {
      await expect(callAs(0, "appoint", adminCtx("0x")))
        .to.be.revertedWithCustomError(host, "ZeroCursor");
    });
  });

  describe("dismiss", () => {
    it("disables guardian account and emits Guardian event with false", async () => {
      const guardianAddress = await (await getSigner(3)).getAddress();
      const guardianAccount = await utils.testToGuardianAccount(guardianAddress);
      const request = encodeAccountBlock(guardianAccount);

      await callAs(0, "appoint", adminCtx(request));

      await expect(callAs(0, "dismiss", adminCtx(request)))
        .to.emit(host, "Guardian")
        .withArgs(await host.host(), guardianAccount, false);

      expect(await host.isGuardianAddress(guardianAddress)).to.be.false;
    });

    it("reverts AccessDenied for non-admin account", async () => {
      const fakeAdmin = ethers.zeroPadValue("0x14", 32);
      const guardianAccount = await utils.testToGuardianAccount(await (await getSigner(3)).getAddress());

      await expect(callAs(0, "dismiss", userCtx(fakeAdmin, encodeAccountBlock(guardianAccount))))
        .to.be.revertedWithCustomError(host, "AccessDenied");
    });

    it("reverts ZeroCursor for empty request", async () => {
      await expect(callAs(0, "dismiss", adminCtx("0x")))
        .to.be.revertedWithCustomError(host, "ZeroCursor");
    });
  });

  // â”€â”€ AllowAssets â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  describe("allowAssets", () => {
    it("emits AllowAssetCalled for each ASSET block", async () => {
      const asset = ethers.zeroPadValue("0x01", 32);
      const request = encodeAssetBlock(asset);
      await expect(callAs(0, "allowAssets", adminCtx(request)))
        .to.emit(host, "AllowAssetCalled")
        .withArgs(asset);
    });

    it("processes multiple ASSET blocks", async () => {
      const a1 = ethers.zeroPadValue("0xA1", 32);
      const a2 = ethers.zeroPadValue("0xA2", 32);
      const request = concat(encodeAssetBlock(a1), encodeAssetBlock(a2));
      const tx = await callAs(0, "allowAssets", adminCtx(request));
      await expect(tx).to.emit(host, "AllowAssetCalled").withArgs(a1);
      await expect(tx).to.emit(host, "AllowAssetCalled").withArgs(a2);
    });

    it("reverts AccessDenied for non-admin account", async () => {
      const fakeAdmin = ethers.zeroPadValue("0x03", 32);
      await expect(callAs(0, "allowAssets", userCtx(fakeAdmin, encodeAssetBlock(ethers.zeroPadValue("0x01", 32)))))
        .to.be.revertedWithCustomError(host, "AccessDenied");
    });

    it("reverts ZeroCursor for empty request", async () => {
      await expect(callAs(0, "allowAssets", adminCtx("0x")))
        .to.be.revertedWithCustomError(host, "ZeroCursor");
    });
  });

  // â”€â”€ DenyAssets â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  describe("denyAssets", () => {
    it("emits DenyAssetCalled for each ASSET block", async () => {
      const asset = ethers.zeroPadValue("0x03", 32);
      await expect(callAs(0, "denyAssets", adminCtx(encodeAssetBlock(asset))))
        .to.emit(host, "DenyAssetCalled")
        .withArgs(asset);
    });

    it("reverts AccessDenied for non-admin", async () => {
      const fakeAdmin = ethers.zeroPadValue("0x04", 32);
      await expect(callAs(0, "denyAssets", userCtx(fakeAdmin, encodeAssetBlock(ethers.zeroPadValue("0x01", 32)))))
        .to.be.revertedWithCustomError(host, "AccessDenied");
    });

    it("reverts ZeroCursor for empty request", async () => {
      await expect(callAs(0, "denyAssets", adminCtx("0x")))
        .to.be.revertedWithCustomError(host, "ZeroCursor");
    });
  });

  // â”€â”€ Allowance â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  describe("allowance", () => {
    it("emits AllowanceCalled for each ALLOWANCE block", async () => {
      const hostId = 9999n;
      const asset  = ethers.zeroPadValue("0x05", 32);
      const amount = 1000n;
      const request = encodeAllowanceBlock(hostId, asset, amount);
      await expect(callAs(0, "allowance", adminCtx(request)))
        .to.emit(host, "AllowanceCalled")
        .withArgs(hostId, asset, amount);
    });

    it("reverts AccessDenied for non-admin", async () => {
      const fakeAdmin = ethers.zeroPadValue("0x05", 32);
      const request = encodeAllowanceBlock(1n, ethers.zeroPadValue("0x01", 32), 1n);
      await expect(callAs(0, "allowance", userCtx(fakeAdmin, request)))
        .to.be.revertedWithCustomError(host, "AccessDenied");
    });

    it("reverts ZeroCursor for empty request", async () => {
      await expect(callAs(0, "allowance", adminCtx("0x")))
        .to.be.revertedWithCustomError(host, "ZeroCursor");
    });
  });

  describe("label", () => {
    it("discovers label and publishes its default label", async () => {
      const deployment = host.deploymentTransaction();
      expect(deployment).to.not.equal(null);

      await expect(deployment!).to.emit(host, "Endpoint")
        .withArgs(
          await host.host(),
          await cmd("label"),
          endpointDescriptor({ input: Keys.Label, admin: true }),
        );
      await expect(deployment!).to.emit(host, "Labeled")
        .withArgs(await cmd("label"), ethers.ZeroHash, "label");
    });

    it("emits Labeled for each LABEL block", async () => {
      const namespace = ethers.encodeBytes32String("docs");
      const request = concat(
        encodeLabelBlock(await cmd("deposit"), namespace, "deposit v2"),
        encodeLabelBlock(await cmd("relayPayable"), ethers.ZeroHash, "relay")
      );

      const tx = await callAs(0, "label", adminCtx(request));
      await expect(tx).to.emit(host, "Labeled")
        .withArgs(await cmd("deposit"), namespace, "deposit v2");
      await expect(tx).to.emit(host, "Labeled")
        .withArgs(await cmd("relayPayable"), ethers.ZeroHash, "relay");
    });

    it("reverts AccessDenied for non-admin account", async () => {
      const fakeAdmin = ethers.zeroPadValue("0x06", 32);
      const request = encodeLabelBlock(await cmd("deposit"), ethers.ZeroHash, "deposit");

      await expect(callAs(0, "label", userCtx(fakeAdmin, request)))
        .to.be.revertedWithCustomError(host, "AccessDenied");
    });

    it("reverts ZeroCursor for empty request", async () => {
      await expect(callAs(0, "label", adminCtx("0x")))
        .to.be.revertedWithCustomError(host, "ZeroCursor");
    });
  });

  describe("publishSchema", () => {
    it("discovers publishSchema and publishes its default label", async () => {
      const deployment = host.deploymentTransaction();
      expect(deployment).to.not.equal(null);

      await expect(deployment!).to.emit(host, "Endpoint")
        .withArgs(
          await host.host(),
          await cmd("publishSchema"),
          endpointDescriptor({ input: Keys.Schema, admin: true }),
        );
      await expect(deployment!).to.emit(host, "Labeled")
        .withArgs(await cmd("publishSchema"), ethers.ZeroHash, "publishSchema");
    });

    it("emits Schema for each SCHEMA block", async () => {
      const amountName = ethers.encodeBytes32String("amount");
      const localName = ethers.encodeBytes32String("payment");
      const amountSchema = "{ bytes32 asset, uint amount }";
      const localSchema = "{ #bytes as left, uint op, #bytes as right }";
      const localKey = "0x00000001";
      const amountSpec = exactSpec(Keys.Amount, 64);
      const localSpec = rangedSpec(localKey, 48, 0, 128);
      const request = concat(
        encodeSchemaBlock(amountSpec, amountSchema, amountName),
        encodeSchemaBlock(localSpec, localSchema, localName),
      );

      const tx = await callAs(0, "publishSchema", adminCtx(request));
      await expect(tx).to.emit(host, "Schema")
        .withArgs(await host.host(), amountSpec, amountSchema, amountName);
      await expect(tx).to.emit(host, "Schema")
        .withArgs(await host.host(), localSpec, localSchema, localName);
    });

    it("reverts AccessDenied for non-admin account", async () => {
      const fakeAdmin = ethers.zeroPadValue("0x16", 32);
      const request = encodeSchemaBlock(
        exactSpec(Keys.Amount, 64),
        "{ bytes32 asset, uint amount }",
        ethers.encodeBytes32String("amount"),
      );

      await expect(callAs(0, "publishSchema", userCtx(fakeAdmin, request)))
        .to.be.revertedWithCustomError(host, "AccessDenied");
    });

    it("reverts ZeroCursor for empty request", async () => {
      await expect(callAs(0, "publishSchema", adminCtx("0x")))
        .to.be.revertedWithCustomError(host, "ZeroCursor");
    });
  });

  describe("executePayable", () => {
    it("reverts AccessDenied for non-admin account", async () => {
      const fakeAdmin = ethers.zeroPadValue("0x07", 32);
      const request = encodeCallBlock(0n, 0n, "0x");
      await expect(callAs(0, "executePayable", userCtx(fakeAdmin, request)))
        .to.be.revertedWithCustomError(host, "AccessDenied");
    });

    it("executes raw calldata against a target node without prior authorization", async () => {
      const target = await deploy("TestExecuteTarget");
      const targetId = await hostIdFor(await target.getAddress());
      const calldata = target.interface.encodeFunctionData("ping", [123n, "0x123456"]);
      const request = encodeCallBlock(targetId, 0n, calldata);

      await expect(callAs(0, "executePayable", adminCtx(request)))
        .to.emit(target, "Ping")
        .withArgs(await host.getAddress(), 0n, 123n, "0x123456");
    });

    it("can govern another host through its commander host", async () => {
      const source = await deploy("TestCommanderHost", commander);
      const sourceAdminAccount = await source.getAdminAccount();
      const target = await deploy("TestHost", await source.getAddress());

      const asset = ethers.zeroPadValue("0x123456", 32);
      const targetArgs = [await target.getAdminAccount(), "0x", encodeAssetBlock(asset)];
      const calldata = target.interface.encodeFunctionData("allowAssets", targetArgs);
      const request = encodeCallBlock(await hostIdFor(await target.getAddress()), 0n, calldata);

      await expect(source.executePayable(sourceAdminAccount, "0x", request))
        .to.emit(target, "AllowAssetCalled")
        .withArgs(asset);
    });

    it("processes multiple CALL blocks in one request", async () => {
      const source = await deploy("TestCommanderHost", commander);
      const sourceAdminAccount = await source.getAdminAccount();
      const targetA = await deploy("TestHost", await source.getAddress());
      const targetB = await deploy("TestHost", await source.getAddress());
      const assetA = ethers.zeroPadValue("0xaa", 32);
      const assetB = ethers.zeroPadValue("0xbb", 32);

      const calldataA = targetA.interface.encodeFunctionData(
        "allowAssets",
        [await targetA.getAdminAccount(), "0x", encodeAssetBlock(assetA)]
      );
      const calldataB = targetB.interface.encodeFunctionData(
        "denyAssets",
        [await targetB.getAdminAccount(), "0x", encodeAssetBlock(assetB)]
      );

      const tx = await source.executePayable(sourceAdminAccount, "0x", concat(
        encodeCallBlock(await hostIdFor(await targetA.getAddress()), 0n, calldataA),
        encodeCallBlock(await hostIdFor(await targetB.getAddress()), 0n, calldataB)
      ));

      await expect(tx).to.emit(targetA, "AllowAssetCalled").withArgs(assetA);
      await expect(tx).to.emit(targetB, "DenyAssetCalled").withArgs(assetB);
    });

    it("can forward native value to a target node without prior authorization", async () => {
      const target = await deploy("TestExecuteTarget");
      const amount = 5n;
      const targetId = await hostIdFor(await target.getAddress());
      const calldata = target.interface.encodeFunctionData("ping", [1n, "0xab"]);
      const request = encodeCallBlock(targetId, amount, calldata);

      await expect(callAs(0, "executePayable", adminCtx(request), { value: amount }))
        .to.emit(target, "Ping")
        .withArgs(await host.getAddress(), amount, 1n, "0xab");
    });

    it("keeps unspent admin value on the host", async () => {
      const target = await deploy("TestExecuteTarget");
      const amount = 5n;
      const surplus = 7n;
      const targetId = await hostIdFor(await target.getAddress());
      const calldata = target.interface.encodeFunctionData("ping", [2n, "0xcd"]);
      const request = encodeCallBlock(targetId, amount, calldata);

      const provider = await getProvider();
      const hostAddr = await host.getAddress();
      const targetAddr = await target.getAddress();
      const tx = await callAs(0, "executePayable", adminCtx(request), { value: amount + surplus });
      const receipt = await tx.wait();
      if (!receipt || receipt.status === 0) throw new Error("executePayable tx reverted");
      const hostBefore = await provider.getBalance(hostAddr, receipt.blockNumber - 1);
      const hostAfter = await provider.getBalance(hostAddr, receipt.blockNumber);
      const targetBefore = await provider.getBalance(targetAddr, receipt.blockNumber - 1);
      const targetAfter = await provider.getBalance(targetAddr, receipt.blockNumber);

      expect(hostAfter - hostBefore).to.equal(surplus);
      expect(targetAfter - targetBefore).to.equal(amount);
    });

    it("can replace relocate by sending native value with empty calldata to a host", async () => {
      const target = await deploy("TestHost", commander);
      const targetAddr = await target.getAddress();
      const targetId = await hostIdFor(targetAddr);
      const amount = ethers.parseEther("0.001");
      const request = encodeCallBlock(targetId, amount, "0x");

      const provider = await getProvider();
      const tx = await callAs(0, "executePayable", adminCtx(request), { value: amount });
      const receipt = await tx.wait();
      if (!receipt || receipt.status === 0) throw new Error("executePayable tx reverted");
      const before = await provider.getBalance(targetAddr, receipt.blockNumber - 1);
      const after = await provider.getBalance(targetAddr, receipt.blockNumber);

      expect(after - before).to.equal(amount);
    });

    it("reverts FailedCall when the raw target call reverts", async () => {
      const target = await deploy("TestRejectEther");
      const targetId = await hostIdFor(await target.getAddress());

      await expect(callAs(0, "executePayable", adminCtx(encodeCallBlock(targetId, 1n, "0x")), { value: 1n }))
        .to.be.revertedWithCustomError(host, "FailedCall");
    });
  });

});



