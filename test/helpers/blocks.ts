import { ethers } from "ethers";

// Block key derivation: bytes4(keccak256(schema))
export function blockKey(schema: string): string {
  return ethers.dataSlice(ethers.id(schema), 0, 4);
}

// Known block keys
export const Keys = {
  Amount: blockKey("#amount { bytes32 asset, bytes32 meta, uint amount }"),
  Balance: blockKey("#balance { bytes32 asset, bytes32 meta, uint amount }"),
  Allocation: blockKey("#allocation { uint host, bytes32 asset, bytes32 meta, uint amount }"),
  Allowance: blockKey("#allowance { uint host, bytes32 asset, bytes32 meta, uint amount }"),
  Custody: blockKey("#custody { uint host, bytes32 asset, bytes32 meta, uint amount }"),
  Fee: blockKey("#fee { uint amount }"),
  Account: blockKey("#account { bytes32 account }"),
  Payout: blockKey("#payout { bytes32 account, bytes32 asset, bytes32 meta, uint amount }"),
  Node: blockKey("#node { uint id }"),
  Asset: blockKey("#asset { bytes32 asset, bytes32 meta }"),
  Step: blockKey("#step { uint target, uint value, #bytes as request }"),
  Call: blockKey("#call { uint target, uint value, #bytes as payload }"),
  Transaction: blockKey("#transaction { bytes32 from, bytes32 to, bytes32 asset, bytes32 meta, uint amount }"),
  Minimum: blockKey("#minimum { bytes32 asset, bytes32 meta, uint amount }"),
  Maximum: blockKey("#maximum { bytes32 asset, bytes32 meta, uint amount }"),
  Auth: blockKey("#auth { uint cid, uint deadline, #bytes as proof }"),
  Bounty: blockKey("#bounty { uint amount, bytes32 relayer }"),
  Bytes: blockKey("#bytes"),
  List: blockKey("#list"),
  Data: blockKey("#data"),
  Evm: blockKey("#evm"),
  Status: blockKey("#status { bool ok }"),
  AssetAmount: blockKey("#assetAmount { bytes32 asset, bytes32 meta, uint amount }"),
  AccountAsset: blockKey("#accountAsset { bytes32 account, bytes32 asset, bytes32 meta }"),
  AccountAmount: blockKey("#accountAmount { bytes32 account, bytes32 asset, bytes32 meta, uint amount }"),
  HostAmount: blockKey("#hostAmount { uint host, bytes32 asset, bytes32 meta, uint amount }"),
  HostAccountAsset: blockKey("#hostAccountAsset { uint host, bytes32 account, bytes32 asset, bytes32 meta }"),
  HostAccountAmount: blockKey("#hostAccountAmount { uint host, bytes32 account, bytes32 asset, bytes32 meta, uint amount }"),
} as const;

// Pad a bigint or hex string to 32 bytes
export function pad32(value: bigint | string): string {
  if (typeof value === "bigint") {
    return ethers.zeroPadValue(ethers.toBeHex(value), 32);
  }
  return ethers.zeroPadValue(value, 32);
}

const USER_PREFIX = 0x20010102n;

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

export function encodeHostAccountAssetBlock(host: bigint, account: string, asset: string, meta: string): string {
  return block(Keys.HostAccountAsset, ethers.concat([pad32(host), pad32(account), pad32(asset), pad32(meta)]));
}

export function encodeAccountAssetBlock(account: string, asset: string, meta: string): string {
  return block(Keys.AccountAsset, ethers.concat([pad32(account), pad32(asset), pad32(meta)]));
}

export function encodePayoutBlock(account: string, asset: string, meta: string, amount: bigint): string {
  return block(Keys.Payout, ethers.concat([pad32(account), pad32(asset), pad32(meta), pad32(amount)]));
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

export function encodeBytesBlock(data: string): string {
  return block(Keys.Bytes, data);
}

export function encodeDataBlock(data: string): string {
  return block(Keys.Data, data);
}

export function encodeEvmBlock(data: string): string {
  return block(Keys.Evm, data);
}

export function encodeStatusBlock(ok: boolean): string {
  return block(Keys.Status, ok ? "0x01" : "0x00");
}

export function encodeListBlock(...members: string[]): string {
  return block(Keys.List, concat(...members));
}

export function encodeAuthBlock(cid: bigint, deadline: bigint, proof: string): string {
  return block(Keys.Auth, ethers.concat([pad32(cid), pad32(deadline), encodeBytesBlock(proof)]));
}

export function encodeMinimumBlock(asset: string, meta: string, amount: bigint): string {
  return block(Keys.Minimum, ethers.concat([pad32(asset), pad32(meta), pad32(amount)]));
}

export function encodeMaximumBlock(asset: string, meta: string, amount: bigint): string {
  return block(Keys.Maximum, ethers.concat([pad32(asset), pad32(meta), pad32(amount)]));
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

export function commandSelector(name: string): string {
  return ethers.dataSlice(ethers.id(name + COMMAND_ARGS), 0, 4);
}

export function peerSelector(name: string): string {
  return ethers.dataSlice(ethers.id(name + PEER_ARGS), 0, 4);
}

