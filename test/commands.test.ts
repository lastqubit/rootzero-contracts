import { expect } from "chai";
import { ethers } from "ethers";
import { commandId, deploy, getSigner } from "./helpers/setup.js";
import "./helpers/matchers.js";
import {
  Keys,
  endpointDescriptor,
  encodeAmountBlock,
  encodeBalanceBlock, encodeAllocationBlock, encodeCustodyBlock,
  encodeAccountBlock, encodeNodeBlock, encodeStepBlock, encodeUserAccount,
  encodeContextBlock, encodeRecoverBlock, encodeRelayBlock,
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
    host = await deploy("TestHost", commander);
    adminAccount = await host.getAdminAccount();

    // Build a user account (unspecified prefix + address)
    const addrBig = BigInt(commander);
    // USER_PREFIX = (0x0120 << 16) | (0x01 << 8) | 0x03 = 0x01200103
    const USER_PREFIX = 0x01200103n;
    userAccount = ethers.zeroPadValue(
      ethers.toBeHex((USER_PREFIX << 224n) | (addrBig << 32n)), 32
    );
  });

  function ctx(overrides: Partial<{ account: string; state: string; input: string }> = {}) {
    return {
      account: overrides.account ?? userAccount,
      state: overrides.state ?? "0x",
      input: overrides.input ?? "0x",
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

  async function cmd(method: string) {
    return commandId(host.interface.getFunction(method)!.selector, host);
  }

  // ── Deposit ───────────────────────────────────────────────────────────────

  describe("deposit", () => {
    it("emits DepositCalled for a single AMOUNT block and returns BALANCE blocks", async () => {
      const asset = ethers.zeroPadValue("0x01", 32);
      const amount = 100n;
      const request = encodeAmountBlock(asset, amount);

      const tx = await callAs(0, "deposit", ctx({ input: request }));
      await expect(tx).to.emit(host, "DepositCalled")
        .withArgs(userAccount, asset, amount);
    });

    it("returns BALANCE blocks matching the deposited amounts", async () => {
      const asset = ethers.zeroPadValue("0x01", 32);
      const amount = 50n;
      const request = encodeAmountBlock(asset, amount);

      const result: string = await host.deposit.staticCall(ctx({ input: request }));
      expect(result).to.equal(encodeBalanceBlock(asset, amount));
    });

    it("processes multiple AMOUNT blocks", async () => {
      const asset1 = ethers.zeroPadValue("0x01", 32);
      const asset2 = ethers.zeroPadValue("0x02", 32);
      const request = concat(
        encodeAmountBlock(asset1, 10n),
        encodeAmountBlock(asset2, 20n)
      );

      const result: string = await host.deposit.staticCall(ctx({ input: request }));
      expect(result).to.equal(concat(
        encodeBalanceBlock(asset1, 10n),
        encodeBalanceBlock(asset2, 20n)
      ));
    });

    it("reverts AccessDenied for untrusted caller", async () => {
      const asset = ethers.zeroPadValue("0x01", 32);
      const request = encodeAmountBlock(asset, 1n);
      await expect(
        callAs(1, "deposit", ctx({ input: request }))
      ).to.be.revertedWithCustomError(host, "AccessDenied");
    });

    it("reverts ZeroCursor when request has no AMOUNT blocks", async () => {
      await expect(
        callAs(0, "deposit", ctx({ input: "0x" }))
      ).to.be.revertedWithCustomError(host, "ZeroCursor");
    });

    it("reverts MalformedBlocks for request with only 4 garbage bytes", async () => {
      await expect(
        callAs(0, "deposit", ctx({ input: "0xdeadbeef" }))
      ).to.be.revertedWithCustomError(host, "MalformedBlocks");
    });
  });
  describe("depositPayable", () => {
    it("passes a shared value budget through to the hook", async () => {
      const asset1 = ethers.zeroPadValue("0x03", 32);
      const asset2 = ethers.zeroPadValue("0x04", 32);
      const request = concat(
        encodeAmountBlock(asset1, 3n),
        encodeAmountBlock(asset2, 7n)
      );

      const tx = await callAs(0, "depositPayable", ctx({ input: request }), { value: 10n });
      await expect(tx).to.emit(host, "DepositPayableCalled")
        .withArgs(userAccount, asset1, 3n, 7n);
      await expect(tx).to.emit(host, "DepositPayableCalled")
        .withArgs(userAccount, asset2, 7n, 0n);
    });

    it("returns BALANCE blocks matching the deposited amounts", async () => {
      const asset = ethers.zeroPadValue("0x05", 32);
      const request = encodeAmountBlock(asset, 8n);

      const result: string = await host.depositPayable.staticCall(ctx({ input: request }), { value: 8n });
      expect(result).to.equal(encodeBalanceBlock(asset, 8n));
    });

  });


  // ── Withdraw ──────────────────────────────────────────────────────────────

  describe("withdraw", () => {
    const asset = ethers.zeroPadValue("0x10", 32);

    it("emits WithdrawCalled for BALANCE blocks in state", async () => {
      const state = encodeBalanceBlock(asset, 100n);
      const tx = await callAs(0, "withdraw", ctx({ state }));
      await expect(tx).to.emit(host, "WithdrawCalled")
        .withArgs(userAccount, asset, 100n);
    });

    it("reverts ZeroCursor for empty state", async () => {
      await expect(callAs(0, "withdraw", ctx()))
        .to.be.revertedWithCustomError(host, "ZeroCursor");
    });

    it("emits WithdrawCalled for each BALANCE block in a batch state", async () => {
      const asset1 = ethers.zeroPadValue("0x11", 32);
      const asset2 = ethers.zeroPadValue("0x12", 32);
      const asset3 = ethers.zeroPadValue("0x13", 32);
      const state = concat(
        encodeBalanceBlock(asset1, 10n),
        encodeBalanceBlock(asset2, 20n),
        encodeBalanceBlock(asset3, 30n),
      );
      const tx = await callAs(0, "withdraw", ctx({ state }));
      await expect(tx).to.emit(host, "WithdrawCalled").withArgs(userAccount, asset1, 10n);
      await expect(tx).to.emit(host, "WithdrawCalled").withArgs(userAccount, asset2, 20n);
      await expect(tx).to.emit(host, "WithdrawCalled").withArgs(userAccount, asset3, 30n);
    });

    it("reverts MalformedBlocks for state with a truncated BALANCE block", async () => {
      const full = encodeBalanceBlock(asset, 100n);
      const truncated = ethers.hexlify(ethers.getBytes(full).slice(0, -1));
      await expect(callAs(0, "withdraw", ctx({ state: truncated })))
        .to.be.revertedWithCustomError(host, "MalformedBlocks");
    });
  });

  describe("payout", () => {
    const asset = ethers.zeroPadValue("0x28", 32);

    it("emits PayoutCalled for paired BALANCE state and ACCOUNT request blocks", async () => {
      const to = encodeUserAccount("0xd00d");
      const state = encodeBalanceBlock(asset, 250n);
      const request = encodeAccountBlock(to);
      const tx = await callAs(0, "payout", ctx({ state, input: request }));

      await expect(tx).to.emit(host, "PayoutCalled")
        .withArgs(userAccount, to, asset, 250n);
    });

    it("pairs each BALANCE block with the matching ACCOUNT block", async () => {
      const asset1 = ethers.zeroPadValue("0x29", 32);
      const asset2 = ethers.zeroPadValue("0x2a", 32);
      const to1 = encodeUserAccount("0xd001");
      const to2 = encodeUserAccount("0xd002");
      const state = concat(
        encodeBalanceBlock(asset1, 10n),
        encodeBalanceBlock(asset2, 20n),
      );
      const request = concat(
        encodeAccountBlock(to1),
        encodeAccountBlock(to2),
      );
      const tx = await callAs(0, "payout", ctx({ state, input: request }));

      await expect(tx).to.emit(host, "PayoutCalled").withArgs(userAccount, to1, asset1, 10n);
      await expect(tx).to.emit(host, "PayoutCalled").withArgs(userAccount, to2, asset2, 20n);
    });

    it("reverts BadRatio when request accounts do not match state balances", async () => {
      const state = concat(
        encodeBalanceBlock(asset, 1n),
        encodeBalanceBlock(asset, 2n),
      );
      const request = encodeAccountBlock(encodeUserAccount("0xd003"));

      await expect(callAs(0, "payout", ctx({ state, input: request })))
        .to.be.revertedWithCustomError(host, "BadRatio");
    });

    it("reverts InvalidBlock when the paired request block is not an ACCOUNT", async () => {
      const state = encodeBalanceBlock(asset, 1n);
      const request = encodeBalanceBlock(asset, 1n);

      await expect(callAs(0, "payout", ctx({ state, input: request })))
        .to.be.revertedWithCustomError(host, "InvalidBlock");
    });
  });

  // ── CreditTo ──────────────────────────────────────────────────────────────

  describe("creditAccount", () => {
    const asset = ethers.zeroPadValue("0x30", 32);

    it("emits CreditToCalled for BALANCE blocks in state", async () => {
      const state = encodeBalanceBlock(asset, 300n);
      const tx = await callAs(0, "creditAccount", ctx({ state }));
      await expect(tx).to.emit(host, "CreditToCalled")
        .withArgs(userAccount, asset, 300n, 300n);
    });

    it("reverts ZeroCursor for empty state", async () => {
      await expect(callAs(0, "creditAccount", ctx()))
        .to.be.revertedWithCustomError(host, "ZeroCursor");
    });
  });

  // ── DebitFrom ─────────────────────────────────────────────────────────────

  describe("debitAccount", () => {
    const asset = ethers.zeroPadValue("0x40", 32);

    it("emits DebitFromCalled and returns BALANCE blocks", async () => {
      const request = encodeAmountBlock(asset, 400n);
      const tx = await callAs(0, "debitAccount", ctx({ input: request }));
      await expect(tx).to.emit(host, "DebitFromCalled")
        .withArgs(userAccount, asset, 400n, 400n);
    });

    it("returns one BALANCE block per AMOUNT block", async () => {
      const request = encodeAmountBlock(asset, 100n);
      const result: string = await host.debitAccount.staticCall(ctx({ input: request }));
      expect(result).to.equal(encodeBalanceBlock(asset, 100n));
    });

    it("reverts ZeroCursor when request has no AMOUNT blocks", async () => {
      await expect(callAs(0, "debitAccount", ctx()))
        .to.be.revertedWithCustomError(host, "ZeroCursor");
    });

    it("processes multiple AMOUNT blocks and emits DebitFromCalled for each", async () => {
      const asset1 = ethers.zeroPadValue("0x41", 32);
      const asset2 = ethers.zeroPadValue("0x42", 32);
      const asset3 = ethers.zeroPadValue("0x43", 32);
      const request = concat(
        encodeAmountBlock(asset1, 100n),
        encodeAmountBlock(asset2, 200n),
        encodeAmountBlock(asset3, 300n),
      );
      const tx = await callAs(0, "debitAccount", ctx({ input: request }));
      await expect(tx).to.emit(host, "DebitFromCalled").withArgs(userAccount, asset1, 100n, 100n);
      await expect(tx).to.emit(host, "DebitFromCalled").withArgs(userAccount, asset2, 200n, 200n);
      await expect(tx).to.emit(host, "DebitFromCalled").withArgs(userAccount, asset3, 300n, 300n);
    });

    it("returns one BALANCE block per AMOUNT block in a batch", async () => {
      const asset1 = ethers.zeroPadValue("0x44", 32);
      const asset2 = ethers.zeroPadValue("0x45", 32);
      const request = concat(
        encodeAmountBlock(asset1, 100n),
        encodeAmountBlock(asset2, 200n),
      );
      const result: string = await host.debitAccount.staticCall(ctx({ input: request }));
      expect(result).to.equal(concat(
        encodeBalanceBlock(asset1, 100n),
        encodeBalanceBlock(asset2, 200n),
      ));
    });
  });

  // ── Fund ──────────────────────────────────────────────────────────────────

  // ── Provision ─────────────────────────────────────────────────────────────

  describe("provision", () => {
    it("emits ProvisionCalled and returns CUSTODY blocks", async () => {
      const asset = ethers.zeroPadValue("0x70", 32);
      const hostId = 654321n;
      const request = encodeAllocationBlock(hostId, asset, 700n);
      const tx = await callAs(0, "provision", ctx({ input: request }));
      await expect(tx).to.emit(host, "ProvisionCalled")
        .withArgs(hostId, userAccount, asset, 700n);
    });

    it("returns CUSTODY blocks", async () => {
      const asset = ethers.zeroPadValue("0x70", 32);
      const hostId = 654321n;
      const request = encodeAllocationBlock(hostId, asset, 700n);
      const result: string = await host.provision.staticCall(ctx({ input: request }));
      expect(result).to.equal(encodeCustodyBlock(hostId, asset, 700n));
    });

    it("reverts InvalidBlock when request is not an ALLOCATION block", async () => {
      const hostId = 654321n;
      const request = encodeNodeBlock(hostId);
      await expect(callAs(0, "provision", ctx({ input: request })))
        .to.be.revertedWithCustomError(host, "InvalidBlock");
    });

    it("emits ProvisionCalled for each ALLOCATION block in a batch", async () => {
      const asset1 = ethers.zeroPadValue("0x71", 32);
      const asset2 = ethers.zeroPadValue("0x72", 32);
      const host1  = 111n;
      const host2  = 222n;
      const request = concat(
        encodeAllocationBlock(host1, asset1, 100n),
        encodeAllocationBlock(host2, asset2, 200n),
      );
      const tx = await callAs(0, "provision", ctx({ input: request }));
      await expect(tx).to.emit(host, "ProvisionCalled").withArgs(host1, userAccount, asset1, 100n);
      await expect(tx).to.emit(host, "ProvisionCalled").withArgs(host2, userAccount, asset2, 200n);
    });

    it("returns one CUSTODY block per request ALLOCATION block in a batch", async () => {
      const asset1 = ethers.zeroPadValue("0x73", 32);
      const asset2 = ethers.zeroPadValue("0x74", 32);
      const host1  = 333n;
      const host2  = 444n;
      const request = concat(
        encodeAllocationBlock(host1, asset1, 100n),
        encodeAllocationBlock(host2, asset2, 200n),
      );
      const result: string = await host.provision.staticCall(ctx({ input: request }));
      expect(result).to.equal(concat(
        encodeCustodyBlock(host1, asset1, 100n),
        encodeCustodyBlock(host2, asset2, 200n),
      ));
    });
  });
  describe("provisionPayable", () => {
    it("passes a shared value budget through to the allocation hook", async () => {
      const asset1 = ethers.zeroPadValue("0x75", 32);
      const asset2 = ethers.zeroPadValue("0x76", 32);
      const host1 = 555n;
      const host2 = 666n;
      const request = concat(
        encodeAllocationBlock(host1, asset1, 3n),
        encodeAllocationBlock(host2, asset2, 7n),
      );

      const tx = await callAs(0, "provisionPayable", ctx({ input: request }), { value: 10n });
      await expect(tx).to.emit(host, "ProvisionPayableCalled")
        .withArgs(host1, userAccount, asset1, 3n, 7n);
      await expect(tx).to.emit(host, "ProvisionPayableCalled")
        .withArgs(host2, userAccount, asset2, 7n, 0n);
    });

    it("returns one CUSTODY block per request ALLOCATION block", async () => {
      const asset = ethers.zeroPadValue("0x77", 32);
      const hostId = 777n;
      const request = encodeAllocationBlock(hostId, asset, 8n);

      const result: string = await host.provisionPayable.staticCall(ctx({ input: request }), { value: 8n });
      expect(result).to.equal(encodeCustodyBlock(hostId, asset, 8n));
    });

  });


  // ── Pipe ──────────────────────────────────────────────────────────────────

  describe("relayPayable", () => {
    const PORTAL_PREFIX = 0x01200201n;

    function portalNode(id: bigint) {
      return (PORTAL_PREFIX << 224n) | id;
    }

    it("discovers relayPayable as accepting any state", async () => {
      const deployment = host.deploymentTransaction();
      expect(deployment).to.not.equal(null);

      await expect(deployment!).to.emit(host, "Endpoint")
        .withArgs(
          await host.host(),
          await cmd("relayPayable"),
          endpointDescriptor({ state: Keys.Any, input: Keys.Relay, funded: true }),
        );
      await expect(deployment!).to.emit(host, "Labeled")
        .withArgs(await cmd("relayPayable"), ethers.ZeroHash, "relayPayable");
    });

    it("passes the RELAY block as an encoded destination context to the hook", async () => {
      const asset = ethers.zeroPadValue("0x80", 32);
      const state = encodeBalanceBlock(asset, 12n);
      const portal = portalNode(31337n);
      const resources = 9n;
      const steps = encodeStepBlock(0n, 0n, "0x1234");
      const request = encodeRelayBlock(portal, resources, steps);
      const context = encodeContextBlock(userAccount, state, steps);

      const result: string = await host.relayPayable.staticCall(ctx({ state, input: request }));
      expect(result).to.equal("0x");

      const tx = await callAs(0, "relayPayable", ctx({ state, input: request }));
      await expect(tx).to.emit(host, "RelayCalled")
        .withArgs(portal, resources, context);
    });

    it("reverts ZeroCursor when request has no RELAY block", async () => {
      await expect(callAs(0, "relayPayable", ctx()))
        .to.be.revertedWithCustomError(host, "ZeroCursor");
    });

    it("reverts AccessDenied for untrusted caller", async () => {
      const portal = portalNode(31337n);
      const request = encodeRelayBlock(portal, 0n, encodeStepBlock(0n, 0n, "0x"));

      await expect(callAs(1, "relayPayable", ctx({ input: request })))
        .to.be.revertedWithCustomError(host, "AccessDenied");
    });

    it("reverts InvalidBlock when request is not a RELAY block", async () => {
      const asset = ethers.zeroPadValue("0x81", 32);
      const request = encodeAmountBlock(asset, 1n);

      await expect(callAs(0, "relayPayable", ctx({ input: request })))
        .to.be.revertedWithCustomError(host, "InvalidBlock");
    });

    it("reverts BadRatio when request has more than one RELAY block", async () => {
      const portal = portalNode(31337n);
      const request = concat(
        encodeRelayBlock(portal, 0n, encodeStepBlock(0n, 0n, "0x")),
        encodeRelayBlock(portal, 0n, encodeStepBlock(0n, 0n, "0x"))
      );

      await expect(callAs(0, "relayPayable", ctx({ input: request })))
        .to.be.revertedWithCustomError(host, "BadRatio");
    });

    it("passes relay resources through even when it exceeds msg.value", async () => {
      const portal = portalNode(31337n);
      const steps = encodeStepBlock(0n, 0n, "0x");
      const request = encodeRelayBlock(portal, 2n, steps);
      const context = encodeContextBlock(userAccount, "0x", steps);

      const tx = await callAs(0, "relayPayable", ctx({ input: request }));
      await expect(tx).to.emit(host, "RelayCalled")
        .withArgs(portal, 2n, context);
    });

    it("settles unspent command value after relay dispatch", async () => {
      const portal = portalNode(31337n);
      const request = encodeRelayBlock(portal, 0n, encodeStepBlock(0n, 0n, "0x"));

      await expect(callAs(0, "relayPayable", ctx({ input: request }), { value: 1n }))
        .to.be.revertedWithCustomError(host, "UnusedValue");
    });
  });

  describe("recoverPayable", () => {
    it("discovers recoverPayable as a payable recovery command", async () => {
      const deployment = host.deploymentTransaction();
      expect(deployment).to.not.equal(null);

      await expect(deployment!).to.emit(host, "Endpoint")
        .withArgs(
          await host.host(),
          await cmd("recoverPayable"),
          endpointDescriptor({ input: Keys.Recover, funded: true }),
        );
      await expect(deployment!).to.emit(host, "Labeled")
        .withArgs(await cmd("recoverPayable"), ethers.ZeroHash, "recoverPayable");
    });

    it("passes the recovery key, witness, and assigned value to the hook", async () => {
      const key = ethers.zeroPadValue("0xbeef", 32);
      const handler = 99n;
      const resources = 13n;
      const step = encodeStepBlock(0n, 0n, "0x1234");
      const witness = encodeContextBlock(userAccount, "0x", step);
      const request = encodeRecoverBlock(handler, resources, key, witness);

      const result: string = await host.recoverPayable.staticCall(ctx({ input: request }), { value: resources });
      expect(result).to.equal("0x");

      const tx = await callAs(0, "recoverPayable", ctx({ input: request }), { value: resources });
      await expect(tx).to.emit(host, "RecoverCalled")
        .withArgs(handler, key, witness, resources);
    });

    it("settles unspent command value after recovery", async () => {
      const key = ethers.zeroPadValue("0xcafe", 32);
      const witness = encodeContextBlock(userAccount, "0x", "0x");
      const request = encodeRecoverBlock(0n, 0n, key, witness);

      await expect(callAs(0, "recoverPayable", ctx({ input: request }), { value: 1n }))
        .to.be.revertedWithCustomError(host, "UnusedValue");
    });
  });

  describe("pipeline", () => {
    it("executes STEP blocks and emits StepDispatched", async () => {
      const request = encodeStepBlock(0n, 0n, "0x");
      const tx = await callAs(0, "testPipe", userAccount, "0x", request);
      await expect(tx).to.emit(host, "StepDispatched");
    });

    it("threads state through multiple steps", async () => {
      const request = concat(
        encodeStepBlock(0n, 0n, "0x"),
        encodeStepBlock(0n, 0n, "0x")
      );
      const tx = await callAs(0, "testPipe", userAccount, "0x", request);
      const count: bigint = await host.stepCount();
      expect(count).to.be.gte(2n);
    });

    it("passes each step target and EVM value through to the dispatcher", async () => {
      const request = concat(
        encodeStepBlock(11n, 7n, "0x1234"),
        encodeStepBlock(22n, 9n, "0xabcd")
      );
      const startCount = await host.stepCount();
      const tx = await callAs(0, "testPipe", userAccount, "0x", request, { value: 16n });
      await expect(tx).to.emit(host, "StepDispatched").withArgs(11n, startCount, 7n);
      await expect(tx).to.emit(host, "StepDispatched").withArgs(22n, startCount + 1n, 9n);
    });

    it("uses only the low 128 resource bits as EVM step value", async () => {
      const resources = (123n << 128n) | 7n;
      const request = encodeStepBlock(11n, resources, "0x1234");
      const startCount = await host.stepCount();

      const tx = await callAs(0, "testPipe", userAccount, "0x", request, { value: 7n });

      await expect(tx).to.emit(host, "StepDispatched").withArgs(11n, startCount, 7n);
    });

    it("reverts UnexpectedState when final threaded state is non-empty", async () => {
      const state = encodeBalanceBlock(
        ethers.zeroPadValue("0x99", 32),
        123n
      );
      const request = encodeStepBlock(0n, 0n, "0x");
      await expect(host.testPipe.staticCall(userAccount, state, request))
        .to.be.revertedWithCustomError(host, "UnexpectedState");
    });

    it("reverts ZeroCursor when no STEP blocks", async () => {
      await expect(callAs(0, "testPipe", userAccount, "0x", "0x"))
        .to.be.revertedWithCustomError(host, "ZeroCursor");
    });


    it("tracks ETH value budget — reverts InsufficientValue when step requests too much", async () => {
      const largeValue = ethers.parseEther("1000");
      const request = encodeStepBlock(0n, largeValue, "0x");
      await expect(
        (host.connect(await getSigner(0)) as any).testPipe(userAccount, "0x", request, { value: 0n })
      ).to.be.revertedWithCustomError(host, "InsufficientValue");
    });
  });
});




