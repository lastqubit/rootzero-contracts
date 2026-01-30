// @generated from Rush at 0x5FbDB2315678afecb367f032d93F642f64180aa3
import { encodeBlock, encodeStep } from "../evm/encode.js";

/** @type {bigint} Endpoint ID for authorize */
export const authorizeId = 86860681130026241580765011601691334635632156767595053603548503450819633875619n;

/**
 * Encode a authorize block for the authorize endpoint
 * @param {{ hosts: bigint[] }} args
 * @returns {string} Encoded block bytes
 */
export function authorize(args = {}) {
    return encodeBlock("authorize(uint[] hosts)", args);
}

/**
 * Encode a full authorize step for the authorize endpoint
 * @param {{ hosts: bigint[] }} args
 * @returns {string} Encoded step bytes
 */
export function authorizeStep(args = {}) {
    return encodeStep(authorizeId, 0n, authorize(args));
}

/** @type {bigint} Endpoint ID for unauthorize */
export const unauthorizeId = 39507870295436024707056532015524311693954508427949573885202905091620398959267n;

/**
 * Encode a unauthorize block for the unauthorize endpoint
 * @param {{ hosts: bigint[] }} args
 * @returns {string} Encoded block bytes
 */
export function unauthorize(args = {}) {
    return encodeBlock("unauthorize(uint[] hosts)", args);
}

/**
 * Encode a full unauthorize step for the unauthorize endpoint
 * @param {{ hosts: bigint[] }} args
 * @returns {string} Encoded step bytes
 */
export function unauthorizeStep(args = {}) {
    return encodeStep(unauthorizeId, 0n, unauthorize(args));
}

/** @type {bigint} Endpoint ID for relocate */
export const relocateId = 100443208725766122487194802942574403209532080320754318632249230172531528829603n;

/**
 * Encode a relocate block for the relocate endpoint
 * @param {{ to: string, min: bigint, max: bigint }} args
 * @returns {string} Encoded block bytes
 */
export function relocate(args = {}) {
    return encodeBlock("relocate(address to, uint min, uint max)", args);
}

/**
 * Encode a full relocate step for the relocate endpoint
 * @param {{ to: string, min: bigint, max: bigint }} args
 * @returns {string} Encoded step bytes
 */
export function relocateStep(args = {}) {
    return encodeStep(relocateId, 0n, relocate(args));
}

/** @type {bigint} Endpoint ID for inject */
export const injectId = 35264053893621121577913027098014901379338636287460203966405244186535445138083n;

/** @type {bigint} Endpoint ID for pipe */
export const pipeId = 82721782434100475221555389965432781134020640369260464492186320090831072529059n;

/** @type {bigint} Endpoint ID for resume */
export const resumeId = 87861467618885060593832557820818120708461818836795977069113511145125579328163n;

/** @type {bigint} Endpoint ID for setup */
export const setupId = 31272755109309471534191651515949536646444688422852973643154019655385137810083n;

/**
 * Encode a debitFrom block for the setup endpoint
 * @param {{ use: bigint, min: bigint, max: bigint, bounty?: bigint }} args
 * @returns {string} Encoded block bytes
 */
export function debitFrom(args = {}) {
    return encodeBlock("debitFrom(uint use, uint min, uint max, uint bounty)", args);
}

/**
 * Encode a full debitFrom step for the setup endpoint
 * @param {{ use: bigint, min: bigint, max: bigint, bounty?: bigint }} args
 * @returns {string} Encoded step bytes
 */
export function debitFromStep(args = {}) {
    return encodeStep(setupId, 0n, debitFrom(args));
}

/** @type {bigint} Endpoint ID for resolve */
export const resolveId = 11388583913720572954747307545628136756200417429807584944095133063384537762467n;

/**
 * Encode a creditTo block for the resolve endpoint
 * @param {{ to: bigint }} args
 * @returns {string} Encoded block bytes
 */
export function creditTo(args = {}) {
    return encodeBlock("creditTo(uint to)", args);
}

/**
 * Encode a full creditTo step for the resolve endpoint
 * @param {{ to: bigint }} args
 * @returns {string} Encoded step bytes
 */
export function creditToStep(args = {}) {
    return encodeStep(resolveId, 0n, creditTo(args));
}

/** @type {bigint} Endpoint ID for transact */
export const transactId = 111357507973462904529588818280263781103895375063071745173843609288553593834147n;

/** @type {bigint} Endpoint ID for isTrusted */
export const isTrustedId = 2312236271581371679440001619610394169878086619985807782052037545776918301347n;

/** @type {bigint} Endpoint ID for getBalances */
export const getBalancesId = 51732848756553988820676281257279128027103427814261481855180686216174637681315n;
