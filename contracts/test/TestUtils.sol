// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {addrOr, toAdminAccount, toUserAccount, accountEvmAddr, isAdminAccount, ensureEvmAccount} from "../utils/Accounts.sol";
import {
    toValueAsset,
    toErc20Asset,
    toErc721Asset,
    isAsset32,
    resolveAmount,
    ensureAmount,
    ensureAssetRef,
    localErc20Addr,
    localErc721Issuer
} from "../utils/Assets.sol";
import {toHostId, toCommandId, toCommandSelector, isHost, isCommand, localNodeAddr, localHostAddr, ensureHost, ensureCommand} from "../utils/Ids.sol";
import {applyBps, beforeBps, isFamily, isLocal, isLocalFamily, matchesBase, toLocalBase, toUnspecifiedBase, max8, max16, max32, max64, max128, max160} from "../utils/Utils.sol";
import {msgValue, useValue, ValueBudget} from "../utils/Value.sol";
import {bytes32ToString} from "../utils/Strings.sol";

contract TestUtils {
    function testAddrOr(address addr, address or_) external pure returns (address) {
        return addrOr(addr, or_);
    }

    function testToAdminAccount(address addr) external view returns (bytes32) {
        return toAdminAccount(addr);
    }

    function testToUserAccount(address addr) external pure returns (bytes32) {
        return toUserAccount(addr);
    }

    function testAccountEvmAddr(bytes32 account) external pure returns (address) {
        return accountEvmAddr(account);
    }

    function testIsAdminAccount(bytes32 account) external pure returns (bool) {
        return isAdminAccount(account);
    }

    function testToValueAsset() external view returns (bytes32) {
        return toValueAsset();
    }

    function testToErc20Asset(address addr) external view returns (bytes32) {
        return toErc20Asset(addr);
    }

    function testToErc721Asset(address addr) external view returns (bytes32) {
        return toErc721Asset(addr);
    }

    function testIsAsset32(bytes32 asset) external pure returns (bool) {
        return isAsset32(asset);
    }

    function testResolveAmount(uint available, uint min, uint max) external pure returns (uint) {
        return resolveAmount(available, min, max);
    }

    function testEnsureAmount(uint amount) external pure returns (uint) {
        return ensureAmount(amount);
    }

    function testEnsureAmountRange(uint amount, uint min, uint max) external pure returns (uint) {
        return ensureAmount(amount, min, max);
    }

    function testEnsureAssetRef(bytes32 asset, bytes32 meta) external pure returns (bytes32) {
        return ensureAssetRef(asset, meta);
    }

    function testLocalErc20Addr(bytes32 asset) external view returns (address) {
        return localErc20Addr(asset);
    }

    function testLocalErc721Issuer(bytes32 asset) external view returns (address) {
        return localErc721Issuer(asset);
    }

    function testToHostId(address addr) external view returns (uint) {
        return toHostId(addr);
    }

    function testToCommandId(bytes32 name, address addr) external view returns (uint) {
        return toCommandId(toCommandSelector(name), addr);
    }

    function testToCommandSelector(bytes32 name) external pure returns (bytes4) {
        return toCommandSelector(name);
    }

    function testIsHost(uint id) external pure returns (bool) {
        return isHost(id);
    }

    function testIsCommand(uint id) external pure returns (bool) {
        return isCommand(id);
    }

    function testLocalNodeAddr(uint node) external view returns (address) {
        return localNodeAddr(node);
    }

    function testLocalHostAddr(uint host) external view returns (address) {
        return localHostAddr(host);
    }

    function testEnsureHost(uint id, address addr) external view returns (uint) {
        return ensureHost(id, addr);
    }

    function testEnsureCommand(uint id) external pure returns (uint) {
        return ensureCommand(id);
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
        ValueBudget memory budget = msgValue();
        return budget.remaining;
    }

    function testUseValue(uint amount, uint remaining) external pure returns (uint spent, uint remainingAfter) {
        ValueBudget memory budget = ValueBudget({remaining: remaining});
        spent = useValue(amount, budget);
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
