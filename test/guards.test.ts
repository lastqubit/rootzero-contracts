import { expect } from "chai";
import { ethers } from "ethers";
import hre from "hardhat";
import "./helpers/matchers.js";
import { deploy, getProvider, getSigner } from "./helpers/setup.js";
import { encodeAccountBlock, encodeNodeBlock, Keys, pad32 } from "./helpers/blocks.js";

describe("Guard Actions", () => {
  let host: Awaited<ReturnType<typeof deploy>>;
  let utils: Awaited<ReturnType<typeof deploy>>;
  let adminAccount: string;
  let commander: string;
  let guardianAddress: string;
  let guardianSigner: Awaited<ReturnType<typeof getSigner>>;

  beforeEach(async () => {
    commander = await (await getSigner(0)).getAddress();
    guardianSigner = await getSigner(1);
    guardianAddress = await guardianSigner.getAddress();

    host = await deploy("TestHost", commander);
    utils = await deploy("TestUtils");
    adminAccount = await host.getAdminAccount();

    const guardianAccount = await utils.testToGuardianAccount(guardianAddress);
    await host.appoint(adminCtx(encodeAccountBlock(guardianAccount)));
  });

  function adminCtx(request: string) {
    return { account: adminAccount, meta: ethers.ZeroHash, state: "0x", request };
  }

  async function hostIdFor(addr: string) {
    const provider = await getProvider();
    const network = await provider.getNetwork();
    const HOST_PREFIX = 0x01200202n;
    return (HOST_PREFIX << 224n) | (network.chainId << 192n) | BigInt(addr);
  }

  it("emits Guard discovery for revoke on deployment", async () => {
    const signer = await getSigner(0);
    const artifact = await hre.artifacts.readArtifact("TestHost");
    const factory = new ethers.ContractFactory(artifact.abi, artifact.bytecode, signer);
    const deployed = await factory.deploy(commander);
    const deploymentTx = deployed.deploymentTransaction();
    if (!deploymentTx) throw new Error("missing deployment transaction");
    await deployed.waitForDeployment();

    await expect(deploymentTx)
      .to.emit(deployed, "Guard")
      .withArgs(await deployed.host(), await deployed.getRevokeId(), "#node { uint id }");
    await expect(deploymentTx)
      .to.emit(deployed, "Labeled")
      .withArgs(await deployed.getRevokeId(), ethers.ZeroHash, "revoke");
  });

  it("guardian can revoke an authorized node directly", async () => {
    const node = await hostIdFor(await (await getSigner(2)).getAddress());

    await host.authorize(adminCtx(encodeNodeBlock(node)));
    expect(await host.isAuthorized(node)).to.be.true;

    await expect(host.connect(guardianSigner).revoke(encodeNodeBlock(node)))
      .to.emit(host, "Node")
      .withArgs(await host.host(), node, false);

    expect(await host.isAuthorized(node)).to.be.false;
  });

  it("guardian can revoke multiple nodes", async () => {
    const node1 = await hostIdFor(await (await getSigner(2)).getAddress());
    const node2 = await hostIdFor(await (await getSigner(3)).getAddress());

    await host.authorize(adminCtx(ethers.concat([encodeNodeBlock(node1), encodeNodeBlock(node2)])));

    await host.connect(guardianSigner).revoke(ethers.concat([encodeNodeBlock(node1), encodeNodeBlock(node2)]));

    expect(await host.isAuthorized(node1)).to.be.false;
    expect(await host.isAuthorized(node2)).to.be.false;
  });

  it("reverts AccessDenied for non-guardian callers", async () => {
    const node = await hostIdFor(await (await getSigner(2)).getAddress());

    await expect(host.revoke(encodeNodeBlock(node)))
      .to.be.revertedWithCustomError(host, "AccessDenied");
  });

  it("reverts ZeroCursor when request is empty", async () => {
    await expect(host.connect(guardianSigner).revoke("0x"))
      .to.be.revertedWithCustomError(host, "ZeroCursor");
  });

  it("reverts InvalidBlock when revoke request is not NODE blocks", async () => {
    const guardianAccount = await utils.testToGuardianAccount(guardianAddress);

    await expect(host.connect(guardianSigner).revoke(encodeAccountBlock(guardianAccount)))
      .to.be.revertedWithCustomError(host, "InvalidBlock");
  });

  it("reverts MalformedBlocks when revoke request has a truncated NODE block", async () => {
    const truncated = ethers.concat([
      Keys.Node,
      ethers.toBeHex(32, 4),
      ethers.dataSlice(pad32(1n), 0, 31),
    ]);

    await expect(host.connect(guardianSigner).revoke(truncated))
      .to.be.revertedWithCustomError(host, "MalformedBlocks");
  });

  it("dismissed guardian cannot revoke nodes", async () => {
    const node = await hostIdFor(await (await getSigner(2)).getAddress());
    await host.authorize(adminCtx(encodeNodeBlock(node)));

    const guardianAccount = await utils.testToGuardianAccount(guardianAddress);
    await host.dismiss(adminCtx(encodeAccountBlock(guardianAccount)));

    await expect(host.connect(guardianSigner).revoke(encodeNodeBlock(node)))
      .to.be.revertedWithCustomError(host, "AccessDenied");
  });

  it("appointing the same guardian twice is idempotent", async () => {
    const guardianAccount = await utils.testToGuardianAccount(guardianAddress);

    await expect(host.appoint(adminCtx(encodeAccountBlock(guardianAccount))))
      .to.emit(host, "Guardian")
      .withArgs(await host.host(), guardianAccount, true);

    expect(await host.isGuardianAddress(guardianAddress)).to.be.true;
  });

  it("guard IDs are correctly distinguished from other node types", async () => {
    const revokeId = await host.getRevokeId();
    const depositId = await host.getDepositId();
    const appointId = await host.getAppointId();

    expect(await utils.testIsGuard(revokeId)).to.be.true;
    expect(await utils.testIsGuard(depositId)).to.be.false;
    expect(await utils.testIsGuard(appointId)).to.be.false;
  });

  it("encodes guard calls from guard IDs", async () => {
    const revokeId = await host.getRevokeId();
    const request = encodeNodeBlock(await hostIdFor(await (await getSigner(2)).getAddress()));

    expect(await utils.testEncodeGuardCall(revokeId, request))
      .to.equal(host.interface.encodeFunctionData("revoke", [request]));
  });

  it("reverts InvalidId when encoding a guard call for a non-guard ID", async () => {
    await expect(utils.testEncodeGuardCall(await host.getDepositId(), "0x"))
      .to.be.revertedWithCustomError(utils, "InvalidId");
  });
});
