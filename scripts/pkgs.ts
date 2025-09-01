import { readFileSync } from "fs";
import { submit } from "../icpack-js/submitPkg";
import { CheckInitializedCallback, SharedModule, SharedModuleBase_1, SharedPackageInfoTemplate, SharedRealPackageInfoBase_1 } from "../src/declarations/repository/repository.did";
import { decodeFile } from "./lib/key";
import { commandOutput } from "../src/lib/scripts";
import { createActor as createRepository } from '../src/declarations/repository';
import { Principal } from "@dfinity/principal";
import { HttpAgent } from "@dfinity/agent";

const pmReal: SharedRealPackageInfoBase_1 = {
    modules: [
        ['battery', { // `battery` needs to be initialized first for bootstrapping, because creating other modules use the battery.
            code: {Wasm: null},
            installByDefault: true,
            forceReinstall: false,
            canisterVersion: [],
            callbacks: [
                [{CodeInstalledForAllCanisters: null}, {method: "init"}],
                [{WithdrawCycles: null}, {method: "withdrawCycles"}],
            ],
        }],
        ['backend', {
            code: {Wasm: null},
            installByDefault: true,
            forceReinstall: false,
            canisterVersion: [],
            callbacks: [
                [{CodeInstalledForAllCanisters: null}, {method: "init"}],
                [{WithdrawCycles: null}, {method: "withdrawCycles"}],
            ],
        }],
        ['frontend', {
            code: {Assets: {wasm: null, assets: Principal.fromText(process.env.CANISTER_ID_PACKAGE_MANAGER_FRONTEND!)}}, // FIXME@P1: assets
            installByDefault: true,
            forceReinstall: false,
            callbacks: [],
            canisterVersion: [],
        }],
        ['main_indirect', {
            code: {Wasm: null},
            installByDefault: true,
            forceReinstall: true,
            canisterVersion: [],
            callbacks: [
                [{CodeInstalledForAllCanisters: null}, {method: "init"}],
                [{WithdrawCycles: null}, {method: "withdrawCycles"}],
            ],
        }],
        ['simple_indirect', {
            code: {Wasm: null},
            installByDefault: true,
            forceReinstall: true,
            canisterVersion: [],
            callbacks: [
                [{CodeInstalledForAllCanisters: null}, {method: "init"}],
                [{WithdrawCycles: null}, {method: "withdrawCycles"}],
            ],
        }],
    ],
    dependencies: [],
    suggests: [],
    recommends: [],
    functions: [],
    permissions: [],
    checkInitializedCallback: [{moduleName: 'backend', how: {methodName: 'isAllInitialized'}}] as [CheckInitializedCallback],
    frontendModule: ['frontend'],
};
const pmInfo: SharedPackageInfoTemplate = {
    base: {
        name: "icpack",
        version: null,
        price: 0n,
        upgradePrice: 0n,
        shortDescription: "Package manager",
        longDescription: "Manager for installing ICP app to user's subnet",
        guid: Uint8Array.from([83,  42, 115, 145, 27, 107,  70, 196, 150, 131,  3,  14, 110, 136, 210,  74]),
        developer: [],
    },
    specific: {real: pmReal},
};
const efReal: SharedRealPackageInfoBase_1 = {
    modules: [
        ['example1', {
            code: {Assets: {assets: Principal.fromText(process.env.CANISTER_ID_EXAMPLE_FRONTEND!), Wasm: null}}, // FIXME@P1: assets
            installByDefault: true,
            forceReinstall: false,
            canisterVersion: [],
            callbacks: [],
        }],
        ['example2', {
            code: {Wasm: null},
            installByDefault: true,
            forceReinstall: false,
            canisterVersion: [],
            callbacks: [
                [{WithdrawCycles: null}, {method: "withdrawCycles"}],
            ],
        }],
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
        version: undefined as never,
        price: 0n,
        upgradePrice: 0n,
        shortDescription: "Example package",
        longDescription: "Used as an example",
        guid: Uint8Array.from([39, 165, 164, 221, 113,  51,  73,  53, 145, 150,  31,  42, 238, 133, 124, 210]),
        developer: [],
    },
    specific: {real: efReal},
};
const walletReal: SharedRealPackageInfoBase_1 = {
    modules: [
        ['frontend', {
            code: {Assets: {assets: Principal.fromText(process.env.CANISTER_ID_WALLET_FRONTEND!), wasm: null}}, // FIXME@P1: assets
            installByDefault: true,
            forceReinstall: false,
            canisterVersion: [],
            callbacks: [],
        }],
        ['backend', {
            code: {Wasm: null},
            installByDefault: true,
            forceReinstall: false,
            canisterVersion: [],
            callbacks: [
                [{WithdrawCycles: null}, {method: "withdrawCycles"}],
            ],
        }],
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
        version: undefined as never,
        price: 0n,
        upgradePrice: 0n,
        shortDescription: "Wallet for IC Pack",
        longDescription: "Wallet for IC Pack, used among other for in-app payments",
        guid: Uint8Array.from([206,  18, 101,   7, 174, 170, 142, 240,  90, 165, 231, 131, 186, 119, 122,  57]),
        developer: [],
    },
    specific: {real: walletReal},
};

const net = process.env.DFX_NETWORK!;

const frontendBlob = Uint8Array.from(readFileSync(`.dfx/${net}/canisters/bootstrapper_frontend/bootstrapper_frontend.wasm.gz`));
const pmBackendBlob = Uint8Array.from(readFileSync(`.dfx/${net}/canisters/package_manager/package_manager.wasm`));
const pmMainIndirectBlob = Uint8Array.from(readFileSync(`.dfx/${net}/canisters/main_indirect/main_indirect.wasm`));
const pmSimpleIndirectBlob = Uint8Array.from(readFileSync(`.dfx/${net}/canisters/simple_indirect/simple_indirect.wasm`));
const pmBatteryBlob = Uint8Array.from(readFileSync(`.dfx/${net}/canisters/battery/battery.wasm`));
const pmExampleFrontendBlob = Uint8Array.from(readFileSync(`.dfx/${net}/canisters/example_frontend/example_frontend.wasm.gz`));
const pmExampleBackendBlob = Uint8Array.from(readFileSync(`.dfx/${net}/canisters/example_backend/example_backend.wasm`));
const walletFrontendBlob = Uint8Array.from(readFileSync(`.dfx/${net}/canisters/wallet_frontend/wallet_frontend.wasm.gz`));
const walletBackendBlob = Uint8Array.from(readFileSync(`.dfx/${net}/canisters/wallet_backend/wallet_backend.wasm`));

async function main() {
    const key = await commandOutput("dfx identity export `dfx identity whoami`"); // secret key
    const identity = decodeFile(key);
    const agent = await HttpAgent.create({
        identity,
        host: net === 'local' ? "http://localhost:8080" : undefined,
        shouldFetchRootKey: net === 'local',
    });
    const repository = createRepository(Principal.fromText(process.env.CANISTER_ID_REPOSITORY!), {agent});
    // FIXME@P1: Check asset canisters.
    const pmFrontendModule = await repository.uploadModule({Assets: {wasm: frontendBlob, assets: Principal.fromText(process.env.CANISTER_ID_PACKAGE_MANAGER_FRONTEND!)}});
    const pmBackendModule = await repository.uploadModule({Wasm: pmBackendBlob});
    const exampleFrontend = await repository.uploadModule({Assets: {assets: Principal.fromText(process.env.CANISTER_ID_EXAMPLE_FRONTEND!), wasm: pmExampleFrontendBlob}});
    const exampleBackend = await repository.uploadModule({Wasm: pmExampleBackendBlob});
    const walletFrontend = await repository.uploadModule({Assets: {assets: Principal.fromText(process.env.CANISTER_ID_WALLET_FRONTEND!), wasm: walletFrontendBlob}});
    const walletBackend = await repository.uploadModule({Wasm: walletBackendBlob});
    const pmMainIndirectModule = await repository.uploadModule({Wasm: pmMainIndirectBlob});
    const pmSimpleIndirectModule = await repository.uploadModule({Wasm: pmSimpleIndirectBlob});
    const pmBatteryModule = await repository.uploadModule({Wasm: pmBatteryBlob});

    // FIXME@P1: Ask for more version strings. (Hm, there are several packages.)
    const version = await commandOutput("git rev-parse HEAD"); // FIXME@P1: Use it AFTER commit.

    await submit([{
        repo: Principal.fromText(process.env.CANISTER_ID_REPOSITORY!),
        tmpl: pmInfo,
        modules: [
            ["battery", pmBatteryModule],
            ["backend", pmBackendModule],
            ["frontend", pmFrontendModule],
            ["main_indirect", pmMainIndirectModule],
            ["simple_indirect", pmSimpleIndirectModule],
        ],
    }, {
        repo: Principal.fromText(process.env.CANISTER_ID_REPOSITORY!),
        tmpl: pmEFInfo,
        modules: [
            ["example1", exampleFrontend],
            ["example2", exampleBackend],
        ],
    }, {
        repo: Principal.fromText(process.env.CANISTER_ID_REPOSITORY!),
        tmpl: walletInfo,
        modules: [
            ["frontend", walletFrontend],
            ["backend", walletBackend],
        ],
    }], identity, version);
}

main();