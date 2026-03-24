# Uniswap Wrapper

This guide explains how to wire Rush Protocol's swap and liquidity commands to Uniswap V3. Rush provides the command dispatch layer; your host implements the hooks that call Uniswap.

## How it works

```
Rush runtime
  └─ calls command (e.g. swapExactCustodyToBalance)
       └─ command iterates state blocks, calls your hook once per block
            └─ your hook decodes route params, calls Uniswap, returns result
```

Your host never implements the loop or the block encoding — only the inner hook.

---

## Imports

```solidity
import {Host} from "../contracts/Core.sol";
import {
    SwapExactBalanceToBalance,
    SwapExactCustodyToBalance,
    AddLiquidityFromBalancesToBalances,
    AddLiquidityFromCustodiesToBalances,
    RemoveLiquidityFromBalanceToBalances,
    RemoveLiquidityFromCustodyToBalances
} from "../contracts/Commands.sol";
import {Data, DataRef, DataPairRef, AssetAmount, HostAmount, Writers, Writer} from "../contracts/Blocks.sol";
import {Assets} from "../contracts/Utils.sol";

using Data for DataRef;
using Writers for Writer;
```

---

## Uniswap V3 interfaces

Declare only what you need — no library dependency required.

```solidity
interface ISwapRouter {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint deadline;
        uint amountIn;
        uint amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }
    function exactInputSingle(ExactInputSingleParams calldata params)
        external returns (uint amountOut);
}

interface IERC20 {
    function approve(address spender, uint amount) external returns (bool);
}

interface INonfungiblePositionManager {
    struct MintParams {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint amount0Desired;
        uint amount1Desired;
        uint amount0Min;
        uint amount1Min;
        address recipient;
        uint deadline;
    }
    struct DecreaseLiquidityParams {
        uint tokenId;
        uint128 liquidity;
        uint amount0Min;
        uint amount1Min;
        uint deadline;
    }
    struct CollectParams {
        uint tokenId;
        address recipient;
        uint128 amount0Max;
        uint128 amount1Max;
    }

    function mint(MintParams calldata params)
        external returns (uint tokenId, uint128 liquidity, uint amount0, uint amount1);
    function positions(uint tokenId) external view returns (
        uint96 nonce,
        address operator,
        address token0,
        address token1,
        uint24 fee,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity,
        uint feeGrowthInside0LastX128,
        uint feeGrowthInside1LastX128,
        uint tokensOwed0,
        uint tokensOwed1
    );
    function decreaseLiquidity(DecreaseLiquidityParams calldata params)
        external returns (uint amount0, uint amount1);
    function collect(CollectParams calldata params)
        external returns (uint amount0, uint amount1);
}
```

---

## Swap commands

### `SwapExactBalanceToBalance`

Triggered when the incoming pipeline state contains `balance(...)` blocks. Called once per balance.

**Hook signature** (from [contracts/commands/Swap.sol](../contracts/commands/Swap.sol)):

```solidity
function swapExactBalanceToBalance(
    bytes32 account,
    AssetAmount memory balance,
    DataRef memory rawRoute
) internal virtual returns (AssetAmount memory out);
```

| Parameter        | Type      | Description                                                                         |
| ---------------- | --------- | ----------------------------------------------------------------------------------- |
| `account`        | `bytes32` | The Rush account ID making the swap                                                 |
| `balance.asset`  | `bytes32` | Rush asset ID of the input token                                                    |
| `balance.meta`   | `bytes32` | Optional metadata (pool fee tier, etc.)                                             |
| `balance.amount` | `uint`    | Input token amount                                                                  |
| `rawRoute`       | `DataRef` | Route block from the request; call `rawRoute.innerMinimum()` to get slippage params |

**Return:** `AssetAmount` of the output token. Return `amount = 0` to skip writing an output block.

**Route extraction:**

```solidity
(bytes32 assetOut, bytes32 meta, uint minOut) = rawRoute.innerMinimum();
// assetOut — Rush asset ID of the output token
// minOut   — minimum output amount (slippage floor)
```

**Constructor:**

```solidity
SwapExactBalanceToBalance(string memory maybeRoute)
// maybeRoute: extra route schema fields appended to route(...); pass "" for none
```

---

### `SwapExactCustodyToBalance`

Same as above but the input is a `custody(...)` block (escrowed asset) rather than a balance.

**Hook signature** (from [contracts/commands/Swap.sol](../contracts/commands/Swap.sol)):

```solidity
function swapExactCustodyToBalance(
    bytes32 account,
    HostAmount memory custody,
    DataRef memory rawRoute
) internal virtual returns (AssetAmount memory out);
```

| Parameter        | Type      | Description                                 |
| ---------------- | --------- | ------------------------------------------- |
| `account`        | `bytes32` | The Rush account ID                         |
| `custody.host`   | `uint`    | Rush host ID that holds the escrowed asset  |
| `custody.asset`  | `bytes32` | Rush asset ID of the input token            |
| `custody.meta`   | `bytes32` | Optional metadata                           |
| `custody.amount` | `uint`    | Escrowed amount to swap                     |
| `rawRoute`       | `DataRef` | Route block; call `rawRoute.innerMinimum()` |

**Constructor:**

```solidity
SwapExactCustodyToBalance(string memory maybeRoute)
```

---

## Liquidity commands

Liquidity hooks receive a `Writer memory out` parameter and call `out.appendBalance(...)` directly for each output block. The command calls `writer.finish()` after your hook returns — do not call it yourself.

The `scaledRatio` constructor argument controls how many output blocks are pre-allocated per input block, scaled by `10_000`. For example:

- `10_000` = 1 output per input (1:1)
- `20_000` = 2 outputs per input
- `30_000` = 3 outputs per input (two refunds + LP receipt)

### `AddLiquidityFromCustodiesToBalances`

Triggered when the state contains pairs of `custody(...)` blocks. Called once per pair.

**Hook signature** (from [contracts/commands/Liquidity.sol](../contracts/commands/Liquidity.sol)):

```solidity
function addLiquidityFromCustodiesToBalances(
    bytes32 account,
    DataPairRef memory rawCustodies,
    DataRef memory rawRoute,
    Writer memory out
) internal virtual;
```

| Parameter        | Type      | Description                                                                      |
| ---------------- | --------- | -------------------------------------------------------------------------------- |
| `account`        | `bytes32` | The Rush account ID                                                              |
| `rawCustodies.a` | `DataRef` | First custody block (token0)                                                     |
| `rawCustodies.b` | `DataRef` | Second custody block (token1)                                                    |
| `rawRoute`       | `DataRef` | Route block; call `rawRoute.innerQuantity()` for the minimum liquidity threshold |
| `out`            | `Writer`  | Output writer; call `out.appendBalance(...)` up to 3 times                       |

**Extracting custody values:**

```solidity
AssetAmount memory c0 = rawCustodies.a.expectCustody(host);
AssetAmount memory c1 = rawCustodies.b.expectCustody(host);
// c0.asset, c0.amount — token0 details
// c1.asset, c1.amount — token1 details
```

**Output:** Append up to three balance blocks — token0 refund, token1 refund, LP receipt:

```solidity
out.appendBalance(AssetAmount(lpTokenAsset, 0, lpAmount));
out.appendBalance(AssetAmount(c0.asset, 0, refund0));   // if non-zero
out.appendBalance(AssetAmount(c1.asset, 0, refund1));   // if non-zero
```

**Constructor:**

```solidity
AddLiquidityFromCustodiesToBalances(string memory maybeRoute, uint scaledRatio)
// scaledRatio: use 30_000 if you may emit up to 3 balance blocks per custody pair
```

---

### `AddLiquidityFromBalancesToBalances`

Same as the custody variant, but inputs are `balance(...)` blocks.

**Hook signature** (from [contracts/commands/Liquidity.sol](../contracts/commands/Liquidity.sol)):

```solidity
function addLiquidityFromBalancesToBalances(
    bytes32 account,
    DataPairRef memory rawBalances,
    DataRef memory rawRoute,
    Writer memory out
) internal virtual;
```

**Extracting balance values:**

```solidity
AssetAmount memory b0 = rawBalances.a.toBalanceValue();
AssetAmount memory b1 = rawBalances.b.toBalanceValue();
```

**Constructor:**

```solidity
AddLiquidityFromBalancesToBalances(string memory maybeRoute, uint scaledRatio)
```

---

### `RemoveLiquidityFromCustodyToBalances`

Triggered when the state contains a single `custody(...)` block holding an LP position ID. Called once per custody.

**Hook signature** (from [contracts/commands/Liquidity.sol](../contracts/commands/Liquidity.sol)):

```solidity
function removeLiquidityFromCustodyToBalances(
    bytes32 account,
    HostAmount memory custody,
    DataRef memory rawRoute,
    Writer memory out
) internal virtual;
```

| Parameter        | Type      | Description                                                                        |
| ---------------- | --------- | ---------------------------------------------------------------------------------- |
| `custody.asset`  | `bytes32` | Rush asset ID representing the LP position                                         |
| `custody.meta`   | `bytes32` | ERC-721 token ID of the LP position                                                |
| `custody.amount` | `uint`    | Ownership count, normally `1` for ERC-721                                          |
| `rawRoute`       | `DataRef` | Route block with two `minimum(...)` children followed by one `quantity(...)` child |
| `out`            | `Writer`  | Append up to 2 balance blocks (token0 and token1 received)                         |

**Extracting two minimums plus quantity**:

```solidity
DataPairRef memory mins = rawRoute.innerPair();
uint liquidityToRemove = rawRoute.innerQuantityAt(mins.b.end);

uint min0 = mins.a.expectMinimum(token0Asset, 0);
uint min1 = mins.b.expectMinimum(token1Asset, 0);
```

**Output:**

```solidity
out.appendBalance(AssetAmount(token0Asset, 0, amount0));
out.appendBalance(AssetAmount(token1Asset, 0, amount1));
```

**Constructor:**

```solidity
RemoveLiquidityFromCustodyToBalances(string memory maybeRoute, uint scaledRatio)
// scaledRatio: use 20_000 for 2 output blocks per input
```

---

### `RemoveLiquidityFromBalanceToBalances`

Same as the custody variant, but the LP position is represented as a `balance(...)` block.

**Hook signature** (from [contracts/commands/Liquidity.sol](../contracts/commands/Liquidity.sol)):

```solidity
function removeLiquidityFromBalanceToBalances(
    bytes32 account,
    AssetAmount memory balance,
    DataRef memory rawRoute,
    Writer memory out
) internal virtual;
```

**Constructor:**

```solidity
RemoveLiquidityFromBalanceToBalances(string memory maybeRoute, uint scaledRatio)
```

---

## Key helper reference

| Call                                     | Returns                                      | Source                                         |
| ---------------------------------------- | -------------------------------------------- | ---------------------------------------------- |
| `rawRoute.innerMinimum()`                | `(bytes32 asset, bytes32 meta, uint amount)` | [Data.sol](../contracts/blocks/Data.sol)       |
| `rawRoute.innerQuantity()`               | `uint amount`                                | [Data.sol](../contracts/blocks/Data.sol)       |
| `ref.expectMinimum(asset, meta)`         | `uint amount`                                | [Data.sol](../contracts/blocks/Data.sol)       |
| `rawCustodies.a.expectCustody(host)`     | `AssetAmount`                                | [Data.sol](../contracts/blocks/Data.sol)       |
| `rawCustodies.b.expectCustody(host)`     | `AssetAmount`                                | [Data.sol](../contracts/blocks/Data.sol)       |
| `rawBalances.a.toBalanceValue()`         | `AssetAmount`                                | [Data.sol](../contracts/blocks/Data.sol)       |
| `rawBalances.b.toBalanceValue()`         | `AssetAmount`                                | [Data.sol](../contracts/blocks/Data.sol)       |
| `out.appendBalance(AssetAmount)`         | —                                            | [Writers.sol](../contracts/blocks/Writers.sol) |
| `out.appendBalance(asset, meta, amount)` | —                                            | [Writers.sol](../contracts/blocks/Writers.sol) |
| `Assets.toERC20Address(asset)`           | `address`                                    | [Utils.sol](../contracts/Utils.sol)            |

---

## Complete host example

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Host} from "../contracts/Core.sol";
import {
    SwapExactCustodyToBalance,
    AddLiquidityFromCustodiesToBalances,
    RemoveLiquidityFromCustodyToBalances
} from "../contracts/Commands.sol";
import {Data, DataRef, DataPairRef, AssetAmount, HostAmount, Writers, Writer} from "../contracts/Blocks.sol";
import {Assets} from "../contracts/Utils.sol";

using Data for DataRef;
using Writers for Writer;

// ── Minimal Uniswap V3 interfaces ────────────────────────────────────────────

interface ISwapRouter {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint deadline;
        uint amountIn;
        uint amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }
    function exactInputSingle(ExactInputSingleParams calldata params)
        external returns (uint amountOut);
}

interface IERC20Minimal {
    function approve(address spender, uint amount) external returns (bool);
}

interface INonfungiblePositionManager {
    struct MintParams {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint amount0Desired;
        uint amount1Desired;
        uint amount0Min;
        uint amount1Min;
        address recipient;
        uint deadline;
    }
    struct DecreaseLiquidityParams {
        uint tokenId;
        uint128 liquidity;
        uint amount0Min;
        uint amount1Min;
        uint deadline;
    }
    struct CollectParams {
        uint tokenId;
        address recipient;
        uint128 amount0Max;
        uint128 amount1Max;
    }

    function mint(MintParams calldata params)
        external returns (uint tokenId, uint128 liquidity, uint amount0, uint amount1);
    function positions(uint tokenId) external view returns (
        uint96 nonce,
        address operator,
        address token0,
        address token1,
        uint24 fee,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity,
        uint feeGrowthInside0LastX128,
        uint feeGrowthInside1LastX128,
        uint tokensOwed0,
        uint tokensOwed1
    );
    function decreaseLiquidity(DecreaseLiquidityParams calldata params)
        external returns (uint amount0, uint amount1);
    function collect(CollectParams calldata params)
        external returns (uint amount0, uint amount1);
}

// ── Pool config — supplied per-deployment ────────────────────────────────────

struct PoolConfig {
    address token0;
    address token1;
    uint24 fee;
    int24 tickLower;
    int24 tickUpper;
}

// ── Host ─────────────────────────────────────────────────────────────────────

contract UniswapHost is
    Host,
    SwapExactCustodyToBalance(""),
    AddLiquidityFromCustodiesToBalances("", 30_000),   // up to 3 balances out per custody pair
    RemoveLiquidityFromCustodyToBalances("", 20_000)   // up to 2 balances out per custody
{
    ISwapRouter immutable router;
    INonfungiblePositionManager immutable positionManager;
    PoolConfig pool;

    // lpTokenAsset is the Rush asset ID you assign to represent LP position NFTs
    bytes32 immutable lpTokenAsset;

    constructor(
        address rush,
        address _router,
        address _positionManager,
        PoolConfig memory _pool,
        bytes32 _lpTokenAsset
    ) Host(rush, 1, "uniswap-v3") {
        router = ISwapRouter(_router);
        positionManager = INonfungiblePositionManager(_positionManager);
        pool = _pool;
        lpTokenAsset = _lpTokenAsset;
    }

    // ── Swap ─────────────────────────────────────────────────────────────────

    function swapExactCustodyToBalance(
        bytes32,                       // account — unused in this example
        HostAmount memory custody,
        DataRef memory rawRoute
    ) internal override returns (AssetAmount memory out) {
        (bytes32 assetOut, , uint minOut) = rawRoute.innerMinimum();

        address tokenIn  = Assets.toERC20Address(custody.asset);
        address tokenOut = Assets.toERC20Address(assetOut);

        IERC20Minimal(tokenIn).approve(address(router), custody.amount);

        uint amountOut = router.exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn:           tokenIn,
                tokenOut:          tokenOut,
                fee:               pool.fee,
                recipient:         address(this),
                deadline:          block.timestamp,
                amountIn:          custody.amount,
                amountOutMinimum:  minOut,
                sqrtPriceLimitX96: 0
            })
        );

        return AssetAmount(assetOut, 0, amountOut);
    }

    // ── Add liquidity ─────────────────────────────────────────────────────────

    function addLiquidityFromCustodiesToBalances(
        bytes32,                          // account — unused
        DataPairRef memory rawCustodies,
        DataRef memory rawRoute,
        Writer memory out
    ) internal override {
        AssetAmount memory c0 = rawCustodies.a.expectCustody(host);
        AssetAmount memory c1 = rawCustodies.b.expectCustody(host);
        uint minLp = rawRoute.innerQuantity();

        address token0 = Assets.toERC20Address(c0.asset);
        address token1 = Assets.toERC20Address(c1.asset);

        IERC20Minimal(token0).approve(address(positionManager), c0.amount);
        IERC20Minimal(token1).approve(address(positionManager), c1.amount);

        (uint tokenId, uint128 liquidity, uint used0, uint used1) = positionManager.mint(
            INonfungiblePositionManager.MintParams({
                token0:         token0,
                token1:         token1,
                fee:            pool.fee,
                tickLower:      pool.tickLower,
                tickUpper:      pool.tickUpper,
                amount0Desired: c0.amount,
                amount1Desired: c1.amount,
                amount0Min:     0,
                amount1Min:     0,
                recipient:      address(this),
                deadline:       block.timestamp
            })
        );

        require(liquidity >= minLp, "insufficient liquidity");

        // Encode tokenId in meta — it flows back as custody.meta on removal, no mapping needed
        out.appendBalance(lpTokenAsset, bytes32(tokenId), 1);

        // Refunds for unused amounts
        out.appendNonZeroBalance(c0.asset, 0, c0.amount - used0);
        out.appendNonZeroBalance(c1.asset, 0, c1.amount - used1);
    }

    // ── Remove liquidity ──────────────────────────────────────────────────────

    function removeLiquidityFromCustodyToBalances(
        bytes32,
        HostAmount memory custody,     // custody.asset = lpTokenAsset, custody.meta = tokenId, custody.amount = 1
        DataRef memory rawRoute,
        Writer memory out
    ) internal override {
        // tokenId was encoded in meta when the LP balance was emitted on add
        uint tokenId = uint(custody.meta);
        (, , address token0, address token1, , , , uint128 liveLiquidity, , , , ) = positionManager.positions(tokenId);
        bytes32 token0Asset = Assets.toErc20Asset(token0);
        bytes32 token1Asset = Assets.toErc20Asset(token1);

        // rawRoute carries minimum(...), minimum(...), then quantity(...)
        DataPairRef memory mins = rawRoute.innerPair();
        uint liquidityToRemove = rawRoute.innerQuantityAt(mins.b.end);

        uint min0 = mins.a.expectMinimum(token0Asset, 0);
        uint min1 = mins.b.expectMinimum(token1Asset, 0);
        require(liquidityToRemove <= liveLiquidity, "insufficient liquidity");

         positionManager.decreaseLiquidity(
            INonfungiblePositionManager.DecreaseLiquidityParams({
                tokenId:    tokenId,
                liquidity:  uint128(liquidityToRemove),
                amount0Min: min0,
                amount1Min: min1,
                deadline:   block.timestamp
            })
        );

        (uint amount0, uint amount1) = positionManager.collect(
            INonfungiblePositionManager.CollectParams({
                tokenId:    tokenId,
                recipient:  address(this),
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            })
        );

        out.appendBalance(token0Asset, 0, amount0);
        out.appendBalance(token1Asset, 0, amount1);
    }
}
```

---

## Constructor reference

| Command                                | Constructor signature                   | Notes                                          |
| -------------------------------------- | --------------------------------------- | ---------------------------------------------- |
| `SwapExactBalanceToBalance`            | `(string maybeRoute)`                   | Pass `""` for no extra route fields            |
| `SwapExactCustodyToBalance`            | `(string maybeRoute)`                   | Pass `""` for no extra route fields            |
| `AddLiquidityFromBalancesToBalances`   | `(string maybeRoute, uint scaledRatio)` | `30_000` if emitting up to 3 balances per pair |
| `AddLiquidityFromCustodiesToBalances`  | `(string maybeRoute, uint scaledRatio)` | `30_000` if emitting up to 3 balances per pair |
| `RemoveLiquidityFromBalanceToBalances` | `(string maybeRoute, uint scaledRatio)` | `20_000` for 2 output balances per input       |
| `RemoveLiquidityFromCustodyToBalances` | `(string maybeRoute, uint scaledRatio)` | `20_000` for 2 output balances per input       |

`scaledRatio` is divided by `10_000` to get the output-to-input block ratio used to pre-allocate the writer buffer. The value must divide evenly — fractional ratios revert.
