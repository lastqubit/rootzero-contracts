import { expect } from "chai";
import { ethers } from "ethers";
import { deploy, getSigner } from "./helpers/setup.js";
import {
  encodeDispatchBlock,
  encodeNodeBlock,
  encodeRecoverBlock,
} from "./helpers/blocks.js";
import "./helpers/matchers.js";

describe("Portal", () => {
  async function commandCtx(host: any, request: string) {
    return {
      account: await host.getAdminAccount(),
      state: "0x",
      request,
    };
  }

  async function authorize(host: any, node: bigint) {
    await host.authorize(await commandCtx(host, encodeNodeBlock(node)));
  }

  async function deployPortal(handler: bigint) {
    const commander = await (await getSigner(0)).getAddress();
    return deploy("TestPortalRecoverHost", commander, handler);
  }

  async function deployPortHost() {
    const commander = await (await getSigner(0)).getAddress();
    return deploy("TestPortHost", commander);
  }

  it("delivers messages to the configured handler without recording undelivered state", async () => {
    const target = await deployPortHost();
    const handler: bigint = await target.getPortDispatchPayableId();
    const portal = await deployPortal(handler);

    await authorize(portal, handler);
    await authorize(target, await portal.host());

    const key = ethers.zeroPadValue("0x01", 32);
    const message = encodeDispatchBlock(0n, 2n, "0x1234");

    const tx = await portal.testDeliver(key, message, 7n, { value: 7n });

    await expect(tx).to.emit(target, "PortDispatchCalled").withArgs(0n, "0x1234", 2n, 7n);

    const request = encodeRecoverBlock(handler, 0n, key, message);
    await expect(portal.recoverPayable(await commandCtx(portal, request)))
      .to.be.revertedWithCustomError(portal, "BadWitness");
  });

  it("records undelivered messages when delivery fails", async () => {
    const target = await deployPortHost();
    const handler: bigint = await target.getPortDispatchPayableId();
    const portal = await deployPortal(handler);

    await authorize(portal, handler);

    const key = ethers.zeroPadValue("0x02", 32);
    const message = encodeDispatchBlock(0n, 3n, "0xabcd");
    const digest = ethers.keccak256(message);

    const tx = await portal.testDeliver(key, message, 0n);

    await expect(tx).to.emit(portal, "Undelivered").withArgs(await portal.host(), key, digest);
  });

  it("recovers a matching witness through the supplied handler and resolves the key", async () => {
    const failingTarget = await deployPortHost();
    const deliveryHandler: bigint = await failingTarget.getPortDispatchPayableId();
    const recoveryTarget = await deployPortHost();
    const recoveryHandler: bigint = await recoveryTarget.getPortDispatchPayableId();
    const portal = await deployPortal(deliveryHandler);

    await authorize(portal, deliveryHandler);
    await authorize(portal, recoveryHandler);
    await authorize(recoveryTarget, await portal.host());

    const key = ethers.zeroPadValue("0x03", 32);
    const witness = encodeDispatchBlock(0n, 9n, "0xcafe");
    await portal.testDeliver(key, witness, 0n);

    const request = encodeRecoverBlock(recoveryHandler, 5n, key, witness);
    const tx = await portal.recoverPayable(await commandCtx(portal, request), { value: 5n });

    await expect(tx).to.emit(recoveryTarget, "PortDispatchCalled").withArgs(0n, "0xcafe", 9n, 5n);
    await expect(tx).to.emit(portal, "Resolved").withArgs(await portal.host(), key);

    const second = encodeRecoverBlock(recoveryHandler, 0n, key, witness);
    await expect(portal.recoverPayable(await commandCtx(portal, second)))
      .to.be.revertedWithCustomError(portal, "BadWitness");
  });

  it("rejects recovery when the witness does not match the recorded digest", async () => {
    const failingTarget = await deployPortHost();
    const deliveryHandler: bigint = await failingTarget.getPortDispatchPayableId();
    const recoveryTarget = await deployPortHost();
    const recoveryHandler: bigint = await recoveryTarget.getPortDispatchPayableId();
    const portal = await deployPortal(deliveryHandler);

    await authorize(portal, deliveryHandler);
    await authorize(portal, recoveryHandler);
    await authorize(recoveryTarget, await portal.host());

    const key = ethers.zeroPadValue("0x04", 32);
    const witness = encodeDispatchBlock(0n, 1n, "0xaaaa");
    const badWitness = encodeDispatchBlock(0n, 1n, "0xbbbb");
    await portal.testDeliver(key, witness, 0n);

    const request = encodeRecoverBlock(recoveryHandler, 0n, key, badWitness);
    await expect(portal.recoverPayable(await commandCtx(portal, request)))
      .to.be.revertedWithCustomError(portal, "BadWitness");
  });
});
