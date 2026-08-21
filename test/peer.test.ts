import { expect } from "chai";
import { deploy, getProvider, getSigner, portId } from "./helpers/setup.js";
import {
  Keys,
  endpointDescriptor,
  concat,
  encodeContextBlock,
  encodeAmountBlock,
  encodeAccountAmountBlock,
  encodeBalanceBlock,
  encodeNodeBlock,
  encodeStepBlock,
  encodeTxBlock,
  encodeDispatchBlock,
  encodeActionBlock,
  encodeLabelBlock,
  encodeUserAccount,
} from "./helpers/blocks.js";
import { ethers } from "ethers";
import "./helpers/matchers.js";

describe("Port Entrypoints", () => {
  let host: Awaited<ReturnType<typeof deploy>>;

  before(async () => {
    const signer = await getSigner(0);
    const commander = await signer.getAddress();
    host = await deploy("TestPortHost", commander);
    const trustedPeer = await callerHost(1);
    const adminAccount: string = await host.getAdminAccount();
    await host.authorize(encodeContextBlock(adminAccount, "0x", encodeNodeBlock(trustedPeer)));
  });

  async function port(method: string) {
    return portId(host.interface.getFunction(method)!.selector, host);
  }

  it("emits Endpoint discovery events with port id as the second argument", async () => {
    const tx = host.deploymentTransaction();
    expect(tx).to.not.equal(null);

    await expect(tx!)
      .to.emit(host, "Endpoint")
      .withArgs(
        await host.host(),
        await port("portRequestAllowance(bytes)"),
        endpointDescriptor({ input: Keys.Amount }),
      );
    await expect(tx!)
      .to.emit(host, "Annotation")
      .withArgs(await port("portRequestAllowance(bytes)"), encodeLabelBlock(ethers.ZeroHash, "portRequestAllowance"));

    await expect(tx!)
      .to.emit(host, "Endpoint")
      .withArgs(
        await host.host(),
        await port("portRedeemBalance(bytes)"),
        endpointDescriptor({ input: Keys.Balance }),
      );
    await expect(tx!)
      .to.emit(host, "Annotation")
      .withArgs(await port("portRedeemBalance(bytes)"), encodeLabelBlock(ethers.ZeroHash, "portRedeemBalance"));

    await expect(tx!)
      .to.emit(host, "Endpoint")
      .withArgs(
        await host.host(),
        await port("portRequestAsset(bytes)"),
        endpointDescriptor({ input: Keys.Amount }),
      );
    await expect(tx!)
      .to.emit(host, "Annotation")
      .withArgs(await port("portRequestAsset(bytes)"), encodeLabelBlock(ethers.ZeroHash, "portRequestAsset"));

    await expect(tx!)
      .to.emit(host, "Endpoint")
      .withArgs(
        await host.host(),
        await port("portCreditAccount(bytes)"),
        endpointDescriptor({ input: Keys.AccountAmount }),
      );
    await expect(tx!)
      .to.emit(host, "Annotation")
      .withArgs(await port("portCreditAccount(bytes)"), encodeLabelBlock(ethers.ZeroHash, "portCreditAccount"));

    await expect(tx!)
      .to.emit(host, "Endpoint")
      .withArgs(
        await host.host(),
        await port("portDebitAccount(bytes)"),
        endpointDescriptor({ input: Keys.AccountAmount }),
      );
    await expect(tx!)
      .to.emit(host, "Annotation")
      .withArgs(await port("portDebitAccount(bytes)"), encodeLabelBlock(ethers.ZeroHash, "portDebitAccount"));

    await expect(tx!)
      .to.emit(host, "Endpoint")
      .withArgs(
        await host.host(),
        await port("portPipePayable(bytes)"),
        endpointDescriptor({ input: Keys.Context, funded: true }),
      );
    await expect(tx!)
      .to.emit(host, "Annotation")
      .withArgs(await port("portPipePayable(bytes)"), encodeLabelBlock(ethers.ZeroHash, "portPipePayable"));

    await expect(tx!)
      .to.emit(host, "Endpoint")
      .withArgs(
        await host.host(),
        await port("portDispatchPayable(bytes)"),
        endpointDescriptor({ input: Keys.Dispatch, funded: true }),
      );
    await expect(tx!)
      .to.emit(host, "Annotation")
      .withArgs(await port("portDispatchPayable(bytes)"), encodeLabelBlock(ethers.ZeroHash, "portDispatchPayable"));

    await expect(tx!)
      .to.emit(host, "Annotation")
      .withArgs(await port("portPost(bytes)"), encodeActionBlock(14n));

  });

  async function callAs(
    signerIndex: number,
    method:
      | "portRequestAllowance(bytes)"
      | "portRedeemBalance(bytes)"
      | "portCreditAccount(bytes)"
      | "portDebitAccount(bytes)"
      | "portPost(bytes)"
      | "portRequestAsset(bytes)"
      | "portPipePayable(bytes)"
      | "portDispatchPayable(bytes)",
    input = "0x",
    overrides: Record<string, bigint> = {}
  ) {
    const signer = await getSigner(signerIndex);
    return (host.connect(signer) as any)[method](input, overrides);
  }

  async function callerHost(signerIndex: number) {
    const signer = await getSigner(signerIndex);
    const addr = await signer.getAddress();
    const provider = await getProvider();
    const network = await provider.getNetwork();
    const HOST_PREFIX = 0x01200202n;
    return (HOST_PREFIX << 224n) | (network.chainId << 192n) | BigInt(addr);
  }

  async function localPortal() {
    return port("portDispatchPayable(bytes)");
  }

  describe("portRequestAllowance", () => {
    const method = "portRequestAllowance(bytes)";
    const asset = ethers.zeroPadValue("0xa0", 32);

    it("passes one allowance request to the hook scoped to the caller host", async () => {
      const peer = await callerHost(1);
      const tx = await callAs(1, method, encodeAmountBlock(asset, 123n));
      await expect(tx).to.emit(host, "PortRequestAllowanceCalled").withArgs(peer, asset, 123n);
    });

    it("passes each allowance request in a batch to the hook", async () => {
      const peer = await callerHost(1);
      const asset2 = ethers.zeroPadValue("0xc0", 32);
      const tx = await callAs(
        1,
        method,
        concat(
          encodeAmountBlock(asset, 123n),
          encodeAmountBlock(asset2, 456n),
        )
      );
      await expect(tx).to.emit(host, "PortRequestAllowanceCalled").withArgs(peer, asset, 123n);
      await expect(tx).to.emit(host, "PortRequestAllowanceCalled").withArgs(peer, asset2, 456n);
    });

    it("returns empty bytes after processing amount blocks", async () => {
      const signer = await getSigner(1);
      const result: string = await (host.connect(signer) as any)[method].staticCall(encodeAmountBlock(asset, 123n));
      expect(result).to.equal("0x");
    });

    it("reverts CommanderNotAllowed for the commander", async () => {
      await expect(callAs(0, method, encodeAmountBlock(asset, 123n)))
        .to.be.revertedWithCustomError(host, "CommanderNotAllowed");
    });

    it("reverts AccessDenied for an untrusted caller", async () => {
      await expect(callAs(2, method, encodeAmountBlock(asset, 123n)))
        .to.be.revertedWithCustomError(host, "AccessDenied");
    });

    it("reverts EmptyRun when input is empty", async () => {
      await expect(callAs(1, method))
        .to.be.revertedWithCustomError(host, "EmptyRun");
    });
  });

  describe("portRedeemBalance", () => {
    const method = "portRedeemBalance(bytes)";
    const asset = ethers.zeroPadValue("0xaa", 32);

    it("emits PortRedeemBalanceCalled for a single BALANCE block", async () => {
      const peer = await callerHost(1);
      const tx = await callAs(1, method, encodeBalanceBlock(asset, 123n));
      await expect(tx).to.emit(host, "PortRedeemBalanceCalled").withArgs(peer, asset, 123n);
    });

    it("emits PortRedeemBalanceCalled for each BALANCE block when multiple are present", async () => {
      const peer = await callerHost(1);
      const asset2 = ethers.zeroPadValue("0xcc", 32);
      const tx = await callAs(
        1,
        method,
        concat(
          encodeBalanceBlock(asset, 123n),
          encodeBalanceBlock(asset2, 456n),
        )
      );
      await expect(tx).to.emit(host, "PortRedeemBalanceCalled").withArgs(peer, asset, 123n);
      await expect(tx).to.emit(host, "PortRedeemBalanceCalled").withArgs(peer, asset2, 456n);
    });

    it("returns empty bytes after processing balance blocks", async () => {
      const signer = await getSigner(1);
      const result: string = await (host.connect(signer) as any)[method].staticCall(encodeBalanceBlock(asset, 123n));
      expect(result).to.equal("0x");
    });

    it("reverts CommanderNotAllowed for the commander", async () => {
      await expect(callAs(0, method, encodeBalanceBlock(asset, 123n)))
        .to.be.revertedWithCustomError(host, "CommanderNotAllowed");
    });

    it("reverts AccessDenied for an untrusted caller", async () => {
      await expect(callAs(2, method, encodeBalanceBlock(asset, 123n)))
        .to.be.revertedWithCustomError(host, "AccessDenied");
    });

    it("reverts EmptyRun when input is empty", async () => {
      await expect(callAs(1, method))
        .to.be.revertedWithCustomError(host, "EmptyRun");
    });
  });

  describe("portRequestAsset", () => {
    const method = "portRequestAsset(bytes)";
    const suppliedAsset = ethers.zeroPadValue("0xd1", 32);

    it("passes the peer, supplied asset, and amount to the hook", async () => {
      const peer = await callerHost(1);
      const tx = await callAs(1, method, encodeAmountBlock(suppliedAsset, 123n));

      await expect(tx)
        .to.emit(host, "PortRequestAssetCalled")
        .withArgs(peer, suppliedAsset, 123n);
    });

    it("passes each request in a batch to the hook", async () => {
      const peer = await callerHost(1);
      const secondAsset = ethers.zeroPadValue("0xd2", 32);
      const tx = await callAs(1, method, concat(
        encodeAmountBlock(suppliedAsset, 123n),
        encodeAmountBlock(secondAsset, 456n),
      ));

      await expect(tx).to.emit(host, "PortRequestAssetCalled").withArgs(peer, suppliedAsset, 123n);
      await expect(tx).to.emit(host, "PortRequestAssetCalled").withArgs(peer, secondAsset, 456n);
    });

    it("returns empty bytes after processing requests", async () => {
      const signer = await getSigner(1);
      const result: string = await (host.connect(signer) as any)[method].staticCall(
        encodeAmountBlock(suppliedAsset, 123n),
      );
      expect(result).to.equal("0x");
    });

    it("reverts CommanderNotAllowed for the commander", async () => {
      await expect(callAs(0, method, encodeAmountBlock(suppliedAsset, 123n)))
        .to.be.revertedWithCustomError(host, "CommanderNotAllowed");
    });

    it("reverts AccessDenied for an untrusted caller", async () => {
      await expect(callAs(2, method, encodeAmountBlock(suppliedAsset, 123n)))
        .to.be.revertedWithCustomError(host, "AccessDenied");
    });

    it("reverts EmptyRun when input is empty", async () => {
      await expect(callAs(1, method))
        .to.be.revertedWithCustomError(host, "EmptyRun");
    });
  });

  describe("portCreditAccount", () => {
    const method = "portCreditAccount(bytes)";
    const account = encodeUserAccount("0x11");
    const asset = ethers.zeroPadValue("0xaa", 32);

    it("credits the account from a single ACCOUNT_AMOUNT block", async () => {
      const tx = await callAs(1, method, encodeAccountAmountBlock(account, asset, 123n));
      await expect(tx).to.emit(host, "PortCreditAccountCalled").withArgs(account, asset, 123n);
    });

    it("credits each account amount block when multiple are present", async () => {
      const account2 = encodeUserAccount("0x22");
      const asset2 = ethers.zeroPadValue("0xcc", 32);
      const tx = await callAs(
        1,
        method,
        concat(
          encodeAccountAmountBlock(account, asset, 123n),
          encodeAccountAmountBlock(account2, asset2, 456n),
        )
      );

      await expect(tx).to.emit(host, "PortCreditAccountCalled").withArgs(account, asset, 123n);
      await expect(tx).to.emit(host, "PortCreditAccountCalled").withArgs(account2, asset2, 456n);
    });

    it("returns empty bytes after processing account amount blocks", async () => {
      const signer = await getSigner(1);
      const result: string = await (host.connect(signer) as any)[method].staticCall(
        encodeAccountAmountBlock(account, asset, 123n)
      );
      expect(result).to.equal("0x");
    });

    it("reverts CommanderNotAllowed for the commander", async () => {
      await expect(callAs(0, method, encodeAccountAmountBlock(account, asset, 123n)))
        .to.be.revertedWithCustomError(host, "CommanderNotAllowed");
    });

    it("reverts AccessDenied for an untrusted caller", async () => {
      await expect(callAs(2, method, encodeAccountAmountBlock(account, asset, 123n)))
        .to.be.revertedWithCustomError(host, "AccessDenied");
    });

    it("reverts EmptyRun when input is empty", async () => {
      await expect(callAs(1, method))
        .to.be.revertedWithCustomError(host, "EmptyRun");
    });

    it("reverts InvalidBlock when input is not an ACCOUNT_AMOUNT block", async () => {
      await expect(callAs(1, method, encodeBalanceBlock(asset, 123n)))
        .to.be.revertedWithCustomError(host, "InvalidBlock");
    });
  });

  describe("portDebitAccount", () => {
    const method = "portDebitAccount(bytes)";
    const account = encodeUserAccount("0x11");
    const asset = ethers.zeroPadValue("0xaa", 32);

    it("debits the account from a single ACCOUNT_AMOUNT block", async () => {
      const tx = await callAs(1, method, encodeAccountAmountBlock(account, asset, 123n));
      await expect(tx).to.emit(host, "PortDebitAccountCalled").withArgs(account, asset, 123n);
    });

    it("debits each account amount block when multiple are present", async () => {
      const account2 = encodeUserAccount("0x22");
      const asset2 = ethers.zeroPadValue("0xcc", 32);
      const tx = await callAs(
        1,
        method,
        concat(
          encodeAccountAmountBlock(account, asset, 123n),
          encodeAccountAmountBlock(account2, asset2, 456n),
        )
      );

      await expect(tx).to.emit(host, "PortDebitAccountCalled").withArgs(account, asset, 123n);
      await expect(tx).to.emit(host, "PortDebitAccountCalled").withArgs(account2, asset2, 456n);
    });

    it("returns empty bytes after processing account amount blocks", async () => {
      const signer = await getSigner(1);
      const result: string = await (host.connect(signer) as any)[method].staticCall(
        encodeAccountAmountBlock(account, asset, 123n)
      );
      expect(result).to.equal("0x");
    });

    it("reverts CommanderNotAllowed for the commander", async () => {
      await expect(callAs(0, method, encodeAccountAmountBlock(account, asset, 123n)))
        .to.be.revertedWithCustomError(host, "CommanderNotAllowed");
    });

    it("reverts AccessDenied for an untrusted caller", async () => {
      await expect(callAs(2, method, encodeAccountAmountBlock(account, asset, 123n)))
        .to.be.revertedWithCustomError(host, "AccessDenied");
    });

    it("reverts EmptyRun when input is empty", async () => {
      await expect(callAs(1, method))
        .to.be.revertedWithCustomError(host, "EmptyRun");
    });

    it("reverts InvalidBlock when input is not an ACCOUNT_AMOUNT block", async () => {
      await expect(callAs(1, method, encodeBalanceBlock(asset, 123n)))
        .to.be.revertedWithCustomError(host, "InvalidBlock");
    });
  });

  describe("settlement", () => {
    const account = encodeUserAccount("0x41");
    const asset = ethers.zeroPadValue("0x42", 32);
    const liability = ethers.zeroPadValue("0x43", 32);

    it("credits the asset and debits the liability of a position", async () => {
      const position = {
        asset,
        amount: 100n,
        liability,
        debt: 40n,
      };

      const tx = await host.testSettle(account, position);
      await expect(tx).to.emit(host, "PortCreditAccountCalled").withArgs(account, asset, 100n);
      await expect(tx).to.emit(host, "PortDebitAccountCalled").withArgs(account, liability, 40n);
    });

    it("skips zero sides of a position", async () => {
      const tx = await host.testSettle(account, {
        asset,
        amount: 0n,
        liability,
        debt: 40n,
      });

      const receipt = await tx.wait();
      const names = receipt?.logs.map((log) => {
        try {
          return host.interface.parseLog({ topics: log.topics as string[], data: log.data })?.name;
        } catch {
          return null;
        }
      });

      expect(names).to.not.include("PortCreditAccountCalled");
      await expect(tx).to.emit(host, "PortDebitAccountCalled").withArgs(account, liability, 40n);
    });
  });

  describe("portPost", () => {
    const method = "portPost(bytes)";
    const from_ = encodeUserAccount("0x11");
    const to_ = encodeUserAccount("0x22");
    const asset = ethers.zeroPadValue("0xaa", 32);

    it("debits and credits both sides of a single TX block", async () => {
      const tx = await callAs(1, method, encodeTxBlock(from_, to_, asset, 123n));
      await expect(tx).to.emit(host, "PortDebitAccountCalled").withArgs(from_, asset, 123n);
      await expect(tx).to.emit(host, "PortCreditAccountCalled").withArgs(to_, asset, 123n);
    });

    it("debits and credits each TX block when multiple are present", async () => {
      const from2 = encodeUserAccount("0x33");
      const tx = await callAs(
        1,
        method,
        concat(
          encodeTxBlock(from_, to_, asset, 123n),
          encodeTxBlock(from2, to_, asset, 456n),
        )
      );
      await expect(tx).to.emit(host, "PortDebitAccountCalled").withArgs(from_, asset, 123n);
      await expect(tx).to.emit(host, "PortCreditAccountCalled").withArgs(to_, asset, 123n);
      await expect(tx).to.emit(host, "PortDebitAccountCalled").withArgs(from2, asset, 456n);
      await expect(tx).to.emit(host, "PortCreditAccountCalled").withArgs(to_, asset, 456n);
    });

    it("skips the debit hook when TX from is zero", async () => {
      const tx = await callAs(1, method, encodeTxBlock(ethers.ZeroHash, to_, asset, 123n));
      await expect(tx).to.emit(host, "PortCreditAccountCalled").withArgs(to_, asset, 123n);

      const receipt = await tx.wait();
      const names = receipt?.logs.map((log) => {
        try {
          return host.interface.parseLog({ topics: log.topics as string[], data: log.data })?.name;
        } catch {
          return null;
        }
      });
      expect(names).to.not.include("PortDebitAccountCalled");
    });

    it("skips the credit hook when TX to is zero", async () => {
      const tx = await callAs(1, method, encodeTxBlock(from_, ethers.ZeroHash, asset, 123n));
      await expect(tx).to.emit(host, "PortDebitAccountCalled").withArgs(from_, asset, 123n);

      const receipt = await tx.wait();
      const names = receipt?.logs.map((log) => {
        try {
          return host.interface.parseLog({ topics: log.topics as string[], data: log.data })?.name;
        } catch {
          return null;
        }
      });
      expect(names).to.not.include("PortCreditAccountCalled");
    });

    it("skips both hooks when the TX amount is zero", async () => {
      const tx = await callAs(1, method, encodeTxBlock(from_, to_, asset, 0n));
      const receipt = await tx.wait();
      const names = receipt?.logs.map((log) => {
        try {
          return host.interface.parseLog({ topics: log.topics as string[], data: log.data })?.name;
        } catch {
          return null;
        }
      });

      expect(names).to.not.include("PortDebitAccountCalled");
      expect(names).to.not.include("PortCreditAccountCalled");
    });

    it("returns empty bytes after processing tx blocks", async () => {
      const signer = await getSigner(1);
      const result: string = await (host.connect(signer) as any)[method].staticCall(encodeTxBlock(from_, to_, asset, 123n));
      expect(result).to.equal("0x");
    });

    it("reverts AccessDenied for an untrusted caller", async () => {
      await expect(callAs(2, method, encodeTxBlock(from_, to_, asset, 123n)))
        .to.be.revertedWithCustomError(host, "AccessDenied");
    });

    it("reverts EmptyRun when input is empty", async () => {
      await expect(callAs(1, method))
        .to.be.revertedWithCustomError(host, "EmptyRun");
    });
  });

  describe("portPipePayable", () => {
    const method = "portPipePayable(bytes)";
    const account = encodeUserAccount("0x44");

    it("unpacks CONTEXT blocks and dispatches nested input as pipe steps", async () => {
      const step = encodeStepBlock(123n, 0n, "0xabcd");
      const input = encodeContextBlock(account, "0x", step);
      const startCount = await host.stepCount();

      const tx = await callAs(1, method, input);

      await expect(tx).to.emit(host, "StepDispatched").withArgs(123n, startCount, 0n);
    });

    it("shares one value budget across multiple pipes", async () => {
      const first = encodeContextBlock(account, "0x", encodeStepBlock(111n, 2n, "0x"));
      const second = encodeContextBlock(account, "0x", encodeStepBlock(222n, 3n, "0x"));
      const startCount = await host.stepCount();

      const tx = await callAs(1, method, concat(first, second), { value: 5n });

      await expect(tx).to.emit(host, "StepDispatched").withArgs(111n, startCount, 2n);
      await expect(tx).to.emit(host, "StepDispatched").withArgs(222n, startCount + 1n, 3n);
    });

    it("reverts UnexpectedState when a pipe context leaves final state", async () => {
      const state = encodeBalanceBlock(ethers.zeroPadValue("0xaa", 32), 77n);
      const input = encodeContextBlock(account, state, encodeStepBlock(0n, 0n, "0x"));
      const signer = await getSigner(1);

      await expect((host.connect(signer) as any)[method].staticCall(input))
        .to.be.revertedWithCustomError(host, "UnexpectedState");
    });

    it("reverts InsufficientValue when a pipe step requests more than the shared budget", async () => {
      const input = encodeContextBlock(account, "0x", encodeStepBlock(0n, 1n, "0x"));

      await expect(callAs(1, method, input, { value: 0n }))
        .to.be.revertedWithCustomError(host, "InsufficientValue");
    });

    it("keeps unspent peer value on the host", async () => {
      const input = encodeContextBlock(account, "0x", encodeStepBlock(0n, 1n, "0x"));
      const provider = await getProvider();
      const hostAddress = await host.getAddress();

      const tx = await callAs(1, method, input, { value: 2n });
      const receipt = await tx.wait();
      if (!receipt || receipt.status === 0) throw new Error("portPipePayable tx reverted");

      const before = await provider.getBalance(hostAddress, receipt.blockNumber - 1);
      const after = await provider.getBalance(hostAddress, receipt.blockNumber);
      expect(after - before).to.equal(2n);
    });
  });

  describe("portDispatchPayable", () => {
    const method = "portDispatchPayable(bytes)";

    it("dispatches a single DISPATCH block and exposes the remaining value budget", async () => {
      const portal = await localPortal();
      const payload = ethers.hexlify(ethers.toUtf8Bytes("encoded-payload"));
      const input = encodeDispatchBlock(portal, 5n, payload);

      const tx = await callAs(1, method, input, { value: 8n });

      await expect(tx).to.emit(host, "PortDispatchCalled").withArgs(portal, payload, 5n, 8n);
    });

    it("returns empty bytes after dispatching a payload", async () => {
      const signer = await getSigner(1);
      const input = encodeDispatchBlock(await localPortal(), 0n, "0x1234");
      const result: string = await (host.connect(signer) as any)[method].staticCall(input);
      expect(result).to.equal("0x");
    });

    it("reverts CommanderNotAllowed for the commander", async () => {
      const input = encodeDispatchBlock(await localPortal(), 0n, "0x");
      await expect(callAs(0, method, input))
        .to.be.revertedWithCustomError(host, "CommanderNotAllowed");
    });

    it("reverts AccessDenied for an untrusted caller", async () => {
      const input = encodeDispatchBlock(await localPortal(), 0n, "0x");
      await expect(callAs(2, method, input))
        .to.be.revertedWithCustomError(host, "AccessDenied");
    });

    it("reverts EmptyRun when input is empty", async () => {
      await expect(callAs(1, method))
        .to.be.revertedWithCustomError(host, "EmptyRun");
    });

    it("reverts InvalidBlock when input is not a DISPATCH block", async () => {
      const input = encodeContextBlock(encodeUserAccount("0x55"), "0x", "0x");
      await expect(callAs(1, method, input))
        .to.be.revertedWithCustomError(host, "InvalidBlock");
    });

    it("dispatches multiple DISPATCH blocks in one input", async () => {
      const portal = await localPortal();
      const first = "0x01";
      const second = "0x02";
      const input = concat(
        encodeDispatchBlock(portal, 2n, first),
        encodeDispatchBlock(portal, 3n, second),
      );

      const tx = await callAs(1, method, input, { value: 5n });

      await expect(tx).to.emit(host, "PortDispatchCalled").withArgs(portal, first, 2n, 5n);
      await expect(tx).to.emit(host, "PortDispatchCalled").withArgs(portal, second, 3n, 5n);
    });

    it("passes dispatch resources through even when it exceeds msg.value", async () => {
      const input = encodeDispatchBlock(await localPortal(), 2n, "0x");

      const tx = await callAs(1, method, input, { value: 1n });
      await expect(tx).to.emit(host, "PortDispatchCalled").withArgs(await localPortal(), "0x", 2n, 1n);
    });
  });
});


