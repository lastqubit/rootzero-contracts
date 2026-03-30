import { expect } from "chai";
import { ethers } from "ethers";
import { deploy, getSigner, getProvider } from "./helpers/setup.js";
import hre from "hardhat";

describe("Host Discovery", () => {
  let discovery: Awaited<ReturnType<typeof deploy>>;

  before(async () => {
    discovery = await deploy("TestDiscovery");
  });

  it("announces host on construction when the rootzero runtime is set", async () => {
    const rootzero = await discovery.getAddress();

    // Deploy host pointing to discovery — should emit HostAnnounced during construction
    const artifact = await hre.artifacts.readArtifact("TestHost");
    const provider = await getProvider();
    const factory = new ethers.ContractFactory(artifact.abi, artifact.bytecode, await provider.getSigner(0));
    const contract = await factory.deploy(rootzero);
    const receipt = await contract.deploymentTransaction()!.wait();

    // Check discovery emitted HostAnnounced
    const discoveryIface = discovery.interface;
    const hostRegisteredLog = receipt!.logs.find((log: any) => {
      try {
        return discoveryIface.parseLog(log)?.name === "HostAnnounced";
      } catch { return false; }
    });
    expect(hostRegisteredLog).to.not.be.undefined;
    const parsed = discoveryIface.parseLog(hostRegisteredLog!);
    expect(parsed!.args.version).to.equal(1n);
    expect(parsed!.args.namespace).to.equal("test");
  });

  it("does NOT announce when the rootzero runtime is address(0)", async () => {
    // No revert, no HostAnnounced from discovery
    const host = await deploy("TestHost", ethers.ZeroAddress);
    expect(await host.getAddress()).to.not.equal(ethers.ZeroAddress);
  });

  it("announceHost reverts InvalidId when caller's host ID does not match id param", async () => {
    const signer = await getSigner(0);

    // Build a host ID that doesn't match the caller
    const fakeHostId = 12345n;

    await expect(
      discovery.connect(signer).announceHost(fakeHostId, 0n, 1n, "test")
    ).to.be.revertedWithCustomError(discovery, "InvalidId");
  });

  it("announceHost succeeds when id matches caller address", async () => {
    const signer = await getSigner(0);
    const callerAddr = await signer.getAddress();

    // Compute correct host ID for caller
    const CHAIN_ID = 31337n;
    const HOST_PREFIX = 0x20010201n;
    const correctHostId = (HOST_PREFIX << 224n) | (CHAIN_ID << 192n) | BigInt(callerAddr);

    await expect(
      discovery.connect(signer).announceHost(correctHostId, 1n, 1n, "manual")
    ).to.emit(discovery, "HostAnnounced")
      .withArgs(correctHostId, 1n, 1n, "manual");
  });

  it("HostAnnounced event contains correct host, blocknum, version, namespace", async () => {
    const signer = await getSigner(0);
    const callerAddr = await signer.getAddress();
    const CHAIN_ID = 31337n;
    const HOST_PREFIX = 0x20010201n;
    const hostId = (HOST_PREFIX << 224n) | (CHAIN_ID << 192n) | BigInt(callerAddr);

    const provider = await getProvider();
    const blockNum = await provider.getBlockNumber();
    const tx = await discovery.connect(signer).announceHost(hostId, BigInt(blockNum), 2n, "v2");
    await expect(tx)
      .to.emit(discovery, "HostAnnounced")
      .withArgs(hostId, BigInt(blockNum), 2n, "v2");
  });
});
