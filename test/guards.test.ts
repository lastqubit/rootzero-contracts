import { expect } from "chai";
import { ethers } from "ethers";
import { deploy, getProvider, getSigner } from "./helpers/setup.js";
import { encodeAccountBlock, encodeNodeBlock } from "./helpers/blocks.js";

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
    await host.guard(adminCtx(encodeAccountBlock(guardianAccount)));
  });

  function adminCtx(request: string) {
    return { account: adminAccount, meta: ethers.ZeroHash, state: "0x", request };
  }

  async function hostIdFor(addr: string) {
    const provider = await getProvider();
    const network = await provider.getNetwork();
    const HOST_PREFIX = 0x20010201n;
    return (HOST_PREFIX << 224n) | (network.chainId << 192n) | BigInt(addr);
  }

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
});
