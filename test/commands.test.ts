import { expect } from "chai";
import { ethers } from "ethers";
import { deploy, getSigner } from "./helpers/setup.js";
import "./helpers/matchers.js";
import {
  encodeAmountBlock,
  encodeBalanceBlock, encodeHostAssetAmountBlock,
  encodeAccountBlock, encodeUserAmountBlock, encodeNodeBlock, encodeTxBlock, encodeStepBlock, encodeUserAccount,
  encodeBundleBlock, concat
} from "./helpers/blocks.js";

describe("Commands", () => {
  let host: Awaited<ReturnType<typeof deploy>>;
  let commander: string;
  let userAccount: string;
  let adminAccount: string;

  before(async () => {
    const signer = await getSigner(0);
    commander = await signer.getAddress();
    host = await deploy("TestHost", commander);
    adminAccount = await host.getAdminAccount();

    // Build a user account (unspecified prefix + address)
    const addrBig = BigInt(commander);
    // USER_PREFIX = (0x2001 << 16) | (0x01 << 8) | 0x02 = 0x20010102
    const USER_PREFIX = 0x20010102n;
    userAccount = ethers.zeroPadValue(
      ethers.toBeHex((USER_PREFIX << 224n) | (addrBig << 32n)), 32
    );
  });

  function ctx(overrides: Partial<{ account: string; state: string; request: string }> = {}) {
    return {
      account: overrides.account ?? userAccount,
      state: overrides.state ?? "0x",
      request: overrides.request ?? "0x",
    };
  }

  function callAs(signerIndex: number, method: string, ...args: unknown[]) {
    const promise = getSigner(signerIndex).then((signer) => {
      const txPromise = (host.connect(signer) as any)[method](...args);
      Promise.resolve(txPromise).catch(() => {});
      return txPromise;
    });
    Promise.resolve(promise).catch(() => {});
    return promise;
  }

  // ── Deposit ───────────────────────────────────────────────────────────────

  describe("deposit", () => {
    it("activeAccount matches c.account", async () => {
      expect(await host.getActiveAccount.staticCall(ctx())).to.equal(userAccount);
    });

    it("emits DepositCalled for a single AMOUNT block and returns BALANCE blocks", async () => {
      const asset = ethers.zeroPadValue("0x01", 32);
      const meta  = ethers.ZeroHash;
      const amount = 100n;
      const request = encodeAmountBlock(asset, meta, amount);

      const tx = await callAs(0, "deposit", ctx({ request }));
      await expect(tx).to.emit(host, "DepositCalled")
        .withArgs(userAccount, asset, meta, amount);
    });

    it("returns BALANCE blocks matching the deposited amounts", async () => {
      const asset = ethers.zeroPadValue("0x01", 32);
      const meta  = ethers.ZeroHash;
      const amount = 50n;
      const request = encodeAmountBlock(asset, meta, amount);

      const result: string = await host.deposit.staticCall(ctx({ request }));
      expect(result).to.equal(encodeBalanceBlock(asset, meta, amount));
    });

    it("processes multiple AMOUNT blocks", async () => {
      const asset1 = ethers.zeroPadValue("0x01", 32);
      const asset2 = ethers.zeroPadValue("0x02", 32);
      const meta   = ethers.ZeroHash;
      const request = concat(
        encodeAmountBlock(asset1, meta, 10n),
        encodeAmountBlock(asset2, meta, 20n)
      );

      const result: string = await host.deposit.staticCall(ctx({ request }));
      expect(result).to.equal(concat(
        encodeBalanceBlock(asset1, meta, 10n),
        encodeBalanceBlock(asset2, meta, 20n)
      ));
    });

    it("reverts UnauthorizedCaller for untrusted caller", async () => {
      const asset = ethers.zeroPadValue("0x01", 32);
      const request = encodeAmountBlock(asset, ethers.ZeroHash, 1n);
      await expect(
        callAs(1, "deposit", ctx({ request }))
      ).to.be.revertedWithCustomError(host, "UnauthorizedCaller");
    });

    it("reverts ZeroCursor when request has no AMOUNT blocks", async () => {
      await expect(
        callAs(0, "deposit", ctx({ request: "0x" }))
      ).to.be.revertedWithCustomError(host, "ZeroCursor");
    });

    it("reverts MalformedBlocks for request with only 4 garbage bytes", async () => {
      await expect(
        callAs(0, "deposit", ctx({ request: "0xdeadbeef" }))
      ).to.be.revertedWithCustomError(host, "MalformedBlocks");
    });
  });
  describe("depositPayable", () => {
    it("passes a shared value budget through to the hook", async () => {
      const asset1 = ethers.zeroPadValue("0x03", 32);
      const asset2 = ethers.zeroPadValue("0x04", 32);
      const meta = ethers.ZeroHash;
      const request = concat(
        encodeAmountBlock(asset1, meta, 3n),
        encodeAmountBlock(asset2, meta, 7n)
      );

      const tx = await callAs(0, "depositPayable", ctx({ request }), { value: 10n });
      await expect(tx).to.emit(host, "DepositPayableCalled")
        .withArgs(userAccount, asset1, meta, 3n, 7n);
      await expect(tx).to.emit(host, "DepositPayableCalled")
        .withArgs(userAccount, asset2, meta, 7n, 0n);
    });

    it("returns BALANCE blocks matching the deposited amounts", async () => {
      const asset = ethers.zeroPadValue("0x05", 32);
      const meta = ethers.ZeroHash;
      const request = encodeAmountBlock(asset, meta, 8n);

      const result: string = await host.depositPayable.staticCall(ctx({ request }), { value: 8n });
      expect(result).to.equal(encodeBalanceBlock(asset, meta, 8n));
    });

  });


  // ── Withdraw ──────────────────────────────────────────────────────────────

  describe("withdraw", () => {
    const asset = ethers.zeroPadValue("0x10", 32);
    const meta  = ethers.ZeroHash;

    it("emits WithdrawCalled for BALANCE blocks in state", async () => {
      const state = encodeBalanceBlock(asset, meta, 100n);
      const tx = await callAs(0, "withdraw", ctx({ state }));
      await expect(tx).to.emit(host, "WithdrawCalled")
        .withArgs(userAccount, asset, meta, 100n);
    });

    it("uses ACCOUNT from request when present", async () => {
      const recipient = encodeUserAccount("0xbabe");
      const state = encodeBalanceBlock(asset, meta, 50n);
      const request = encodeAccountBlock(recipient);
      const tx = await callAs(0, "withdraw", ctx({ state, request }));
      await expect(tx).to.emit(host, "WithdrawCalled")
        .withArgs(recipient, asset, meta, 50n);
    });

    it("reverts ZeroCursor for empty state", async () => {
      await expect(callAs(0, "withdraw", ctx()))
        .to.be.revertedWithCustomError(host, "ZeroCursor");
    });

    it("emits WithdrawCalled for each BALANCE block in a batch state", async () => {
      const asset1 = ethers.zeroPadValue("0x11", 32);
      const asset2 = ethers.zeroPadValue("0x12", 32);
      const asset3 = ethers.zeroPadValue("0x13", 32);
      const meta   = ethers.ZeroHash;
      const state = concat(
        encodeBalanceBlock(asset1, meta, 10n),
        encodeBalanceBlock(asset2, meta, 20n),
        encodeBalanceBlock(asset3, meta, 30n),
      );
      const tx = await callAs(0, "withdraw", ctx({ state }));
      await expect(tx).to.emit(host, "WithdrawCalled").withArgs(userAccount, asset1, meta, 10n);
      await expect(tx).to.emit(host, "WithdrawCalled").withArgs(userAccount, asset2, meta, 20n);
      await expect(tx).to.emit(host, "WithdrawCalled").withArgs(userAccount, asset3, meta, 30n);
    });

    it("reverts MalformedBlocks for state with a truncated BALANCE block", async () => {
      const full = encodeBalanceBlock(asset, meta, 100n);
      const truncated = ethers.hexlify(ethers.getBytes(full).slice(0, -1));
      await expect(callAs(0, "withdraw", ctx({ state: truncated })))
        .to.be.revertedWithCustomError(host, "MalformedBlocks");
    });
  });

  // ── Transfer ──────────────────────────────────────────────────────────────

  describe("transfer", () => {
    const asset = ethers.zeroPadValue("0x20", 32);
    const meta  = ethers.ZeroHash;

    it("emits TransferCalled for USER_AMOUNT blocks", async () => {
      const to = encodeUserAccount("0xbeef");
      const request = encodeUserAmountBlock(to, asset, meta, 200n);
      const tx = await callAs(0, "transfer", ctx({ request }));
      await expect(tx).to.emit(host, "TransferCalled")
        .withArgs(userAccount, to, asset, meta, 200n);
    });

    it("reverts InvalidBlock when no AMOUNT blocks", async () => {
      const to = encodeUserAccount("0xbeef");
      const request = encodeAccountBlock(to);
      await expect(callAs(0, "transfer", ctx({ request })))
        .to.be.revertedWithCustomError(host, "InvalidBlock");
    });

    it("reverts MalformedBlocks when a USER_AMOUNT block is truncated", async () => {
      const full = encodeUserAmountBlock(encodeUserAccount("0xbeef"), asset, meta, 1n);
      const request = ethers.hexlify(ethers.getBytes(full).slice(0, -1));
      await expect(callAs(0, "transfer", ctx({ request })))
        .to.be.revertedWithCustomError(host, "MalformedBlocks");
    });

    it("emits TransferCalled for each USER_AMOUNT block in a batch", async () => {
      const asset1 = ethers.zeroPadValue("0x21", 32);
      const asset2 = ethers.zeroPadValue("0x22", 32);
      const meta   = ethers.ZeroHash;
      const to1    = encodeUserAccount("0xbeef");
      const to2    = encodeUserAccount("0xcafe");
      const request = concat(
        encodeUserAmountBlock(to1, asset1, meta, 100n),
        encodeUserAmountBlock(to2, asset2, meta, 200n),
      );
      const tx = await callAs(0, "transfer", ctx({ request }));
      await expect(tx).to.emit(host, "TransferCalled").withArgs(userAccount, to1, asset1, meta, 100n);
      await expect(tx).to.emit(host, "TransferCalled").withArgs(userAccount, to2, asset2, meta, 200n);
    });

  });

  // ── CreditTo ──────────────────────────────────────────────────────────────

  describe("creditAccount", () => {
    const asset = ethers.zeroPadValue("0x30", 32);
    const meta  = ethers.ZeroHash;

    it("emits CreditToCalled for BALANCE blocks in state", async () => {
      const state = encodeBalanceBlock(asset, meta, 300n);
      const tx = await callAs(0, "creditAccount", ctx({ state }));
      await expect(tx).to.emit(host, "CreditToCalled");
    });

    it("uses ACCOUNT from request when present", async () => {
      const recipient = encodeUserAccount("0xcafe");
      const state = encodeBalanceBlock(asset, meta, 100n);
      const request = encodeAccountBlock(recipient);
      const tx = await callAs(0, "creditAccount", ctx({ state, request }));
      await expect(tx).to.emit(host, "CreditToCalled")
        .withArgs(recipient, asset, meta, 100n, 100n);
    });

    it("reverts ZeroCursor for empty state", async () => {
      await expect(callAs(0, "creditAccount", ctx()))
        .to.be.revertedWithCustomError(host, "ZeroCursor");
    });
  });

  // ── DebitFrom ─────────────────────────────────────────────────────────────

  describe("debitAccount", () => {
    const asset = ethers.zeroPadValue("0x40", 32);
    const meta  = ethers.ZeroHash;

    it("emits DebitFromCalled and returns BALANCE blocks", async () => {
      const request = encodeAmountBlock(asset, meta, 400n);
      const tx = await callAs(0, "debitAccount", ctx({ request }));
      await expect(tx).to.emit(host, "DebitFromCalled")
        .withArgs(userAccount, asset, meta, 400n, 400n);
    });

    it("returns one BALANCE block per AMOUNT block", async () => {
      const request = encodeAmountBlock(asset, meta, 100n);
      const result: string = await host.debitAccount.staticCall(ctx({ request }));
      expect(result).to.equal(encodeBalanceBlock(asset, meta, 100n));
    });

    it("reverts ZeroCursor when request has no AMOUNT blocks", async () => {
      await expect(callAs(0, "debitAccount", ctx()))
        .to.be.revertedWithCustomError(host, "ZeroCursor");
    });

    it("processes multiple AMOUNT blocks and emits DebitFromCalled for each", async () => {
      const asset1 = ethers.zeroPadValue("0x41", 32);
      const asset2 = ethers.zeroPadValue("0x42", 32);
      const asset3 = ethers.zeroPadValue("0x43", 32);
      const meta   = ethers.ZeroHash;
      const request = concat(
        encodeAmountBlock(asset1, meta, 100n),
        encodeAmountBlock(asset2, meta, 200n),
        encodeAmountBlock(asset3, meta, 300n),
      );
      const tx = await callAs(0, "debitAccount", ctx({ request }));
      await expect(tx).to.emit(host, "DebitFromCalled").withArgs(userAccount, asset1, meta, 100n, 100n);
      await expect(tx).to.emit(host, "DebitFromCalled").withArgs(userAccount, asset2, meta, 200n, 200n);
      await expect(tx).to.emit(host, "DebitFromCalled").withArgs(userAccount, asset3, meta, 300n, 300n);
    });

    it("returns one BALANCE block per AMOUNT block in a batch", async () => {
      const asset1 = ethers.zeroPadValue("0x44", 32);
      const asset2 = ethers.zeroPadValue("0x45", 32);
      const meta   = ethers.ZeroHash;
      const request = concat(
        encodeAmountBlock(asset1, meta, 100n),
        encodeAmountBlock(asset2, meta, 200n),
      );
      const result: string = await host.debitAccount.staticCall(ctx({ request }));
      expect(result).to.equal(concat(
        encodeBalanceBlock(asset1, meta, 100n),
        encodeBalanceBlock(asset2, meta, 200n),
      ));
    });
  });

  // ── Settle ────────────────────────────────────────────────────────────────

  describe("settle", () => {
    it("emits SettleCalled for each TX block in state", async () => {
      const from_ = encodeUserAccount("0xaa");
      const to_   = encodeUserAccount("0xbb");
      const asset = ethers.zeroPadValue("0x50", 32);
      const meta  = ethers.ZeroHash;
      const state = encodeTxBlock(from_, to_, asset, meta, 500n);
      const tx = await callAs(0, "settle", ctx({ state }));
      await expect(tx).to.emit(host, "SettleCalled")
        .withArgs(from_, to_, asset, meta, 500n);
    });

    it("reverts ZeroCursor for empty state", async () => {
      await expect(callAs(0, "settle", ctx()))
        .to.be.revertedWithCustomError(host, "ZeroCursor");
    });

    it("emits SettleCalled for each TX block in a batch state", async () => {
      const from1 = encodeUserAccount("0xa1");
      const from2 = encodeUserAccount("0xa2");
      const from3 = encodeUserAccount("0xa3");
      const to_   = encodeUserAccount("0xbb");
      const asset = ethers.zeroPadValue("0x50", 32);
      const meta  = ethers.ZeroHash;
      const state = concat(
        encodeTxBlock(from1, to_, asset, meta, 100n),
        encodeTxBlock(from2, to_, asset, meta, 200n),
        encodeTxBlock(from3, to_, asset, meta, 300n),
      );
      const tx = await callAs(0, "settle", ctx({ state }));
      await expect(tx).to.emit(host, "SettleCalled").withArgs(from1, to_, asset, meta, 100n);
      await expect(tx).to.emit(host, "SettleCalled").withArgs(from2, to_, asset, meta, 200n);
      await expect(tx).to.emit(host, "SettleCalled").withArgs(from3, to_, asset, meta, 300n);
    });
  });

  // ── Fund ──────────────────────────────────────────────────────────────────

  describe("provisionFromBalance", () => {
    it("emits ProvisionCalled and returns CUSTODY blocks", async () => {
      const asset = ethers.zeroPadValue("0x60", 32);
      const meta  = ethers.ZeroHash;
      const hostId = 123456n;
      const state = encodeBalanceBlock(asset, meta, 600n);
      const request = encodeNodeBlock(hostId);
      const tx = await callAs(0, "provisionFromBalance", ctx({ state, request }));
      await expect(tx).to.emit(host, "ProvisionCalled")
        .withArgs(hostId, userAccount, asset, meta, 600n);
    });

    it("returns HOST_ASSET_AMOUNT blocks matching input BALANCE blocks", async () => {
      const asset = ethers.zeroPadValue("0x60", 32);
      const meta  = ethers.ZeroHash;
      const hostId = 123456n;
      const state = encodeBalanceBlock(asset, meta, 600n);
      const request = encodeNodeBlock(hostId);
      const result: string = await host.provisionFromBalance.staticCall(ctx({ state, request }));
      expect(result).to.equal(encodeHostAssetAmountBlock(hostId, asset, meta, 600n));
    });

    it("reverts ZeroCursor when state has no BALANCE blocks", async () => {
      const hostId = 123456n;
      const request = encodeNodeBlock(hostId);
      await expect(callAs(0, "provisionFromBalance", ctx({ request })))
        .to.be.revertedWithCustomError(host, "ZeroCursor");
    });

    it("reverts ZeroNode when no NODE block and backup is 0", async () => {
      const asset = ethers.zeroPadValue("0x60", 32);
      const state = encodeBalanceBlock(asset, ethers.ZeroHash, 100n);
      await expect(callAs(0, "provisionFromBalance", ctx({ state })))
        .to.be.revertedWithCustomError(host, "ZeroNode");
    });

    it("emits ProvisionCalled for each BALANCE block in a batch state", async () => {
      const asset1 = ethers.zeroPadValue("0x61", 32);
      const asset2 = ethers.zeroPadValue("0x62", 32);
      const asset3 = ethers.zeroPadValue("0x63", 32);
      const meta   = ethers.ZeroHash;
      const hostId = 999n;
      const state = concat(
        encodeBalanceBlock(asset1, meta, 10n),
        encodeBalanceBlock(asset2, meta, 20n),
        encodeBalanceBlock(asset3, meta, 30n),
      );
      const request = encodeNodeBlock(hostId);
      const tx = await callAs(0, "provisionFromBalance", ctx({ state, request }));
      await expect(tx).to.emit(host, "ProvisionCalled").withArgs(hostId, userAccount, asset1, meta, 10n);
      await expect(tx).to.emit(host, "ProvisionCalled").withArgs(hostId, userAccount, asset2, meta, 20n);
      await expect(tx).to.emit(host, "ProvisionCalled").withArgs(hostId, userAccount, asset3, meta, 30n);
    });

    it("returns one HOST_ASSET_AMOUNT block per BALANCE block in a batch state", async () => {
      const asset1 = ethers.zeroPadValue("0x64", 32);
      const asset2 = ethers.zeroPadValue("0x65", 32);
      const meta   = ethers.ZeroHash;
      const hostId = 999n;
      const state = concat(
        encodeBalanceBlock(asset1, meta, 10n),
        encodeBalanceBlock(asset2, meta, 20n),
      );
      const result: string = await host.provisionFromBalance.staticCall(ctx({ state, request: encodeNodeBlock(hostId) }));
      expect(result).to.equal(concat(
        encodeHostAssetAmountBlock(hostId, asset1, meta, 10n),
        encodeHostAssetAmountBlock(hostId, asset2, meta, 20n),
      ));
    });

    it("reverts MalformedBlocks when second BALANCE block in state is truncated", async () => {
      const asset1 = ethers.zeroPadValue("0x66", 32);
      const asset2 = ethers.zeroPadValue("0x67", 32);
      const meta   = ethers.ZeroHash;
      const b1 = encodeBalanceBlock(asset1, meta, 10n);
      const b2 = encodeBalanceBlock(asset2, meta, 20n);
      const truncatedState = ethers.hexlify(ethers.getBytes(concat(b1, b2)).slice(0, -1));
      await expect(callAs(0, "provisionFromBalance", ctx({ state: truncatedState, request: encodeNodeBlock(123n) })))
        .to.be.revertedWithCustomError(host, "MalformedBlocks");
    });
  });

  // ── Provision ─────────────────────────────────────────────────────────────

  describe("provision", () => {
    it("emits ProvisionCalled and returns HOST_ASSET_AMOUNT blocks", async () => {
      const asset = ethers.zeroPadValue("0x70", 32);
      const meta  = ethers.ZeroHash;
      const hostId = 654321n;
      const request = encodeHostAssetAmountBlock(hostId, asset, meta, 700n);
      const tx = await callAs(0, "provision", ctx({ request }));
      await expect(tx).to.emit(host, "ProvisionCalled")
        .withArgs(hostId, userAccount, asset, meta, 700n);
    });

    it("returns HOST_ASSET_AMOUNT blocks", async () => {
      const asset = ethers.zeroPadValue("0x70", 32);
      const hostId = 654321n;
      const request = encodeHostAssetAmountBlock(hostId, asset, ethers.ZeroHash, 700n);
      const result: string = await host.provision.staticCall(ctx({ request }));
      expect(result).to.equal(encodeHostAssetAmountBlock(hostId, asset, ethers.ZeroHash, 700n));
    });

    it("reverts InvalidBlock when request is not a HOST_ASSET_AMOUNT block", async () => {
      const hostId = 654321n;
      const request = encodeNodeBlock(hostId);
      await expect(callAs(0, "provision", ctx({ request })))
        .to.be.revertedWithCustomError(host, "InvalidBlock");
    });

    it("emits ProvisionCalled for each HOST_ASSET_AMOUNT block in a batch", async () => {
      const asset1 = ethers.zeroPadValue("0x71", 32);
      const asset2 = ethers.zeroPadValue("0x72", 32);
      const meta   = ethers.ZeroHash;
      const host1  = 111n;
      const host2  = 222n;
      const request = concat(
        encodeHostAssetAmountBlock(host1, asset1, meta, 100n),
        encodeHostAssetAmountBlock(host2, asset2, meta, 200n),
      );
      const tx = await callAs(0, "provision", ctx({ request }));
      await expect(tx).to.emit(host, "ProvisionCalled").withArgs(host1, userAccount, asset1, meta, 100n);
      await expect(tx).to.emit(host, "ProvisionCalled").withArgs(host2, userAccount, asset2, meta, 200n);
    });

    it("returns one HOST_ASSET_AMOUNT block per request HOST_ASSET_AMOUNT block in a batch", async () => {
      const asset1 = ethers.zeroPadValue("0x73", 32);
      const asset2 = ethers.zeroPadValue("0x74", 32);
      const meta   = ethers.ZeroHash;
      const host1  = 333n;
      const host2  = 444n;
      const request = concat(
        encodeHostAssetAmountBlock(host1, asset1, meta, 100n),
        encodeHostAssetAmountBlock(host2, asset2, meta, 200n),
      );
      const result: string = await host.provision.staticCall(ctx({ request }));
      expect(result).to.equal(concat(
        encodeHostAssetAmountBlock(host1, asset1, meta, 100n),
        encodeHostAssetAmountBlock(host2, asset2, meta, 200n),
      ));
    });
  });
  describe("provisionPayable", () => {
    it("passes a shared value budget through to the host-asset-amount hook", async () => {
      const asset1 = ethers.zeroPadValue("0x75", 32);
      const asset2 = ethers.zeroPadValue("0x76", 32);
      const meta = ethers.ZeroHash;
      const host1 = 555n;
      const host2 = 666n;
      const request = concat(
        encodeHostAssetAmountBlock(host1, asset1, meta, 3n),
        encodeHostAssetAmountBlock(host2, asset2, meta, 7n),
      );

      const tx = await callAs(0, "provisionPayable", ctx({ request }), { value: 10n });
      await expect(tx).to.emit(host, "ProvisionPayableCalled")
        .withArgs(host1, userAccount, asset1, meta, 3n, 7n);
      await expect(tx).to.emit(host, "ProvisionPayableCalled")
        .withArgs(host2, userAccount, asset2, meta, 7n, 0n);
    });

    it("returns one HOST_ASSET_AMOUNT block per request HOST_ASSET_AMOUNT block", async () => {
      const asset = ethers.zeroPadValue("0x77", 32);
      const meta = ethers.ZeroHash;
      const hostId = 777n;
      const request = encodeHostAssetAmountBlock(hostId, asset, meta, 8n);

      const result: string = await host.provisionPayable.staticCall(ctx({ request }), { value: 8n });
      expect(result).to.equal(encodeHostAssetAmountBlock(hostId, asset, meta, 8n));
    });

  });


  // ── Pipe ──────────────────────────────────────────────────────────────────

  describe("pipePayable", () => {
    it("executes STEP blocks and emits StepDispatched", async () => {
      const request = encodeStepBlock(0n, 0n, "0x");
      const tx = await callAs(0, "pipePayable", ctx({ account: userAccount, request }));
      await expect(tx).to.emit(host, "StepDispatched");
    });

    it("threads state through multiple steps", async () => {
      const request = concat(
        encodeStepBlock(0n, 0n, "0x"),
        encodeStepBlock(0n, 0n, "0x")
      );
      const tx = await callAs(0, "pipePayable", ctx({ account: userAccount, request }));
      const count: bigint = await host.stepCount();
      expect(count).to.be.gte(2n);
    });

    it("passes each step target and value through to the dispatcher", async () => {
      const request = concat(
        encodeStepBlock(11n, 7n, "0x1234"),
        encodeStepBlock(22n, 9n, "0xabcd")
      );
      const startCount = await host.stepCount();
      const tx = await callAs(0, "pipePayable", ctx({ account: userAccount, request }), { value: 16n });
      await expect(tx).to.emit(host, "StepDispatched").withArgs(11n, startCount, 7n);
      await expect(tx).to.emit(host, "StepDispatched").withArgs(22n, startCount + 1n, 9n);
    });

    it("returns the final threaded state", async () => {
      const state = encodeBalanceBlock(
        ethers.zeroPadValue("0x99", 32),
        ethers.ZeroHash,
        123n
      );
      const request = encodeStepBlock(0n, 0n, "0x");
      const result = await host.pipePayable.staticCall(ctx({ account: userAccount, state, request }));
      expect(result).to.equal(state);
    });

    it("reverts InvalidAccount when account is admin account", async () => {
      const request = encodeStepBlock(0n, 0n, "0x");
      await expect(
        callAs(0, "pipePayable", ctx({ account: adminAccount, request }))
      ).to.be.revertedWithCustomError(host, "InvalidAccount");
    });

    it("reverts ZeroCursor when no STEP blocks", async () => {
      await expect(callAs(0, "pipePayable", ctx({ account: userAccount })))
        .to.be.revertedWithCustomError(host, "ZeroCursor");
    });


    it("tracks ETH value budget — reverts InsufficientValue when step requests too much", async () => {
      const largeValue = ethers.parseEther("1000");
      const request = encodeStepBlock(0n, largeValue, "0x");
      await expect(
        (host.connect(await getSigner(0)) as any).pipePayable(ctx({ account: userAccount, request }), { value: 0n })
      ).to.be.revertedWithCustomError(host, "InsufficientValue");
    });
  });
});




