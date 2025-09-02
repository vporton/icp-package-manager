import { Principal } from "@dfinity/principal";
import { CheckInitializedCallback, SharedPackageInfoTemplate, SharedRealPackageInfoBase_1 } from "../../src/declarations/repository/repository.did";

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
export const pmInfo: SharedPackageInfoTemplate = {
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
            code: {Assets: {assets: Principal.fromText(process.env.CANISTER_ID_EXAMPLE_FRONTEND!), wasm: null}}, // FIXME@P1: assets
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
export const pmEFInfo: SharedPackageInfoTemplate = {
    base: {
        name: "example",
        version: null,
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
export const walletInfo: SharedPackageInfoTemplate = {
    base: {
        name: "wallet",
        version: null,
        price: 0n,
        upgradePrice: 0n,
        shortDescription: "Wallet for IC Pack",
        longDescription: "Wallet for IC Pack, used among other for in-app payments",
        guid: Uint8Array.from([206,  18, 101,   7, 174, 170, 142, 240,  90, 165, 231, 131, 186, 119, 122,  57]),
        developer: [],
    },
    specific: {real: walletReal},
};
