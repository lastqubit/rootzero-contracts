import { id, Contract, EventFragment, FunctionFragment } from "ethers";
import { parseParams } from "./schema.js";

export function getSelector(signature) {
    return id(signature).slice(0, 10);
}

export function parseEvent(signature) {
    return EventFragment.from(signature);
}

export function parseFunction(signature) {
    return FunctionFragment.from(signature);
}

export function parseFunctions(signatures) {
    return signatures
        .split(";")
        .map((s) => s.trim())
        .filter(Boolean)
        .reduce((map, sig) => {
            const { clean, rules } = parseParams(sig);
            const f = FunctionFragment.from(clean);
            map[f.name] = { fragment: f, signature: clean, rules };
            return map;
        }, {});
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
