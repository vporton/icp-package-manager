import { readFileSync } from "fs";
import { submit } from "../icpack-js/submitPkg";
import { CheckInitializedCallback, SharedPackageInfoTemplate } from "../src/declarations/repository/repository.did";
import { decodeFile } from "./lib/key";
import { commandOutput } from "../src/lib/scripts";
import { createActor as createRepository } from '../src/declarations/repository';
import { Principal } from "@dfinity/principal";
import { HttpAgent } from "@dfinity/agent";

const pmReal = {
    modules: [
        // TODO@P3: using magic with TS types
        ['battery', undefined] as [string, never], // `battery` needs to be initialized first for bootstrapping, because creating other modules use the battery.
        ['backend', undefined] as [string, never],
        ['frontend', undefined] as [string, never],
        ['main_indirect', undefined] as [string, never],
        ['simple_indirect', undefined] as [string, never],
    ],
    dependencies: [],
    suggests: [],
    recommends: [],
    functions: [],
    permissions: [],
    checkInitializedCallback: [{moduleName: 'backend', how: {methodName: 'isAllInitialized'}}] as [CheckInitializedCallback],
    frontendModule: ['frontend'] as [string],
};
const pmInfo: SharedPackageInfoTemplate = {
    base: {
        name: "icpack",
        version: "0.0.1", // FIXME@P1: It's superfluous here.
        price: 0n,
        upgradePrice: 0n,
        shortDescription: "Package manager",
        longDescription: "Manager for installing ICP app to user's subnet",
        guid: Uint8Array.from([83,  42, 115, 145, 27, 107,  70, 196, 150, 131,  3,  14, 110, 136, 210,  74]),
        developer: [],
    },
    specific: {real: pmReal},
};
const efReal = {
    modules: [
        ['example1', undefined] as [string, never],
        ['example2', undefined] as [string, never],
    ],
    dependencies: [],
    suggests: [],
    recommends: [],
    functions: [],
    permissions: [],
    checkInitializedCallback: [{moduleName: 'example1', how: {urlPath: '/index.html'}}] as [CheckInitializedCallback],
    frontendModule: ['example1'] as [string],
};
const pmEFInfo: SharedPackageInfoTemplate = {
    base: {
        name: "example",
        version: "0.0.1",
        price: 0n,
        upgradePrice: 0n,
        shortDescription: "Example package",
        longDescription: "Used as an example",
        guid: Uint8Array.from([39, 165, 164, 221, 113,  51,  73,  53, 145, 150,  31,  42, 238, 133, 124, 210]),
        developer: [],
    },
    specific: {real: efReal},
};
const walletReal = {
    modules: [
        ['frontend', undefined] as [string, never],
        ['backend', undefined] as [string, never],
    ],
    dependencies: [],
    suggests: [],
    recommends: [],
    functions: [],
    permissions: [],
    checkInitializedCallback: [{moduleName: 'backend', how: {methodName: 'isAllInitialized'}}] as [CheckInitializedCallback],
    frontendModule: ['frontend'] as [string],
};
const walletInfo: SharedPackageInfoTemplate = {
    base: {
        name: "wallet",
        version: "0.0.1",
        price: 0n,
        upgradePrice: 0n,
        shortDescription: "Wallet for IC Pack",
        longDescription: "Wallet for IC Pack, used among other for in-app payments",
        guid: Uint8Array.from([206,  18, 101,   7, 174, 170, 142, 240,  90, 165, 231, 131, 186, 119, 122,  57]),
        developer: [],
    },
    specific: {real: walletReal},
};


const frontendBlob = Uint8Array.from(readFileSync(`.dfx/${net}/canisters/bootstrapper_frontend/bootstrapper_frontend.wasm.gz`));
const pmBackendBlob = Uint8Array.from(readFileSync(`.dfx/${net}/canisters/package_manager/package_manager.wasm`));
const pmMainIndirectBlob = Uint8Array.from(readFileSync(`.dfx/${net}/canisters/main_indirect/main_indirect.wasm`));
const pmSimpleIndirectBlob = Uint8Array.from(readFileSync(`.dfx/${net}/canisters/simple_indirect/simple_indirect.wasm`));
const pmBatteryBlob = Uint8Array.from(readFileSync(`.dfx/${net}/canisters/battery/battery.wasm`));
const pmExampleFrontendBlob = Uint8Array.from(readFileSync(`.dfx/${net}/canisters/example_frontend/example_frontend.wasm.gz`));
const pmExampleBackendBlob = Uint8Array.from(readFileSync(`.dfx/${net}/canisters/example_backend/example_backend.wasm`));
const walletFrontendBlob = Uint8Array.from(readFileSync(`.dfx/${net}/canisters/wallet_frontend/wallet_frontend.wasm.gz`));
const walletBackendBlob = Uint8Array.from(readFileSync(`.dfx/${net}/canisters/wallet_backend/wallet_backend.wasm`));

async function main({testMode}: {testMode: boolean}) {
    const key = await commandOutput("dfx identity export `dfx identity whoami`"); // secret key
    const identity = decodeFile(key);
    const agent = await HttpAgent.create({identity, host: testMode ? "http://localhost:8080" : undefined, shouldFetchRootKey: testMode});
    const repositoryIndex = createRepository(Principal.fromText(process.env.CANISTER_ID_REPOSITORY!), {agent});
    const pmFrontendModule = await repositoryIndex.uploadModule({
        code: {Assets: {wasm: frontendBlob, assets: Principal.fromText(process.env.CANISTER_ID_PACKAGE_MANAGER_FRONTEND!)}},
        installByDefault: true,
        forceReinstall: false,
        callbacks: [],
        canisterVersion: [],
    });
    const pmBackendModule = await repositoryIndex.uploadModule({
        code: {Wasm: pmBackendBlob},
        installByDefault: true,
        forceReinstall: false,
        canisterVersion: [],
        callbacks: [
            [{CodeInstalledForAllCanisters: null}, {method: "init"}],
            [{WithdrawCycles: null}, {method: "withdrawCycles"}],
        ],
    });
    const exampleFrontend = await repositoryIndex.uploadModule({
        code: {Assets: {assets: Principal.fromText(process.env.CANISTER_ID_EXAMPLE_FRONTEND!), wasm: pmExampleFrontendBlob}},
        installByDefault: true,
        forceReinstall: false,
        canisterVersion: [],
        callbacks: [],
    });
    const exampleBackend = await repositoryIndex.uploadModule({
        code: {Wasm: pmExampleBackendBlob},
        installByDefault: true,
        forceReinstall: false,
        canisterVersion: [],
        callbacks: [
            [{WithdrawCycles: null}, {method: "withdrawCycles"}],
        ],
    });
    const walletFrontend = await repositoryIndex.uploadModule({
        code: {Assets: {assets: Principal.fromText(process.env.CANISTER_ID_WALLET_FRONTEND!), wasm: walletFrontendBlob}},
        installByDefault: true,
        forceReinstall: false,
        canisterVersion: [],
        callbacks: [],
    });
    const walletBackend = await repositoryIndex.uploadModule({
        code: {Wasm: walletBackendBlob},
        installByDefault: true,
        forceReinstall: false,
        canisterVersion: [],
        callbacks: [
            [{WithdrawCycles: null}, {method: "withdrawCycles"}],
        ],
    });
    const pmMainIndirectModule = await repositoryIndex.uploadModule({
        code: {Wasm: pmMainIndirectBlob},
        installByDefault: true,
        forceReinstall: true,
        canisterVersion: [],
        callbacks: [
            [{CodeInstalledForAllCanisters: null}, {method: "init"}],
            [{WithdrawCycles: null}, {method: "withdrawCycles"}],
        ],
    });
    const pmSimpleIndirectModule = await repositoryIndex.uploadModule({
        code: {Wasm: pmSimpleIndirectBlob},
        installByDefault: true,
        forceReinstall: true,
        canisterVersion: [],
        callbacks: [
            [{CodeInstalledForAllCanisters: null}, {method: "init"}],
            [{WithdrawCycles: null}, {method: "withdrawCycles"}],
        ],
    });
    const pmBatteryModule = await repositoryIndex.uploadModule({
        code: {Wasm: pmBatteryBlob},
        installByDefault: true,
        forceReinstall: false,
        canisterVersion: [],
        callbacks: [
            [{CodeInstalledForAllCanisters: null}, {method: "init"}],
            [{WithdrawCycles: null}, {method: "withdrawCycles"}],
        ],
    });

    await submit([{
        name: "icpack",
        tmpl: pmInfo,
        modules: [
            ["battery", pmBatteryModule],
            ["backend", pmBackendModule],
            ["frontend", pmFrontendModule],
            ["main_indirect", pmMainIndirectModule],
            ["simple_indirect", pmSimpleIndirectModule],
        ],
    }, {
        name: "example",
        tmpl: pmEFInfo,
        modules: [
            ["example1", exampleFrontend],
            ["example2", exampleBackend],
        ],
    }, {
        name: "wallet",
        tmpl: walletInfo,
        modules: [
            ["frontend", exampleFrontend],
            ["backend", exampleBackend],
        ],
    }], identity)
}

main({testMode: true}); // TODO@P1: `testMode` option.