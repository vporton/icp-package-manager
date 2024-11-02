/// TODO: unused code?
import { readFileSync } from 'fs';
import { exec, execSync } from "child_process";
import { Actor, createAssetCanisterActor, HttpAgent } from "@dfinity/agent";
import { Principal } from "@dfinity/principal";
import { decodeFile } from "./lib/key";
import { SharedRealPackageInfo, _SERVICE as RepositoryPartition } from '../src/declarations/RepositoryPartition/RepositoryPartition.did';
import { idlFactory as repositoryPartitionIdl } from '../src/declarations/RepositoryPartition';
import { idlFactory as bootstrapperIdl } from '../src/declarations/bootstrapper';
import { Location, SharedModule, _SERVICE as RepositoryIndex } from '../src/declarations/RepositoryIndex/RepositoryIndex.did';
import { idlFactory as repositoryIndexIdl } from '../src/declarations/RepositoryIndex';
import { SharedPackageInfo } from '../src/declarations/RepositoryPartition/RepositoryPartition.did';
import { SharedFullPackageInfo } from '../src/declarations/RepositoryPartition/RepositoryPartition.did';
import { config as dotenv_config } from 'dotenv';
import node_fetch from 'node-fetch';
import { Bootstrap } from '../src/declarations/bootstrapper/bootstrapper.did';

dotenv_config({ path: '.env' });

global.fetch = node_fetch as any;

execSync("dfx ledger fabricate-cycles --amount 100000000 --canister RepositoryIndex")
execSync("dfx ledger fabricate-cycles --amount 100000000 --canister bootstrapper")
execSync("dfx ledger fabricate-cycles --amount 100000000 --canister cycles_ledger") // FIXME: only if local

function commandOutput(command: string): Promise<string> {
    return new Promise((resolve) => exec(command, function(error, stdout, stderr){ resolve(stdout); }));
}

// TODO: Disallow to run it two times in a row.
async function main() {
    const key = await commandOutput("dfx identity export Zon");
    const identity = decodeFile(key);

    const frontendBlob = Uint8Array.from(readFileSync(".dfx/local/canisters/bootstrapper_frontend/bootstrapper_frontend.wasm.gz"));
    const pmBackendBlob = Uint8Array.from(readFileSync(".dfx/local/canisters/package_manager/package_manager.wasm"));
    // const counterBlob = Uint8Array.from(readFileSync(".dfx/local/canisters/counter/counter.wasm"));

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
        callbacks: []
    });
    const pmBackendModule = await repositoryIndex.uploadModule({code: {Wasm: pmBackendBlob}, callbacks: []});

    console.log("Creating packages...");
    const real: SharedRealPackageInfo = {
        modules: [['frontend', [pmFrontendModule, true]], ['backend', [pmBackendModule, false]]],
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
        versionsMap: [],
    };
    await repositoryIndex.createPackage("icpack", pmFullInfo);

    // const counterInfo: SharedPackageInfo = {
    //     base: {
    //         name: "counter",
    //         version: "1.0.0",
    //         shortDescription: "Counter variable",
    //         longDescription: "Counter variable controlled by a shared method",
    //     },
    //     specific: { real: await repositoryIndex.uploadRealPackageInfo({
    //         modules: [['backend', {Wasm: counterBlob}]],
    //         extraModules: [],
    //         dependencies: [],
    //         functions: [],
    //         permissions: [],
    //     }) },
    // };
    // const counterFullInfo: SharedFullPackageInfo = {
    //     packages: [["1.0.0", counterInfo]],
    //     versionsMap: [],
    // };
    // await repositoryIndex.createPackage("counter", counterFullInfo);

    console.log("Setting bootstrapper...");
    const bootstrapper: Bootstrap = Actor.createActor(bootstrapperIdl, {agent, canisterId: process.env.CANISTER_ID_BOOTSTRAPPER!});
    await bootstrapper.init();
    await bootstrapper.setOurModules({pmFrontendModule, pmBackendModule});
}

// TODO: Remove?
// function getModuleLocation(m: SharedModule): Location {
//     return (m as any).Wasm !== undefined ? (m as any).Wasm : (m as any).Assets.wasm;
// }

main()