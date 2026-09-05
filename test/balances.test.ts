import { expect } from "chai";
import { ethers } from "ethers";
import { deploy } from "./helpers/setup.js";
import "./helpers/matchers.js";

describe("Balance ledgers", () => {
  const asset = ethers.zeroPadValue("0x11", 32);
  const otherAsset = ethers.zeroPadValue("0x12", 32);
  const account = ethers.zeroPadValue("0x21", 32);
  const otherAccount = ethers.zeroPadValue("0x22", 32);

  it("credits and debits host balances independently by asset", async () => {
    const ledger = await deploy("TestBalancesLedger");

    expect(await ledger.creditHost.staticCall(asset, 100n)).to.equal(100n);
    await ledger.creditHost(asset, 100n);
    await ledger.creditHost(otherAsset, 40n);
    expect(await ledger.debitHost.staticCall(asset, 30n)).to.equal(70n);
    await ledger.debitHost(asset, 30n);

    expect(await ledger.hostBalance(asset)).to.equal(70n);
    expect(await ledger.hostBalance(otherAsset)).to.equal(40n);
  });

  it("credits and debits account balances independently by account and asset", async () => {
    const ledger = await deploy("TestBalancesLedger");

    await ledger.creditToAccount(account, asset, 100n);
    await ledger.creditToAccount(account, otherAsset, 40n);
    await ledger.creditToAccount(otherAccount, asset, 25n);
    expect(await ledger.debitFromAccount.staticCall(account, asset, 30n)).to.equal(70n);
    await ledger.debitFromAccount(account, asset, 30n);

    expect(await ledger.accountBalance(account, asset)).to.equal(70n);
    expect(await ledger.accountBalance(account, otherAsset)).to.equal(40n);
    expect(await ledger.accountBalance(otherAccount, asset)).to.equal(25n);
    expect(await ledger.hostBalance(asset)).to.equal(0n);
  });

  it("rejects insufficient host and account balances", async () => {
    const ledger = await deploy("TestBalancesLedger");

    await expect(ledger.debitHost(asset, 1n))
      .to.be.revertedWithCustomError(ledger, "InsufficientFunds");
    await expect(ledger.debitFromAccount(account, asset, 1n))
      .to.be.revertedWithCustomError(ledger, "InsufficientFunds");
  });
});
