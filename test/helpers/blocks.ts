import { ethers } from "ethers";

// Block key derivation: bytes4(keccak256("#name"))
export function blockKey(name: string): string {
  return ethers.dataSlice(ethers.id(name), 0, 4);
}

// Known block keys
export const Keys = {
  Empty: "0x00000000",
  Any: "0xffffffff",
  Amount: blockKey("#amount"),
  Balance: blockKey("#balance"),
  BalanceLimit: blockKey("#balanceLimit"),
  Allocation: blockKey("#allocation"),
  Allowance: blockKey("#allowance"),
  Custody: blockKey("#custody"),
  CustodyLimit: blockKey("#custodyLimit"),
  Fee: blockKey("#fee"),
  Account: blockKey("#account"),
  Node: blockKey("#node"),
  Asset: blockKey("#asset"),
  Step: blockKey("#step"),
  Call: blockKey("#call"),
  Context: blockKey("#context"),
  Pipe: blockKey("#pipe"),
  Relay: blockKey("#relay"),
  Dispatch: blockKey("#dispatch"),
  Transaction: blockKey("#transaction"),
  Auth: blockKey("#auth"),
  Bounty: blockKey("#bounty"),
  Label: blockKey("#label"),
  Bytes: blockKey("#bytes"),
  String: blockKey("#string"),
  List: blockKey("#list"),
  Data: blockKey("#data"),
  Evm: blockKey("#evm"),
  Status: blockKey("#status"),
  AssetAmount: blockKey("#assetAmount"),
  AccountAsset: blockKey("#accountAsset"),
  AccountAmount: blockKey("#accountAmount"),
  HostAmount: blockKey("#hostAmount"),
  HostAccountAsset: blockKey("#hostAccountAsset"),
  HostAccountAmount: blockKey("#hostAccountAmount"),
} as const;

// Pad a bigint or hex string to 32 bytes
export function pad32(value: bigint | string): string {
  if (typeof value === "bigint") {
    return ethers.zeroPadValue(ethers.toBeHex(value), 32);
  }
  return ethers.zeroPadValue(value, 32);
}

const USER_PREFIX = 0x01200103n;

export function encodeUserAccount(addr: string): string {
  const account = (USER_PREFIX << 224n) | (BigInt(ethers.zeroPadValue(addr, 20)) << 32n);
  return ethers.zeroPadValue(ethers.toBeHex(account), 32);
}

// Encode a 4-byte big-endian uint32
function encodeUint32(value: number): string {
  return ethers.toBeHex(value, 4);
}

// Build a block header + payload
function block(key: string, payload: string): string {
  const payloadBytes = ethers.getBytes(payload);
  return ethers.concat([key, encodeUint32(payloadBytes.length), payload]);
}

export function encodeAmountBlock(asset: string, meta: string, amount: bigint): string {
  return block(Keys.Amount, ethers.concat([pad32(asset), pad32(meta), pad32(amount)]));
}

export function encodeBalanceBlock(asset: string, meta: string, amount: bigint): string {
  return block(Keys.Balance, ethers.concat([pad32(asset), pad32(meta), pad32(amount)]));
}

export function encodeBalanceLimitBlock(asset: string, meta: string, min: bigint, max: bigint): string {
  return block(Keys.BalanceLimit, ethers.concat([pad32(asset), pad32(meta), pad32(min), pad32(max)]));
}

export function encodeHostAccountAssetBlock(host: bigint, account: string, asset: string, meta: string): string {
  return block(Keys.HostAccountAsset, ethers.concat([pad32(host), pad32(account), pad32(asset), pad32(meta)]));
}

export function encodeAccountAssetBlock(account: string, asset: string, meta: string): string {
  return block(Keys.AccountAsset, ethers.concat([pad32(account), pad32(asset), pad32(meta)]));
}

export function encodeAccountAmountBlock(account: string, asset: string, meta: string, amount: bigint): string {
  return block(Keys.AccountAmount, ethers.concat([pad32(account), pad32(asset), pad32(meta), pad32(amount)]));
}

export function encodeAllocationBlock(host: bigint, asset: string, meta: string, amount: bigint): string {
  return block(Keys.Allocation, ethers.concat([pad32(host), pad32(asset), pad32(meta), pad32(amount)]));
}

export function encodeAllowanceBlock(host: bigint, asset: string, meta: string, amount: bigint): string {
  return block(Keys.Allowance, ethers.concat([pad32(host), pad32(asset), pad32(meta), pad32(amount)]));
}

export function encodeCustodyBlock(host: bigint, asset: string, meta: string, amount: bigint): string {
  return block(Keys.Custody, ethers.concat([pad32(host), pad32(asset), pad32(meta), pad32(amount)]));
}

export function encodeCustodyLimitBlock(host: bigint, asset: string, meta: string, min: bigint, max: bigint): string {
  return block(Keys.CustodyLimit, ethers.concat([pad32(host), pad32(asset), pad32(meta), pad32(min), pad32(max)]));
}

export function encodeAccountBlock(account: string): string {
  return block(Keys.Account, pad32(account));
}

export function encodeNodeBlock(id: bigint): string {
  return block(Keys.Node, pad32(id));
}

export function encodeAssetBlock(asset: string, meta: string): string {
  return block(Keys.Asset, ethers.concat([pad32(asset), pad32(meta)]));
}

export function encodeFeeBlock(amount: bigint): string {
  return block(Keys.Fee, pad32(amount));
}

export function encodeTxBlock(from: string, to: string, asset: string, meta: string, amount: bigint): string {
  return block(Keys.Transaction, ethers.concat([pad32(from), pad32(to), pad32(asset), pad32(meta), pad32(amount)]));
}

export function encodeStepBlock(target: bigint, value: bigint, request: string): string {
  return block(Keys.Step, ethers.concat([pad32(target), pad32(value), encodeBytesBlock(request)]));
}

export function encodeCallBlock(target: bigint, value: bigint, data: string): string {
  return block(Keys.Call, ethers.concat([pad32(target), pad32(value), encodeBytesBlock(data)]));
}

export function encodeContextBlock(account: string, state: string, request: string): string {
  return block(Keys.Context, ethers.concat([pad32(account), encodeBytesBlock(state), encodeBytesBlock(request)]));
}

export function encodePipeBlock(value: bigint, account: string, state: string, request: string): string {
  return block(Keys.Pipe, ethers.concat([pad32(value), encodeContextBlock(account, state, request)]));
}

export function encodeRelayBlock(chain: bigint, resources: bigint, steps: string): string {
  return block(Keys.Relay, ethers.concat([pad32(chain), pad32(resources), encodeBytesBlock(steps)]));
}

export function encodeDispatchBlock(chain: bigint, resources: bigint, payload: string): string {
  return block(Keys.Dispatch, ethers.concat([pad32(chain), pad32(resources), encodeBytesBlock(payload)]));
}

export function encodeBytesBlock(data: string): string {
  return block(Keys.Bytes, data);
}

export function encodeStringBlock(data: string): string {
  return block(Keys.String, ethers.hexlify(ethers.toUtf8Bytes(data)));
}

export function encodeLabelBlock(id: bigint, namespace: string, name: string): string {
  return block(Keys.Label, ethers.concat([pad32(id), pad32(namespace), encodeStringBlock(name)]));
}

export function encodeDataBlock(data: string): string {
  return block(Keys.Data, data);
}

export function encodeEvmBlock(data: string): string {
  return block(Keys.Evm, data);
}

export function encodeStatusBlock(code: bigint): string {
  return block(Keys.Status, pad32(code));
}

export function encodeListBlock(...members: string[]): string {
  return block(Keys.List, concat(...members));
}

export function encodeAuthBlock(cid: bigint, deadline: bigint, proof: string): string {
  return block(Keys.Auth, ethers.concat([pad32(cid), pad32(deadline), encodeBytesBlock(proof)]));
}

export function encodeBountyBlock(amount: bigint, relayer: string): string {
  return block(Keys.Bounty, ethers.concat([pad32(amount), pad32(relayer)]));
}

export function concat(...parts: string[]): string {
  return ethers.concat(parts);
}

// Command args suffix appended when computing command selectors
const COMMAND_ARGS = "((bytes32,bytes,bytes))";
const PEER_ARGS = "(bytes)";
const GUARD_ARGS = "(bytes)";

export function commandSelector(name: string): string {
  return ethers.dataSlice(ethers.id(name + COMMAND_ARGS), 0, 4);
}

export function peerSelector(name: string): string {
  return ethers.dataSlice(ethers.id(name + PEER_ARGS), 0, 4);
}

export function guardSelector(name: string): string {
  return ethers.dataSlice(ethers.id(name + GUARD_ARGS), 0, 4);
}

