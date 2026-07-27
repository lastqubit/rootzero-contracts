import { expect } from "chai";
import { ethers } from "ethers";
import { deploy, getSigner, portId } from "./helpers/setup.js";
import {
  encodeDispatchBlock,
  encodeNodeBlock,
  encodeRecoverBlock,
} from "./helpers/blocks.js";
import "./helpers/matchers.js";

describe("Portal", () => {
  async function commandCtx(host: any, request: string) {
    return [await host.getAdminAccount(), "0x", request] as const;
  }

  async function authorize(host: any, node: bigint) {
    await host.authorize(...await commandCtx(host, encodeNodeBlock(node)));
  }

  async function deployPortal() {
    const commander = await (await getSigner(0)).getAddress();
    return deploy("TestPortalRecoverHost", commander);
  }

  async function deployPortHost() {
    const commander = await (await getSigner(0)).getAddress();
    return deploy("TestPortHost", commander);
  }

  async function dispatchPort(host: Awaited<ReturnType<typeof deploy>>) {
    return portId(host.interface.getFunction("portDispatchPayable(bytes)")!.selector, host);
  }

  it("forwards messages to the configured handler without recording undelivered state", async () => {
    const target = await deployPortHost();
    const handler = await dispatchPort(target);
    const portal = await deployPortal();

    await authorize(portal, handler);
    await authorize(target, await portal.host());

    const key = ethers.zeroPadValue("0x01", 32);
    const message = encodeDispatchBlock(0n, 2n, "0x1234");

    const tx = await portal.testForward(handler, key, message, 7n, { value: 7n });

    await expect(tx).to.emit(target, "PortDispatchCalled").withArgs(0n, "0x1234", 2n, 7n);

    const request = encodeRecoverBlock(handler, 0n, key, message);
    await expect(portal.recoverPayable(...await commandCtx(portal, request)))
      .to.be.revertedWithCustomError(portal, "BadWitness");
  });

  it("records undelivered messages when forwarding fails", async () => {
    const target = await deployPortHost();
    const handler = await dispatchPort(target);
    const portal = await deployPortal();

    await authorize(portal, handler);

    const key = ethers.zeroPadValue("0x02", 32);
    const message = encodeDispatchBlock(0n, 3n, "0xabcd");
    const digest = ethers.keccak256(message);

    const tx = await portal.testForward(handler, key, message, 0n);

    await expect(tx).to.emit(portal, "Undelivered").withArgs(await portal.host(), key, digest);
  });

  it("recovers a matching witness through the supplied handler and resolves the key", async () => {
    const failingTarget = await deployPortHost();
    const forwardingHandler = await dispatchPort(failingTarget);
    const recoveryTarget = await deployPortHost();
    const recoveryHandler = await dispatchPort(recoveryTarget);
    const portal = await deployPortal();

    await authorize(portal, forwardingHandler);
    await authorize(portal, recoveryHandler);
    await authorize(recoveryTarget, await portal.host());

    const key = ethers.zeroPadValue("0x03", 32);
    const witness = encodeDispatchBlock(0n, 9n, "0xcafe");
    await portal.testForward(forwardingHandler, key, witness, 0n);

    const request = encodeRecoverBlock(recoveryHandler, 5n, key, witness);
    const tx = await portal.recoverPayable(...await commandCtx(portal, request), { value: 5n });

    await expect(tx).to.emit(recoveryTarget, "PortDispatchCalled").withArgs(0n, "0xcafe", 9n, 5n);

    const second = encodeRecoverBlock(recoveryHandler, 0n, key, witness);
    await expect(portal.recoverPayable(...await commandCtx(portal, second)))
      .to.be.revertedWithCustomError(portal, "BadWitness");
  });

  it("rejects recovery when the witness does not match the recorded digest", async () => {
    const failingTarget = await deployPortHost();
    const forwardingHandler = await dispatchPort(failingTarget);
    const recoveryTarget = await deployPortHost();
    const recoveryHandler = await dispatchPort(recoveryTarget);
    const portal = await deployPortal();

    await authorize(portal, forwardingHandler);
    await authorize(portal, recoveryHandler);
    await authorize(recoveryTarget, await portal.host());

    const key = ethers.zeroPadValue("0x04", 32);
    const witness = encodeDispatchBlock(0n, 1n, "0xaaaa");
    const badWitness = encodeDispatchBlock(0n, 1n, "0xbbbb");
    await portal.testForward(forwardingHandler, key, witness, 0n);

    const request = encodeRecoverBlock(recoveryHandler, 0n, key, badWitness);
    await expect(portal.recoverPayable(...await commandCtx(portal, request)))
      .to.be.revertedWithCustomError(portal, "BadWitness");
  });
});
