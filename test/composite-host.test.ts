import { expect } from "chai";
import { deploy } from "./helpers/setup.js";

describe("Composite Host", () => {
  it("deploys a host that mixes commands, peer commands, and queries", async () => {
    const host = await deploy("TestCompositeHost", "0x0000000000000000000000000000000000000000");
    expect(await host.getAddress()).to.not.equal("0x0000000000000000000000000000000000000000");
  });
});
