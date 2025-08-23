import { SharedRealPackageInfo } from "../src/declarations/repository/repository.did";

const pmReal: SharedRealPackageInfo = {
    modules: [
        ['battery', pmBatteryModule], // `battery` needs to be initialized first for bootstrapping, because creating other modules use the battery.
        ['backend', pmBackendModule],
        ['frontend', pmFrontendModule],
        ['main_indirect', pmMainIndirectModule],
        ['simple_indirect', pmSimpleIndirectModule],
    ],
    dependencies: [],
    suggests: [],
    recommends: [],
    functions: [],
    permissions: [],
    checkInitializedCallback: [{moduleName: 'backend', how: {methodName: 'isAllInitialized'}}],
    frontendModule: ['frontend'],
};
const pmInfo: SharedPackageInfo = {
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
