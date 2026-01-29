import { JsonRpcProvider } from "ethers";

const DEFAULT_RPC = "http://localhost:8545";

export function getProvider(options = {}) {
    const { url, apiKey, network } = options;

    // Local or custom RPC URL
    if (url) {
        return new JsonRpcProvider(url);
    }

    // API key for hosted providers (e.g., Infura, Alchemy)
    if (apiKey && network) {
        return new JsonRpcProvider(`https://${network}.infura.io/v3/${apiKey}`);
    }

    // Default to local node
    return new JsonRpcProvider(DEFAULT_RPC);
}
