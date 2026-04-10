// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { AssetAmount, Cursors, Cur, Writers, Writer } from "../Cursors.sol";

using Cursors for Cur;
using Writers for Writer;

abstract contract AmountToBalance {
    function amountToBalance(bytes32 account, AssetAmount memory amount) internal virtual returns (AssetAmount memory);

    function amountsToBalances(bytes calldata blocks, uint i, bytes32 account) internal returns (bytes memory) {
        Cur memory scan = Cursors.open(blocks[i:]);
        (, uint count) = scan.primeRun(1);
        Writer memory writer = Writers.allocBalances(count);

        while (scan.i < scan.bound) {
            AssetAmount memory amount = scan.unpackAmountValue();
            AssetAmount memory out = amountToBalance(account, amount);
            writer.appendNonZeroBalance(out);
        }

        return writer.finish();
    }
}





