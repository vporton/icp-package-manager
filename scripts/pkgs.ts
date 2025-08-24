import { CheckInitializedCallback, SharedPackageInfoTemplate } from "../src/declarations/repository/repository.did";

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
