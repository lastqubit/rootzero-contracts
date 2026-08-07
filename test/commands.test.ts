import { expect } from "chai";
import { ethers } from "ethers";
import { commandId, deploy, getSigner } from "./helpers/setup.js";
import "./helpers/matchers.js";
import {
  Keys,
  endpointDescriptor,
  exactSpec,
  encodeAmountBlock,
  encodeBalanceBlock, encodeAllocationBlock, encodeCustodyBlock,
  encodeAccountBlock, encodeNodeBlock, encodeStepBlock, encodeUserAccount,
  encodeActionBlock, encodeContextBlock, encodeRecoverBlock, encodeRelayBlock, encodeTxBlock, encodeLabelBlock,
  concat
} from "./helpers/blocks.js";

describe("Commands", () => {
  let host: Awaited<ReturnType<typeof deploy>>;
  let utils: Awaited<ReturnType<typeof deploy>>;
  let commander: string;
  let userAccount: string;
  let adminAccount: string;

  before(async () => {
    const signer = await getSigner(0);
    commander = await signer.getAddress();
    host = await deploy("TestHost", commander);
    utils = await deploy("TestUtils");
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
    return [
      overrides.account ?? userAccount,
      overrides.state ?? "0x",
      overrides.input ?? "0x",
    ] as const;
  }

  function callAs(signerIndex: number, method: string, ...args: unknown[]) {
    const promise = getSigner(signerIndex).then((signer) => {
      const callArgs = Array.isArray(args[0]) ? [...args[0], ...args.slice(1)] : args;
      const txPromise = (host.connect(signer) as any)[method](...callArgs);
      Promise.resolve(txPromise).catch(() => {});
      return txPromise;
    });
    Promise.resolve(promise).catch(() => {});
    return promise;
  }

  async function cmd(method: string) {
    return commandId(host.interface.getFunction(method)!.selector, host);
  }

  it("annotates commands with intrinsic semantic actions", async () => {
    const deployment = host.deploymentTransaction();
    expect(deployment).to.not.equal(null);

    for (const [method, action] of [
      ["deposit", 4n],
      ["depositPayable", 4n],
      ["withdraw", 5n],
      ["payout", 2n],
    ] as const) {
      await expect(deployment!).to.emit(host, "Annotation")
        .withArgs(await cmd(method), encodeActionBlock(action));
    }
  });

  // ── Deposit ───────────────────────────────────────────────────────────────

  describe("deposit", () => {
    it("emits DepositCalled for a single AMOUNT block and returns BALANCE blocks", async () => {
      const asset = ethers.zeroPadValue("0x01", 32);
      const amount = 100n;
      const input = encodeAmountBlock(asset, amount);

      const tx = await callAs(0, "deposit", ctx({ input: input }));
      await expect(tx).to.emit(host, "DepositCalled")
        .withArgs(userAccount, asset, amount);
    });

    it("returns BALANCE blocks matching the deposited amounts", async () => {
      const asset = ethers.zeroPadValue("0x01", 32);
      const amount = 50n;
      const input = encodeAmountBlock(asset, amount);

      const [result, transactions] = await host.deposit.staticCall(...ctx({ input: input }));
      expect(result).to.equal(encodeBalanceBlock(asset, amount));
      expect(transactions).to.equal("0x");
    });

    it("processes multiple AMOUNT blocks", async () => {
      const asset1 = ethers.zeroPadValue("0x01", 32);
      const asset2 = ethers.zeroPadValue("0x02", 32);
      const input = concat(
        encodeAmountBlock(asset1, 10n),
        encodeAmountBlock(asset2, 20n)
      );

      const [result, transactions] = await host.deposit.staticCall(...ctx({ input: input }));
      expect(result).to.equal(concat(
        encodeBalanceBlock(asset1, 10n),
        encodeBalanceBlock(asset2, 20n)
      ));
      expect(transactions).to.equal("0x");
    });

    it("accepts an ordinary command call from an authorized node", async () => {
      const caller = await deploy("TestExecuteTarget");
      const node = await utils.testToHostId(await caller.getAddress());
      await host.authorize(adminAccount, "0x", encodeNodeBlock(node));

      const asset = ethers.zeroPadValue("0x03", 32);
      const input = encodeAmountBlock(asset, 25n);
      const data = host.interface.encodeFunctionData("deposit", ctx({ input }));

      await expect(caller.callTarget(await host.getAddress(), data))
        .to.emit(host, "DepositCalled")
        .withArgs(userAccount, asset, 25n);
    });

    it("reverts AccessDenied for untrusted caller", async () => {
      const asset = ethers.zeroPadValue("0x01", 32);
      const input = encodeAmountBlock(asset, 1n);
      await expect(
        callAs(1, "deposit", ctx({ input: input }))
      ).to.be.revertedWithCustomError(host, "AccessDenied");
    });

    it("reverts EmptyRun when input has no AMOUNT blocks", async () => {
      await expect(
        callAs(0, "deposit", ctx({ input: "0x" }))
      ).to.be.revertedWithCustomError(host, "EmptyRun");
    });

    it("reverts MalformedBlocks for input with only 4 garbage bytes", async () => {
      await expect(
        callAs(0, "deposit", ctx({ input: "0xdeadbeef" }))
      ).to.be.revertedWithCustomError(host, "MalformedBlocks");
    });
  });
  describe("depositPayable", () => {
    it("passes a shared value budget through to the hook", async () => {
      const asset1 = ethers.zeroPadValue("0x03", 32);
      const asset2 = ethers.zeroPadValue("0x04", 32);
      const input = concat(
        encodeAmountBlock(asset1, 3n),
        encodeAmountBlock(asset2, 7n)
      );

      const tx = await callAs(0, "depositPayable", ctx({ input: input }), { value: 10n });
      await expect(tx).to.emit(host, "DepositPayableCalled")
        .withArgs(userAccount, asset1, 3n, 7n);
      await expect(tx).to.emit(host, "DepositPayableCalled")
        .withArgs(userAccount, asset2, 7n, 0n);
    });

    it("returns BALANCE blocks matching the deposited amounts", async () => {
      const asset = ethers.zeroPadValue("0x05", 32);
      const input = encodeAmountBlock(asset, 8n);

      const [result, transactions] = await host.depositPayable.staticCall(...ctx({ input: input }), { value: 8n });
      expect(result).to.equal(encodeBalanceBlock(asset, 8n));
      expect(transactions).to.equal("0x");
    });

    it("keeps output and remaining-value transactions in separate writer lanes", async () => {
      const asset = ethers.zeroPadValue("0x06", 32);
      const input = encodeAmountBlock(asset, 8n);

      const [result, transactions] = await host.depositPayable.staticCall(...ctx({ input: input }), { value: 9n });
      expect(result).to.equal(encodeBalanceBlock(asset, 8n));
      expect(ethers.getBytes(transactions).length).to.equal(136);
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

    it("reverts EmptyRun for empty state", async () => {
      await expect(callAs(0, "withdraw", ctx()))
        .to.be.revertedWithCustomError(host, "EmptyRun");
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

    it("emits PayoutCalled for paired BALANCE state and ACCOUNT input blocks", async () => {
      const to = encodeUserAccount("0xd00d");
      const state = encodeBalanceBlock(asset, 250n);
      const input = encodeAccountBlock(to);
      const tx = await callAs(0, "payout", ctx({ state, input: input }));

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
      const input = concat(
        encodeAccountBlock(to1),
        encodeAccountBlock(to2),
      );
      const tx = await callAs(0, "payout", ctx({ state, input: input }));

      await expect(tx).to.emit(host, "PayoutCalled").withArgs(userAccount, to1, asset1, 10n);
      await expect(tx).to.emit(host, "PayoutCalled").withArgs(userAccount, to2, asset2, 20n);
    });

    it("reverts BadRatio when input accounts do not match state balances", async () => {
      const state = concat(
        encodeBalanceBlock(asset, 1n),
        encodeBalanceBlock(asset, 2n),
      );
      const input = encodeAccountBlock(encodeUserAccount("0xd003"));

      await expect(callAs(0, "payout", ctx({ state, input: input })))
        .to.be.revertedWithCustomError(host, "BadRatio");
    });

    it("reverts InvalidBlock when the paired input block is not an ACCOUNT", async () => {
      const state = encodeBalanceBlock(asset, 1n);
      const input = encodeBalanceBlock(asset, 1n);

      await expect(callAs(0, "payout", ctx({ state, input: input })))
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

    it("reverts EmptyRun for empty state", async () => {
      await expect(callAs(0, "creditAccount", ctx()))
        .to.be.revertedWithCustomError(host, "EmptyRun");
    });
  });

  // ── DebitFrom ─────────────────────────────────────────────────────────────

  describe("debitAccount", () => {
    const asset = ethers.zeroPadValue("0x40", 32);

    it("emits DebitFromCalled and returns BALANCE blocks", async () => {
      const input = encodeAmountBlock(asset, 400n);
      const tx = await callAs(0, "debitAccount", ctx({ input: input }));
      await expect(tx).to.emit(host, "DebitFromCalled")
        .withArgs(userAccount, asset, 400n, 400n);
    });

    it("returns one BALANCE block per AMOUNT block", async () => {
      const input = encodeAmountBlock(asset, 100n);
      const [result, transactions] = await host.debitAccount.staticCall(...ctx({ input: input }));
      expect(result).to.equal(encodeBalanceBlock(asset, 100n));
      expect(transactions).to.equal("0x");
    });

    it("reverts EmptyRun when input has no AMOUNT blocks", async () => {
      await expect(callAs(0, "debitAccount", ctx()))
        .to.be.revertedWithCustomError(host, "EmptyRun");
    });

    it("processes multiple AMOUNT blocks and emits DebitFromCalled for each", async () => {
      const asset1 = ethers.zeroPadValue("0x41", 32);
      const asset2 = ethers.zeroPadValue("0x42", 32);
      const asset3 = ethers.zeroPadValue("0x43", 32);
      const input = concat(
        encodeAmountBlock(asset1, 100n),
        encodeAmountBlock(asset2, 200n),
        encodeAmountBlock(asset3, 300n),
      );
      const tx = await callAs(0, "debitAccount", ctx({ input: input }));
      await expect(tx).to.emit(host, "DebitFromCalled").withArgs(userAccount, asset1, 100n, 100n);
      await expect(tx).to.emit(host, "DebitFromCalled").withArgs(userAccount, asset2, 200n, 200n);
      await expect(tx).to.emit(host, "DebitFromCalled").withArgs(userAccount, asset3, 300n, 300n);
    });

    it("returns one BALANCE block per AMOUNT block in a batch", async () => {
      const asset1 = ethers.zeroPadValue("0x44", 32);
      const asset2 = ethers.zeroPadValue("0x45", 32);
      const input = concat(
        encodeAmountBlock(asset1, 100n),
        encodeAmountBlock(asset2, 200n),
      );
      const [result, transactions] = await host.debitAccount.staticCall(...ctx({ input: input }));
      expect(result).to.equal(concat(
        encodeBalanceBlock(asset1, 100n),
        encodeBalanceBlock(asset2, 200n),
      ));
      expect(transactions).to.equal("0x");
    });
  });

  // ── Fund ──────────────────────────────────────────────────────────────────

  // ── Allocate / Provision ──────────────────────────────────────────────────

  describe("allocate", () => {
    it("discovers BALANCE state, NODE input, and CUSTODY output lanes", async () => {
      const deployment = host.deploymentTransaction();
      expect(deployment).to.not.equal(null);

      await expect(deployment!).to.emit(host, "Endpoint")
        .withArgs(
          await host.host(),
          await cmd("allocate"),
          endpointDescriptor({ state: Keys.Balance, input: Keys.Node, output: exactSpec(Keys.Custody, 96) }),
        );
    });

    it("calls the hook and returns CUSTODY state", async () => {
      const asset = ethers.zeroPadValue("0x60", 32);
      const hostId = 123456n;
      const state = encodeBalanceBlock(asset, 600n);
      const input = encodeNodeBlock(hostId);

      const tx = await callAs(0, "allocate", ctx({ state, input }));
      await expect(tx).to.emit(host, "AllocateCalled")
        .withArgs(hostId, userAccount, asset, 600n);

      const [result, transactions] = await host.allocate.staticCall(...ctx({ state, input }));
      expect(result).to.equal(encodeCustodyBlock(hostId, asset, 600n));
      expect(transactions).to.equal("0x");
    });

    it("pairs each BALANCE with the NODE at the same position", async () => {
      const asset1 = ethers.zeroPadValue("0x61", 32);
      const asset2 = ethers.zeroPadValue("0x62", 32);
      const state = concat(
        encodeBalanceBlock(asset1, 100n),
        encodeBalanceBlock(asset2, 200n),
      );
      const input = concat(encodeNodeBlock(111n), encodeNodeBlock(222n));

      const [result, transactions] = await host.allocate.staticCall(...ctx({ state, input }));
      expect(result).to.equal(concat(
        encodeCustodyBlock(111n, asset1, 100n),
        encodeCustodyBlock(222n, asset2, 200n),
      ));
      expect(transactions).to.equal("0x");
    });

    it("reverts BadRatio when NODE and BALANCE counts differ", async () => {
      const asset = ethers.zeroPadValue("0x63", 32);
      const state = concat(
        encodeBalanceBlock(asset, 100n),
        encodeBalanceBlock(asset, 200n),
      );
      const input = encodeNodeBlock(111n);

      await expect(callAs(0, "allocate", ctx({ state, input })))
        .to.be.revertedWithCustomError(host, "BadRatio");
    });

    it("reverts InvalidBlock for non-NODE input", async () => {
      const asset = ethers.zeroPadValue("0x64", 32);
      const state = encodeBalanceBlock(asset, 100n);
      const input = encodeAmountBlock(asset, 100n);

      await expect(callAs(0, "allocate", ctx({ state, input })))
        .to.be.revertedWithCustomError(host, "InvalidBlock");
    });
  });

  describe("provision", () => {
    it("emits ProvisionCalled and returns CUSTODY blocks", async () => {
      const asset = ethers.zeroPadValue("0x70", 32);
      const hostId = 654321n;
      const input = encodeAllocationBlock(hostId, asset, 700n);
      const tx = await callAs(0, "provision", ctx({ input: input }));
      await expect(tx).to.emit(host, "ProvisionCalled")
        .withArgs(hostId, userAccount, asset, 700n);
    });

    it("returns CUSTODY blocks", async () => {
      const asset = ethers.zeroPadValue("0x70", 32);
      const hostId = 654321n;
      const input = encodeAllocationBlock(hostId, asset, 700n);
      const [result, transactions] = await host.provision.staticCall(...ctx({ input: input }));
      expect(result).to.equal(encodeCustodyBlock(hostId, asset, 700n));
      expect(transactions).to.equal("0x");
    });

    it("reverts OutOfBounds when input is too short for an ALLOCATION block", async () => {
      const hostId = 654321n;
      const input = encodeNodeBlock(hostId);
      await expect(callAs(0, "provision", ctx({ input: input })))
        .to.be.revertedWithCustomError(host, "OutOfBounds");
    });

    it("emits ProvisionCalled for each ALLOCATION block in a batch", async () => {
      const asset1 = ethers.zeroPadValue("0x71", 32);
      const asset2 = ethers.zeroPadValue("0x72", 32);
      const host1  = 111n;
      const host2  = 222n;
      const input = concat(
        encodeAllocationBlock(host1, asset1, 100n),
        encodeAllocationBlock(host2, asset2, 200n),
      );
      const tx = await callAs(0, "provision", ctx({ input: input }));
      await expect(tx).to.emit(host, "ProvisionCalled").withArgs(host1, userAccount, asset1, 100n);
      await expect(tx).to.emit(host, "ProvisionCalled").withArgs(host2, userAccount, asset2, 200n);
    });

    it("returns one CUSTODY block per input ALLOCATION block in a batch", async () => {
      const asset1 = ethers.zeroPadValue("0x73", 32);
      const asset2 = ethers.zeroPadValue("0x74", 32);
      const host1  = 333n;
      const host2  = 444n;
      const input = concat(
        encodeAllocationBlock(host1, asset1, 100n),
        encodeAllocationBlock(host2, asset2, 200n),
      );
      const [result, transactions] = await host.provision.staticCall(...ctx({ input: input }));
      expect(result).to.equal(concat(
        encodeCustodyBlock(host1, asset1, 100n),
        encodeCustodyBlock(host2, asset2, 200n),
      ));
      expect(transactions).to.equal("0x");
    });
  });
  describe("provisionPayable", () => {
    it("passes a shared value budget through to the allocation hook", async () => {
      const asset1 = ethers.zeroPadValue("0x75", 32);
      const asset2 = ethers.zeroPadValue("0x76", 32);
      const host1 = 555n;
      const host2 = 666n;
      const input = concat(
        encodeAllocationBlock(host1, asset1, 3n),
        encodeAllocationBlock(host2, asset2, 7n),
      );

      const tx = await callAs(0, "provisionPayable", ctx({ input: input }), { value: 10n });
      await expect(tx).to.emit(host, "ProvisionPayableCalled")
        .withArgs(host1, userAccount, asset1, 3n, 7n);
      await expect(tx).to.emit(host, "ProvisionPayableCalled")
        .withArgs(host2, userAccount, asset2, 7n, 0n);
    });

    it("returns one CUSTODY block per input ALLOCATION block", async () => {
      const asset = ethers.zeroPadValue("0x77", 32);
      const hostId = 777n;
      const input = encodeAllocationBlock(hostId, asset, 8n);

      const [result, transactions] = await host.provisionPayable.staticCall(...ctx({ input: input }), { value: 8n });
      expect(result).to.equal(encodeCustodyBlock(hostId, asset, 8n));
      expect(transactions).to.equal("0x");
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
      await expect(deployment!).to.emit(host, "Annotation")
        .withArgs(await cmd("relayPayable"), encodeLabelBlock(ethers.ZeroHash, "relayPayable"));
    });

    it("passes the RELAY block as an encoded destination context to the hook", async () => {
      const asset = ethers.zeroPadValue("0x80", 32);
      const state = encodeBalanceBlock(asset, 12n);
      const portal = portalNode(31337n);
      const resources = 9n;
      const steps = encodeStepBlock(0n, 0n, "0x1234");
      const input = encodeRelayBlock(portal, resources, steps);
      const context = encodeContextBlock(userAccount, state, steps);

      const [result, transactions] = await host.relayPayable.staticCall(...ctx({ state, input: input }));
      expect(result).to.equal("0x");
      expect(transactions).to.equal("0x");

      const tx = await callAs(0, "relayPayable", ctx({ state, input: input }));
      await expect(tx).to.emit(host, "RelayCalled")
        .withArgs(portal, resources, context);
    });

    it("reverts EmptyRun when input has no RELAY block", async () => {
      await expect(callAs(0, "relayPayable", ctx()))
        .to.be.revertedWithCustomError(host, "EmptyRun");
    });

    it("reverts AccessDenied for untrusted caller", async () => {
      const portal = portalNode(31337n);
      const input = encodeRelayBlock(portal, 0n, encodeStepBlock(0n, 0n, "0x"));

      await expect(callAs(1, "relayPayable", ctx({ input: input })))
        .to.be.revertedWithCustomError(host, "AccessDenied");
    });

    it("reverts InvalidBlock when input is not a RELAY block", async () => {
      const asset = ethers.zeroPadValue("0x81", 32);
      const input = encodeAmountBlock(asset, 1n);

      await expect(callAs(0, "relayPayable", ctx({ input: input })))
        .to.be.revertedWithCustomError(host, "InvalidBlock");
    });

    it("reverts BadRatio when input has more than one RELAY block", async () => {
      const portal = portalNode(31337n);
      const input = concat(
        encodeRelayBlock(portal, 0n, encodeStepBlock(0n, 0n, "0x")),
        encodeRelayBlock(portal, 0n, encodeStepBlock(0n, 0n, "0x"))
      );

      await expect(callAs(0, "relayPayable", ctx({ input: input })))
        .to.be.revertedWithCustomError(host, "BadRatio");
    });

    it("passes relay resources through even when it exceeds msg.value", async () => {
      const portal = portalNode(31337n);
      const steps = encodeStepBlock(0n, 0n, "0x");
      const input = encodeRelayBlock(portal, 2n, steps);
      const context = encodeContextBlock(userAccount, "0x", steps);

      const tx = await callAs(0, "relayPayable", ctx({ input: input }));
      await expect(tx).to.emit(host, "RelayCalled")
        .withArgs(portal, 2n, context);
    });

    it("returns unspent command value after relay dispatch as a transaction", async () => {
      const portal = portalNode(31337n);
      const input = encodeRelayBlock(portal, 0n, encodeStepBlock(0n, 0n, "0x"));

      const [state, transactions] = await host.relayPayable.staticCall(...ctx({ input: input }), { value: 1n });
      expect(state).to.equal("0x");
      expect(ethers.getBytes(transactions).length).to.equal(136);
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
      await expect(deployment!).to.emit(host, "Annotation")
        .withArgs(await cmd("recoverPayable"), encodeLabelBlock(ethers.ZeroHash, "recoverPayable"));
    });

    it("passes the recovery key, witness, and assigned value to the hook", async () => {
      const key = ethers.zeroPadValue("0xbeef", 32);
      const handler = 99n;
      const resources = 13n;
      const step = encodeStepBlock(0n, 0n, "0x1234");
      const witness = encodeContextBlock(userAccount, "0x", step);
      const input = encodeRecoverBlock(handler, resources, key, witness);

      const [result, transactions] = await host.recoverPayable.staticCall(...ctx({ input: input }), { value: resources });
      expect(result).to.equal("0x");
      expect(transactions).to.equal("0x");

      const tx = await callAs(0, "recoverPayable", ctx({ input: input }), { value: resources });
      await expect(tx).to.emit(host, "RecoverCalled")
        .withArgs(handler, key, witness, resources);
    });

    it("returns unspent command value after recovery as a transaction", async () => {
      const key = ethers.zeroPadValue("0xcafe", 32);
      const witness = encodeContextBlock(userAccount, "0x", "0x");
      const input = encodeRecoverBlock(0n, 0n, key, witness);

      const [state, transactions] = await host.recoverPayable.staticCall(...ctx({ input: input }), { value: 1n });
      expect(state).to.equal("0x");
      expect(ethers.getBytes(transactions).length).to.equal(136);
    });
  });

  describe("pipeline", () => {
    it("executes STEP blocks and emits StepDispatched", async () => {
      const input = encodeStepBlock(0n, 0n, "0x");
      const tx = await callAs(0, "testPipe", userAccount, "0x", input);
      await expect(tx).to.emit(host, "StepDispatched");
    });

    it("threads state through multiple steps", async () => {
      const input = concat(
        encodeStepBlock(0n, 0n, "0x"),
        encodeStepBlock(0n, 0n, "0x")
      );
      const tx = await callAs(0, "testPipe", userAccount, "0x", input);
      const count: bigint = await host.stepCount();
      expect(count).to.be.gte(2n);
    });

    it("passes each step command and EVM value through to the dispatcher", async () => {
      const input = concat(
        encodeStepBlock(11n, 7n, "0x1234"),
        encodeStepBlock(22n, 9n, "0xabcd")
      );
      const startCount = await host.stepCount();
      const tx = await callAs(0, "testPipe", userAccount, "0x", input, { value: 16n });
      await expect(tx).to.emit(host, "StepDispatched").withArgs(11n, startCount, 7n);
      await expect(tx).to.emit(host, "StepDispatched").withArgs(22n, startCount + 1n, 9n);
    });

    it("uses only the low 128 resource bits as EVM step value", async () => {
      const resources = (123n << 128n) | 7n;
      const input = encodeStepBlock(11n, resources, "0x1234");
      const startCount = await host.stepCount();

      const tx = await callAs(0, "testPipe", userAccount, "0x", input, { value: 7n });

      await expect(tx).to.emit(host, "StepDispatched").withArgs(11n, startCount, 7n);
    });

    it("settles each decoded transaction returned by dispatch", async () => {
      const first = {
        from: encodeUserAccount("0x11"),
        to: encodeUserAccount("0x12"),
        asset: ethers.zeroPadValue("0x13", 32),
        amount: 14n,
      };
      const second = {
        from: encodeUserAccount("0x21"),
        to: encodeUserAccount("0x22"),
        asset: ethers.zeroPadValue("0x23", 32),
        amount: 24n,
      };
      const transactions = concat(
        encodeTxBlock(first.from, first.to, first.asset, first.amount),
        encodeTxBlock(second.from, second.to, second.asset, second.amount),
      );
      const input = encodeStepBlock(ethers.MaxUint256, 0n, transactions);

      const tx = await callAs(0, "testPipe", userAccount, "0x", input);

      await expect(tx)
        .to.emit(host, "DebitFromCalled")
        .withArgs(first.from, first.asset, first.amount, first.amount);
      await expect(tx)
        .to.emit(host, "CreditToCalled")
        .withArgs(first.to, first.asset, first.amount, first.amount);
      await expect(tx)
        .to.emit(host, "DebitFromCalled")
        .withArgs(second.from, second.asset, second.amount, second.amount);
      await expect(tx)
        .to.emit(host, "CreditToCalled")
        .withArgs(second.to, second.asset, second.amount, second.amount);
    });

    it("settles transactions from consecutive steps before dispatching the next step", async () => {
      const first = {
        from: encodeUserAccount("0x31"),
        to: encodeUserAccount("0x32"),
        asset: ethers.zeroPadValue("0x33", 32),
        amount: 34n,
      };
      const second = {
        from: encodeUserAccount("0x41"),
        to: encodeUserAccount("0x42"),
        asset: ethers.zeroPadValue("0x43", 32),
        amount: 44n,
      };
      const input = concat(
        encodeStepBlock(
          ethers.MaxUint256,
          0n,
          encodeTxBlock(first.from, first.to, first.asset, first.amount),
        ),
        encodeStepBlock(
          ethers.MaxUint256,
          0n,
          encodeTxBlock(second.from, second.to, second.asset, second.amount),
        ),
      );

      const tx = await callAs(0, "testPipe", userAccount, "0x", input);
      const receipt = await tx.wait();
      const events = receipt!.logs
        .map((log) => {
          try {
            return host.interface.parseLog(log);
          } catch {
            return null;
          }
        })
        .filter(
          (event) =>
            event?.name === "StepDispatched" ||
            event?.name === "DebitFromCalled" ||
            event?.name === "CreditToCalled",
        );

      expect(events.map((event) => event!.name)).to.deep.equal([
        "StepDispatched",
        "DebitFromCalled",
        "CreditToCalled",
        "StepDispatched",
        "DebitFromCalled",
        "CreditToCalled",
      ]);
      expect(Array.from(events[1]!.args)).to.deep.equal([
        first.from,
        first.asset,
        first.amount,
        first.amount,
      ]);
      expect(Array.from(events[2]!.args)).to.deep.equal([
        first.to,
        first.asset,
        first.amount,
        first.amount,
      ]);
      expect(Array.from(events[4]!.args)).to.deep.equal([
        second.from,
        second.asset,
        second.amount,
        second.amount,
      ]);
      expect(Array.from(events[5]!.args)).to.deep.equal([
        second.to,
        second.asset,
        second.amount,
        second.amount,
      ]);
    });

    it("rejects a malformed transaction stream returned by dispatch", async () => {
      const input = encodeStepBlock(ethers.MaxUint256, 0n, "0x1234");

      await expect(callAs(0, "testPipe", userAccount, "0x", input))
        .to.be.revertedWithCustomError(host, "InvalidBlock");
    });

    it("settles decoded unspent value after the pipeline closes", async () => {
      const input = encodeStepBlock(11n, 0n, "0x");
      const nativeAsset = await utils.testToNativeAsset();

      const tx = await callAs(0, "testPipe", userAccount, "0x", input, { value: 5n });

      await expect(tx)
        .to.emit(host, "CreditToCalled")
        .withArgs(userAccount, nativeAsset, 5n, 5n);
    });

    it("reverts UnexpectedState when final threaded state is non-empty", async () => {
      const state = encodeBalanceBlock(
        ethers.zeroPadValue("0x99", 32),
        123n
      );
      const input = encodeStepBlock(0n, 0n, "0x");
      await expect(host.testPipe.staticCall(userAccount, state, input))
        .to.be.revertedWithCustomError(host, "UnexpectedState");
    });

    it("reverts EmptyRun when no STEP blocks", async () => {
      await expect(callAs(0, "testPipe", userAccount, "0x", "0x"))
        .to.be.revertedWithCustomError(host, "EmptyRun");
    });


    it("tracks ETH value budget — reverts InsufficientValue when step requests too much", async () => {
      const largeValue = ethers.parseEther("1000");
      const input = encodeStepBlock(0n, largeValue, "0x");
      await expect(
        (host.connect(await getSigner(0)) as any).testPipe(userAccount, "0x", input, { value: 0n })
      ).to.be.revertedWithCustomError(host, "InsufficientValue");
    });
  });
});




