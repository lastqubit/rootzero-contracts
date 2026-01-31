import { Interface, Contract } from "ethers";
import { ensureSignature } from "./utils";

const DESC = "event EventDesc(string abi)";

const lookup = {};

function toLowerCase(value) {
    return String(value).toLocaleLowerCase();
}

function parseSignature(sig) {
    const match = sig.match(/^(?:event\s+)?(\w+)(?::(\w+))?\s*\(/);
    const name = match[1];
    const category = match[2] || name;
    const clean = match[2] ? sig.replace(`${name}:${category}`, name) : sig;
    return { name, category, clean };
}

function indexEvent(signature) {
    const { name, category, clean } = parseSignature(ensureSignature(signature));
    lookup[toLowerCase(name)] = toLowerCase(category);
    return clean;
}

function toInterface(signatures = []) {
    return new Interface(signatures.map((s) => indexEvent(s)));
}

function normalize(log, desc) {
    const name = log.name || desc.name;
    return {
        ...log,
        name,
        category: lookup[toLowerCase(name)],
        args: (log.args || desc.args)?.toObject(),
    };
}

function decodeLogs(logs, iface) {
    return logs.reduce((out, log) => {
        const p = iface.parseLog(log);
        if (p) out.push(normalize(log, p));
        return out;
    }, []);
}

export async function getLogs({ addr, topics, block, fromBlock = 0, toBlock = "latest", provider }) {
    return provider.getLogs({ address: addr, fromBlock: block || fromBlock, toBlock: block || toBlock, topics });
}

export async function getEvents({ signature, addr, args = [], block, fromBlock = 0, toBlock = "latest", provider }) {
    const { name, category, clean } = parseSignature(signature);
    const contract = new Contract(addr, [clean], provider);
    const filter = contract.filters[name](...args);
    const events = await contract.queryFilter(filter, block || fromBlock, block || toBlock);
    return { category, name, events: events.map(normalize) };
}

export async function getEventInterface({ addr, block, provider }) {
    const { events } = await getEvents({ signature: DESC, addr, block, provider });
    return toInterface(events.map((e) => e.args.abi));
}

export async function decodeEvents({ addr, iface, block, fromBlock, toBlock, provider }) {
    return decodeLogs(await getLogs({ addr, block, fromBlock, toBlock, provider }), iface);
}
