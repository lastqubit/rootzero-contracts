import { Interface, Contract, EventFragment } from "ethers";

const EVENT = "event EventDesc(string abi)";

function parseEvent(signature) {
    return EventFragment.from(signature.trim());
}

function toArgs(e) {
    return e?.args?.toObject();
}

async function getLogs({ addr, fromBlock = 0, toBlock = "latest", topics, provider }) {
    return provider.getLogs({ address: addr, fromBlock, toBlock, topics });
}

async function getBlockLogs({ addr, block, topics, provider }) {
    return provider.getLogs({ address: addr, fromBlock: block, toBlock: block, topics });
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

export async function getAllEvents(provider, addr, eventSignatures, options = {}) {
    // Create interface with all event signatures
    const iface = new Interface([eventSignatures]);

    // Get all logs for the address (no event filter)
    const logs = await getLogs({ addr, provider, ...options });

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

async function createHost(contractAddress, provider) {
    // Load event registry
    const host = new Contract(contractAddress, [EVENT], provider);
    const descEvents = await host.queryFilter(host.filters.EventDesc());
    const descs = descEvents.map(toArgs);

    // Extract all event signatures
    const eventSignatures = descs.map((e) => e.abi);

    // Create interface with all event signatures
    const iface = new Interface(eventSignatures);

    async function getEvents(category, options = {}) {
        // Get all logs for the address
        const logs = await getLogs({ addr: contractAddress, provider, ...options });

        // Decode and filter by category
        const categorySet = new Set(descs.filter((a) => a.category === category).map((a) => a.abi));

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
