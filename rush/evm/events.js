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

async function createHost(contractAddress, provider) {
    // Load event registry
    const host = new Contract(contractAddress, [EVENT], provider);
    const descEvents = await host.queryFilter(host.filters.EventDesc());

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