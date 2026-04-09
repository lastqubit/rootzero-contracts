// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { AssetAmount, Cursors, Cur, Writers, Writer } from "../Cursors.sol";

using Cursors for Cur;
using Writers for Writer;

abstract contract MapBalance {
    function mapBalance(bytes32 account, AssetAmount memory balance) internal virtual returns (AssetAmount memory out);

    function mapBalances(bytes calldata state, uint i, bytes32 account) internal returns (bytes memory) {
        (Cur memory scan, , uint count) = Cursors.init(state[i:], 1);
        Writer memory writer = Writers.allocBalances(count);

        while (scan.i < scan.bound) {
            AssetAmount memory balance = scan.unpackBalanceValue();
            AssetAmount memory out = mapBalance(account, balance);
            writer.appendNonZeroBalance(out);
        }

        return writer.finish();
    }
}





