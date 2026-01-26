import { Interface, Contract, EventFragment } from "ethers";

const EVENT = "event EventDesc(bool once, string category, string abi)";

export function parseEvent(signature) {
    return EventFragment.from(signature.trim());
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

async function queryAndFormatEvents({ fragment, contract, filterFn }, options) {
    const filter = filterFn(...(options.args || []));
    const events = await contract.queryFilter(filter, options.fromBlock || 0, options.toBlock || "latest");

    return events.map((event) => ({
        eventName: fragment.name,
        blockNumber: event.blockNumber,
        transactionHash: event.transactionHash,
        args: event.args.toObject(),
    }));
}

export async function createHost(hostAddr, provider) {
    // Load event registry
    const host = new Contract(hostAddr, [EVENT], provider);
    const definitions = await host.queryFilter(host.filters.EventDesc());

    // Build registry: category -> array of { fragment, contract, filter }
    const registry = {};

    for (const event of definitions) {
        const { category, abi } = event.args.toObject();

        if (!registry[category]) registry[category] = [];

        const fragment = EventFragment.from(abi);
        const contract = new Contract(hostAddr, [fragment], provider);
        const filterFn = contract.filters[fragment.name];

        registry[category].push({ fragment, contract, filterFn });
    }

    async function getEvents(category, options = {}) {
        const categoryEvents = registry[category];
        if (!categoryEvents) return [];

        const eventPromises = categoryEvents.map((eventConfig) => queryAndFormatEvents(eventConfig, options));

        const results = await Promise.all(eventPromises);
        return results.flat();
    }

    return { getEvents };
}

export async function getAllEvents(provider, contractAddress, eventSignatures, options = {}) {
    // Create interface with all event signatures
    const iface = new Interface([eventSignatures]);

    // Get all logs for the address (no event filter)
    const logs = await provider.getLogs({
        address: contractAddress,
        fromBlock: options.fromBlock || 0,
        toBlock: options.toBlock || "latest",
        topics: options.topics, // Optional: filter by specific topics
    });

    // Decode logs based on their topic hash
    const decodedEvents = logs.map((log) => {
        try {
            const parsed = iface.parseLog(log);
            return {
                eventName: parsed.name,
                blockNumber: log.blockNumber,
                transactionHash: log.transactionHash,
                args: parsed.args.toObject(),
                fragment: parsed.fragment,
            };
        } catch (error) {
            // Log couldn't be decoded with any known signature
            return {
                eventName: "Unknown",
                blockNumber: log.blockNumber,
                transactionHash: log.transactionHash,
                topics: log.topics,
                data: log.data,
            };
        }
    });

    return decodedEvents;
}

/* // Usage
const eventSigs = [
  "event Balance(address indexed account, uint indexed eid, uint id, uint balance, uint change)",
  "event Transfer(address indexed from, address indexed to, uint256 value)",
  "event Approval(address indexed owner, address indexed spender, uint256 value)"
];

const allEvents = await getAllEvents(provider, contractAddress, eventSigs);
console.log(allEvents); */

async function createEventManager(provider, contractAddress) {
    // Load event registry
    const descContract = new Contract(contractAddress, [EVENT], provider);
    const descEvents = await descContract.queryFilter(descContract.filters.EventDesc());

    // Extract all event signatures
    const eventSignatures = descEvents.map((e) => e.args.toObject().abi);

    // Create interface with all event signatures
    const iface = new Interface(eventSignatures);

    async function getEvents(category, options = {}) {
        // Get all logs for the address
        const logs = await provider.getLogs({
            address: contractAddress,
            fromBlock: options.fromBlock || 0,
            toBlock: options.toBlock || "latest",
            topics: options.topics,
        });

        // Decode and filter by category
        const categorySet = new Set(
            descEvents.filter((e) => e.args.toObject().category === category).map((e) => e.args.toObject().abi)
        );

        return logs
            .map((log) => {
                try {
                    const parsed = iface.parseLog(log);
                    return {
                        eventName: parsed.name,
                        blockNumber: log.blockNumber,
                        transactionHash: log.transactionHash,
                        args: parsed.args.toObject(),
                        signature: parsed.fragment.format("sighash"),
                    };
                } catch {
                    return null;
                }
            })
            .filter((e) => e && categorySet.has(e.signature));
    }

    return { getEvents };
}

/* // Usage
const manager = await createEventManager(provider, contractAddress);
const balanceEvents = await manager.getEvents("balance");
 */