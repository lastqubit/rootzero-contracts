import { expect } from "chai";
import { ethers } from "ethers";
import { commandId, deploy, getSigner } from "./helpers/setup.js";
import "./helpers/matchers.js";
import {
  Keys,
  endpointDescriptor,
  exactSpec,
  encodeAmountBlock,
  encodeBalanceBlock, encodeDebtBlock, encodePositionBlock, encodeAllocationBlock, encodeCustodyBlock,
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
      encodeContextBlock(
        overrides.account ?? userAccount,
        overrides.state ?? "0x",
        overrides.input ?? "0x",
      ),
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
      ["settle", 3n],
      ["settlePayable", 3n],
      ["repay", 11n],
      ["repayPayable", 11n],
      ["repayPosition", 11n],
      ["repayPositionPayable", 11n],
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
      await host.authorize(encodeContextBlock(adminAccount, "0x", encodeNodeBlock(node)));

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

    it("rejects more than one context block", async () => {
      const input = encodeAmountBlock(ethers.zeroPadValue("0x01", 32), 1n);
      const context = ctx({ input })[0];

      await expect(callAs(0, "deposit", [concat(context, context)]))
        .to.be.revertedWithCustomError(host, "InvalidBlock");
    });

    it("rejects state when the command declares an empty state lane", async () => {
      const asset = ethers.zeroPadValue("0x01", 32);
      const liability = ethers.zeroPadValue("0x02", 32);
      const state = encodePositionBlock(asset, 10n, liability, 5n);
      const input = encodeAmountBlock(asset, 10n);

      await expect(callAs(0, "deposit", ctx({ state, input })))
        .to.be.revertedWithCustomError(host, "ZeroStride");
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

    it("does not truncate exact deposit values to the resource value lane", async () => {
      const asset = ethers.zeroPadValue("0x07", 32);
      const input = encodeAmountBlock(asset, 1n << 128n);

      await expect(callAs(0, "depositPayable", ctx({ input })))
        .to.be.revertedWithCustomError(host, "InsufficientValue");
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

  describe("settle", () => {
    const asset = ethers.zeroPadValue("0x20", 32);
    const liability = ethers.zeroPadValue("0x21", 32);

    it("discovers POSITION state with empty input and output lanes", async () => {
      const deployment = host.deploymentTransaction();
      expect(deployment).to.not.equal(null);

      await expect(deployment!).to.emit(host, "Endpoint")
        .withArgs(
          await host.host(),
          await cmd("settle"),
          endpointDescriptor({ state: Keys.Position }),
        );
    });

    it("passes each POSITION value and the acting account to the hook", async () => {
      const state = encodePositionBlock(asset, 100n, liability, 40n);
      const tx = await callAs(0, "settle", ctx({ state }));

      await expect(tx).to.emit(host, "SettleCalled")
        .withArgs(userAccount, asset, 100n, liability, 40n);

      const [output, transactions] = await host.settle.staticCall(...ctx({ state }));
      expect(output).to.equal("0x");
      expect(transactions).to.equal("0x");
    });

    it("settles a batch of POSITION blocks", async () => {
      const secondAsset = ethers.zeroPadValue("0x22", 32);
      const secondLiability = ethers.zeroPadValue("0x23", 32);
      const state = concat(
        encodePositionBlock(asset, 100n, liability, 40n),
        encodePositionBlock(secondAsset, 200n, secondLiability, 75n),
      );
      const tx = await callAs(0, "settle", ctx({ state }));

      await expect(tx).to.emit(host, "SettleCalled")
        .withArgs(userAccount, asset, 100n, liability, 40n);
      await expect(tx).to.emit(host, "SettleCalled")
        .withArgs(userAccount, secondAsset, 200n, secondLiability, 75n);
    });

    it("reverts EmptyRun for empty state", async () => {
      await expect(callAs(0, "settle", ctx()))
        .to.be.revertedWithCustomError(host, "EmptyRun");
    });

    it("reverts MalformedBlocks for truncated POSITION state", async () => {
      const full = encodePositionBlock(asset, 100n, liability, 40n);
      const truncated = ethers.hexlify(ethers.getBytes(full).slice(0, -1));
      await expect(callAs(0, "settle", ctx({ state: truncated })))
        .to.be.revertedWithCustomError(host, "MalformedBlocks");
    });

    it("reverts AccessDenied for an untrusted caller", async () => {
      const state = encodePositionBlock(asset, 100n, liability, 40n);
      await expect(callAs(1, "settle", ctx({ state })))
        .to.be.revertedWithCustomError(host, "AccessDenied");
    });

    it("rejects input when the command declares an empty input lane", async () => {
      const state = encodePositionBlock(asset, 100n, liability, 40n);
      const input = encodeAmountBlock(asset, 1n);

      await expect(callAs(0, "settle", ctx({ state, input })))
        .to.be.revertedWithCustomError(host, "ZeroStride");
    });
  });

  describe("settlePayable", () => {
    const asset = ethers.zeroPadValue("0x24", 32);
    const liability = ethers.zeroPadValue("0x25", 32);

    it("discovers a funded command with POSITION state", async () => {
      const deployment = host.deploymentTransaction();
      expect(deployment).to.not.equal(null);

      await expect(deployment!).to.emit(host, "Endpoint")
        .withArgs(
          await host.host(),
          await cmd("settlePayable"),
          endpointDescriptor({ state: Keys.Position, funded: true }),
        );
    });

    it("passes one shared value budget through a batch", async () => {
      const secondAsset = ethers.zeroPadValue("0x26", 32);
      const secondLiability = ethers.zeroPadValue("0x27", 32);
      const state = concat(
        encodePositionBlock(asset, 100n, liability, 40n),
        encodePositionBlock(secondAsset, 20n, secondLiability, 10n),
      );
      const tx = await callAs(0, "settlePayable", ctx({ state }), { value: 200n });

      await expect(tx).to.emit(host, "SettlePayableCalled")
        .withArgs(userAccount, asset, 100n, liability, 40n, 60n);
      await expect(tx).to.emit(host, "SettlePayableCalled")
        .withArgs(userAccount, secondAsset, 20n, secondLiability, 10n, 30n);
    });

    it("returns unspent command value as a refund transaction", async () => {
      const state = encodePositionBlock(asset, 3n, liability, 2n);
      const [output, transactions] = await host.settlePayable.staticCall(
        ...ctx({ state }),
        { value: 8n },
      );

      expect(output).to.equal("0x");
      expect(ethers.getBytes(transactions).length).to.equal(136);
    });

    it("reverts InsufficientValue when the hook overspends the budget", async () => {
      const state = encodePositionBlock(asset, 3n, liability, 2n);

      await expect(callAs(0, "settlePayable", ctx({ state }), { value: 4n }))
        .to.be.revertedWithCustomError(host, "InsufficientValue");
    });

    it("reverts EmptyRun for empty state", async () => {
      await expect(callAs(0, "settlePayable", ctx()))
        .to.be.revertedWithCustomError(host, "EmptyRun");
    });

    it("reverts AccessDenied for an untrusted caller", async () => {
      const state = encodePositionBlock(asset, 3n, liability, 2n);

      await expect(callAs(1, "settlePayable", ctx({ state }), { value: 5n }))
        .to.be.revertedWithCustomError(host, "AccessDenied");
    });

    it("rejects input because the input lane is empty", async () => {
      const state = encodePositionBlock(asset, 3n, liability, 2n);
      const input = encodeAmountBlock(asset, 1n);

      await expect(callAs(0, "settlePayable", ctx({ state, input }), { value: 5n }))
        .to.be.revertedWithCustomError(host, "ZeroStride");
    });
  });

  describe("repay", () => {
    const liability = ethers.zeroPadValue("0x2e", 32);

    it("discovers a DEBT-to-empty command", async () => {
      const deployment = host.deploymentTransaction();
      expect(deployment).to.not.equal(null);

      await expect(deployment!).to.emit(host, "Endpoint")
        .withArgs(
          await host.host(),
          await cmd("repay"),
          endpointDescriptor({ state: Keys.Debt }),
        );
    });

    it("repays standalone DEBT state and returns empty state", async () => {
      const state = encodeDebtBlock(liability, 40n);
      const [output, transactions] = await host.repay.staticCall(...ctx({ state }));

      expect(output).to.equal("0x");
      expect(transactions).to.equal("0x");

      const tx = await callAs(0, "repay", ctx({ state }));
      await expect(tx).to.emit(host, "DebitFromCalled")
        .withArgs(userAccount, liability, 40n, 40n);
    });

    it("repays a batch of standalone debts", async () => {
      const secondLiability = ethers.zeroPadValue("0x2f", 32);
      const state = concat(
        encodeDebtBlock(liability, 40n),
        encodeDebtBlock(secondLiability, 10n),
      );

      const [output] = await host.repay.staticCall(...ctx({ state }));
      expect(output).to.equal("0x");

      const tx = await callAs(0, "repay", ctx({ state }));
      await expect(tx).to.emit(host, "DebitFromCalled")
        .withArgs(userAccount, secondLiability, 10n, 10n);
    });

    it("rejects empty state, POSITION state, and non-empty input", async () => {
      await expect(callAs(0, "repay", ctx()))
        .to.be.revertedWithCustomError(host, "EmptyRun");

      const position = encodePositionBlock(liability, 1n, liability, 40n);
      await expect(callAs(0, "repay", ctx({ state: position })))
        .to.be.revertedWithCustomError(host, "InvalidBlock");

      const state = encodeDebtBlock(liability, 40n);
      const input = encodeAmountBlock(liability, 1n);
      await expect(callAs(0, "repay", ctx({ state, input })))
        .to.be.revertedWithCustomError(host, "ZeroStride");
    });
  });

  describe("repayPayable", () => {
    const liability = ethers.zeroPadValue("0x2f", 32);

    it("discovers a funded DEBT-to-empty command", async () => {
      const deployment = host.deploymentTransaction();
      expect(deployment).to.not.equal(null);

      await expect(deployment!).to.emit(host, "Endpoint")
        .withArgs(
          await host.host(),
          await cmd("repayPayable"),
          endpointDescriptor({ state: Keys.Debt, funded: true }),
        );
    });

    it("repays standalone DEBT state and returns only unused value", async () => {
      const state = encodeDebtBlock(liability, 40n);
      const [output, transactions] = await host.repayPayable.staticCall(
        ...ctx({ state }),
        { value: 50n },
      );

      expect(output).to.equal("0x");
      expect(ethers.getBytes(transactions).length).to.equal(136);

      const tx = await callAs(0, "repayPayable", ctx({ state }), { value: 50n });
      await expect(tx).to.emit(host, "RepayPayableCalled")
        .withArgs(userAccount, liability, 40n, 10n);
    });

    it("rejects insufficient value and empty state", async () => {
      const state = encodeDebtBlock(liability, 40n);
      await expect(callAs(0, "repayPayable", ctx({ state }), { value: 39n }))
        .to.be.revertedWithCustomError(host, "InsufficientValue");
      await expect(callAs(0, "repayPayable", ctx()))
        .to.be.revertedWithCustomError(host, "EmptyRun");
    });
  });

  describe("repayPosition", () => {
    const asset = ethers.zeroPadValue("0x30", 32);
    const liability = ethers.zeroPadValue("0x31", 32);

    it("discovers a POSITION-to-BALANCE command", async () => {
      const deployment = host.deploymentTransaction();
      expect(deployment).to.not.equal(null);

      await expect(deployment!).to.emit(host, "Endpoint")
        .withArgs(
          await host.host(),
          await cmd("repayPosition"),
          endpointDescriptor({
            state: Keys.Position,
            output: exactSpec(Keys.Balance, 64),
          }),
        );
    });

    it("repays the liability and returns the asset as BALANCE state", async () => {
      const state = encodePositionBlock(asset, 100n, liability, 40n);
      const [output, transactions] = await host.repayPosition.staticCall(...ctx({ state }));

      expect(output).to.equal(encodeBalanceBlock(asset, 100n));
      expect(transactions).to.equal("0x");

      const tx = await callAs(0, "repayPosition", ctx({ state }));
      await expect(tx).to.emit(host, "DebitFromCalled")
        .withArgs(userAccount, liability, 40n, 40n);
    });

    it("repays a batch and returns every released asset", async () => {
      const secondAsset = ethers.zeroPadValue("0x32", 32);
      const secondLiability = ethers.zeroPadValue("0x33", 32);
      const state = concat(
        encodePositionBlock(asset, 100n, liability, 40n),
        encodePositionBlock(secondAsset, 20n, secondLiability, 10n),
      );
      const [output] = await host.repayPosition.staticCall(...ctx({ state }));

      expect(output).to.equal(concat(
        encodeBalanceBlock(asset, 100n),
        encodeBalanceBlock(secondAsset, 20n),
      ));
    });

    it("rejects empty state and non-empty input", async () => {
      await expect(callAs(0, "repayPosition", ctx()))
        .to.be.revertedWithCustomError(host, "EmptyRun");

      const state = encodePositionBlock(asset, 100n, liability, 40n);
      const input = encodeAmountBlock(asset, 1n);
      await expect(callAs(0, "repayPosition", ctx({ state, input })))
        .to.be.revertedWithCustomError(host, "ZeroStride");
    });
  });

  describe("repayPositionPayable", () => {
    const asset = ethers.zeroPadValue("0x34", 32);
    const liability = ethers.zeroPadValue("0x35", 32);

    it("discovers a funded POSITION-to-BALANCE command", async () => {
      const deployment = host.deploymentTransaction();
      expect(deployment).to.not.equal(null);

      await expect(deployment!).to.emit(host, "Endpoint")
        .withArgs(
          await host.host(),
          await cmd("repayPositionPayable"),
          endpointDescriptor({
            state: Keys.Position,
            output: exactSpec(Keys.Balance, 64),
            funded: true,
          }),
        );
    });

    it("repays only the liability and returns the asset as BALANCE state", async () => {
      const state = encodePositionBlock(asset, 100n, liability, 40n);
      const [output] = await host.repayPositionPayable.staticCall(
        ...ctx({ state }),
        { value: 40n },
      );

      expect(output).to.equal(encodeBalanceBlock(asset, 100n));

      const tx = await callAs(0, "repayPositionPayable", ctx({ state }), { value: 40n });
      await expect(tx).to.emit(host, "RepayPayableCalled")
        .withArgs(userAccount, liability, 40n, 0n);
    });

    it("shares the value budget across liabilities and refunds the remainder", async () => {
      const secondAsset = ethers.zeroPadValue("0x36", 32);
      const secondLiability = ethers.zeroPadValue("0x37", 32);
      const state = concat(
        encodePositionBlock(asset, 100n, liability, 40n),
        encodePositionBlock(secondAsset, 20n, secondLiability, 10n),
      );
      const [output, transactions] = await host.repayPositionPayable.staticCall(
        ...ctx({ state }),
        { value: 60n },
      );

      expect(output).to.equal(concat(
        encodeBalanceBlock(asset, 100n),
        encodeBalanceBlock(secondAsset, 20n),
      ));
      expect(ethers.getBytes(transactions).length).to.equal(136);
    });

    it("reverts InsufficientValue when liabilities exceed the budget", async () => {
      const state = encodePositionBlock(asset, 100n, liability, 40n);

      await expect(callAs(0, "repayPositionPayable", ctx({ state }), { value: 39n }))
        .to.be.revertedWithCustomError(host, "InsufficientValue");
    });

    it("rejects empty state and non-empty input", async () => {
      await expect(callAs(0, "repayPositionPayable", ctx()))
        .to.be.revertedWithCustomError(host, "EmptyRun");

      const state = encodePositionBlock(asset, 100n, liability, 40n);
      const input = encodeAmountBlock(asset, 1n);
      await expect(callAs(0, "repayPositionPayable", ctx({ state, input }), { value: 40n }))
        .to.be.revertedWithCustomError(host, "ZeroStride");
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

    it("reverts InvalidBlock when input is not an ALLOCATION block", async () => {
      const hostId = 654321n;
      const input = encodeNodeBlock(hostId);
      await expect(callAs(0, "provision", ctx({ input: input })))
        .to.be.revertedWithCustomError(host, "InvalidBlock");
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

    it("does not truncate exact provision values to the resource value lane", async () => {
      const asset = ethers.zeroPadValue("0x78", 32);
      const input = encodeAllocationBlock(888n, asset, 1n << 128n);

      await expect(callAs(0, "provisionPayable", ctx({ input })))
        .to.be.revertedWithCustomError(host, "InsufficientValue");
    });

  });


  // ── Pipe ──────────────────────────────────────────────────────────────────

  describe("relayPayable", () => {
    const PORTAL_PREFIX = 0x01200201n;

    function portalNode(id: bigint) {
      return (PORTAL_PREFIX << 224n) | id;
    }

    it("discovers relayPayable with empty state", async () => {
      const deployment = host.deploymentTransaction();
      expect(deployment).to.not.equal(null);

      await expect(deployment!).to.emit(host, "Endpoint")
        .withArgs(
          await host.host(),
          await cmd("relayPayable"),
          endpointDescriptor({ input: Keys.Relay, funded: true }),
        );
      await expect(deployment!).to.emit(host, "Annotation")
        .withArgs(await cmd("relayPayable"), encodeLabelBlock(ethers.ZeroHash, "relayPayable"));
    });

    it("passes the destination context fields to the relay hook", async () => {
      const portal = portalNode(31337n);
      const resources = 9n;
      const steps = encodeStepBlock(0n, 0n, "0x1234");
      const input = encodeRelayBlock(portal, resources, steps);
      const [result, transactions] = await host.relayPayable.staticCall(...ctx({ input }));
      expect(result).to.equal("0x");
      expect(transactions).to.equal("0x");

      const tx = await callAs(0, "relayPayable", ctx({ input }));
      await expect(tx).to.emit(host, "RelayCalled")
        .withArgs(portal, resources, userAccount, "0x", steps);
    });

    it("reverts when state is supplied", async () => {
      const state = encodeBalanceBlock(ethers.zeroPadValue("0x80", 32), 1n);
      const input = encodeRelayBlock(portalNode(31337n), 0n, encodeStepBlock(0n, 0n, "0x"));

      await expect(callAs(0, "relayPayable", ctx({ state, input })))
        .to.be.revertedWithCustomError(host, "ZeroStride");
    });

    it("reverts EmptyRun when input has no RELAY block", async () => {
      await expect(callAs(0, "relayPayable", ctx()))
        .to.be.revertedWithCustomError(host, "EmptyRun");
    });
  });

  describe("relayBalancePayable", () => {
    const PORTAL_PREFIX = 0x01200201n;
    const relayAsset = ethers.zeroPadValue("0x80", 32);

    function portalNode(id: bigint) {
      return (PORTAL_PREFIX << 224n) | id;
    }

    it("discovers relayBalancePayable with BALANCE state", async () => {
      const deployment = host.deploymentTransaction();
      expect(deployment).to.not.equal(null);

      await expect(deployment!).to.emit(host, "Endpoint")
        .withArgs(
          await host.host(),
          await cmd("relayBalancePayable"),
          endpointDescriptor({ state: Keys.Balance, input: Keys.Relay, funded: true }),
        );
      await expect(deployment!).to.emit(host, "Annotation")
        .withArgs(await cmd("relayBalancePayable"), encodeLabelBlock(ethers.ZeroHash, "relayBalancePayable"));
    });

    it("passes account, state, and RELAY input separately to the hook", async () => {
      const state = encodeBalanceBlock(relayAsset, 12n);
      const portal = portalNode(31337n);
      const resources = 9n;
      const steps = encodeStepBlock(0n, 0n, "0x1234");
      const input = encodeRelayBlock(portal, resources, steps);
      const [result, transactions] = await host.relayBalancePayable.staticCall(...ctx({ state, input: input }));
      expect(result).to.equal("0x");
      expect(transactions).to.equal("0x");

      const tx = await callAs(0, "relayBalancePayable", ctx({ state, input: input }));
      await expect(tx).to.emit(host, "RelayCalled")
        .withArgs(portal, resources, userAccount, state, steps);
    });

    it("reverts EmptyRun when input has no RELAY block", async () => {
      const state = encodeBalanceBlock(relayAsset, 1n);
      await expect(callAs(0, "relayBalancePayable", ctx({ state })))
        .to.be.revertedWithCustomError(host, "EmptyRun");
    });

    it("reverts EmptyRun when BALANCE state is empty", async () => {
      const input = encodeRelayBlock(portalNode(31337n), 0n, encodeStepBlock(0n, 0n, "0x"));
      await expect(callAs(0, "relayBalancePayable", ctx({ input })))
        .to.be.revertedWithCustomError(host, "EmptyRun");
    });

    it("reverts AccessDenied for untrusted caller", async () => {
      const portal = portalNode(31337n);
      const input = encodeRelayBlock(portal, 0n, encodeStepBlock(0n, 0n, "0x"));

      await expect(callAs(1, "relayBalancePayable", ctx({ input: input })))
        .to.be.revertedWithCustomError(host, "AccessDenied");
    });

    it("reverts InvalidBlock when input is not a RELAY block", async () => {
      const asset = ethers.zeroPadValue("0x81", 32);
      const state = encodeBalanceBlock(relayAsset, 1n);
      const input = encodeAmountBlock(asset, 1n);

      await expect(callAs(0, "relayBalancePayable", ctx({ state, input })))
        .to.be.revertedWithCustomError(host, "InvalidBlock");
    });

    it("reverts InvalidBlock when state is not BALANCE", async () => {
      const state = encodePositionBlock(relayAsset, 1n, relayAsset, 1n);
      const input = encodeRelayBlock(portalNode(31337n), 0n, encodeStepBlock(0n, 0n, "0x"));

      await expect(callAs(0, "relayBalancePayable", ctx({ state, input })))
        .to.be.revertedWithCustomError(host, "InvalidBlock");
    });

    it("reverts InvalidBlock when BALANCE state has a trailing different block type", async () => {
      const state = concat(
        encodeBalanceBlock(relayAsset, 1n),
        encodePositionBlock(relayAsset, 1n, relayAsset, 1n),
      );
      const input = encodeRelayBlock(portalNode(31337n), 0n, encodeStepBlock(0n, 0n, "0x"));

      await expect(callAs(0, "relayBalancePayable", ctx({ state, input })))
        .to.be.revertedWithCustomError(host, "InvalidBlock");
    });

    it("reverts BadRatio when input has more than one RELAY block", async () => {
      const portal = portalNode(31337n);
      const input = concat(
        encodeRelayBlock(portal, 0n, encodeStepBlock(0n, 0n, "0x")),
        encodeRelayBlock(portal, 0n, encodeStepBlock(0n, 0n, "0x"))
      );
      const state = encodeBalanceBlock(relayAsset, 1n);

      await expect(callAs(0, "relayBalancePayable", ctx({ state, input })))
        .to.be.revertedWithCustomError(host, "BadRatio");
    });

    it("reverts BadRatio when multiple BALANCE blocks are paired with one RELAY block", async () => {
      const secondAsset = ethers.zeroPadValue("0x82", 32);
      const state = concat(
        encodeBalanceBlock(relayAsset, 1n),
        encodeBalanceBlock(secondAsset, 2n),
      );
      const portal = portalNode(31337n);
      const steps = encodeStepBlock(0n, 0n, "0x");
      const input = encodeRelayBlock(portal, 0n, steps);

      await expect(callAs(0, "relayBalancePayable", ctx({ state, input })))
        .to.be.revertedWithCustomError(host, "BadRatio");
    });

    it("passes relay resources through even when it exceeds msg.value", async () => {
      const portal = portalNode(31337n);
      const steps = encodeStepBlock(0n, 0n, "0x");
      const input = encodeRelayBlock(portal, 2n, steps);
      const state = encodeBalanceBlock(relayAsset, 1n);
      const tx = await callAs(0, "relayBalancePayable", ctx({ state, input }));
      await expect(tx).to.emit(host, "RelayCalled")
        .withArgs(portal, 2n, userAccount, state, steps);
    });

    it("returns unspent command value after relay dispatch as a transaction", async () => {
      const portal = portalNode(31337n);
      const input = encodeRelayBlock(portal, 0n, encodeStepBlock(0n, 0n, "0x"));
      const state = encodeBalanceBlock(relayAsset, 1n);

      const [output, transactions] = await host.relayBalancePayable.staticCall(...ctx({ state, input }), { value: 1n });
      expect(output).to.equal("0x");
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

    it("passes full recovery resources and the shared value budget to the hook", async () => {
      const key = ethers.zeroPadValue("0xbeef", 32);
      const handler = 99n;
      const resources = (7n << 128n) | 13n;
      const step = encodeStepBlock(0n, 0n, "0x1234");
      const witness = encodeContextBlock(userAccount, "0x", step);
      const input = encodeRecoverBlock(handler, resources, key, witness);

      const [result, transactions] = await host.recoverPayable.staticCall(...ctx({ input: input }), { value: 13n });
      expect(result).to.equal("0x");
      expect(transactions).to.equal("0x");

      const tx = await callAs(0, "recoverPayable", ctx({ input: input }), { value: 13n });
      await expect(tx).to.emit(host, "RecoverCalled")
        .withArgs(handler, resources, key, witness, 13n);
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
    it("executes local debit and credit commands against threaded state", async () => {
      const asset = ethers.zeroPadValue("0xa1", 32);
      const amount = 42n;
      const input = concat(
        encodeStepBlock(await cmd("debitAccount"), 0n, encodeAmountBlock(asset, amount)),
        encodeStepBlock(await cmd("creditAccount"), 0n, "0x"),
      );

      const tx = await callAs(0, "testPipe", userAccount, "0x", input);

      await expect(tx)
        .to.emit(host, "DebitFromCalled")
        .withArgs(userAccount, asset, amount, amount);
      await expect(tx)
        .to.emit(host, "CreditToCalled")
        .withArgs(userAccount, asset, amount, amount);
    });

    it("executes local settlement against memory-backed position state", async () => {
      const asset = ethers.zeroPadValue("0xb1", 32);
      const liability = ethers.zeroPadValue("0xb2", 32);
      const amount = 75n;
      const debt = 25n;
      const state = encodePositionBlock(asset, amount, liability, debt);
      const input = encodeStepBlock(await cmd("settle"), 0n, "0x");

      const tx = await callAs(0, "testPipe", userAccount, state, input);

      await expect(tx)
        .to.emit(host, "SettleCalled")
        .withArgs(userAccount, asset, amount, liability, debt);
    });

    it("executes local repayment against memory-backed debt state", async () => {
      const liability = ethers.zeroPadValue("0xb3", 32);
      const debt = 25n;
      const state = encodeDebtBlock(liability, debt);
      const input = encodeStepBlock(await cmd("repay"), 0n, "0x");

      const tx = await callAs(0, "testPipe", userAccount, state, input);

      await expect(tx)
        .to.emit(host, "DebitFromCalled")
        .withArgs(userAccount, liability, debt, debt);
    });

    it("rejects value assigned to every local non-funded command", async () => {
      const asset = ethers.zeroPadValue("0xc1", 32);
      const liability = ethers.zeroPadValue("0xc2", 32);
      const cases = [
        {
          command: "debitAccount",
          state: "0x",
          input: encodeAmountBlock(asset, 1n),
        },
        {
          command: "creditAccount",
          state: encodeBalanceBlock(asset, 1n),
          input: "0x",
        },
        {
          command: "settle",
          state: encodePositionBlock(asset, 1n, liability, 1n),
          input: "0x",
        },
        {
          command: "repay",
          state: encodeDebtBlock(liability, 1n),
          input: "0x",
        },
      ];

      for (const testCase of cases) {
        const steps = encodeStepBlock(
          await cmd(testCase.command),
          1n,
          testCase.input,
        );
        await expect(
          callAs(0, "testPipe", userAccount, testCase.state, steps, { value: 1n }),
        ).to.be.revertedWithCustomError(host, "ValueNotAllowed");
      }
    });

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

    it("posts each decoded transaction returned by dispatch", async () => {
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

    it("posts transactions from consecutive steps before dispatching the next step", async () => {
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

    it("posts decoded unspent value after the pipeline closes", async () => {
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

    it("rejects a non-STEP block trailing the STEP stream", async () => {
      const input = concat(
        encodeStepBlock(0n, 0n, "0x"),
        encodeAmountBlock(ethers.ZeroHash, 1n),
      );

      await expect(callAs(0, "testPipe", userAccount, "0x", input))
        .to.be.revertedWithCustomError(host, "InvalidBlock");
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




