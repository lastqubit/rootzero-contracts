import { expect } from "chai";
import { ethers } from "ethers";
import { deploy, getSigner, getProvider } from "./helpers/setup.js";
import { encodeTxBlock, encodeUserAccount } from "./helpers/blocks.js";

async function expectCustomError(promise: Promise<unknown>, name: string) {
  try {
    await promise;
    expect.fail(`Expected ${name} revert`);
  } catch (e) {
    const err = e as { revert?: { name?: string } };
    expect(err.revert?.name).to.equal(name);
  }
}

function opaqueKeccak(preimage: string) {
  const hash = ethers.keccak256(preimage);
  return `0x00${hash.slice(2, 64)}`;
}

describe("Utils", () => {
  let utils: Awaited<ReturnType<typeof deploy>>;
  let signerAddress: string;
  let chainId: bigint;

  before(async () => {
    utils = await deploy("TestUtils");
    const signer = await getSigner();
    signerAddress = await signer.getAddress();
    const provider = await getProvider();
    const network = await provider.getNetwork();
    chainId = network.chainId;
  });

  // ── IDs ───────────────────────────────────────────────────────────────────

  describe("Ids", () => {
    it("derives opaque keccak IDs with a zero first byte", async () => {
      const preimage = ethers.concat(["0x01", ethers.toUtf8Bytes("rootzero:asset:gold")]);
      const expected = opaqueKeccak(preimage);

      expect(await utils.testToKeccak(preimage)).to.equal(expected);
      expect(await utils.testIsOpaqueId(expected)).to.be.true;
      expect(BigInt(expected) >> 248n).to.equal(0n);
    });

    it("opaque validator returns matching IDs", async () => {
      const preimage = ethers.concat(["0x01", ethers.toUtf8Bytes("rootzero:account:user")]);
      const opaque = opaqueKeccak(preimage);
      const structured = await utils.testToUserAccount(signerAddress);

      expect(await utils.testOpaqueId(opaque)).to.equal(opaque);
      await expectCustomError(utils.testOpaqueId(structured), "InvalidId");
    });

    it("rejects non-keccak opaque preimages", async () => {
      await expectCustomError(utils.testToKeccak("0x"), "InvalidPreimage");
      await expectCustomError(utils.testToKeccak("0x02abcd"), "InvalidPreimage");
    });

    it("matches opaque keccak IDs against their preimage", async () => {
      const preimage = ethers.concat(["0x01", ethers.toUtf8Bytes("rootzero:node:remote")]);
      const id = opaqueKeccak(preimage);

      expect(await utils.testMatchKeccak(id, preimage)).to.equal(id);
      await expectCustomError(utils.testMatchKeccak(ethers.ZeroHash, preimage), "InvalidId");
    });
  });

  // ── Accounts ──────────────────────────────────────────────────────────────

  describe("Accounts", () => {
    it("addrOr returns or when addr is zero", async () => {
      const or = "0x" + "ab".repeat(20);
      const result = await utils.testAddrOr(ethers.ZeroAddress, or);
      expect(result.toLowerCase()).to.equal(or.toLowerCase());
    });

    it("addrOr returns addr when non-zero", async () => {
      const addr = "0x" + "cd".repeat(20);
      const or = "0x" + "ef".repeat(20);
      const result = await utils.testAddrOr(addr, or);
      expect(result.toLowerCase()).to.equal(addr.toLowerCase());
    });

    it("toAdminAccount encodes admin prefix, chainId and address", async () => {
      const result: string = await utils.testToAdminAccount(signerAddress);
      const val = BigInt(result);
      // First two bytes are EVM + 32-byte width.
      expect((val >> 240n) & 0xffffn).to.equal(0x0120n);
      // Address is in bits 32..191
      const embeddedAddr = (val >> 32n) & ((1n << 160n) - 1n);
      expect("0x" + embeddedAddr.toString(16).padStart(40, "0")).to.equal(signerAddress.toLowerCase());
    });

    it("toUserAccount encodes user prefix without chain-specific chainId", async () => {
      const result: string = await utils.testToUserAccount(signerAddress);
      const val = BigInt(result);
      // Chain bytes (bits 192..223) should be 0 for unspecified
      const chainBytes = (val >> 192n) & 0xffffffffn;
      expect(chainBytes).to.equal(0n);
    });

    it("isAdminAccount returns true for admin account", async () => {
      const adminAccount = await utils.testToAdminAccount(signerAddress);
      expect(await utils.testIsAdminAccount(adminAccount)).to.be.true;
    });

    it("isAdminAccount returns false for user account", async () => {
      const userAccount = await utils.testToUserAccount(signerAddress);
      expect(await utils.testIsAdminAccount(userAccount)).to.be.false;
    });

    it("isUserAccount returns true for user account", async () => {
      const userAccount = await utils.testToUserAccount(signerAddress);
      expect(await utils.testIsUserAccount(userAccount)).to.be.true;
    });

    it("isUserAccount returns false for admin accounts", async () => {
      expect(await utils.testIsUserAccount(await utils.testToAdminAccount(signerAddress))).to.be.false;
    });

    it("EVM account helpers accept supported EVM accounts", async () => {
      const admin = await utils.testToAdminAccount(signerAddress);
      const user = await utils.testToUserAccount(signerAddress);

      expect(await utils.testIsEvmAccount(admin)).to.be.true;
      expect(await utils.testIsEvmAccount(user)).to.be.true;
      expect(await utils.testEvmAccount(admin)).to.equal(admin);
      expect(await utils.testEvmAccount(user)).to.equal(user);
    });

    it("EVM account helpers reject non-EVM accounts", async () => {
      await expectCustomError(utils.testEvmAccount(await utils.testToNativeAsset()), "InvalidAccount");
      expect(await utils.testIsEvmAccount(ethers.ZeroHash)).to.be.false;
    });

    it("opaque account helpers use account errors", async () => {
      const preimage = ethers.concat(["0x01", ethers.toUtf8Bytes("rootzero:account:opaque")]);
      const account = opaqueKeccak(preimage);
      const structured = await utils.testToUserAccount(signerAddress);

      expect(await utils.testIsOpaqueAccount(account)).to.be.true;
      expect(await utils.testToKeccakAccount(preimage)).to.equal(account);
      expect(await utils.testOpaqueAccount(account)).to.equal(account);
      expect(await utils.testMatchKeccakAccount(account, preimage)).to.equal(account);
      await expectCustomError(utils.testOpaqueAccount(structured), "InvalidAccount");
    });

    it("typed account helpers return matching accounts", async () => {
      const adminAccount = await utils.testToAdminAccount(signerAddress);
      const userAccount = await utils.testToUserAccount(signerAddress);

      expect(await utils.testAdminAccount(adminAccount)).to.equal(adminAccount);
      expect(await utils.testUserAccount(userAccount)).to.equal(userAccount);
    });

    it("typed account helpers reject mismatched accounts", async () => {
      const adminAccount = await utils.testToAdminAccount(signerAddress);
      const userAccount = await utils.testToUserAccount(signerAddress);

      await expectCustomError(utils.testAdminAccount(userAccount), "InvalidAccount");
      await expectCustomError(utils.testUserAccount(adminAccount), "InvalidAccount");
    });

    it("accountAddr extracts embedded address", async () => {
      const userAccount = await utils.testToUserAccount(signerAddress);
      const extracted = await utils.testAccountAddr(userAccount);
      expect(extracted.toLowerCase()).to.equal(signerAddress.toLowerCase());
    });

    it("accountAddr reverts for non-EVM account", async () => {
      await expectCustomError(utils.testAccountAddr(await utils.testToNativeAsset()), "InvalidAccount");
    });

    it("accountAddr reverts ZeroAddress for zero embedded address", async () => {
      await expectCustomError(utils.testAccountAddr(await utils.testToUserAccount(ethers.ZeroAddress)), "ZeroAddress");
    });
  });

  // ── Assets ────────────────────────────────────────────────────────────────

  describe("Assets", () => {
    it("toNativeAsset returns an EVM asset", async () => {
      const asset: string = await utils.testToNativeAsset();
      expect((BigInt(asset) >> 240n) & 0xffffn).to.equal(0x0120n);
    });

    it("toErc20Asset embeds token address", async () => {
      const token = signerAddress;
      const asset: string = await utils.testToErc20Asset(token);
      const val = BigInt(asset);
      const embedded = (val >> 32n) & ((1n << 160n) - 1n);
      expect("0x" + embedded.toString(16).padStart(40, "0")).to.equal(token.toLowerCase());
    });

    it("EVM asset helpers accept supported EVM assets", async () => {
      const native = await utils.testToNativeAsset();
      const erc20 = await utils.testToErc20Asset(signerAddress);

      expect(await utils.testIsEvmAsset(native)).to.be.true;
      expect(await utils.testIsEvmAsset(erc20)).to.be.true;
      expect(await utils.testEvmAsset(native)).to.equal(native);
      expect(await utils.testEvmAsset(erc20)).to.equal(erc20);
    });

    it("EVM asset helpers reject non-EVM assets", async () => {
      await expectCustomError(utils.testEvmAsset(await utils.testToUserAccount(signerAddress)), "InvalidAsset");
      expect(await utils.testIsEvmAsset(ethers.ZeroHash)).to.be.false;
    });

    it("opaque asset helpers use asset errors", async () => {
      const preimage = ethers.concat(["0x01", ethers.toUtf8Bytes("rootzero:asset:opaque")]);
      const asset = opaqueKeccak(preimage);
      const structured = await utils.testToNativeAsset();

      expect(await utils.testIsOpaqueAsset(asset)).to.be.true;
      expect(await utils.testToKeccakAsset(preimage)).to.equal(asset);
      expect(await utils.testOpaqueAsset(asset)).to.equal(asset);
      expect(await utils.testMatchKeccakAsset(asset, preimage)).to.equal(asset);
      await expectCustomError(utils.testOpaqueAsset(structured), "InvalidAsset");
    });

    it("resolveAmount clamps to max", async () => {
      expect(await utils.testResolveAmount(200n, 10n, 100n)).to.equal(100n);
    });

    it("resolveAmount returns available when within range", async () => {
      expect(await utils.testResolveAmount(50n, 10n, 100n)).to.equal(50n);
    });

    it("resolveAmount reverts BadAmount when below min", async () => {
      await expectCustomError(utils.testResolveAmount(5n, 10n, 100n), "BadAmount");
    });

    it("ensureAmount reverts ZeroAmount on zero", async () => {
      await expectCustomError(utils.testEnsureAmount(0n), "ZeroAmount");
    });

    it("ensureAmount returns value when non-zero", async () => {
      expect(await utils.testEnsureAmount(42n)).to.equal(42n);
    });

    it("ensureAmount with range reverts BadAmount when out of range", async () => {
      await expectCustomError(utils.testEnsureAmountRange(0n, 1n, 10n), "BadAmount");
      await expectCustomError(utils.testEnsureAmountRange(11n, 1n, 10n), "BadAmount");
    });

    it("localErc20Addr extracts token address from ERC20 asset", async () => {
      const token = signerAddress;
      const asset = await utils.testToErc20Asset(token);
      const extracted = await utils.testLocalErc20Addr(asset);
      expect(extracted.toLowerCase()).to.equal(token.toLowerCase());
    });

    it("matchErc20 returns the asset when it matches the token", async () => {
      const token = signerAddress;
      const asset = await utils.testToErc20Asset(token);
      expect(await utils.testMatchErc20(asset, token)).to.equal(asset);
    });

    it("localErc20Addr reverts InvalidAsset for native asset", async () => {
      const asset = await utils.testToNativeAsset();
      await expectCustomError(utils.testLocalErc20Addr(asset), "InvalidAsset");
    });

    it("localErc20Addr reverts ZeroAddress for zero embedded address", async () => {
      const asset = await utils.testToErc20Asset(ethers.ZeroAddress);
      await expectCustomError(utils.testLocalErc20Addr(asset), "ZeroAddress");
    });

    it("matchErc20 reverts InvalidAsset for the wrong token", async () => {
      const token = signerAddress;
      const other = "0x00000000000000000000000000000000000000ab";
      const asset = await utils.testToErc20Asset(token);
      await expectCustomError(utils.testMatchErc20(asset, other), "InvalidAsset");
    });

  });

  // ── Nodes ───────────────────────────────────────────────────────────────────

  describe("Nodes", () => {
    it("localChainId creates a chain node ID with zero selector and address", async () => {
      const id: bigint = await utils.testLocalChainId();
      const prefix = (id >> 224n) & 0xffffffffn;
      const embeddedChainId = (id >> 192n) & 0xffffffffn;
      const selector = (id >> 160n) & 0xffffffffn;
      const embeddedAddress = id & ((1n << 160n) - 1n);

      expect(prefix).to.equal(0x01200201n);
      expect(embeddedChainId).to.equal(chainId);
      expect(selector).to.equal(0n);
      expect(embeddedAddress).to.equal(0n);
    });

    it("addr rejects chain node IDs", async () => {
      const chainNode: bigint = await utils.testLocalChainId();
      await expectCustomError(utils.testAddr(chainNode), "ZeroAddress");
    });

    it("toHostId creates host ID from address", async () => {
      const id: bigint = await utils.testToHostId(signerAddress);
      expect(id).to.be.gt(0n);
      expect(await utils.testIsHost(id)).to.be.true;
    });

    it("endpoint IDs derive canonical selectors from names", async () => {
      const command: bigint = await utils.testToCommandId("example", signerAddress);
      const port: bigint = await utils.testToPortId("example", signerAddress);
      const query: bigint = await utils.testToQueryId("example", signerAddress);
      const guard: bigint = await utils.testToGuardId("example", signerAddress);
      const embeddedSelector = (node: bigint) => (node >> 160n) & 0xffffffffn;
      const commandSelector = BigInt(ethers.dataSlice(ethers.id("example(bytes32,bytes,bytes)"), 0, 4));
      const directSelector = BigInt(ethers.dataSlice(ethers.id("example(bytes)"), 0, 4));

      expect(embeddedSelector(command)).to.equal(commandSelector);
      expect(embeddedSelector(port)).to.equal(directSelector);
      expect(embeddedSelector(query)).to.equal(directSelector);
      expect(embeddedSelector(guard)).to.equal(directSelector);
    });

    it("EVM node helpers accept supported EVM nodes", async () => {
      const host: bigint = await utils.testToHostId(signerAddress);
      const command: bigint = await utils.testToCommandId("deposit", signerAddress);

      expect(await utils.testIsEvmNode(host)).to.be.true;
      expect(await utils.testIsEvmNode(command)).to.be.true;
      expect(await utils.testIsLocalNode(host)).to.be.true;
      expect(await utils.testIsLocalNode(command)).to.be.true;
      expect(await utils.testEvmNode(host)).to.equal(host);
      expect(await utils.testEvmNode(command)).to.equal(command);
      expect(await utils.testLocalNode(host)).to.equal(host);
      expect(await utils.testLocalNode(command)).to.equal(command);
    });

    it("EVM node helpers reject non-EVM nodes", async () => {
      await expectCustomError(utils.testEvmNode(0n), "InvalidId");
      await expectCustomError(utils.testLocalNode(0n), "InvalidId");
      expect(await utils.testIsEvmNode(0n)).to.be.false;
      expect(await utils.testIsLocalNode(0n)).to.be.false;
    });

    it("opaque node helpers use node IDs and errors", async () => {
      const preimage = ethers.concat(["0x01", ethers.toUtf8Bytes("rootzero:node:opaque")]);
      const node = BigInt(opaqueKeccak(preimage));
      const structured = await utils.testToHostId(signerAddress);

      expect(await utils.testIsOpaqueNode(node)).to.be.true;
      expect(await utils.testToKeccakNode(preimage)).to.equal(node);
      expect(await utils.testOpaqueNode(node)).to.equal(node);
      expect(await utils.testMatchKeccakNode(node, preimage)).to.equal(node);
      await expectCustomError(utils.testOpaqueNode(structured), "InvalidId");
    });

    it("local node helper rejects foreign-chain EVM nodes", async () => {
      const foreignHostId = (0x01200202n << 224n) | (999n << 192n) | BigInt(signerAddress);
      expect(await utils.testIsEvmNode(foreignHostId)).to.be.true;
      expect(await utils.testIsLocalNode(foreignHostId)).to.be.false;
      await expectCustomError(utils.testLocalNode(foreignHostId), "InvalidId");
    });

    it("isHost returns false for command ID", async () => {
      const cid: bigint = await utils.testToCommandId("deposit", signerAddress);
      expect(await utils.testIsHost(cid)).to.be.false;
    });

    it("host succeeds for host ID", async () => {
      const hid: bigint = await utils.testToHostId(signerAddress);
      const result: bigint = await utils.testHostNode(hid);
      expect(result).to.equal(hid);
    });

    it("isCommand returns true for command ID", async () => {
      const cid: bigint = await utils.testToCommandId("deposit", signerAddress);
      expect(await utils.testIsCommand(cid)).to.be.true;
    });

    it("isCommand returns false for host ID", async () => {
      const hid: bigint = await utils.testToHostId(signerAddress);
      expect(await utils.testIsCommand(hid)).to.be.false;
    });

    it("isPort returns true for port ID", async () => {
      const pid: bigint = await utils.testToPortId("portAllowance", signerAddress);
      expect(await utils.testIsPort(pid)).to.be.true;
    });

    it("isGuard returns true for guard ID", async () => {
      const gid: bigint = await utils.testToGuardId("revoke", signerAddress);
      expect(await utils.testIsGuard(gid)).to.be.true;
    });

    it("isPort returns false for host ID", async () => {
      const hid: bigint = await utils.testToHostId(signerAddress);
      expect(await utils.testIsPort(hid)).to.be.false;
    });

    it("isGuard returns false for host ID", async () => {
      const hid: bigint = await utils.testToHostId(signerAddress);
      expect(await utils.testIsGuard(hid)).to.be.false;
    });

    it("addr extracts address from host ID", async () => {
      const id: bigint = await utils.testToHostId(signerAddress);
      const addr = await utils.testAddr(id);
      expect(addr.toLowerCase()).to.equal(signerAddress.toLowerCase());
    });

    it("localHostAddr extracts address from host ID", async () => {
      const id: bigint = await utils.testToHostId(signerAddress);
      const addr = await utils.testLocalHostAddr(id);
      expect(addr.toLowerCase()).to.equal(signerAddress.toLowerCase());
    });

    it("localHostAddr reverts ZeroAddress for zero embedded address", async () => {
      const id: bigint = await utils.testToHostId(ethers.ZeroAddress);
      await expectCustomError(utils.testLocalHostAddr(id), "ZeroAddress");
    });

    it("ensureHost reverts InvalidId for wrong address", async () => {
      const id: bigint = await utils.testToHostId(signerAddress);
      const other = "0x" + "ab".repeat(20);
      await expectCustomError(utils.testEnsureHost(id, other), "InvalidId");
    });

    it("command reverts InvalidId for host ID", async () => {
      const hid: bigint = await utils.testToHostId(signerAddress);
      await expectCustomError(utils.testCommandNode(hid), "InvalidId");
    });

    it("command succeeds for command ID", async () => {
      const cid: bigint = await utils.testToCommandId("deposit", signerAddress);
      const result: bigint = await utils.testCommandNode(cid);
      expect(result).to.equal(cid);
    });

    it("port succeeds for port ID", async () => {
      const pid: bigint = await utils.testToPortId("portAllowance", signerAddress);
      const result: bigint = await utils.testPortNode(pid);
      expect(result).to.equal(pid);
    });

    it("guard succeeds for guard ID", async () => {
      const gid: bigint = await utils.testToGuardId("revoke", signerAddress);
      const result: bigint = await utils.testGuardNode(gid);
      expect(result).to.equal(gid);
    });

    it("localHostAddr reverts for a foreign-chain host id", async () => {
      const foreignHostId = (0x01200202n << 224n) | (999n << 192n) | BigInt(signerAddress);
      await expectCustomError(utils.testLocalHostAddr(foreignHostId), "InvalidId");
    });
  });

  // ── Utils (bps, families) ─────────────────────────────────────────────────

  describe("Utils (bps / families)", () => {
    it("applyBps returns correct basis-point amount", async () => {
      expect(await utils.testApplyBps(10000n, 100)).to.equal(100n); // 1%
      expect(await utils.testApplyBps(1000n, 50)).to.equal(5n);     // 0.5%
    });

    it("applyBps returns 0 when amount is 0", async () => {
      expect(await utils.testApplyBps(0n, 100)).to.equal(0n);
    });

    it("applyBps returns 0 when bps is 0", async () => {
      expect(await utils.testApplyBps(1000n, 0)).to.equal(0n);
    });

    it("beforeBps is inverse of applyBps", async () => {
      const gross = await utils.testBeforeBps(100n, 100); // 100 after 1% fee -> what was gross?
      // gross * 10000 / 10100 ~= 99
      expect(gross).to.be.lte(100n);
      expect(gross).to.be.gte(98n);
    });

    it("max8 returns value when within range", async () => {
      expect(await utils.testMax8(255n)).to.equal(255n);
    });

    it("max8 reverts ValueOverflow when too large", async () => {
      await expectCustomError(utils.testMax8(256n), "ValueOverflow");
    });

    it("max160 returns value within range", async () => {
      const val = (1n << 160n) - 1n;
      expect(await utils.testMax160(val)).to.equal(val);
    });

    it("max160 reverts for 2^160", async () => {
      await expectCustomError(utils.testMax160(1n << 160n), "ValueOverflow");
    });

    it("isFamily matches family prefix", async () => {
      // Build a value with a known family prefix
      // EVM = 0x0120, ACCOUNT = 0x01 -> family = (0x0120 << 8) | 0x01 = 0x012001
      const family = 0x012001n;
      const value = (family << 232n) | (1n << 191n); // some filler
      expect(await utils.testIsFamily(value, 0x012001)).to.be.true;
    });

    it("max16/max32/max64/max128 accept boundary values", async () => {
      expect(await utils.testMax16((1n << 16n) - 1n)).to.equal((1n << 16n) - 1n);
      expect(await utils.testMax32((1n << 32n) - 1n)).to.equal((1n << 32n) - 1n);
      expect(await utils.testMax64((1n << 64n) - 1n)).to.equal((1n << 64n) - 1n);
      expect(await utils.testMax128((1n << 128n) - 1n)).to.equal((1n << 128n) - 1n);
    });

    it("clears and replaces shifted 32-bit fields", async () => {
      const value = (0xaan << 96n) | (0xffffffffn << 64n) | 0xbbn;

      expect(await utils.testClear32(value, 64)).to.equal((0xaan << 96n) | 0xbbn);
      expect(await utils.testReplace32(value, 64, 0x12345678)).to.equal(
        (0xaan << 96n) | (0x12345678n << 64n) | 0xbbn,
      );
      await expectCustomError(utils.testReplace32(value, 64, 1n << 32n), "ValueOverflow");
    });

    it("replaces checked 8-, 16-, and 64-bit fields", async () => {
      const value = (1n << 128n) - 1n;

      expect(await utils.testClear8(value, 8)).to.equal(value & ~(0xffn << 8n));
      expect(await utils.testClear16(value, 16)).to.equal(value & ~(0xffffn << 16n));
      expect(await utils.testClear64(value, 64)).to.equal(value & ~(((1n << 64n) - 1n) << 64n));
      expect(await utils.testReplace8(value, 8, 0x12)).to.equal((value & ~(0xffn << 8n)) | (0x12n << 8n));
      expect(await utils.testReplace16(value, 16, 0x1234)).to.equal(
        (value & ~(0xffffn << 16n)) | (0x1234n << 16n),
      );
      expect(await utils.testReplace64(value, 64, 0x123456789abcdef0n)).to.equal(
        (value & ~(((1n << 64n) - 1n) << 64n)) | (0x123456789abcdef0n << 64n),
      );
      await expectCustomError(utils.testReplace8(value, 8, 1n << 8n), "ValueOverflow");
      await expectCustomError(utils.testReplace16(value, 16, 1n << 16n), "ValueOverflow");
      await expectCustomError(utils.testReplace64(value, 64, 1n << 64n), "ValueOverflow");
    });
  });

  // ── Value ─────────────────────────────────────────────────────────────────

  describe("Value", () => {
    it("converts remaining native value into a transaction block", async () => {
      const account = encodeUserAccount("0x03");
      const nativeAsset = await utils.testToNativeAsset();
      const [transaction, remaining] = await utils.testValueTransaction.staticCall(100n, account);

      expect(transaction).to.equal(encodeTxBlock(ethers.ZeroHash, account, nativeAsset, 100n));
      expect(remaining).to.equal(0n);
      const receipt = await (await utils.testValueTransaction(100n, account)).wait();
      const receivedEvent = utils.interface.getEvent("Received")!;
      const receivedLog = receipt!.logs.find((log) => log.topics[0] === receivedEvent.topicHash)!;
      const received = utils.interface.decodeEventLog(receivedEvent, receivedLog.data, receivedLog.topics);
      expect([...received]).to.deep.equal([account, nativeAsset, 100n, 13n, 0n]);
    });

    it("returns empty bytes for an empty native-value budget", async () => {
      const account = encodeUserAccount("0x03");
      const [transaction, remaining] = await utils.testValueTransaction.staticCall(0n, account);

      expect(transaction).to.equal("0x");
      expect(remaining).to.equal(0n);
      const receipt = await (await utils.testValueTransaction(0n, account)).wait();
      const receivedTopic = utils.interface.getEvent("Received")!.topicHash;
      expect(receipt!.logs.some((log) => log.topics[0] === receivedTopic)).to.be.false;
    });

  });

  // ── Strings ───────────────────────────────────────────────────────────────

  describe("Strings", () => {
    it("bytes32ToString trims null bytes", async () => {
      const val = ethers.encodeBytes32String("hello");
      const result = await utils.testBytes32ToString(val);
      expect(result).to.equal("hello");
    });

    it("bytes32ToString handles all-zero bytes32", async () => {
      const result = await utils.testBytes32ToString(ethers.ZeroHash);
      expect(result).to.equal("");
    });

    it("bytes32ToString handles 32 non-null chars", async () => {
      const val = "0x" + "61".repeat(32); // 'a' * 32
      const result = await utils.testBytes32ToString(val);
      expect(result).to.equal("a".repeat(32));
    });
  });
});


