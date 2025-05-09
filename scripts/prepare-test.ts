import { readFileSync } from 'fs';
import { execSync } from "child_process";
import { Actor, HttpAgent } from "@dfinity/agent";
import { Principal } from "@dfinity/principal";
import { decodeFile } from "./lib/key";
import { commandOutput } from "../src/lib/scripts";
import { Repository, SharedRealPackageInfo } from '../src/declarations/repository/repository.did';
import { _SERVICE as repository } from '../src/declarations/repository/repository.did';
import { idlFactory as repositoryIndexIdl } from '../src/declarations/repository';
import { SharedPackageInfo } from '../src/declarations/repository/repository.did';
import { SharedFullPackageInfo } from '../src/declarations/repository/repository.did';
import { config as dotenv_config } from 'dotenv';
import node_fetch from 'node-fetch';

dotenv_config({ path: '.env' });

global.fetch = node_fetch as any;

if (process.env.DFX_NETWORK === 'local') {
    execSync("dfx ledger fabricate-cycles --amount 100000000 --canister repository");
    execSync("dfx ledger fabricate-cycles --amount 100000000 --canister bootstrapper");
    execSync("dfx ledger fabricate-cycles --amount 100000000 --canister cycles_ledger");
    execSync("dfx ledger fabricate-cycles --amount 100000000 --canister cmc");
}

async function main() {
    const key = await commandOutput("dfx identity export `dfx identity whoami`"); // secret key
    const identity = decodeFile(key);

    const frontendBlob = Uint8Array.from(readFileSync(".dfx/local/canisters/bootstrapper_frontend/bootstrapper_frontend.wasm.gz"));
    const pmBackendBlob = Uint8Array.from(readFileSync(".dfx/local/canisters/package_manager/package_manager.wasm"));
    const pmMainIndirectBlob = Uint8Array.from(readFileSync(".dfx/local/canisters/main_indirect/main_indirect.wasm"));
    const pmSimpleIndirectBlob = Uint8Array.from(readFileSync(".dfx/local/canisters/simple_indirect/simple_indirect.wasm"));
    const pmBatteryBlob = Uint8Array.from(readFileSync(".dfx/local/canisters/battery/battery.wasm"));
    const pmExampleFrontendBlob = Uint8Array.from(readFileSync(".dfx/local/canisters/example_frontend/example_frontend.wasm.gz"));
    const pmExampleBackendBlob = Uint8Array.from(readFileSync(".dfx/local/canisters/example_backend/example_backend.wasm"));

    const pmUpgradeable1V1Blob = Uint8Array.from(readFileSync(".dfx/local/canisters/upgrade_example_backend1_v1/upgrade_example_backend1_v1.wasm"));
    const pmUpgradeable2V1Blob = Uint8Array.from(readFileSync(".dfx/local/canisters/upgrade_example_backend2_v1/upgrade_example_backend2_v1.wasm"));
    const pmUpgradeable2V2Blob = Uint8Array.from(readFileSync(".dfx/local/canisters/upgrade_example_backend2_v2/upgrade_example_backend2_v2.wasm"));
    const pmUpgradeable3V2Blob = Uint8Array.from(readFileSync(".dfx/local/canisters/upgrade_example_backend3_v2/upgrade_example_backend3_v2.wasm"));

    const agent = new HttpAgent({host: "http://localhost:4943", identity}); // TODO@P3: Use `HttpAgent.create`.
    if (process.env.DFX_NETWORK === 'local') {
        agent.fetchRootKey();
    }

    const repositoryIndex: Repository = Actor.createActor(repositoryIndexIdl, {agent, canisterId: process.env.CANISTER_ID_REPOSITORY!});
    console.log("repository init...");
    try {
        await repositoryIndex.init();
    }
    catch (e) {
        if (!/already initialized/.test((e as any).toString())) {
            throw e;
        }
    }
    console.log("Setting repository name...")
    await repositoryIndex.setRepositoryName("RedSocks");

    console.log("Setting repository versions...")
    await repositoryIndex.setDefaultVersions({versions: ['stable'], defaultVersionIndex: BigInt(0)});

    console.log("Uploading WASM code...");
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

    const pmUpgradeable1V1 = await repositoryIndex.uploadModule({
        code: {Wasm: pmUpgradeable1V1Blob},
        installByDefault: true,
        forceReinstall: false,
        canisterVersion: [],
        callbacks: [
            [{WithdrawCycles: null}, {method: "withdrawCycles"}],
        ],
    });
    const pmUpgradeable2V1 = await repositoryIndex.uploadModule({
        code: {Wasm: pmUpgradeable2V1Blob},
        installByDefault: true,
        forceReinstall: false,
        canisterVersion: [],
        callbacks: [
            [{WithdrawCycles: null}, {method: "withdrawCycles"}],
        ],
    });
    const pmUpgradeable2V2 = await repositoryIndex.uploadModule({
        code: {Wasm: pmUpgradeable2V2Blob},
        installByDefault: true,
        forceReinstall: false,
        canisterVersion: [],
        callbacks: [
            [{WithdrawCycles: null}, {method: "withdrawCycles"}],
        ],
    });
    const pmUpgradeable3V2 = await repositoryIndex.uploadModule({
        code: {Wasm: pmUpgradeable3V2Blob},
        installByDefault: true,
        forceReinstall: false,
        canisterVersion: [],
        callbacks: [
            [{WithdrawCycles: null}, {method: "withdrawCycles"}],
        ],
    });

    console.log("Creating packages...");
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
            version: "0.0.1",
            shortDescription: "Package manager",
            longDescription: "Manager for installing ICP app to user's subnet",
            guid: Uint8Array.from([83,  42, 115, 145, 27, 107,  70, 196, 150, 131,  3,  14, 110, 136, 210,  74]),
        },
        specific: {real: pmReal},
    };
    const pmFullInfo: SharedFullPackageInfo = {
        packages: [["0.0.1", pmInfo]],
        versionsMap: [["stable", "0.0.1"]],
    };
    await repositoryIndex.setFullPackageInfo("icpack", pmFullInfo);

    const efReal: SharedRealPackageInfo = {
        modules: [
            ['example1', exampleFrontend],
            ['example2', exampleBackend],
        ],
        dependencies: [],
        suggests: [],
        recommends: [],
        functions: [],
        permissions: [],
        checkInitializedCallback: [{moduleName: 'example1', how: {urlPath: '/index.html'}}],
        frontendModule: ['example1'],
    };
    const pmEFInfo: SharedPackageInfo = {
        base: {
            name: "example",
            version: "0.0.1",
            shortDescription: "Example package",
            longDescription: "Used as an example",
            guid: Uint8Array.from([39, 165, 164, 221, 113,  51,  73,  53, 145, 150,  31,  42, 238, 133, 124, 210]),
        },
        specific: {real: efReal},
    };
    const pmEFFullInfo: SharedFullPackageInfo = {
        packages: [["0.0.1", pmEFInfo]],
        versionsMap: [["stable", "0.0.1"]],
    };
    await repositoryIndex.setFullPackageInfo("example", pmEFFullInfo);

    const upgradeableV1Real: SharedRealPackageInfo = {
        modules: [
            ['m1', pmUpgradeable1V1],
            ['m2', pmUpgradeable2V1],
        ],
        dependencies: [],
        suggests: [],
        recommends: [],
        functions: [],
        permissions: [],
        checkInitializedCallback: [],
        frontendModule: [],
    };
    const upgradeableV1Info: SharedPackageInfo = {
        base: {
            name: "upgradeable",
            version: "0.0.1",
            shortDescription: "Example upgradeable package",
            longDescription: "Used as an example",
            guid: Uint8Array.from([109, 30, 239, 245, 65, 4, 168, 138, 77, 89, 159, 205, 146, 220, 143, 20]),
        },
        specific: {real: upgradeableV1Real},
    };
    const upgradeableV2Real: SharedRealPackageInfo = {
        modules: [
            ['m2', pmUpgradeable2V2],
            ['m3', pmUpgradeable3V2],
        ],
        dependencies: [],
        suggests: [],
        recommends: [],
        functions: [],
        permissions: [],
        checkInitializedCallback: [],
        frontendModule: [],
    };
    const upgradeableV2Info: SharedPackageInfo = {
        base: {
            name: "upgradeable",
            version: "0.0.2",
            shortDescription: "Example upgradeable package",
            longDescription: "Used as an example",
            guid: Uint8Array.from([109, 30, 239, 245, 65, 4, 168, 138, 77, 89, 159, 205, 146, 220, 143, 20]),
        },
        specific: {real: upgradeableV2Real},
    };
    const upgradeableFullInfo: SharedFullPackageInfo = {
        packages: [["0.0.1", upgradeableV1Info], ["0.0.2", upgradeableV2Info]],
        versionsMap: [["stable", "0.0.1"], ["beta", "0.0.2"]],
    };
    await repositoryIndex.setFullPackageInfo("upgradeable", upgradeableFullInfo);
}

main()