import { expect } from "chai";
import { ethers } from "ethers";
import { deploy, getSigner } from "./helpers/setup.js";
import {
  encodeAmountBlock, encodeAmountBlockWithNode, encodeAmountBlockWithRecipient, encodeBalanceBlock, encodeCustodyBlock,
  encodeRecipientBlock, encodeNodeBlock, encodeTxBlock, encodeStepBlock,
  concat
} from "./helpers/blocks.js";

describe("Commands", () => {
  let host: Awaited<ReturnType<typeof deploy>>;
  let commander: string;
  let userAccount: string;
  let adminAccount: string;

  before(async () => {
    const signer = await getSigner(0);
    commander = await signer.getAddress();
    host = await deploy("TestHost", commander, ethers.ZeroAddress);
    adminAccount = await host.getAdminAccount();

    // Build a user account (unspecified prefix + address)
    const addrBig = BigInt(commander);
    // USER_PREFIX = (0x2001 << 16) | (0x01 << 8) | 0x02 = 0x20010102
    const USER_PREFIX = 0x20010102n;
    userAccount = ethers.zeroPadValue(
      ethers.toBeHex((USER_PREFIX << 224n) | (addrBig << 32n)), 32
    );
  });

  function ctx(overrides: Partial<{ target: bigint; account: string; state: string; request: string }> = {}) {
    return {
      target: overrides.target ?? 0n,
      account: overrides.account ?? userAccount,
      state: overrides.state ?? "0x",
      request: overrides.request ?? "0x",
    };
  }

  async function callAs(signerIndex: number, method: string, ...args: unknown[]) {
    const signer = await getSigner(signerIndex);
    return (host.connect(signer) as any)[method](...args);
  }

  // ── Deposit ───────────────────────────────────────────────────────────────

  describe("deposit", () => {
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

    it("accepts the explicit deposit command id as the target", async () => {
      const asset = ethers.zeroPadValue("0x01", 32);
      const request = encodeAmountBlock(asset, ethers.ZeroHash, 5n);
      const target = await host.getDepositId();
      await expect(callAs(0, "deposit", ctx({ target, request })))
        .to.emit(host, "DepositCalled")
        .withArgs(userAccount, asset, ethers.ZeroHash, 5n);
    });

    it("reverts UnexpectedEndpoint for wrong non-zero target", async () => {
      const asset = ethers.zeroPadValue("0x01", 32);
      const request = encodeAmountBlock(asset, ethers.ZeroHash, 1n);
      await expect(
        callAs(0, "deposit", ctx({ target: 999n, request }))
      ).to.be.revertedWithCustomError(host, "UnexpectedEndpoint");
    });

    it("reverts UnauthorizedCaller for untrusted caller", async () => {
      const asset = ethers.zeroPadValue("0x01", 32);
      const request = encodeAmountBlock(asset, ethers.ZeroHash, 1n);
      await expect(
        callAs(1, "deposit", ctx({ request }))
      ).to.be.revertedWithCustomError(host, "UnauthorizedCaller");
    });

    it("reverts EmptyRequest when request has no AMOUNT blocks", async () => {
      await expect(
        callAs(0, "deposit", ctx({ request: "0x" }))
      ).to.be.revertedWithCustomError(host, "EmptyRequest");
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

    it("uses RECIPIENT from request when present", async () => {
      const recipient = ethers.zeroPadValue("0xbabe", 32);
      const state = encodeBalanceBlock(asset, meta, 50n);
      const request = encodeRecipientBlock(recipient);
      const tx = await callAs(0, "withdraw", ctx({ state, request }));
      await expect(tx).to.emit(host, "WithdrawCalled")
        .withArgs(recipient, asset, meta, 50n);
    });

    it("reverts NoOperation for empty state", async () => {
      await expect(callAs(0, "withdraw", ctx()))
        .to.be.revertedWithCustomError(host, "NoOperation");
    });

    it("reverts ZeroRecipient when recipient resolves to zero", async () => {
      const state = encodeBalanceBlock(asset, meta, 10n);
      const zeroRecipient = encodeRecipientBlock(ethers.ZeroHash);
      await expect(callAs(0, "withdraw", ctx({ state, request: zeroRecipient })))
        .to.be.revertedWithCustomError(host, "ZeroRecipient");
    });
  });

  // ── Transfer ──────────────────────────────────────────────────────────────

  describe("transfer", () => {
    const asset = ethers.zeroPadValue("0x20", 32);
    const meta  = ethers.ZeroHash;

    it("emits TransferCalled for AMOUNT with RECIPIENT child", async () => {
      const to = ethers.zeroPadValue("0xbeef", 32);
      const request = encodeAmountBlockWithRecipient(asset, meta, 200n, to);
      const tx = await callAs(0, "transfer", ctx({ request }));
      await expect(tx).to.emit(host, "TransferCalled")
        .withArgs(userAccount, to, asset, meta, 200n);
    });

    it("reverts NoOperation when no AMOUNT blocks", async () => {
      const to = ethers.zeroPadValue("0xbeef", 32);
      const request = encodeRecipientBlock(to);
      await expect(callAs(0, "transfer", ctx({ request })))
        .to.be.revertedWithCustomError(host, "NoOperation");
    });

    it("reverts MalformedBlocks when AMOUNT has no RECIPIENT child", async () => {
      const request = encodeAmountBlock(asset, meta, 1n);
      await expect(callAs(0, "transfer", ctx({ request })))
        .to.be.revertedWithCustomError(host, "MalformedBlocks");
    });
  });

  // ── CreditTo ──────────────────────────────────────────────────────────────

  describe("creditBalanceToAccount", () => {
    const asset = ethers.zeroPadValue("0x30", 32);
    const meta  = ethers.ZeroHash;

    it("emits CreditToCalled for BALANCE blocks in state", async () => {
      const state = encodeBalanceBlock(asset, meta, 300n);
      const tx = await callAs(0, "creditBalanceToAccount", ctx({ state }));
      await expect(tx).to.emit(host, "CreditToCalled");
    });

    it("uses RECIPIENT from request when present", async () => {
      const recipient = ethers.zeroPadValue("0xcafe", 32);
      const state = encodeBalanceBlock(asset, meta, 100n);
      const request = encodeRecipientBlock(recipient);
      const tx = await callAs(0, "creditBalanceToAccount", ctx({ state, request }));
      await expect(tx).to.emit(host, "CreditToCalled")
        .withArgs(recipient, asset, meta, 100n, 100n);
    });

    it("reverts NoOperation for empty state", async () => {
      await expect(callAs(0, "creditBalanceToAccount", ctx()))
        .to.be.revertedWithCustomError(host, "NoOperation");
    });
  });

  // ── DebitFrom ─────────────────────────────────────────────────────────────

  describe("debitAccountToBalance", () => {
    const asset = ethers.zeroPadValue("0x40", 32);
    const meta  = ethers.ZeroHash;

    it("emits DebitFromCalled and returns BALANCE blocks", async () => {
      const request = encodeAmountBlock(asset, meta, 400n);
      const tx = await callAs(0, "debitAccountToBalance", ctx({ request }));
      await expect(tx).to.emit(host, "DebitFromCalled")
        .withArgs(userAccount, asset, meta, 400n, 400n);
    });

    it("returns one BALANCE block per AMOUNT block", async () => {
      const request = encodeAmountBlock(asset, meta, 100n);
      const result: string = await host.debitAccountToBalance.staticCall(ctx({ request }));
      expect(result).to.equal(encodeBalanceBlock(asset, meta, 100n));
    });

    it("reverts EmptyRequest when request has no AMOUNT blocks", async () => {
      await expect(callAs(0, "debitAccountToBalance", ctx()))
        .to.be.revertedWithCustomError(host, "EmptyRequest");
    });
  });

  // ── Settle ────────────────────────────────────────────────────────────────

  describe("settle", () => {
    it("emits SettleCalled for each TX block in state", async () => {
      const from_ = ethers.zeroPadValue("0xaa", 32);
      const to_   = ethers.zeroPadValue("0xbb", 32);
      const asset = ethers.zeroPadValue("0x50", 32);
      const meta  = ethers.ZeroHash;
      const state = encodeTxBlock(from_, to_, asset, meta, 500n);
      const tx = await callAs(0, "settle", ctx({ state }));
      await expect(tx).to.emit(host, "SettleCalled")
        .withArgs(from_, to_, asset, meta, 500n);
    });

    it("reverts NoOperation for empty state", async () => {
      await expect(callAs(0, "settle", ctx()))
        .to.be.revertedWithCustomError(host, "NoOperation");
    });
  });

  // ── Fund ──────────────────────────────────────────────────────────────────

  describe("fund", () => {
    it("emits FundCalled and returns CUSTODY blocks", async () => {
      const asset = ethers.zeroPadValue("0x60", 32);
      const meta  = ethers.ZeroHash;
      const hostId = 123456n;
      const state = encodeBalanceBlock(asset, meta, 600n);
      const request = encodeNodeBlock(hostId);
      const tx = await callAs(0, "fund", ctx({ state, request }));
      await expect(tx).to.emit(host, "FundCalled")
        .withArgs(hostId, userAccount, asset, meta, 600n);
    });

    it("returns CUSTODY blocks matching input BALANCE blocks", async () => {
      const asset = ethers.zeroPadValue("0x60", 32);
      const meta  = ethers.ZeroHash;
      const hostId = 123456n;
      const state = encodeBalanceBlock(asset, meta, 600n);
      const request = encodeNodeBlock(hostId);
      const result: string = await host.fund.staticCall(ctx({ state, request }));
      expect(result).to.equal(encodeCustodyBlock(hostId, asset, meta, 600n));
    });

    it("reverts EmptyRequest when state has no BALANCE blocks", async () => {
      const hostId = 123456n;
      const request = encodeNodeBlock(hostId);
      await expect(callAs(0, "fund", ctx({ request })))
        .to.be.revertedWithCustomError(host, "EmptyRequest");
    });

    it("reverts ZeroNode when no NODE block and backup is 0", async () => {
      const asset = ethers.zeroPadValue("0x60", 32);
      const state = encodeBalanceBlock(asset, ethers.ZeroHash, 100n);
      await expect(callAs(0, "fund", ctx({ state })))
        .to.be.revertedWithCustomError(host, "ZeroNode");
    });
  });

  // ── Provision ─────────────────────────────────────────────────────────────

  describe("provision", () => {
    it("emits ProvisionCalled and returns CUSTODY blocks", async () => {
      const asset = ethers.zeroPadValue("0x70", 32);
      const meta  = ethers.ZeroHash;
      const hostId = 654321n;
      const request = encodeAmountBlockWithNode(asset, meta, 700n, hostId);
      const tx = await callAs(0, "provision", ctx({ request }));
      await expect(tx).to.emit(host, "ProvisionCalled")
        .withArgs(hostId, userAccount, asset, meta, 700n);
    });

    it("returns CUSTODY blocks", async () => {
      const asset = ethers.zeroPadValue("0x70", 32);
      const hostId = 654321n;
      const request = encodeAmountBlockWithNode(asset, ethers.ZeroHash, 700n, hostId);
      const result: string = await host.provision.staticCall(ctx({ request }));
      expect(result).to.equal(encodeCustodyBlock(hostId, asset, ethers.ZeroHash, 700n));
    });

    it("reverts EmptyRequest when no AMOUNT blocks", async () => {
      const hostId = 654321n;
      const request = encodeNodeBlock(hostId);
      await expect(callAs(0, "provision", ctx({ request })))
        .to.be.revertedWithCustomError(host, "EmptyRequest");
    });
  });

  // ── Pipe ──────────────────────────────────────────────────────────────────

  describe("pipe", () => {
    it("executes STEP blocks and emits StepDispatched", async () => {
      const request = encodeStepBlock(0n, 0n, "0x");
      const tx = await callAs(0, "pipe", ctx({ account: userAccount, request }));
      await expect(tx).to.emit(host, "StepDispatched");
    });

    it("threads state through multiple steps", async () => {
      const request = concat(
        encodeStepBlock(0n, 0n, "0x"),
        encodeStepBlock(0n, 0n, "0x")
      );
      const tx = await callAs(0, "pipe", ctx({ account: userAccount, request }));
      const count: bigint = await host.stepCount();
      expect(count).to.be.gte(2n);
    });

    it("passes each step target and value through to the dispatcher", async () => {
      const request = concat(
        encodeStepBlock(11n, 7n, "0x1234"),
        encodeStepBlock(22n, 9n, "0xabcd")
      );
      const startCount = await host.stepCount();
      const tx = await callAs(0, "pipe", ctx({ account: userAccount, request }), { value: 16n });
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
      const result = await host.pipe.staticCall(ctx({ account: userAccount, state, request }));
      expect(result).to.equal(state);
    });

    it("reverts InvalidAccount when account is admin account", async () => {
      const request = encodeStepBlock(0n, 0n, "0x");
      await expect(
        callAs(0, "pipe", ctx({ account: adminAccount, request }))
      ).to.be.revertedWithCustomError(host, "InvalidAccount");
    });

    it("reverts NoOperation when no STEP blocks", async () => {
      await expect(callAs(0, "pipe", ctx({ account: userAccount })))
        .to.be.revertedWithCustomError(host, "NoOperation");
    });

    it("tracks ETH value budget — reverts InsufficientValue when step requests too much", async () => {
      const largeValue = ethers.parseEther("1000");
      const request = encodeStepBlock(0n, largeValue, "0x");
      await expect(
        (host.connect(await getSigner(0)) as any).pipe(ctx({ account: userAccount, request }), { value: 0n })
      ).to.be.revertedWithCustomError(host, "InsufficientValue");
    });
  });
});
