import { Contract } from "ethers";

const INJECT = "function inject(bytes[] steps) external payable returns(uint count)";
const EXECUTE = "function execute(bytes[] steps, bytes signed) external payable returns(uint count)";

export function createRush(addr, provider) {
    const contract = new Contract(addr, [INJECT, EXECUTE], provider);

    async function inject(steps = []) {
        return contract.inject(steps, { value: 0n });
    }

    async function execute(steps = [], signed = "0x") {
        return contract.execute(steps, signed, { value: 0n });
    }

    return { inject, execute };
}
