import { expect } from "chai";
import { ethers } from "ethers";
import { deploy, getSigner, getSigners } from "./helpers/setup.js";
import { encodeNodeBlock, pad32 } from "./helpers/blocks.js";

describe("Access Control", () => {
  let host: Awaited<ReturnType<typeof deploy>>;
  let commander: string;
  let stranger: string;
  let hostAddress: string;

  before(async () => {
    const signers = await getSigners(3);
    commander = await signers[0].getAddress();
    stranger  = await signers[1].getAddress();

    host = await deploy("TestHost", commander);
    hostAddress = await host.getAddress();
  });

  it("host ID is derived from contract address", async () => {
    const hostId: bigint = await host.host();
    // Lower 160 bits should be the contract address
    const embedded = hostId & ((1n << 160n) - 1n);
    expect("0x" + embedded.toString(16).padStart(40, "0"))
      .to.equal(hostAddress.toLowerCase());
  });

  it("adminAccount encodes commander address", async () => {
    const adminAccount: string = await host.getAdminAccount();
    const val = BigInt(adminAccount);
    const embedded = (val >> 32n) & ((1n << 160n) - 1n);
    expect("0x" + embedded.toString(16).padStart(40, "0"))
      .to.equal(commander.toLowerCase());
  });

  it("commander is trusted", async () => {
    // Commander can call trusted-only functions without reverting.
    // We test by calling authorize with zero request from commander (should revert ZeroCursor, not Unauthorized).
    const adminAccount: string = await host.getAdminAccount();
    const ctx = { account: adminAccount, meta: ethers.ZeroHash, state: "0x", request: "0x" };
    const signers = await getSigners(1);
    await expect(
      host.connect(signers[0]).authorize(ctx)
    ).to.be.revertedWithCustomError(host, "ZeroCursor");
  });

  it("stranger is not trusted and gets UnauthorizedCaller", async () => {
    const adminAccount: string = await host.getAdminAccount();
    const ctx = { account: adminAccount, meta: ethers.ZeroHash, state: "0x", request: "0x" };
    const signers = await getSigners(2);
    await expect(
      host.connect(signers[1]).authorize(ctx)
    ).to.be.revertedWithCustomError(host, "UnauthorizedCaller");
  });

  it("authorize emits Access event with allow=true", async () => {
    const signers = await getSigners(1);
    const adminAccount: string = await host.getAdminAccount();
    const dummyNode = 0xdeadbeefn << 192n; // some non-zero node id
    const nodeBlock = encodeNodeBlock(dummyNode);
    const ctx = { account: adminAccount, meta: ethers.ZeroHash, state: "0x", request: nodeBlock };

    await expect(host.connect(signers[0]).authorize(ctx))
      .to.emit(host, "Access")
      .withArgs(await host.host(), dummyNode, true);
  });

  it("node is authorized after authorize call", async () => {
    const signers = await getSigners(1);
    const adminAccount: string = await host.getAdminAccount();
    const dummyNode = 0xcafebaben << 192n;
    const nodeBlock = encodeNodeBlock(dummyNode);
    const ctx = { account: adminAccount, meta: ethers.ZeroHash, state: "0x", request: nodeBlock };
    await host.connect(signers[0]).authorize(ctx);
    expect(await host.isAuthorized(dummyNode)).to.be.true;
  });

  it("unauthorize emits Access event with allow=false", async () => {
    const signers = await getSigners(1);
    const adminAccount: string = await host.getAdminAccount();
    const dummyNode = 0x11111111n << 192n;
    // First authorize
    await host.connect(signers[0]).authorize({ account: adminAccount, meta: ethers.ZeroHash, state: "0x", request: encodeNodeBlock(dummyNode) });
    // Then unauthorize
    await expect(
      host.connect(signers[0]).unauthorize({ account: adminAccount, meta: ethers.ZeroHash, state: "0x", request: encodeNodeBlock(dummyNode) })
    ).to.emit(host, "Access").withArgs(await host.host(), dummyNode, false);
  });

  it("node is not authorized after unauthorize call", async () => {
    const signers = await getSigners(1);
    const adminAccount: string = await host.getAdminAccount();
    const dummyNode = 0x22222222n << 192n;
    await host.connect(signers[0]).authorize({ account: adminAccount, meta: ethers.ZeroHash, state: "0x", request: encodeNodeBlock(dummyNode) });
    await host.connect(signers[0]).unauthorize({ account: adminAccount, meta: ethers.ZeroHash, state: "0x", request: encodeNodeBlock(dummyNode) });
    expect(await host.isAuthorized(dummyNode)).to.be.false;
  });

  it("isAuthorized mapping returns false for node 0", async () => {
    expect(await host.isAuthorized(0n)).to.be.false;
  });

  it("falls back to the host address when commander is zero", async () => {
    const selfManaged = await deploy("TestHost", ethers.ZeroAddress);
    const selfManagedAddress = await selfManaged.getAddress();
    expect(await selfManaged.getCommander()).to.equal(selfManagedAddress);

    const adminAccount: string = await selfManaged.getAdminAccount();
    const val = BigInt(adminAccount);
    const embedded = (val >> 32n) & ((1n << 160n) - 1n);
    expect("0x" + embedded.toString(16).padStart(40, "0"))
      .to.equal(selfManagedAddress.toLowerCase());
  });
});


