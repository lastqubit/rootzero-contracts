import { createEndpoint } from "./evm/endpoint.js";

const endpoints = {};

export function listEndpoints() {
    return Object.values(endpoints);
}

export function addEndpoints(list = []) {
    for (const ep of list) {
        const descriptor = createEndpoint(ep);
        endpoints[descriptor.id] = descriptor;
    }
}

export function getEndpoint(id) {
    if (id in endpoints === false) {
        throw new Error("Endpoint not found: " + id);
    }
    return endpoints[id];
}

export function findEndpoint(name) {
    return Object.values(endpoints).find((ep) => ep.name === name);
}
