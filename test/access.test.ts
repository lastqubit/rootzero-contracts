import { expect } from "chai";
import { ethers } from "ethers";
import hre from "hardhat";
import "./helpers/matchers.js";
import { deploy, getProvider, getSigner, getSigners } from "./helpers/setup.js";
import { encodeAccountBlock, encodeContextBlock, encodeNodeBlock, pad32 } from "./helpers/blocks.js";

describe("Access Control", () => {
  let host: Awaited<ReturnType<typeof deploy>>;
  let utils: Awaited<ReturnType<typeof deploy>>;
  let commander: string;
  let stranger: string;
  let hostAddress: string;

  before(async () => {
    const signers = await getSigners(3);
    commander = await signers[0].getAddress();
    stranger  = await signers[1].getAddress();

    host = await deploy("TestHost", commander);
    utils = await deploy("TestUtils");
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
    // An empty authorize batch is a successful no-op.
    const adminAccount: string = await host.getAdminAccount();
    const ctx = [encodeContextBlock(adminAccount, "0x", "0x")] as const;
    const signers = await getSigners(1);
    await host.connect(signers[0]).authorize(...ctx);
  });

  it("stranger is not trusted and gets AccessDenied", async () => {
    const adminAccount: string = await host.getAdminAccount();
    const ctx = [encodeContextBlock(adminAccount, "0x", "0x")] as const;
    const signers = await getSigners(2);
    await expect(
      host.connect(signers[1]).authorize(...ctx)
    ).to.be.revertedWithCustomError(host, "AccessDenied");
  });

  it("enforces the expected message sender", async () => {
    const signers = await getSigners(2);

    expect(await utils.connect(signers[0]).testEnforceSender(commander))
      .to.equal(commander);
    await expect(utils.connect(signers[1]).testEnforceSender(commander))
      .to.be.revertedWithCustomError(utils, "AccessDenied");
  });

  it("authorize emits Node event with active=true", async () => {
    const signers = await getSigners(1);
    const adminAccount: string = await host.getAdminAccount();
    const dummyNode = 0xdeadbeefn << 192n; // some non-zero node id
    const nodeBlock = encodeNodeBlock(dummyNode);
    const ctx = [encodeContextBlock(adminAccount, "0x", nodeBlock)] as const;

    await expect(host.connect(signers[0]).authorize(...ctx))
      .to.emit(host, "Node")
      .withArgs(await host.host(), dummyNode, true);
  });

  it("node is authorized after authorize call", async () => {
    const signers = await getSigners(1);
    const adminAccount: string = await host.getAdminAccount();
    const dummyNode = 0xcafebaben << 192n;
    const nodeBlock = encodeNodeBlock(dummyNode);
    const ctx = [encodeContextBlock(adminAccount, "0x", nodeBlock)] as const;
    await host.connect(signers[0]).authorize(...ctx);
    expect(await host.isAuthorized(dummyNode)).to.be.true;
  });

  it("unauthorize emits Node event with active=false", async () => {
    const signers = await getSigners(1);
    const adminAccount: string = await host.getAdminAccount();
    const dummyNode = 0x11111111n << 192n;
    // First authorize
    await host.connect(signers[0]).authorize(encodeContextBlock(adminAccount, "0x", encodeNodeBlock(dummyNode)));
    // Then unauthorize
    await expect(
      host.connect(signers[0]).unauthorize(encodeContextBlock(adminAccount, "0x", encodeNodeBlock(dummyNode)))
    ).to.emit(host, "Node").withArgs(await host.host(), dummyNode, false);
  });

  it("node is not authorized after unauthorize call", async () => {
    const signers = await getSigners(1);
    const adminAccount: string = await host.getAdminAccount();
    const dummyNode = 0x22222222n << 192n;
    await host.connect(signers[0]).authorize(encodeContextBlock(adminAccount, "0x", encodeNodeBlock(dummyNode)));
    await host.connect(signers[0]).unauthorize(encodeContextBlock(adminAccount, "0x", encodeNodeBlock(dummyNode)));
    expect(await host.isAuthorized(dummyNode)).to.be.false;
  });

  it("isAuthorized mapping returns false for node 0", async () => {
    expect(await host.isAuthorized(0n)).to.be.false;
  });

  it("isGuardian converts an address to its user account", async () => {
    const guardianAddress = await (await getSigner(2)).getAddress();
    const guardianAccount = await utils.testToUserAccount(guardianAddress);

    expect(await host.isGuardianAddress(guardianAddress)).to.be.false;

    await host.setGuardianAccount(guardianAccount, true);
    expect(await host.isGuardianAddress(guardianAddress)).to.be.true;
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

describe("Commander Access", () => {
  it("rejects a zero commander", async () => {
    let rejected = false;
    try {
      await deploy("TestMinimalCommandHost", ethers.ZeroAddress);
    } catch {
      rejected = true;
    }
    expect(rejected).to.equal(true);
  });

  it("allows the commander to call a command", async () => {
    const signers = await getSigners(1);
    const commander = await signers[0].getAddress();
    const host = await deploy("TestMinimalCommandHost", commander);

    expect(await host.connect(signers[0]).ping()).to.equal(true);
  });

  it("rejects other command callers", async () => {
    const signers = await getSigners(2);
    const commander = await signers[0].getAddress();
    const host = await deploy("TestMinimalCommandHost", commander);

    await expect(host.connect(signers[1]).ping())
      .to.be.revertedWithCustomError(host, "AccessDenied");
  });

  it("does not expose advanced host entrypoints or accept direct native transfers", async () => {
    const signers = await getSigners(1);
    const host = await deploy("TestMinimalCommandHost", await signers[0].getAddress());

    for (const name of [
      "annotate",
      "authorize",
      "unauthorize",
      "appoint",
      "dismiss",
      "executePayable",
      "revoke",
      "introduce",
    ]) {
      expect(host.interface.getFunction(name)).to.equal(null);
    }

    let rejected = false;
    try {
      const tx = await signers[0].sendTransaction({ to: await host.getAddress(), value: 1n });
      await tx.wait();
    } catch {
      rejected = true;
    }
    expect(rejected).to.equal(true);
  });

  it("stays materially smaller than the built-in advanced host", async () => {
    const minimal = await hre.artifacts.readArtifact("TestMinimalCommandHost");
    const advanced = await hre.artifacts.readArtifact("TestBareHost");
    const minimalSize = ethers.getBytes(minimal.deployedBytecode).length;
    const advancedSize = ethers.getBytes(advanced.deployedBytecode).length;

    expect(minimalSize).to.be.lessThan(advancedSize / 2);
  });
});

describe("Host feature bundles", () => {
  it("composes the default admin commands without guardian functionality", async () => {
    const commander = await (await getSigner(0)).getAddress();
    const host = await deploy("TestAdminsHost", commander);

    for (const name of ["annotate", "authorize", "unauthorize", "executePayable"]) {
      expect(host.interface.getFunction(name)).to.not.equal(null);
    }
    for (const name of ["appoint", "dismiss", "revoke"]) {
      expect(host.interface.getFunction(name)).to.equal(null);
    }
  });

  it("keeps standalone admin commands commander-only even after authorizing a peer", async () => {
    const signers = await getSigners(3);
    const commander = await signers[0].getAddress();
    const peer = await signers[1].getAddress();
    const host = await deploy("TestAdminsHost", commander);
    const utils = await deploy("TestUtils");
    const adminAccount = await utils.testToAdminAccount(commander);
    const network = await (await getProvider()).getNetwork();
    const peerNode = (0x01200202n << 224n) | (network.chainId << 192n) | BigInt(peer);

    await host.authorize(encodeContextBlock(adminAccount, "0x", encodeNodeBlock(peerNode)));

    await expect(host.connect(signers[1]).unauthorize(encodeContextBlock(adminAccount, "0x", encodeNodeBlock(peerNode))))
      .to.be.revertedWithCustomError(host, "AccessDenied");
    await expect(host.connect(signers[2]).authorize(encodeContextBlock(adminAccount, "0x", encodeNodeBlock(peerNode))))
      .to.be.revertedWithCustomError(host, "AccessDenied");
  });

  it("composes guardian management and revoke without other admin commands", async () => {
    const commander = await (await getSigner(0)).getAddress();
    const host = await deploy("TestGuardiansHost", commander);

    for (const name of ["appoint", "dismiss", "revoke"]) {
      expect(host.interface.getFunction(name)).to.not.equal(null);
    }
    for (const name of ["annotate", "authorize", "unauthorize", "executePayable"]) {
      expect(host.interface.getFunction(name)).to.equal(null);
    }
  });

  it("enforces commander-managed guardian access in the standalone bundle", async () => {
    const signers = await getSigners(3);
    const commander = await signers[0].getAddress();
    const guardian = await signers[1].getAddress();
    const host = await deploy("TestGuardiansHost", commander);
    const utils = await deploy("TestUtils");
    const adminAccount = await utils.testToAdminAccount(commander);
    const guardianAccount = await utils.testToUserAccount(guardian);
    const node = 123n;

    await expect(host.connect(signers[2]).revoke(encodeNodeBlock(node)))
      .to.be.revertedWithCustomError(host, "AccessDenied");

    await host.appoint(encodeContextBlock(adminAccount, "0x", encodeAccountBlock(guardianAccount)));
    await expect(host.connect(signers[1]).revoke(encodeNodeBlock(node)))
      .to.emit(host, "Node")
      .withArgs(await host.host(), node, false);

    await host.dismiss(encodeContextBlock(adminAccount, "0x", encodeAccountBlock(guardianAccount)));
    await expect(host.connect(signers[1]).revoke(encodeNodeBlock(node)))
      .to.be.revertedWithCustomError(host, "AccessDenied");
  });
});


