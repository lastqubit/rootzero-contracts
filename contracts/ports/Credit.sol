// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {PortBase} from "./Base.sol";
import {CreditHostHook, CreditAccountHook} from "../core/Settlement.sol";
import {Specs} from "../Codec.sol";
import {Execution, Executions} from "../execution/Execution.sol";

using Executions for Execution;

/// @title CreditPort
/// @notice Port that lets a trusted peer credit the host directly.
/// Each AMOUNT block calls `creditHost` for its asset.
abstract contract CreditPort is PortBase, CreditHostHook {
    uint private immutable descriptor;

    constructor() {
        (, descriptor) = port("portCredit", Specs.Amount, Specs.Empty, 0);
    }

    /// @notice Execute the host-level port-credit call.
    /// @param data AMOUNT block stream supplied by the trusted peer.
    /// @return Empty response bytes.
    function portCredit(bytes calldata data) external onlyPeer returns (bytes memory) {
        Execution memory exec = openInput(data, descriptor);

        while (exec.more()) {
            (bytes32 asset, uint amount) = exec.unpackAmount();
            creditHost(asset, amount);
        }

        return "";
    }
}

/// @title CreditAccountPort
/// @notice Port that lets a trusted peer credit supplied accounts directly.
/// Each ACCOUNT_AMOUNT block calls `creditAccount` for its account.
abstract contract CreditAccountPort is PortBase, CreditAccountHook {
    uint private immutable descriptor;

    constructor() {
        (, descriptor) = port("portCreditAccount", Specs.AccountAmount, Specs.Empty, 0);
    }

    /// @notice Execute the port-credit call.
    /// @param data ACCOUNT_AMOUNT block stream supplied by the trusted peer.
    /// @return Empty response bytes.
    function portCreditAccount(bytes calldata data) external onlyPeer returns (bytes memory) {
        Execution memory exec = openInput(data, descriptor);

        while (exec.more()) {
            (bytes32 account, bytes32 asset, uint amount) = exec.unpackAccountAmount();
            creditAccount(account, asset, amount);
        }
        
        return "";
    }
}
