/// TODO: unused code?
import { readFileSync } from 'fs';
import { exec, execSync } from "child_process";
import { Actor, createAssetCanisterActor, HttpAgent } from "@dfinity/agent";
import { Principal } from "@dfinity/principal";
import { decodeFile } from "./lib/key";
import { SharedRealPackageInfo, _SERVICE as RepositoryPartition } from '../src/declarations/RepositoryPartition/RepositoryPartition.did';
import { idlFactory as repositoryPartitionIdl } from '../src/declarations/RepositoryPartition';
import { Location, SharedModule, _SERVICE as RepositoryIndex } from '../src/declarations/RepositoryIndex/RepositoryIndex.did';
import { idlFactory as repositoryIndexIdl } from '../src/declarations/RepositoryIndex';
import { SharedPackageInfo } from '../src/declarations/RepositoryPartition/RepositoryPartition.did';
import { SharedFullPackageInfo } from '../src/declarations/RepositoryPartition/RepositoryPartition.did';
import { config as dotenv_config } from 'dotenv';
import node_fetch from 'node-fetch';

dotenv_config({ path: '.env' });

global.fetch = node_fetch as any;

if (process.env.DFX_NETWORK === 'local') {
    execSync("dfx ledger fabricate-cycles --amount 100000000 --canister RepositoryIndex");
    execSync("dfx ledger fabricate-cycles --amount 100000000 --canister Bootstrapper");
    execSync("dfx ledger fabricate-cycles --amount 100000000 --canister cycles_ledger");
} else {
    // TODO
} 

function commandOutput(command: string): Promise<string> {
    return new Promise((resolve) => exec(command, function(error, stdout, stderr){ resolve(stdout); }));
}

// TODO: Disallow to run it two times in a row.
async function main() {
    const key = await commandOutput("dfx identity export Zon");
    const identity = decodeFile(key);

    const frontendBlob = Uint8Array.from(readFileSync(".dfx/local/canisters/bootstrapper_frontend/bootstrapper_frontend.wasm.gz"));
    const pmBackendBlob = Uint8Array.from(readFileSync(".dfx/local/canisters/package_manager/package_manager.wasm"));
    const pmIndirectBlob = Uint8Array.from(readFileSync(".dfx/local/canisters/indirect_caller/indirect_caller.wasm"));
    const pmSimpleIndirectBlob = Uint8Array.from(readFileSync(".dfx/local/canisters/simple_indirect/simple_indirect.wasm"));
    const pmExampleFrontendBlob = Uint8Array.from(readFileSync(".dfx/local/canisters/example_frontend/example_frontend.wasm.gz"));

    const agent = new HttpAgent({host: "http://localhost:4943", identity})
    agent.fetchRootKey(); // TODO: should not be used in production.

    const repositoryIndex: RepositoryIndex = Actor.createActor(repositoryIndexIdl, {agent, canisterId: process.env.CANISTER_ID_REPOSITORYINDEX!});
    console.log("Repository init...");
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

    console.log("Uploading WASM code...");
    const pmFrontendModule = await repositoryIndex.uploadModule({
        code: {Assets: {wasm: frontendBlob, assets: Principal.fromText(process.env.CANISTER_ID_PACKAGE_MANAGER_FRONTEND!)}},
        installByDefault: true,
        forceReinstall: false,
        callbacks: [],
    });
    const pmBackendModule = await repositoryIndex.uploadModule({
        code: {Wasm: pmBackendBlob},
        installByDefault: true,
        forceReinstall: false,
        callbacks: [], // [[{CodeInstalledForAllCanisters: null}, {method: "init"}]],
    });
    const pmIndirectModule = await repositoryIndex.uploadModule({
        code: {Wasm: pmIndirectBlob},
        installByDefault: true,
        forceReinstall: true,
        callbacks: [[{CodeInstalledForAllCanisters: null}, {method: "init"}]],
    });
    const pmSimpleIndirectModule = await repositoryIndex.uploadModule({
        code: {Wasm: pmSimpleIndirectBlob},
        installByDefault: true,
        forceReinstall: true,
        callbacks: [[{CodeInstalledForAllCanisters: null}, {method: "init"}]],
    });
    const pmExampleFrontend = await repositoryIndex.uploadModule({
        code: {Assets: {assets: Principal.fromText(process.env.CANISTER_ID_EXAMPLE_FRONTEND!), wasm: pmExampleFrontendBlob}},
        installByDefault: true,
        forceReinstall: false,
        callbacks: [],
    });

    console.log("Creating packages...");
    const pmReal: SharedRealPackageInfo = {
        modules: [
            // "backend" goes first, because it stores installation information.
            ['backend', pmBackendModule],
            ['frontend', pmFrontendModule],
            ['indirect', pmIndirectModule],
            ['simple_indirect', pmSimpleIndirectModule],
        ],
        dependencies: [],
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
        },
        specific: {real: pmReal},
    };
    const pmFullInfo: SharedFullPackageInfo = {
        packages: [["0.0.1", pmInfo]], // TODO: Change to "stable"
        versionsMap: [["stable", "0.0.1"]],
    };
    await repositoryIndex.createPackage("icpack", pmFullInfo);

    const efReal: SharedRealPackageInfo = {
        modules: [
            ['example1', pmExampleFrontend],
        ],
        dependencies: [],
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
        },
        specific: {real: efReal},
    };
    const pmEFFullInfo: SharedFullPackageInfo = {
        packages: [["0.0.1", pmEFInfo]], // TODO: Change to "stable"
        versionsMap: [["stable", "0.0.1"]],
    };
    await repositoryIndex.createPackage("example", pmEFFullInfo);
}

// TODO: Remove?
// function getModuleLocation(m: SharedModule): Location {
//     return (m as any).Wasm !== undefined ? (m as any).Wasm : (m as any).Assets.wasm;
// }

main()