import { expect } from "chai";
import { ethers } from "ethers";
import { deploy, getSigner, getProvider } from "./helpers/setup.js";
import { commandSelector, guardSelector, peerSelector } from "./helpers/blocks.js";

async function expectCustomError(promise: Promise<unknown>, name: string) {
  try {
    await promise;
    expect.fail(`Expected ${name} revert`);
  } catch (e) {
    const err = e as { revert?: { name?: string } };
    expect(err.revert?.name).to.equal(name);
  }
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

    it("toGuardianAccount encodes guardian prefix, chainId and address", async () => {
      const result: string = await utils.testToGuardianAccount(signerAddress);
      const val = BigInt(result);
      const prefix = (val >> 224n) & 0xffffffffn;
      expect(prefix).to.equal(0x01200102n);

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

    it("isGuardianAccount returns true for guardian account", async () => {
      const guardianAccount = await utils.testToGuardianAccount(signerAddress);
      expect(await utils.testIsGuardianAccount(guardianAccount)).to.be.true;
    });

    it("isGuardianAccount returns false for admin and user accounts", async () => {
      expect(await utils.testIsGuardianAccount(await utils.testToAdminAccount(signerAddress))).to.be.false;
      expect(await utils.testIsGuardianAccount(await utils.testToUserAccount(signerAddress))).to.be.false;
    });

    it("isUserAccount returns true for user account", async () => {
      const userAccount = await utils.testToUserAccount(signerAddress);
      expect(await utils.testIsUserAccount(userAccount)).to.be.true;
    });

    it("isUserAccount returns false for admin and guardian accounts", async () => {
      expect(await utils.testIsUserAccount(await utils.testToAdminAccount(signerAddress))).to.be.false;
      expect(await utils.testIsUserAccount(await utils.testToGuardianAccount(signerAddress))).to.be.false;
    });

    it("isAccount returns true for supported account IDs", async () => {
      expect(await utils.testIsAccount(await utils.testToAdminAccount(signerAddress))).to.be.true;
      expect(await utils.testIsAccount(await utils.testToGuardianAccount(signerAddress))).to.be.true;
      expect(await utils.testIsAccount(await utils.testToUserAccount(signerAddress))).to.be.true;
    });

    it("isAccount returns false for non-account category values", async () => {
      expect(await utils.testIsAccount(await utils.testToNativeAsset())).to.be.false;
      expect(await utils.testIsAccount(ethers.ZeroHash)).to.be.false;
    });

    it("typed account helpers return matching accounts", async () => {
      const adminAccount = await utils.testToAdminAccount(signerAddress);
      const guardianAccount = await utils.testToGuardianAccount(signerAddress);
      const userAccount = await utils.testToUserAccount(signerAddress);

      expect(await utils.testEnsureAccount(adminAccount)).to.equal(adminAccount);
      expect(await utils.testEnsureAccount(guardianAccount)).to.equal(guardianAccount);
      expect(await utils.testEnsureAccount(userAccount)).to.equal(userAccount);
      expect(await utils.testAdminAccount(adminAccount)).to.equal(adminAccount);
      expect(await utils.testGuardianAccount(guardianAccount)).to.equal(guardianAccount);
      expect(await utils.testUserAccount(userAccount)).to.equal(userAccount);
    });

    it("typed account helpers reject mismatched accounts", async () => {
      const adminAccount = await utils.testToAdminAccount(signerAddress);
      const guardianAccount = await utils.testToGuardianAccount(signerAddress);
      const userAccount = await utils.testToUserAccount(signerAddress);

      await expectCustomError(utils.testAdminAccount(userAccount), "InvalidAccount");
      await expectCustomError(utils.testGuardianAccount(adminAccount), "InvalidAccount");
      await expectCustomError(utils.testUserAccount(guardianAccount), "InvalidAccount");
      await expectCustomError(utils.testEnsureAccount(await utils.testToNativeAsset()), "InvalidAccount");
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

    it("isAsset returns true for supported asset IDs", async () => {
      expect(await utils.testIsAsset(await utils.testToNativeAsset())).to.be.true;
      expect(await utils.testIsAsset(await utils.testToErc20Asset(signerAddress))).to.be.true;
    });

    it("isAsset returns false for non-asset category values", async () => {
      expect(await utils.testIsAsset(await utils.testToUserAccount(signerAddress))).to.be.false;
      expect(await utils.testIsAsset(ethers.ZeroHash)).to.be.false;
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

  // ── Ids ───────────────────────────────────────────────────────────────────

  describe("Ids", () => {
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

    it("localNodeAddr rejects chain node IDs", async () => {
      const chainNode: bigint = await utils.testLocalChainId();
      await expectCustomError(utils.testLocalNodeAddr(chainNode), "ZeroAddress");
    });

    it("toHostId creates host ID from address", async () => {
      const id: bigint = await utils.testToHostId(signerAddress);
      expect(id).to.be.gt(0n);
      expect(await utils.testIsHost(id)).to.be.true;
    });

    it("isHost returns false for command ID", async () => {
      const name = ethers.encodeBytes32String("deposit");
      const cid: bigint = await utils.testToCommandId(name, signerAddress);
      expect(await utils.testIsHost(cid)).to.be.false;
    });

    it("isCommand returns true for command ID", async () => {
      const name = ethers.encodeBytes32String("deposit");
      const cid: bigint = await utils.testToCommandId(name, signerAddress);
      expect(await utils.testIsCommand(cid)).to.be.true;
    });

    it("isCommand returns false for host ID", async () => {
      const hid: bigint = await utils.testToHostId(signerAddress);
      expect(await utils.testIsCommand(hid)).to.be.false;
    });

    it("isPeer returns true for peer ID", async () => {
      const name = ethers.encodeBytes32String("peerAllowance");
      const pid: bigint = await utils.testToPeerId(name, signerAddress);
      expect(await utils.testIsPeer(pid)).to.be.true;
    });

    it("isGuard returns true for guard ID", async () => {
      const name = ethers.encodeBytes32String("revoke");
      const gid: bigint = await utils.testToGuardId(name, signerAddress);
      expect(await utils.testIsGuard(gid)).to.be.true;
    });

    it("isPeer returns false for host ID", async () => {
      const hid: bigint = await utils.testToHostId(signerAddress);
      expect(await utils.testIsPeer(hid)).to.be.false;
    });

    it("isGuard returns false for host ID", async () => {
      const hid: bigint = await utils.testToHostId(signerAddress);
      expect(await utils.testIsGuard(hid)).to.be.false;
    });

    it("localNodeAddr extracts address from host ID", async () => {
      const id: bigint = await utils.testToHostId(signerAddress);
      const addr = await utils.testLocalNodeAddr(id);
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

    it("ensureCommand reverts InvalidId for host ID", async () => {
      const hid: bigint = await utils.testToHostId(signerAddress);
      await expectCustomError(utils.testEnsureCommand(hid), "InvalidId");
    });

    it("ensureCommand succeeds for command ID", async () => {
      const name = ethers.encodeBytes32String("deposit");
      const cid: bigint = await utils.testToCommandId(name, signerAddress);
      const result: bigint = await utils.testEnsureCommand(cid);
      expect(result).to.equal(cid);
    });

    it("ensurePeer succeeds for peer ID", async () => {
      const name = ethers.encodeBytes32String("peerAllowance");
      const pid: bigint = await utils.testToPeerId(name, signerAddress);
      const result: bigint = await utils.testEnsurePeer(pid);
      expect(result).to.equal(pid);
    });

    it("ensureGuard succeeds for guard ID", async () => {
      const name = ethers.encodeBytes32String("revoke");
      const gid: bigint = await utils.testToGuardId(name, signerAddress);
      const result: bigint = await utils.testEnsureGuard(gid);
      expect(result).to.equal(gid);
    });

    it("toCommandSelector matches the TypeScript helper", async () => {
      const name = ethers.encodeBytes32String("deposit");
      expect(await utils.testToCommandSelector(name)).to.equal(commandSelector("deposit"));
    });

    it("toPeerSelector matches the TypeScript helper", async () => {
      const name = ethers.encodeBytes32String("peerAllowance");
      expect(await utils.testToPeerSelector(name)).to.equal(peerSelector("peerAllowance"));
    });

    it("toGuardSelector matches the TypeScript helper", async () => {
      const name = ethers.encodeBytes32String("revoke");
      expect(await utils.testToGuardSelector(name)).to.equal(guardSelector("revoke"));
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

    it("isLocalChain returns true for current chainId", async () => {
      const base = await utils.testToLocalBase(0x12345678);
      expect(await utils.testIsLocalChain(base)).to.be.true;
    });

    it("isLocalChain returns false for a foreign-chain value", async () => {
      const foreign = (0x12345678n << 224n) | (999n << 192n);
      expect(await utils.testIsLocalChain(foreign)).to.be.false;
    });

    it("max16/max32/max64/max128 accept boundary values", async () => {
      expect(await utils.testMax16((1n << 16n) - 1n)).to.equal((1n << 16n) - 1n);
      expect(await utils.testMax32((1n << 32n) - 1n)).to.equal((1n << 32n) - 1n);
      expect(await utils.testMax64((1n << 64n) - 1n)).to.equal((1n << 64n) - 1n);
      expect(await utils.testMax128((1n << 128n) - 1n)).to.equal((1n << 128n) - 1n);
    });
  });

  // ── Value ─────────────────────────────────────────────────────────────────

  describe("Value", () => {
    it("msgValue captures msg.value", async () => {
      const result = await utils.testMsgValue.staticCall({ value: 42n });
      expect(result).to.equal(42n);
    });

    it("useValue deducts amount from budget", async () => {
      const [spent, remaining] = await utils.testUseValue(30n, 100n);
      expect(spent).to.equal(30n);
      expect(remaining).to.equal(70n);
    });

    it("useValue reverts InsufficientValue when amount exceeds remaining", async () => {
      await expectCustomError(utils.testUseValue(101n, 100n), "InsufficientValue");
    });

    it("allocate deducts amount from parent and returns a child budget", async () => {
      const [subRemaining, parentRemaining] = await utils.testAllocate(30n, 100n);
      expect(subRemaining).to.equal(30n);
      expect(parentRemaining).to.equal(70n);
    });

    it("allocate reverts InsufficientValue when amount exceeds remaining", async () => {
      await expectCustomError(utils.testAllocate(101n, 100n), "InsufficientValue");
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


