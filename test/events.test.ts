import { expect } from "chai";
import { ethers } from "ethers";
import { deploy } from "./helpers/setup.js";
import "./helpers/matchers.js";

describe("Positioned Event", () => {
  it("publishes its ABI and emits the resulting position with its action", async () => {
    const positioned = await deploy("TestPositionedEvent");
    const receipt = await positioned.deploymentTransaction()!.wait();
    const abi = receipt!.logs
      .map((log: any) => {
        try {
          return positioned.interface.parseLog(log);
        } catch {
          return null;
        }
      })
      .find((log: any) => log?.name === "EventAbi");

    expect(abi!.args.abi).to.equal(
      "event Positioned(bytes32 indexed account, bytes32 asset, uint amount, bytes32 liability, uint debt, uint32 action)",
    );

    const account = ethers.zeroPadValue("0x01", 32);
    const asset = ethers.zeroPadValue("0x02", 32);
    const liability = ethers.zeroPadValue("0x03", 32);
    await expect(positioned.emitPositioned(account, asset, 100n, liability, 25n, 7))
      .to.emit(positioned, "Positioned")
      .withArgs(account, asset, 100n, liability, 25n, 7);
  });
});
