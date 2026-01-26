import { id, AbiCoder, Contract, EventFragment, FunctionFragment } from "ethers";

const SOLIDITY_DEFAULTS = {
    uint: 0n,
    int: 0n,
    bytes: "0x",
    fixedBytes: "0x00", // for bytes1-bytes32
    bool: false,
    address: "0x0000000000000000000000000000000000000000",
    string: "",
    array: [],
};

const abi = AbiCoder.defaultAbiCoder();

function getDefaultValue(type) {
    if (type === "array") return SOLIDITY_DEFAULTS.array;
    if (type.startsWith("uint")) return SOLIDITY_DEFAULTS.uint;
    if (type.startsWith("int")) return SOLIDITY_DEFAULTS.int;
    if (type.startsWith("bytes") && type !== "bytes") {
        const size = parseInt(type.replace("bytes", ""));
        return "0x" + "00".repeat(size);
    }
    return SOLIDITY_DEFAULTS[type] ?? null;
}

export function getSelector(signature) {
  return id(signature).slice(0, 10);
}

export function parseEvent(signature) {
    return EventFragment.from(signature.trim());
}

export function parseFunction(signature) {
    return FunctionFragment.from(signature.trim());
}

export function parseFunctions(signatures) {
    return signatures
        .split(";")
        .map((s) => s.trim())
        .filter(Boolean)
        .reduce((map, sig) => {
            const f = FunctionFragment.from(sig);
            map[f.name] = f;
            return map;
        }, {});
}

function encodeInputs(inputs, params = {}) {
    const values = inputs.map((i) => params[i.name] ?? getDefaultValue(i.type));
    return abi.encode(inputs, values);
}

export async function getEvents({ event, addr, provider, args = [], fromBlock = 0, toBlock = "latest" }) {
    const fragment = parseEvent(event);
    const contract = new Contract(addr, [fragment], provider);
    const filter = contract.filters[fragment.name](...args);
    const events = await contract.queryFilter(filter, fromBlock, toBlock);
    return events.map((event) => ({
        name: fragment.name,
        blockNumber: event.blockNumber,
        transactionHash: event.transactionHash,
        args: event.args.toObject(), // Convert args to named object
    }));
}
