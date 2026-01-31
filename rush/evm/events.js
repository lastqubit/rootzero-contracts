import { Interface, Contract } from "ethers";
import { parseSignature, parseSignatures } from "./utils";

const EVENTSIG = "event EventSignature(string abi)";

const lookup = {};

function toLowerCase(value) {
    return String(value).toLocaleLowerCase();
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

function indexEvent(o) {
    const { name, category, clean } = o;
    lookup[toLowerCase(name)] = toLowerCase(category);
    return clean;
}

export function toEventInterface(...signatures) {
    return new Interface(parseSignatures(...signatures).map(indexEvent));
}

export function decodeLogs(logs, iface) {
    return logs.reduce((out, log) => {
        const p = iface.parseLog(log);
        if (p) out.push(normalize(log, p));
        return out;
    }, []);
}

export function decodeSignatures(logs, ...signatures) {
    return decodeLogs(logs, toEventInterface(signatures));
}

export async function getLogs({ addr, block, topics, fromBlock = 0, toBlock = "latest", provider }) {
    return provider.getLogs({ address: addr, fromBlock: block || fromBlock, toBlock: block || toBlock, topics });
}

export async function getEvents({ signature, addr, args = [], block, fromBlock = 0, toBlock = "latest", provider }) {
    const { name, category, clean } = parseSignature(signature);
    const contract = new Contract(addr, [clean], provider);
    const filter = contract.filters[name](...args);
    const events = await contract.queryFilter(filter, block || fromBlock, block || toBlock);
    return { category, name, events: events.map(normalize) };
}

export async function getEventSignatures({ addr, block, provider }) {
    const { events } = await getEvents({ signature: EVENTSIG, addr, block, provider });
    return events.map((e) => e.args.abi);
}

export async function getEventInterface({ addr, block, provider }) {
    const { events } = await getEvents({ signature: EVENTSIG, addr, block, provider });
    return toEventInterface(events.map((e) => e.args.abi));
}

export async function decodeEvents({ addr, iface, block, fromBlock, toBlock, provider }) {
    return decodeLogs(await getLogs({ addr, block, fromBlock, toBlock, provider }), iface);
}

function createListener(addr, cursor, signatures = [], provider) {}
