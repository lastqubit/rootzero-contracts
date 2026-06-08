import { expect } from "chai";
import { ethers } from "ethers";
import { deploy, getSigner, getProvider } from "./helpers/setup.js";
import hre from "hardhat";
import "./helpers/matchers.js";

describe("Host Introduction", () => {
  let rootzero: Awaited<ReturnType<typeof deploy>>;

  before(async () => {
    rootzero = await deploy("TestHost", ethers.ZeroAddress);
  });

  it("introduces host on construction when the rootzero runtime is set", async () => {
    const rootzeroAddress = await rootzero.getAddress();

    const artifact = await hre.artifacts.readArtifact("TestHost");
    const provider = await getProvider();
    const factory = new ethers.ContractFactory(artifact.abi, artifact.bytecode, await provider.getSigner(0));
    const contract = await factory.deploy(rootzeroAddress);
    const receipt = await contract.deploymentTransaction()!.wait();

    const rootzeroIface = rootzero.interface;
    const hostIntroducedLog = receipt!.logs.find((log: any) => {
      try {
        return rootzeroIface.parseLog(log)?.name === "Introduction";
      } catch { return false; }
    });
    expect(hostIntroducedLog).to.not.be.undefined;
    const parsed = rootzeroIface.parseLog(hostIntroducedLog!);
    expect(parsed!.args.host).to.not.equal(0n);
    expect(parsed!.args.blocknum).to.be.greaterThan(0n);
  });

  it("does NOT introduce when the rootzero runtime is address(0)", async () => {
    const host = await deploy("TestHost", ethers.ZeroAddress);
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
    const HOST_PREFIX = 0x01200202n;
    const correctHostId = (HOST_PREFIX << 224n) | (CHAIN_ID << 192n) | BigInt(callerAddr);

    await expect(
      rootzero.connect(signer).introduce(correctHostId, 1n)
    ).to.emit(rootzero, "Introduction")
      .withArgs(correctHostId, 1n);
  });

  it("Introduction event contains correct host and blocknum", async () => {
    const signer = await getSigner(0);
    const callerAddr = await signer.getAddress();
    const CHAIN_ID = 31337n;
    const HOST_PREFIX = 0x01200202n;
    const hostId = (HOST_PREFIX << 224n) | (CHAIN_ID << 192n) | BigInt(callerAddr);

    const provider = await getProvider();
    const blockNum = await provider.getBlockNumber();
    const tx = await rootzero.connect(signer).introduce(hostId, BigInt(blockNum));
    await expect(tx)
      .to.emit(rootzero, "Introduction")
      .withArgs(hostId, BigInt(blockNum));
  });
});
