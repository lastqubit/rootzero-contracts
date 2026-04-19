// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { Accounts } from "../utils/Accounts.sol";
import { Amounts, Assets } from "../utils/Assets.sol";
import { Ids, Selectors } from "../utils/Ids.sol";
import { addrOr, applyBps, beforeBps, bytes32ToString, isFamily, isLocal, isLocalFamily, matchesBase, toLocalBase, toUnspecifiedBase, max8, max16, max32, max64, max128, max160 } from "../utils/Utils.sol";
import { Budget, Values } from "../utils/Value.sol";

contract TestUtils {
    function testAddrOr(address addr, address or_) external pure returns (address) {
        return addrOr(addr, or_);
    }

    function testToAdminAccount(address addr) external view returns (bytes32) {
        return Accounts.toAdmin(addr);
    }

    function testToUserAccount(address addr) external pure returns (bytes32) {
        return Accounts.toUser(addr);
    }

    function testAccountEvmAddr(bytes32 account) external pure returns (address) {
        return Accounts.addrEvm(account);
    }

    function testIsAdminAccount(bytes32 account) external pure returns (bool) {
        return Accounts.isAdmin(account);
    }

    function testIsKeccakAccount(bytes32 account) external pure returns (bool) {
        return Accounts.isKeccak(account);
    }

    function testToKeccakAccount(bytes calldata raw) external pure returns (bytes32) {
        return Accounts.toKeccak(raw);
    }

    function testMatchesKeccakAccount(bytes32 account, bytes calldata raw) external pure returns (bool) {
        return Accounts.matchesKeccak(account, raw);
    }

    function testToValueAsset() external view returns (bytes32) {
        return Assets.toValue();
    }

    function testToErc20Asset(address addr) external view returns (bytes32) {
        return Assets.toErc20(addr);
    }

    function testToErc721Asset(address addr) external view returns (bytes32) {
        return Assets.toErc721(addr);
    }

    function testToErc1155Asset(address addr) external view returns (bytes32) {
        return Assets.toErc1155(addr);
    }

    function testIsAsset32(bytes32 asset) external pure returns (bool) {
        return Assets.is32(asset);
    }

    function testIsAsset64(bytes32 asset) external pure returns (bool) {
        return Assets.is64(asset);
    }

    function testResolveAmount(uint available, uint min, uint max) external pure returns (uint) {
        return Amounts.resolve(available, min, max);
    }

    function testEnsureAmount(uint amount) external pure returns (uint) {
        return Amounts.ensure(amount);
    }

    function testEnsureAmountRange(uint amount, uint min, uint max) external pure returns (uint) {
        return Amounts.ensure(amount, min, max);
    }

    function testAssetKey(bytes32 asset, bytes32 meta) external pure returns (bytes32) {
        return Assets.key(asset, meta);
    }

    function testIsSortedErc20Assets(bytes32 a, bytes32 b) external view returns (bool ordered) {
        return Assets.isSortedErc20(a, b);
    }

    function testErc20Addrs(bytes32 a, bytes32 b) external view returns (address addrA, address addrB, bool ordered) {
        return Assets.erc20Addrs(a, b);
    }

    function testLocalErc20Addr(bytes32 asset) external view returns (address) {
        return Assets.erc20Addr(asset);
    }

    function testMatchErc20(bytes32 asset, address token) external view returns (bytes32) {
        return Assets.matchErc20(asset, token);
    }

    function testLocalErc721Collection(bytes32 asset) external view returns (address) {
        return Assets.erc721Collection(asset);
    }

    function testMatchErc721(bytes32 asset, address collection) external view returns (bytes32) {
        return Assets.matchErc721(asset, collection);
    }

    function testLocalErc1155Collection(bytes32 asset) external view returns (address) {
        return Assets.erc1155Collection(asset);
    }

    function testMatchErc1155(bytes32 asset, address collection) external view returns (bytes32) {
        return Assets.matchErc1155(asset, collection);
    }

    function testToHostId(address addr) external view returns (uint) {
        return Ids.toHost(addr);
    }

    function testToCommandId(bytes32 name, address addr) external view returns (uint) {
        return Ids.toCommand(Selectors.command(bytes32ToString(name)), addr);
    }

    function testToCommandSelector(bytes32 name) external pure returns (bytes4) {
        return Selectors.command(bytes32ToString(name));
    }

    function testIsHost(uint id) external pure returns (bool) {
        return Ids.isHost(id);
    }

    function testIsCommand(uint id) external pure returns (bool) {
        return Ids.isCommand(id);
    }

    function testLocalNodeAddr(uint node) external view returns (address) {
        return Ids.nodeAddr(node);
    }

    function testLocalHostAddr(uint host) external view returns (address) {
        return Ids.hostAddr(host);
    }

    function testEnsureHost(uint id, address addr) external view returns (uint) {
        return Ids.matchHost(id, addr);
    }

    function testEnsureCommand(uint id) external pure returns (uint) {
        return Ids.command(id);
    }

    function testApplyBps(uint amount, uint16 bps) external pure returns (uint) {
        return applyBps(amount, bps);
    }

    function testBeforeBps(uint amount, uint16 bps) external pure returns (uint) {
        return beforeBps(amount, bps);
    }

    function testIsFamily(uint value, uint24 family) external pure returns (bool) {
        return isFamily(value, family);
    }

    function testIsLocal(uint value) external view returns (bool) {
        return isLocal(value);
    }

    function testMatchesBase(bytes32 value, uint base) external pure returns (bool) {
        return matchesBase(value, base);
    }

    function testToLocalBase(uint32 prefix) external view returns (uint) {
        return toLocalBase(prefix);
    }

    function testMsgValue() external payable returns (uint) {
        Budget memory budget = Values.fromMsg();
        return budget.remaining;
    }

    function testUseValue(uint amount, uint remaining) external pure returns (uint spent, uint remainingAfter) {
        Budget memory budget = Budget({remaining: remaining});
        spent = Values.use(budget, amount);
        remainingAfter = budget.remaining;
    }

    function testBytes32ToString(bytes32 value) external pure returns (string memory) {
        return bytes32ToString(value);
    }

    function testMax8(uint value) external pure returns (uint) {
        return max8(value);
    }

    function testMax16(uint value) external pure returns (uint) {
        return max16(value);
    }

    function testMax32(uint value) external pure returns (uint) {
        return max32(value);
    }

    function testMax64(uint value) external pure returns (uint) {
        return max64(value);
    }

    function testMax128(uint value) external pure returns (uint) {
        return max128(value);
    }

    function testMax160(uint value) external pure returns (uint) {
        return max160(value);
    }
}



