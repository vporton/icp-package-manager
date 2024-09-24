/// TODO: unused code?
import { readFileSync } from 'fs';
import { exec, execSync } from "child_process";
import { Actor, createAssetCanisterActor, HttpAgent } from "@dfinity/agent";
import { Principal } from "@dfinity/principal";
import { decodeFile } from "./lib/key";
import { RealPackageInfo, _SERVICE as RepositoryPartition } from '../src/declarations/RepositoryPartition/RepositoryPartition.did';
import { idlFactory as repositoryPartitionIdl } from '../src/declarations/RepositoryPartition';
import { _SERVICE as RepositoryIndex } from '../src/declarations/RepositoryIndex/RepositoryIndex.did';
import { idlFactory as repositoryIndexIdl } from '../src/declarations/RepositoryIndex';
import { PackageInfo } from '../src/declarations/RepositoryPartition/RepositoryPartition.did';
import { FullPackageInfo } from '../src/declarations/RepositoryPartition/RepositoryPartition.did';
import { config as dotenv_config } from 'dotenv';
import node_fetch from 'node-fetch';

dotenv_config({ path: '.env' });

global.fetch = node_fetch as any;

execSync("dfx ledger fabricate-cycles --amount 100000000 --canister RepositoryIndex")

function commandOutput(command: string): Promise<string> {
    return new Promise((resolve) => exec(command, function(error, stdout, stderr){ resolve(stdout); }));
}

async function main() {
    const key = await commandOutput("dfx identity export Zon");
    const identity = decodeFile(key);

    const frontendBlob = Uint8Array.from(readFileSync(".dfx/local/canisters/bootstrapper_frontend/bootstrapper_frontend.wasm.gz"));
    const pmBackendBlob = Uint8Array.from(readFileSync(".dfx/local/canisters/package_manager/package_manager.wasm"));
    const counterBlob = Uint8Array.from(readFileSync(".dfx/local/canisters/counter/counter.wasm"));

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

    const real: RealPackageInfo = await repositoryIndex.uploadRealPackageInfo({
        modules: [['frontend', {Assets: {wasm: frontendBlob, assets: Principal.fromText(process.env.CANISTER_ID_BOOTSTRAPPER_FRONTEND!)}}]],
        extraModules: [['backend', {Wasm: pmBackendBlob}]],
        dependencies: [],
        functions: [],
        permissions: [],
    });
    const pmInfo: PackageInfo = {
        base: {
            name: "icpack",
            version: "0.0.1",
            shortDescription: "Package manager",
            longDescription: "Manager for installing ICP app to user's subnet",
        },
        specific: {real},
    };
    const pmFullInfo: FullPackageInfo = {
        packages: [["0.0.1", pmInfo]], // TODO: Change to "stable"
        versionsMap: [],
    };
    await repositoryIndex.createPackage("icpack", pmFullInfo);

    const counterInfo: PackageInfo = {
        base: {
            name: "counter",
            version: "1.0.0",
            shortDescription: "Counter variable",
            longDescription: "Counter variable controlled by a shared method",
        },
        specific: { real: await repositoryIndex.uploadRealPackageInfo({
            modules: [['backend', {Wasm: counterBlob}]],
            extraModules: [],
            dependencies: [],
            functions: [],
            permissions: [],
        }) },
    };
    const counterFullInfo: FullPackageInfo = {
        packages: [["1.0.0", counterInfo]],
        versionsMap: [],
    };
    await repositoryIndex.createPackage("counter", counterFullInfo);
}

main()