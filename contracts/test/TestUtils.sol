// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { Accounts } from "../utils/Accounts.sol";
import { Amounts, Assets } from "../utils/Assets.sol";
import { Ids } from "../utils/Ids.sol";
import { Nodes } from "../utils/Nodes.sol";
import { Selectors } from "../utils/Selectors.sol";
import { addrOr, applyBps, beforeBps, bytes32ToString, isFamily, matchesBase, toLocalBase, toUnspecifiedBase, max8, max16, max32, max64, max128, max160 } from "../utils/Utils.sol";
import { CommandBase } from "../commands/Base.sol";
import { AccessControl } from "../core/Access.sol";
import { Execution } from "../execution/Execution.sol";

contract TestUtils is CommandBase {
    constructor() AccessControl(address(0)) {}

    function testAddrOr(address addr, address or_) external pure returns (address) {
        return addrOr(addr, or_);
    }

    function testIsOpaqueId(bytes32 id) external pure returns (bool) {
        return Ids.isOpaque(id);
    }

    function testOpaqueId(bytes32 id) external pure returns (bytes32) {
        return Ids.opaque(id);
    }

    function testToKeccak(bytes memory preimage) external pure returns (bytes32) {
        return Ids.toKeccak(preimage);
    }

    function testMatchKeccak(bytes32 id, bytes memory preimage) external pure returns (bytes32) {
        return Ids.matchKeccak(id, preimage);
    }

    function testCommandSelector(string memory name) external pure returns (bytes4) {
        return Selectors.command(name);
    }

    function testPortSelector(string memory name) external pure returns (bytes4) {
        return Selectors.port(name);
    }

    function testQuerySelector(string memory name) external pure returns (bytes4) {
        return Selectors.query(name);
    }

    function testGuardSelector(string memory name) external pure returns (bytes4) {
        return Selectors.guard(name);
    }

    function testToAdminAccount(address addr) external view returns (bytes32) {
        return Accounts.toAdmin(addr);
    }

    function testToGuardianAccount(address addr) external view returns (bytes32) {
        return Accounts.toGuardian(addr);
    }

    function testToUserAccount(address addr) external pure returns (bytes32) {
        return Accounts.toUser(addr);
    }

    function testAccountAddr(bytes32 account) external pure returns (address) {
        return Accounts.addr(account);
    }

    function testIsAdminAccount(bytes32 account) external pure returns (bool) {
        return Accounts.isAdmin(account);
    }

    function testIsGuardianAccount(bytes32 account) external pure returns (bool) {
        return Accounts.isGuardian(account);
    }

    function testIsUserAccount(bytes32 account) external pure returns (bool) {
        return Accounts.isUser(account);
    }

    function testAdminAccount(bytes32 account) external pure returns (bytes32) {
        return Accounts.admin(account);
    }

    function testGuardianAccount(bytes32 account) external pure returns (bytes32) {
        return Accounts.guardian(account);
    }

    function testUserAccount(bytes32 account) external pure returns (bytes32) {
        return Accounts.user(account);
    }

    function testIsEvmAccount(bytes32 account) external pure returns (bool) {
        return Accounts.isEvm(account);
    }

    function testIsOpaqueAccount(bytes32 account) external pure returns (bool) {
        return Accounts.isOpaque(account);
    }

    function testEvmAccount(bytes32 account) external pure returns (bytes32) {
        return Accounts.evm(account);
    }

    function testOpaqueAccount(bytes32 account) external pure returns (bytes32) {
        return Accounts.opaque(account);
    }

    function testToKeccakAccount(bytes memory preimage) external pure returns (bytes32) {
        return Accounts.toKeccak(preimage);
    }

    function testMatchKeccakAccount(bytes32 account, bytes memory preimage) external pure returns (bytes32) {
        return Accounts.matchKeccak(account, preimage);
    }

    function testToNativeAsset() external view returns (bytes32) {
        return Assets.toNative();
    }

    function testToErc20Asset(address addr) external view returns (bytes32) {
        return Assets.toErc20(addr);
    }

    function testIsEvmAsset(bytes32 asset) external pure returns (bool) {
        return Assets.isEvm(asset);
    }

    function testIsOpaqueAsset(bytes32 asset) external pure returns (bool) {
        return Assets.isOpaque(asset);
    }

    function testEvmAsset(bytes32 asset) external pure returns (bytes32) {
        return Assets.evm(asset);
    }

    function testOpaqueAsset(bytes32 asset) external pure returns (bytes32) {
        return Assets.opaque(asset);
    }

    function testToKeccakAsset(bytes memory preimage) external pure returns (bytes32) {
        return Assets.toKeccak(preimage);
    }

    function testMatchKeccakAsset(bytes32 asset, bytes memory preimage) external pure returns (bytes32) {
        return Assets.matchKeccak(asset, preimage);
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

    function testLocalErc20Addr(bytes32 asset) external view returns (address) {
        return Assets.erc20Addr(asset);
    }

    function testMatchErc20(bytes32 asset, address token) external view returns (bytes32) {
        return Assets.matchErc20(asset, token);
    }

    function testToHostId(address addr) external view returns (uint) {
        return Nodes.toHost(addr);
    }

    function testLocalChainId() external view returns (uint) {
        return Nodes.localChain();
    }

    function testToCommandId(bytes4 selector, address addr) external view returns (uint) {
        return Nodes.toCommand(selector, addr);
    }

    function testToPortId(bytes4 selector, address addr) external view returns (uint) {
        return Nodes.toPort(selector, addr);
    }

    function testToGuardId(bytes4 selector, address addr) external view returns (uint) {
        return Nodes.toGuard(selector, addr);
    }

    function testIsHost(uint node) external pure returns (bool) {
        return Nodes.isHost(node);
    }

    function testIsCommand(uint node) external pure returns (bool) {
        return Nodes.isCommand(node);
    }

    function testIsPort(uint node) external pure returns (bool) {
        return Nodes.isPort(node);
    }

    function testIsGuard(uint node) external pure returns (bool) {
        return Nodes.isGuard(node);
    }

    function testIsEvmNode(uint node) external pure returns (bool) {
        return Nodes.isEvm(node);
    }

    function testIsOpaqueNode(uint node) external pure returns (bool) {
        return Nodes.isOpaque(node);
    }

    function testIsLocalNode(uint node) external view returns (bool) {
        return Nodes.isLocal(node);
    }

    function testHostNode(uint value) external pure returns (uint) {
        return Nodes.host(value);
    }

    function testCommandNode(uint value) external pure returns (uint) {
        return Nodes.command(value);
    }

    function testPortNode(uint value) external pure returns (uint) {
        return Nodes.port(value);
    }

    function testGuardNode(uint value) external pure returns (uint) {
        return Nodes.guard(value);
    }

    function testEvmNode(uint value) external pure returns (uint) {
        return Nodes.evm(value);
    }

    function testOpaqueNode(uint value) external pure returns (uint) {
        return Nodes.opaque(value);
    }

    function testToKeccakNode(bytes memory preimage) external pure returns (uint) {
        return Nodes.toKeccak(preimage);
    }

    function testMatchKeccakNode(uint node, bytes memory preimage) external pure returns (uint) {
        return Nodes.matchKeccak(node, preimage);
    }

    function testLocalNode(uint value) external view returns (uint) {
        return Nodes.local(value);
    }

    function testAddr(uint node) external view returns (address) {
        return Nodes.addr(node);
    }

    function testLocalHostAddr(uint host) external view returns (address) {
        return Nodes.hostAddr(host);
    }

    function testEnsureHost(uint value, address target) external view returns (uint) {
        return Nodes.matchHost(value, target);
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

    function testMatchesBase(bytes32 value, uint base) external pure returns (bool) {
        return matchesBase(value, base);
    }

    function testToLocalBase(uint32 prefix) external view returns (uint) {
        return toLocalBase(prefix);
    }

    function testValueTransaction(
        uint remaining,
        bytes32 account
    ) external returns (bytes memory transaction, uint remainingAfter) {
        Execution memory exec;
        exec.budget = remaining;
        transaction = endValue(exec, account);
        remainingAfter = exec.budget;
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



