import { expect } from "chai";
import { ethers } from "ethers";
import { deploy, getSigner, getProvider, hostId } from "./helpers/setup.js";
import hre from "hardhat";
import "./helpers/matchers.js";
import { encodeUserAccount } from "./helpers/blocks.js";

describe("Host Introduction", () => {
  let rootzero: Awaited<ReturnType<typeof deploy>>;

  before(async () => {
    rootzero = await deploy("TestHost", 0n);
  });

  it("introduces host on construction when the rootzero runtime is set", async () => {
    const artifact = await hre.artifacts.readArtifact("TestHost");
    const provider = await getProvider();
    const factory = new ethers.ContractFactory(artifact.abi, artifact.bytecode, await provider.getSigner(0));
    const contract = await factory.deploy(await rootzero.host());
    const receipt = await contract.deploymentTransaction()!.wait();

    const rootzeroIface = rootzero.interface;
    const hostIntroducedLog = receipt!.logs.find((log: any) => {
      try {
        return rootzeroIface.parseLog(log)?.name === "Introduction";
      } catch { return false; }
    });
    expect(hostIntroducedLog).to.not.be.undefined;
    const parsed = rootzeroIface.parseLog(hostIntroducedLog!);
    expect(parsed!.args.host).to.equal(await rootzero.host());
    expect(parsed!.args.peer).to.not.equal(0n);
    expect(parsed!.args.origin).to.equal(encodeUserAccount(await (await getSigner(0)).getAddress()));
    expect(parsed!.args.blocknum).to.be.greaterThan(0n);
  });

  it("introduces a command host to its contract commander", async () => {
    const artifact = await hre.artifacts.readArtifact("TestMinimalCommandHost");
    const provider = await getProvider();
    const factory = new ethers.ContractFactory(artifact.abi, artifact.bytecode, await provider.getSigner(0));
    const contract = await factory.deploy(await rootzero.host());
    const receipt = await contract.deploymentTransaction()!.wait();

    const introduced = receipt!.logs
      .map((log: any) => {
        try {
          return rootzero.interface.parseLog(log);
        } catch {
          return null;
        }
      })
      .find((log) => log?.name === "Introduction");

    expect(introduced).to.not.be.undefined;
    expect(introduced!.args.host).to.equal(await rootzero.host());
    expect(introduced!.args.peer).to.equal(await (contract as any).host());
  });

  it("rejects deployment when a contract commander cannot accept introductions", async () => {
    const commander = await deploy("TestExecuteTarget");

    for (const host of ["TestMinimalCommandHost", "TestBareHost"]) {
      let rejected = false;
      try {
        await deploy(host, await hostId(commander));
      } catch {
        rejected = true;
      }
      expect(rejected).to.equal(true);
    }
  });

  it("does NOT introduce when the commander host ID is zero", async () => {
    const host = await deploy("TestHost", 0n);
    expect(await host.getAddress()).to.not.equal(ethers.ZeroAddress);
  });

  it("introduce rejects claims that do not match the caller address", async () => {
    const signer = await getSigner(0);
    const claimedHostId = 12345n;

    await expect(
      rootzero.connect(signer).introduce(claimedHostId, 0n)
    ).to.be.revertedWithCustomError(rootzero, "InvalidId");
  });

  it("introduce succeeds when id matches caller address", async () => {
    const signer = await getSigner(0);
    const callerAddr = await signer.getAddress();

    const CHAIN_ID = 31337n;
    const HOST_PREFIX = 0x01020200n;
    const correctHostId = (HOST_PREFIX << 224n) | (CHAIN_ID << 192n) | BigInt(callerAddr);

    await expect(
      rootzero.connect(signer).introduce(correctHostId, 1n)
    ).to.emit(rootzero, "Introduction")
      .withArgs(await rootzero.host(), correctHostId, encodeUserAccount(callerAddr), 1n);
  });

  it("Introduction event contains correct host, peer, origin, and blocknum", async () => {
    const signer = await getSigner(0);
    const callerAddr = await signer.getAddress();
    const CHAIN_ID = 31337n;
    const HOST_PREFIX = 0x01020200n;
    const hostId = (HOST_PREFIX << 224n) | (CHAIN_ID << 192n) | BigInt(callerAddr);

    const provider = await getProvider();
    const blockNum = await provider.getBlockNumber();
    const tx = await rootzero.connect(signer).introduce(hostId, BigInt(blockNum));
    await expect(tx)
      .to.emit(rootzero, "Introduction")
      .withArgs(await rootzero.host(), hostId, encodeUserAccount(callerAddr), BigInt(blockNum));
  });
});
