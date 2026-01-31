import { expect } from "chai";
import { network } from "hardhat";
import { AbiCoder, FunctionFragment } from "ethers";
import { encodeStep, encodeCall } from "../rush/evm/encode.js";
import { createEndpoint } from "../rush/evm/endpoint.js";
import { getEventInterface, decodeEvents, decodeSignatures, getEvents } from "../rush/evm/events.js";

const { ethers } = await network.connect();
const coder = AbiCoder.defaultAbiCoder();
const ZERO_BYTES = "0x";

// --- ID construction helpers (mirrors Utils.sol build function) ---

const ACCOUNT = 0x01010200n;
const NODE = 0x01010300n;
const ENDPOINT = 0x01010400n;

async function getChainId() {
    const { chainId } = await ethers.provider.getNetwork();
    return chainId;
}

function buildId(addr, selectorBits, chainBits, descBits) {
    let v = BigInt(addr);
    v |= chainBits << 160n;
    v |= descBits << 192n;
    v |= selectorBits << 224n;
    return v;
}

function toAccountId(addr) {
    return buildId(addr, 0n, 0n, ACCOUNT);
}

async function toNodeId(addr) {
    const chainId = await getChainId();
    return buildId(addr, 0n, chainId, NODE);
}

async function toEndpointId(addr, selector) {
    const chainId = await getChainId();
    const selectorUint = BigInt(selector);
    return buildId(addr, selectorUint, chainId, ENDPOINT);
}

// --- Query helper ---

async function query(addr, signature, args = {}) {
    const data = encodeCall(signature, args);
    const result = await ethers.provider.call({ to: addr, data });
    const { outputs } = FunctionFragment.from(signature);
    const decoded = coder.decode(outputs, result);
    return decoded.length === 1 ? decoded[0] : decoded;
}

// --- Event helpers ---

const ENDPOINT_EVENT = "event Endpoint(uint indexed node, uint id, uint gas, string abi, string params)";
const ACCESS_EVENT = "event Access(uint indexed node, address caller, bool trusted)";
const BALANCE_EVENT = "event Balance(uint indexed account, uint indexed eid, uint id, uint balance, uint change)";

async function getEndpointEvents(contract) {
    const addr = await contract.getAddress();
    const { events } = await getEvents({ signature: ENDPOINT_EVENT, addr, provider: ethers.provider });
    return events.map((e) => e.args);
}

function findEndpoint(endpoints, fnName) {
    return endpoints.find((e) => e.abi.includes(`function ${fnName}(`));
}

// --- Test Suite ---

describe("Rush Protocol", function () {
    let rush, faucet;
    let owner, user, other;
    let rushAddr, faucetAddr;
    let rushEndpoints, faucetEndpoints;
    let chainId;

    before(async function () {
        [owner, user, other] = await ethers.getSigners();
        chainId = await getChainId();
    });

    describe("Deployment", function () {
        it("Should deploy Rush with the deployer as owner", async function () {
            rush = await ethers.deployContract("Rush", [owner.address]);
            rushAddr = await rush.getAddress();
            expect(await rush.owner()).to.equal(owner.address);
        });

        it("Should deploy Faucet with Rush as cmdr and discovery", async function () {
            faucet = await ethers.deployContract("Faucet", [rushAddr, rushAddr]);
            faucetAddr = await faucet.getAddress();
        });

        it("Rush should have a valid nodeId", async function () {
            const nodeId = await rush.nodeId();
            expect(nodeId).to.not.equal(0n);
            // Verify address is embedded in the lower 160 bits
            const embeddedAddr = "0x" + (nodeId & ((1n << 160n) - 1n)).toString(16).padStart(40, "0");
            expect(embeddedAddr.toLowerCase()).to.equal(rushAddr.toLowerCase());
        });

        it("Faucet should have a valid nodeId", async function () {
            const nodeId = await faucet.nodeId();
            expect(nodeId).to.not.equal(0n);
            const embeddedAddr = "0x" + (nodeId & ((1n << 160n) - 1n)).toString(16).padStart(40, "0");
            expect(embeddedAddr.toLowerCase()).to.equal(faucetAddr.toLowerCase());
        });

        it("Rush should emit Endpoint events for its commands", async function () {
            rushEndpoints = await getEndpointEvents(rush);
            expect(rushEndpoints.length).to.be.greaterThan(0);

            // Should have setup, resolve, pipe, inject, resume, authorize, unauthorize, relocate endpoints
            expect(findEndpoint(rushEndpoints, "setup")).to.not.be.undefined;
            expect(findEndpoint(rushEndpoints, "resolve")).to.not.be.undefined;
            expect(findEndpoint(rushEndpoints, "pipe")).to.not.be.undefined;
            expect(findEndpoint(rushEndpoints, "inject")).to.not.be.undefined;
            expect(findEndpoint(rushEndpoints, "authorize")).to.not.be.undefined;
        });

        it("Faucet should emit Endpoint events for setup and resolve", async function () {
            faucetEndpoints = await getEndpointEvents(faucet);
            expect(faucetEndpoints.length).to.be.greaterThan(0);

            expect(findEndpoint(faucetEndpoints, "setup")).to.not.be.undefined;
            expect(findEndpoint(faucetEndpoints, "resolve")).to.not.be.undefined;
        });

        it("decodeEvents should return Endpoint events from the deployment block", async function () {
            const receipt = await rush.deploymentTransaction().wait();
            const block = receipt.blockNumber;
            const iface = await getEventInterface({ addr: rushAddr, block, provider: ethers.provider });
            const events = await decodeEvents({
                addr: rushAddr,
                iface,
                block,
                provider: ethers.provider,
            });
            console.info('Decoded event: ', events);
            expect(events.length).to.be.greaterThan(0);
            expect(events.some((e) => e.name === "Endpoint")).to.equal(true);
        });

        it("Endpoint events should include params for commands with request objects", async function () {
            const setupEp = findEndpoint(rushEndpoints, "setup");
            expect(setupEp.params).to.include("debitFrom");

            const resolveEp = findEndpoint(rushEndpoints, "resolve");
            expect(resolveEp.params).to.include("creditTo");

            const authorizeEp = findEndpoint(rushEndpoints, "authorize");
            expect(authorizeEp.params).to.include("authorize");
        });
    });

    describe("Access Control", function () {
        it("Faucet should not be trusted by Rush before authorization", async function () {
            const faucetNodeId = await faucet.nodeId();
            const trusted = await query(rushAddr, "function isTrusted(uint caller) external view returns (bool)", {
                caller: faucetNodeId,
            });
            expect(trusted).to.equal(false);
        });

        it("Non-owner should not be able to call inject", async function () {
            await expect(rush.connect(user).inject([])).to.revert(ethers);
        });

        it("Non-authorized address should not be able to call resume", async function () {
            await expect(rush.connect(user).resume("0x00000000", "0x" + "00".repeat(64), [])).to.revert(ethers);
        });

        it("Non-trusted address should not be able to call Faucet setup directly", async function () {
            // Create a minimal step
            const step = "0x" + "00".repeat(96);
            await expect(faucet.connect(user).setup(0n, step)).to.revert(ethers);
        });

        it("Pipe should revert with expired deadline", async function () {
            const expiredDeadline = 1n; // timestamp in the past
            await expect(rush.connect(user).pipe(expiredDeadline, [], ZERO_BYTES)).to.revert(ethers);
        });

        it("Pipe with no steps and valid deadline should revert (zero amount credit)", async function () {
            const futureDeadline = BigInt(Math.floor(Date.now() / 1000) + 3600);
            // With empty steps, pipe calls creditTo(head, args) with zero amount,
            // which reverts because ensureAmount rejects zero
            await expect(rush.connect(user).pipe(futureDeadline, [], ZERO_BYTES)).to.revert(ethers);
        });
    });

    describe("Authorization via inject", function () {
        it("Owner should authorize Faucet via inject pipeline", async function () {
            const faucetNodeId = await faucet.nodeId();
            const authorizeEp = findEndpoint(rushEndpoints, "authorize");

            const step = createEndpoint(authorizeEp)
                .authorize({ hosts: [faucetNodeId] })
                .step();

            const tx = await rush.connect(owner).inject([step]);
            const receipt = await tx.wait();

            // Verify the Access event was emitted
            const accessEvents = decodeSignatures(receipt.logs, [ACCESS_EVENT]);
            expect(accessEvents.length).to.be.greaterThan(0);

            const { args } = accessEvents[0];
            expect(args.caller.toLowerCase()).to.equal(faucetAddr.toLowerCase());
            expect(args.trusted).to.equal(true);
        });

        it("Faucet should be trusted by Rush after authorization", async function () {
            const faucetNodeId = await faucet.nodeId();
            const trusted = await query(rushAddr, "function isTrusted(uint caller) external view returns (bool)", {
                caller: faucetNodeId,
            });
            expect(trusted).to.equal(true);
        });
    });

    describe("Pipeline: Faucet debit → Rush credit", function () {
        it("Should execute a debit from Faucet and credit to Rush balances", async function () {
            const faucetSetupEp = findEndpoint(faucetEndpoints, "setup");
            const rushResolveEp = findEndpoint(rushEndpoints, "resolve");

            // Build a token ID to use (we'll use a dummy token address)
            const dummyTokenAddr = "0x0000000000000000000000000000000000000001";
            const tokenId = buildId(BigInt(dummyTokenAddr), chainId, 0x01010500n, 0n);

            // Step 1: DebitFrom on Faucet
            const debitStep = createEndpoint(faucetSetupEp)
                .debitFrom({ use: tokenId, min: 100n, max: 500n, bounty: 0n })
                .step();

            // Step 2: CreditTo on Rush (credit to self)
            const creditStep = createEndpoint(rushResolveEp).step();

            const futureDeadline = BigInt(Math.floor(Date.now() / 1000) + 3600);

            const tx = await rush.connect(user).pipe(futureDeadline, [debitStep, creditStep], ZERO_BYTES);
            const receipt = await tx.wait();

            // Verify Balance events were emitted
            const balanceEvents = decodeSignatures(receipt.logs, [BALANCE_EVENT]);
            expect(balanceEvents.length).to.be.greaterThan(0);

            // Check user's balance on Rush
            const userAccountId = toAccountId(user.address);
            const balances = await query(
                rushAddr,
                "function getBalances(uint account, uint[] ids) external view returns (uint[])",
                { account: userAccountId, ids: [tokenId] }
            );
            expect(balances[0]).to.equal(500n); // Faucet balance is 1000e18, max is 500
        });

        it("Should execute debit and auto-credit when pipeline ends without explicit resolve step", async function () {
            const faucetSetupEp = findEndpoint(faucetEndpoints, "setup");

            const dummyTokenAddr = "0x0000000000000000000000000000000000000002";
            const tokenId = buildId(BigInt(dummyTokenAddr), chainId, 0x01010500n, 0n);

            const debitStep = createEndpoint(faucetSetupEp)
                .debitFrom({ use: tokenId, min: 50n, max: 200n, bounty: 0n })
                .step();

            const futureDeadline = BigInt(Math.floor(Date.now() / 1000) + 3600);

            // Only one step (debit), no resolve step
            // Pipeline should auto-credit via creditTo(head, args)
            const tx = await rush.connect(user).pipe(futureDeadline, [debitStep], ZERO_BYTES);
            await tx.wait();

            const userAccountId = toAccountId(user.address);
            const balances = await query(
                rushAddr,
                "function getBalances(uint account, uint[] ids) external view returns (uint[])",
                { account: userAccountId, ids: [tokenId] }
            );
            expect(balances[0]).to.equal(200n);
        });
    });

    describe("Credit redirection", function () {
        it("Should redirect credit to a different account via creditTo request", async function () {
            const faucetSetupEp = findEndpoint(faucetEndpoints, "setup");
            const rushResolveEp = findEndpoint(rushEndpoints, "resolve");

            const dummyTokenAddr = "0x0000000000000000000000000000000000000003";
            const tokenId = buildId(BigInt(dummyTokenAddr), chainId, 0x01010500n, 0n);

            // Debit step
            const debitStep = createEndpoint(faucetSetupEp)
                .debitFrom({ use: tokenId, min: 100n, max: 300n, bounty: 0n })
                .step();

            // Credit step with redirection to 'other' account
            const otherAccountId = toAccountId(other.address);
            const creditStep = createEndpoint(rushResolveEp)
                .creditTo({ to: otherAccountId })
                .step();

            const futureDeadline = BigInt(Math.floor(Date.now() / 1000) + 3600);

            const tx = await rush.connect(user).pipe(futureDeadline, [debitStep, creditStep], ZERO_BYTES);
            await tx.wait();

            // Funds should be in 'other' account, not 'user'
            const balances = await query(
                rushAddr,
                "function getBalances(uint account, uint[] ids) external view returns (uint[])",
                { account: otherAccountId, ids: [tokenId] }
            );
            expect(balances[0]).to.equal(300n);
        });
    });

    describe("Pipeline state machine enforcement", function () {
        it("Should revert if trying to resolve without setup first", async function () {
            // Try to call resolve (OPERATE phase) directly from pipe (which starts in SETUP phase)
            // The resolve endpoint should only be reachable after a setup step transitions to OPERATE
            const rushResolveEp = findEndpoint(rushEndpoints, "resolve");

            // Attempting resolve as first step from SETUP head should fail
            // because resolve's selector is OPERATE-phase, not SETUP-phase
            // canAdvance(SETUP, RESOLVE_selector) should return false
            const creditStep = encodeStep(rushResolveEp.id, 0n);
            const futureDeadline = BigInt(Math.floor(Date.now() / 1000) + 3600);

            await expect(rush.connect(user).pipe(futureDeadline, [creditStep], ZERO_BYTES)).to.revert(ethers);
        });
    });

    describe("Rush internal balances", function () {
        it("Should track balances correctly via getBalances", async function () {
            const userAccountId = toAccountId(user.address);
            const dummyTokenAddr = "0x0000000000000000000000000000000000000001";
            const tokenId = buildId(BigInt(dummyTokenAddr), chainId, 0x01010500n, 0n);

            // User should have balance from the earlier debit-credit test
            const balances = await query(
                rushAddr,
                "function getBalances(uint account, uint[] ids) external view returns (uint[])",
                { account: userAccountId, ids: [tokenId] }
            );
            expect(balances[0]).to.be.greaterThan(0n);
        });

        it("Should return zero for accounts with no balance", async function () {
            const randomAccountId = toAccountId(other.address);
            const unknownTokenId = buildId(
                BigInt("0x0000000000000000000000000000000000000099"),
                chainId,
                0x01010500n,
                0n
            );

            const balances = await query(
                rushAddr,
                "function getBalances(uint account, uint[] ids) external view returns (uint[])",
                { account: randomAccountId, ids: [unknownTokenId] }
            );
            expect(balances[0]).to.equal(0n);
        });
    });

    describe("Unauthorize", function () {
        it("Owner should be able to unauthorize Faucet via inject", async function () {
            const faucetNodeId = await faucet.nodeId();
            const unauthorizeEp = findEndpoint(rushEndpoints, "unauthorize");

            const step = createEndpoint(unauthorizeEp)
                .unauthorize({ hosts: [faucetNodeId] })
                .step();

            const tx = await rush.connect(owner).inject([step]);
            await tx.wait();

            // Faucet should no longer be trusted
            const trusted = await query(rushAddr, "function isTrusted(uint caller) external view returns (bool)", {
                caller: faucetNodeId,
            });
            expect(trusted).to.equal(false);
        });

        it("Pipeline with Faucet should fail after unauthorization", async function () {
            const faucetSetupEp = findEndpoint(faucetEndpoints, "setup");
            const dummyTokenAddr = "0x0000000000000000000000000000000000000001";
            const tokenId = buildId(BigInt(dummyTokenAddr), chainId, 0x01010500n, 0n);

            const debitStep = createEndpoint(faucetSetupEp)
                .debitFrom({ use: tokenId, min: 100n, max: 500n, bounty: 0n })
                .step();

            const futureDeadline = BigInt(Math.floor(Date.now() / 1000) + 3600);

            // Should fail because Faucet is no longer trusted
            await expect(rush.connect(user).pipe(futureDeadline, [debitStep], ZERO_BYTES)).to.revert(ethers);
        });

        it("Should re-authorize Faucet for subsequent tests", async function () {
            const faucetNodeId = await faucet.nodeId();
            const authorizeEp = findEndpoint(rushEndpoints, "authorize");

            const step = createEndpoint(authorizeEp)
                .authorize({ hosts: [faucetNodeId] })
                .step();

            await rush.connect(owner).inject([step]);
            const trusted = await query(rushAddr, "function isTrusted(uint caller) external view returns (bool)", {
                caller: faucetNodeId,
            });
            expect(trusted).to.equal(true);
        });
    });
});
