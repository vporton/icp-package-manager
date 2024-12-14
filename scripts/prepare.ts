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
    execSync("dfx ledger fabricate-cycles --amount 100000000 --canister BootstrapperIndirectCaller");
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
    const pmIndirectBlob = Uint8Array.from(readFileSync(".dfx/local/canisters/BootstrapperIndirectCaller/BootstrapperIndirectCaller.wasm"));
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
        forceReinstall: false,
        callbacks: [],
    });
    const pmBackendModule = await repositoryIndex.uploadModule({
        code: {Wasm: pmBackendBlob},
        forceReinstall: false,
        callbacks: [[{CodeInstalledForAllCanisters: null}, {moduleName: "backend", method: "init"}]], // TODO: I specify the canister twice: here and by var name.
    });
    const pmIndirectModule = await repositoryIndex.uploadModule({
        code: {Wasm: pmIndirectBlob},
        forceReinstall: true,
        callbacks: [[{CodeInstalledForAllCanisters: null}, {moduleName: "indirect", method: "init"}]], // TODO: I specify the canister twice: here and by var name.
    });
    const pmExampleFrontend = await repositoryIndex.uploadModule({
        code: {Wasm: pmExampleFrontendBlob},
        forceReinstall: false,
        callbacks: [],
    });

    console.log("Creating packages...");
    const real: SharedRealPackageInfo = {
        modules: [
            // "backend" goes first, because it stores installation information.
            ['backend', [pmBackendModule, true]], // TODO: Make this boolean a named parameter instead.
            ['frontend', [pmFrontendModule, true]],
            ['indirect', [pmIndirectModule, true]],
        ],
        dependencies: [],
        functions: [],
        permissions: [],
    };
    const pmInfo: SharedPackageInfo = {
        base: {
            name: "icpack",
            version: "0.0.1",
            shortDescription: "Package manager",
            longDescription: "Manager for installing ICP app to user's subnet",
        },
        specific: {real},
    };
    const pmFullInfo: SharedFullPackageInfo = {
        packages: [["0.0.1", pmInfo]], // TODO: Change to "stable"
        versionsMap: [["stable", "0.0.1"]],
    };
    await repositoryIndex.createPackage("icpack", pmFullInfo);

    const efReal: SharedRealPackageInfo = {
        modules: [
            ['example', [pmExampleFrontend, true]],
        ],
        dependencies: [],
        functions: [],
        permissions: [],
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