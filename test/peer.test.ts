import { expect } from "chai";
import { deploy, getProvider, getSigner } from "./helpers/setup.js";
import {
  concat,
  encodePipeBlock,
  encodeAmountBlock,
  encodeBalanceBlock,
  encodeNodeBlock,
  encodeStepBlock,
  encodeTxBlock,
  encodeDispatchBlock,
  encodeUserAccount,
} from "./helpers/blocks.js";
import { ethers } from "ethers";
import "./helpers/matchers.js";

describe("Peer Entrypoints", () => {
  let host: Awaited<ReturnType<typeof deploy>>;

  before(async () => {
    const signer = await getSigner(0);
    const commander = await signer.getAddress();
    host = await deploy("TestPeerHost", commander);
    const trustedPeer = await callerHost(1);
    const adminAccount: string = await host.getAdminAccount();
    await host.authorize({ account: adminAccount, meta: ethers.ZeroHash, state: "0x", request: encodeNodeBlock(trustedPeer) });
  });

  it("emits Peer discovery events with id as the second argument", async () => {
    const tx = host.deploymentTransaction();
    expect(tx).to.not.equal(null);

    await expect(tx!)
      .to.emit(host, "Peer")
      .withArgs(
        await host.host(),
        await host.getPeerAllowanceId(),
        "peerAllowance",
        ethers.encodeBytes32String("1:0"),
        "#amount { bytes32 asset, bytes32 meta, uint amount }",
        "",
        false,
      );

    await expect(tx!)
      .to.emit(host, "Peer")
      .withArgs(
        await host.host(),
        await host.getPeerBalancePullId(),
        "peerBalancePull",
        ethers.encodeBytes32String("1:0"),
        "#balance { bytes32 asset, bytes32 meta, uint amount }",
        "",
        false,
      );

    await expect(tx!)
      .to.emit(host, "Peer")
      .withArgs(
        await host.host(),
        await host.getPeerPipePayableId(),
        "peerPipePayable",
        ethers.encodeBytes32String("1:0"),
        "#pipe { uint value, #context { bytes32 account, #bytes as state, #bytes as steps } }",
        "",
        true,
      );

    await expect(tx!)
      .to.emit(host, "Peer")
      .withArgs(
        await host.host(),
        await host.getPeerDispatchPayableId(),
        "peerDispatchPayable",
        ethers.encodeBytes32String("1:0"),
        "#dispatch { uint chain, uint resources, #bytes as payload }",
        "",
        true,
      );

  });

  async function callAs(
    signerIndex: number,
    method:
      | "peerAllowance(bytes)"
      | "peerBalancePull(bytes)"
      | "peerSettle(bytes)"
      | "peerPipePayable(bytes)"
      | "peerDispatchPayable(bytes)",
    request = "0x",
    overrides: Record<string, bigint> = {}
  ) {
    const signer = await getSigner(signerIndex);
    return (host.connect(signer) as any)[method](request, overrides);
  }

  async function callerHost(signerIndex: number) {
    const signer = await getSigner(signerIndex);
    const addr = await signer.getAddress();
    const provider = await getProvider();
    const network = await provider.getNetwork();
    const HOST_PREFIX = 0x01200202n;
    return (HOST_PREFIX << 224n) | (network.chainId << 192n) | BigInt(addr);
  }

  async function localChain() {
    const provider = await getProvider();
    const network = await provider.getNetwork();
    const CHAIN_PREFIX = 0x01200201n;
    return (CHAIN_PREFIX << 224n) | network.chainId;
  }

  describe("peerAllowance", () => {
    const method = "peerAllowance(bytes)";
    const asset = ethers.zeroPadValue("0xa0", 32);
    const meta = ethers.zeroPadValue("0xb0", 32);

    it("emits PeerAllowanceCalled for a single AMOUNT block scoped to the caller host", async () => {
      const peer = await callerHost(1);
      const tx = await callAs(1, method, encodeAmountBlock(asset, meta, 123n));
      await expect(tx).to.emit(host, "PeerAllowanceCalled").withArgs(peer, asset, meta, 123n);
    });

    it("emits PeerAllowanceCalled for each AMOUNT block when multiple are present", async () => {
      const peer = await callerHost(1);
      const asset2 = ethers.zeroPadValue("0xc0", 32);
      const tx = await callAs(
        1,
        method,
        concat(
          encodeAmountBlock(asset, meta, 123n),
          encodeAmountBlock(asset2, meta, 456n),
        )
      );
      await expect(tx).to.emit(host, "PeerAllowanceCalled").withArgs(peer, asset, meta, 123n);
      await expect(tx).to.emit(host, "PeerAllowanceCalled").withArgs(peer, asset2, meta, 456n);
    });

    it("returns empty bytes after processing amount blocks", async () => {
      const signer = await getSigner(1);
      const result: string = await (host.connect(signer) as any)[method].staticCall(encodeAmountBlock(asset, meta, 123n));
      expect(result).to.equal("0x");
    });

    it("reverts CommanderNotAllowed for the commander", async () => {
      await expect(callAs(0, method, encodeAmountBlock(asset, meta, 123n)))
        .to.be.revertedWithCustomError(host, "CommanderNotAllowed");
    });

    it("reverts AccessDenied for an untrusted caller", async () => {
      await expect(callAs(2, method, encodeAmountBlock(asset, meta, 123n)))
        .to.be.revertedWithCustomError(host, "AccessDenied");
    });

    it("reverts ZeroCursor when request is empty", async () => {
      await expect(callAs(1, method))
        .to.be.revertedWithCustomError(host, "ZeroCursor");
    });
  });

  describe("peerBalancePull", () => {
    const method = "peerBalancePull(bytes)";
    const asset = ethers.zeroPadValue("0xaa", 32);
    const meta = ethers.zeroPadValue("0xbb", 32);

    it("emits PeerBalancePullCalled for a single BALANCE block", async () => {
      const peer = await callerHost(1);
      const tx = await callAs(1, method, encodeBalanceBlock(asset, meta, 123n));
      await expect(tx).to.emit(host, "PeerBalancePullCalled").withArgs(peer, asset, meta, 123n);
    });

    it("emits PeerBalancePullCalled for each BALANCE block when multiple are present", async () => {
      const peer = await callerHost(1);
      const asset2 = ethers.zeroPadValue("0xcc", 32);
      const tx = await callAs(
        1,
        method,
        concat(
          encodeBalanceBlock(asset, meta, 123n),
          encodeBalanceBlock(asset2, meta, 456n),
        )
      );
      await expect(tx).to.emit(host, "PeerBalancePullCalled").withArgs(peer, asset, meta, 123n);
      await expect(tx).to.emit(host, "PeerBalancePullCalled").withArgs(peer, asset2, meta, 456n);
    });

    it("returns empty bytes after processing balance blocks", async () => {
      const signer = await getSigner(1);
      const result: string = await (host.connect(signer) as any)[method].staticCall(encodeBalanceBlock(asset, meta, 123n));
      expect(result).to.equal("0x");
    });

    it("reverts CommanderNotAllowed for the commander", async () => {
      await expect(callAs(0, method, encodeBalanceBlock(asset, meta, 123n)))
        .to.be.revertedWithCustomError(host, "CommanderNotAllowed");
    });

    it("reverts AccessDenied for an untrusted caller", async () => {
      await expect(callAs(2, method, encodeBalanceBlock(asset, meta, 123n)))
        .to.be.revertedWithCustomError(host, "AccessDenied");
    });

    it("reverts ZeroCursor when request is empty", async () => {
      await expect(callAs(1, method))
        .to.be.revertedWithCustomError(host, "ZeroCursor");
    });
  });

  describe("peerSettle", () => {
    const method = "peerSettle(bytes)";
    const from_ = encodeUserAccount("0x11");
    const to_ = encodeUserAccount("0x22");
    const asset = ethers.zeroPadValue("0xaa", 32);
    const meta = ethers.zeroPadValue("0xbb", 32);

    it("debits and credits both sides of a single TX block", async () => {
      const tx = await callAs(1, method, encodeTxBlock(from_, to_, asset, meta, 123n));
      await expect(tx).to.emit(host, "PeerDebitAccountCalled").withArgs(from_, asset, meta, 123n);
      await expect(tx).to.emit(host, "PeerCreditAccountCalled").withArgs(to_, asset, meta, 123n);
    });

    it("debits and credits each TX block when multiple are present", async () => {
      const from2 = encodeUserAccount("0x33");
      const tx = await callAs(
        1,
        method,
        concat(
          encodeTxBlock(from_, to_, asset, meta, 123n),
          encodeTxBlock(from2, to_, asset, meta, 456n),
        )
      );
      await expect(tx).to.emit(host, "PeerDebitAccountCalled").withArgs(from_, asset, meta, 123n);
      await expect(tx).to.emit(host, "PeerCreditAccountCalled").withArgs(to_, asset, meta, 123n);
      await expect(tx).to.emit(host, "PeerDebitAccountCalled").withArgs(from2, asset, meta, 456n);
      await expect(tx).to.emit(host, "PeerCreditAccountCalled").withArgs(to_, asset, meta, 456n);
    });

    it("skips the debit hook when TX from is zero", async () => {
      const tx = await callAs(1, method, encodeTxBlock(ethers.ZeroHash, to_, asset, meta, 123n));
      await expect(tx).to.emit(host, "PeerCreditAccountCalled").withArgs(to_, asset, meta, 123n);

      const receipt = await tx.wait();
      const names = receipt?.logs.map((log) => {
        try {
          return host.interface.parseLog({ topics: log.topics as string[], data: log.data })?.name;
        } catch {
          return null;
        }
      });
      expect(names).to.not.include("PeerDebitAccountCalled");
    });

    it("skips the credit hook when TX to is zero", async () => {
      const tx = await callAs(1, method, encodeTxBlock(from_, ethers.ZeroHash, asset, meta, 123n));
      await expect(tx).to.emit(host, "PeerDebitAccountCalled").withArgs(from_, asset, meta, 123n);

      const receipt = await tx.wait();
      const names = receipt?.logs.map((log) => {
        try {
          return host.interface.parseLog({ topics: log.topics as string[], data: log.data })?.name;
        } catch {
          return null;
        }
      });
      expect(names).to.not.include("PeerCreditAccountCalled");
    });

    it("returns empty bytes after processing tx blocks", async () => {
      const signer = await getSigner(1);
      const result: string = await (host.connect(signer) as any)[method].staticCall(encodeTxBlock(from_, to_, asset, meta, 123n));
      expect(result).to.equal("0x");
    });

    it("reverts AccessDenied for an untrusted caller", async () => {
      await expect(callAs(2, method, encodeTxBlock(from_, to_, asset, meta, 123n)))
        .to.be.revertedWithCustomError(host, "AccessDenied");
    });

    it("reverts ZeroCursor when request is empty", async () => {
      await expect(callAs(1, method))
        .to.be.revertedWithCustomError(host, "ZeroCursor");
    });
  });

  describe("peerPipePayable", () => {
    const method = "peerPipePayable(bytes)";
    const account = encodeUserAccount("0x44");

    it("unpacks PIPE blocks and dispatches nested context request as pipe steps", async () => {
      const step = encodeStepBlock(123n, 0n, "0xabcd");
      const request = encodePipeBlock(0n, account, "0x", step);
      const startCount = await host.stepCount();

      const tx = await callAs(1, method, request);

      await expect(tx).to.emit(host, "StepDispatched").withArgs(123n, startCount, 0n);
    });

    it("allocates independent value sub-budgets across multiple pipes", async () => {
      const first = encodePipeBlock(2n, account, "0x", encodeStepBlock(111n, 2n, "0x"));
      const second = encodePipeBlock(3n, account, "0x", encodeStepBlock(222n, 3n, "0x"));
      const startCount = await host.stepCount();

      const tx = await callAs(1, method, concat(first, second), { value: 5n });

      await expect(tx).to.emit(host, "StepDispatched").withArgs(111n, startCount, 2n);
      await expect(tx).to.emit(host, "StepDispatched").withArgs(222n, startCount + 1n, 3n);
    });

    it("reverts UnexpectedState when a pipe context leaves final state", async () => {
      const state = encodeBalanceBlock(ethers.zeroPadValue("0xaa", 32), ethers.ZeroHash, 77n);
      const request = encodePipeBlock(0n, account, state, encodeStepBlock(0n, 0n, "0x"));
      const signer = await getSigner(1);

      await expect((host.connect(signer) as any)[method].staticCall(request))
        .to.be.revertedWithCustomError(host, "UnexpectedState");
    });

    it("reverts InsufficientValue when a pipe step requests more than its value", async () => {
      const request = encodePipeBlock(0n, account, "0x", encodeStepBlock(0n, 1n, "0x"));

      await expect(callAs(1, method, request, { value: 2n }))
        .to.be.revertedWithCustomError(host, "InsufficientValue");
    });

    it("reverts UnusedValue when a pipe sub-budget is not fully spent", async () => {
      const request = encodePipeBlock(2n, account, "0x", encodeStepBlock(0n, 1n, "0x"));

      await expect(callAs(1, method, request, { value: 2n }))
        .to.be.revertedWithCustomError(host, "UnusedValue");
    });

    it("keeps top-level value that is not allocated to pipes", async () => {
      const request = encodePipeBlock(1n, account, "0x", encodeStepBlock(0n, 1n, "0x"));
      const provider = await getProvider();
      const hostAddress = await host.getAddress();

      const tx = await callAs(1, method, request, { value: 2n });
      const receipt = await tx.wait();
      if (!receipt || receipt.status === 0) throw new Error("peerPipePayable tx reverted");

      const before = await provider.getBalance(hostAddress, receipt.blockNumber - 1);
      const after = await provider.getBalance(hostAddress, receipt.blockNumber);
      expect(after - before).to.equal(2n);
    });
  });

  describe("peerDispatchPayable", () => {
    const method = "peerDispatchPayable(bytes)";

    it("dispatches a single DISPATCH block and exposes the remaining value budget", async () => {
      const chain = await localChain();
      const payload = ethers.hexlify(ethers.toUtf8Bytes("encoded-payload"));
      const request = encodeDispatchBlock(chain, 5n, payload);

      const tx = await callAs(1, method, request, { value: 8n });

      await expect(tx).to.emit(host, "PeerDispatchCalled").withArgs(chain, payload, 5n, 8n);
    });

    it("returns empty bytes after dispatching a payload", async () => {
      const signer = await getSigner(1);
      const request = encodeDispatchBlock(await localChain(), 0n, "0x1234");
      const result: string = await (host.connect(signer) as any)[method].staticCall(request);
      expect(result).to.equal("0x");
    });

    it("reverts CommanderNotAllowed for the commander", async () => {
      const request = encodeDispatchBlock(await localChain(), 0n, "0x");
      await expect(callAs(0, method, request))
        .to.be.revertedWithCustomError(host, "CommanderNotAllowed");
    });

    it("reverts AccessDenied for an untrusted caller", async () => {
      const request = encodeDispatchBlock(await localChain(), 0n, "0x");
      await expect(callAs(2, method, request))
        .to.be.revertedWithCustomError(host, "AccessDenied");
    });

    it("reverts ZeroCursor when request is empty", async () => {
      await expect(callAs(1, method))
        .to.be.revertedWithCustomError(host, "ZeroCursor");
    });

    it("reverts InvalidBlock when request is not a DISPATCH block", async () => {
      const request = encodePipeBlock(0n, encodeUserAccount("0x55"), "0x", "0x");
      await expect(callAs(1, method, request))
        .to.be.revertedWithCustomError(host, "InvalidBlock");
    });

    it("dispatches multiple DISPATCH blocks in one request", async () => {
      const chain = await localChain();
      const first = "0x01";
      const second = "0x02";
      const request = concat(
        encodeDispatchBlock(chain, 2n, first),
        encodeDispatchBlock(chain, 3n, second),
      );

      const tx = await callAs(1, method, request, { value: 5n });

      await expect(tx).to.emit(host, "PeerDispatchCalled").withArgs(chain, first, 2n, 5n);
      await expect(tx).to.emit(host, "PeerDispatchCalled").withArgs(chain, second, 3n, 5n);
    });

    it("passes dispatch resources through even when it exceeds msg.value", async () => {
      const request = encodeDispatchBlock(await localChain(), 2n, "0x");

      const tx = await callAs(1, method, request, { value: 1n });
      await expect(tx).to.emit(host, "PeerDispatchCalled").withArgs(await localChain(), "0x", 2n, 1n);
    });
  });
});


