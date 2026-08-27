// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { Accounts } from "../utils/Accounts.sol";
import { Assets } from "../utils/Assets.sol";
import {InvalidAsset} from "../utils/Errors.sol";
import { GetBalances } from "../queries/Balances.sol";

contract TestErc20BalanceToken {
    mapping(address => uint) internal balances;

    function mint(address account, uint amount) external {
        balances[account] += amount;
    }

    function balanceOf(address account) external view returns (uint) {
        return balances[account];
    }
}

contract TestBalancesQuery is GetBalances {
    TestErc20BalanceToken public immutable token = new TestErc20BalanceToken();
    bytes32 public immutable tokenAsset = Assets.toErc20(address(token));

    function mint(address account, uint amount) external {
        token.mint(account, amount);
    }

    function nativeAssetId() external view returns (bytes32) {
        return nativeAsset;
    }

    function getBalance(bytes32 account, bytes32 asset) internal view override returns (uint amount) {
        address accountAddr = Accounts.addr(account);
        if (asset == nativeAsset) return accountAddr.balance;
        if (asset == tokenAsset) return token.balanceOf(accountAddr);
        revert InvalidAsset();
    }
}
