import { id, Contract, EventFragment, FunctionFragment } from "ethers";

export function getSelector(signature) {
    return id(signature).slice(0, 10);
}

export function parseEvent(signature) {
    return EventFragment.from(signature.trim());
}

export function parseFunction(signature) {
    return FunctionFragment.from(signature.trim());
}

function splitParams(params) {
    return params.split(";").filter(Boolean);
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
