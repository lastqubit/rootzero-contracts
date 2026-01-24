// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {AccessEvent} from "./Events/Node/Access.sol";
import {Id} from "./Id.sol";
import {addrOr} from "./Utils.sol";

abstract contract AccessControl is AccessEvent {
    address internal immutable cmdr;
    uint internal immutable admin;
    uint internal immutable hostId;

    mapping(address => bool) internal authorized;

    error Unauthorized(address addr);

    constructor(address commander) {
        cmdr = addrOr(commander, address(this));
        admin = Id.account(cmdr);
        hostId = Id.host(address(this));
    }

    modifier onlyAdmin(uint account) {
        // CHECK ACCOUNT
        ensureTrusted(msg.sender);
        _;
    }

    modifier onlyAuthorized() {
        ensureAuthorized(msg.sender);
        _;
    }

    modifier onlyTrusted() {
        ensureTrusted(msg.sender);
        _;
    }

    function access(uint caller, bool allow) internal returns (address) {
        address addr = Id.hostAddr(caller, true);
        authorized[addr] = allow;
        emit Access(hostId, addr, allow);
        return addr;
    }

    function auth(address addr, bool allow) internal pure returns (address) {
        if (allow == false) {
            revert Unauthorized(addr);
        }
        return addr;
    }

    function isAuthorized(address addr) internal view returns (bool) {
        return addr != address(0) && authorized[addr];
    }

    function isTrusted(address addr) internal view virtual returns (bool) {
        if (addr == address(0)) return false;
        return addr == cmdr || addr == address(this) || authorized[addr];
    }

    function ensureAuthorized(address addr) internal view returns (address) {
        return auth(addr, isAuthorized(addr));
    }

    function ensureTrusted(address addr) internal view returns (address) {
        return auth(addr, isTrusted(addr));
    }
}

// @dev guardians are locally trusted addresses.

/* import {AccessEvent} from "./Events/Access.sol";
import {IGetTrusted} from "./Queries/GetTrusted.sol";

abstract contract AccessControl is AccessEvent {
    mapping(address => bool) public authorized; // pub??

    error Unauthorized(address addr);

    modifier onlySelf() {
        ensureSelf(msg.sender);
        _;
    }

    modifier onlyAuthorized() {
        ensureAuthorized(msg.sender);
        _;
    }

    modifier onlyTrusted() {
        ensureTrusted(msg.sender);
        _;
    }

    function access(address addr, bool allow) internal returns (address) {
        authorized[addr] = allow;
        emit Access(addr, allow);
        return addr;
    }

    function auth(address addr, bool allow) internal pure returns (address) {
        if (addr == address(0) || allow == false) {
            revert Unauthorized(addr);
        }
        return addr;
    }

    function isSelf(address addr) internal view returns (bool) {
        return addr == address(this);
    }

    function isAuthorized(address addr) internal view returns (bool) {
        return addr != address(0) && (addr == address(this) || authorized[addr]);
    }

    function isTrusted(address addr) internal view virtual returns (bool) {
        return isAuthorized(addr);
    }

    function ensureSelf(address addr) internal view returns (address) {
        return auth(addr, isSelf(addr));
    }

    function ensureAuthorized(address addr) internal view returns (address) {
        return auth(addr, isAuthorized(addr));
    }

    function ensureTrusted(address addr) internal view returns (address) {
        return auth(addr, isTrusted(addr));
    }
}

abstract contract ServiceAccess is AccessControl {
    address public immutable admin; // pub??
    address public immutable cmdr; // pub??

    modifier onlyAdmin() {
        ensureAdmin(msg.sender);
        _;
    }

    modifier onlyCommander() {
        ensureCommander(msg.sender);
        _;
    }

    function isTrusted(address addr) internal view override returns (bool) {
        if (addr == address(0)) return false;
        if (addr == address(this) || addr == admin || addr == cmdr) return true;
        return IGetTrusted(admin).getTrusted(addr) || authorized[addr];
    }

    function ensureAdmin(address addr) internal view returns (address) {
        return auth(addr, addr == admin);
    }

    function ensureCommander(address addr) internal view returns (address) {
        return auth(addr, addr == cmdr);
    }
}
 */
