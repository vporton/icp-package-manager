import { readFileSync } from 'fs';
import { exec, execSync } from "child_process";
import { Actor, HttpAgent } from "@dfinity/agent";
import { Principal } from "@dfinity/principal";
import { decodeFile } from "./lib/key";
import { _SERVICE as RepositoryPartition } from '../src/declarations/RepositoryPartition/RepositoryPartition.did';
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

    const wasm = readFileSync(".dfx/local/canisters/counter/counter.wasm");
    const blob = Uint8Array.from(wasm);
    // const wasmX = readFileSync(".dfx/local/canisters/package_manager/package_manager.wasm");
    // const blobX = Uint8Array.from(wasmX);
    // const wasmY = readFileSync(".dfx/local/canisters/package_manager_frontend/package_manager_frontend.wasm");
    // const blobY = Uint8Array.from(wasmY);

    // const ids = readFileSync('.dfx/local/canister_ids.json', {encoding: 'utf-8'});
    // const ids_j = JSON.parse(ids);
    // const repositoryIndex = ids_j['RepositoryIndex']['local']

    const agent = new HttpAgent({host: "http://localhost:4943", identity})
    agent.fetchRootKey(); // TODO: should not be used in production.

    const repositoryIndex: RepositoryIndex = Actor.createActor(repositoryIndexIdl, {agent, canisterId: process.env.CANISTER_ID_REPOSITORYINDEX!});
    // console.log("Repository init...")
    // try {
    //     await repositoryIndex.init();
    // }
    // catch (e) {
    //     if (!/already initialized/.test((e as any).toString())) {
    //         throw e;
    //     }
    // }
    console.log("Setting repository name...")
    await repositoryIndex.setRepositoryName("RedSocks");

    console.log("Uploading WASM code...");
    // let wasmPart0X: string = await repositoryIndex.getLastCanistersByPK("wasms");
    // let wasmPartX = Actor.createActor(repositoryPartitionIdl, {agent, canisterId: wasmPart0X});
    // await wasmPartX.putAttribute("0", "w", {blob: blobX}); // FIXME: not 0 in general
    // let pPart0X = await repositoryIndex.getLastCanistersByPK("main"); // FIXME: Receive it from `setFullPackageInfo`.
    // let pPartX = Actor.createActor(repositoryPartitionIdl, {agent, canisterId: pPart0X});

    // let wasmPart0Y: string = await repositoryIndex.getLastCanistersByPK("wasms");
    // let wasmPartY = Actor.createActor(repositoryPartitionIdl, {agent, canisterId: wasmPart0Y});
    // await wasmPartY.putAttribute("0", "w", {blob: blobY}); // FIXME: not 0 in general
    // let pPart0Y = await repositoryIndex.getLastCanistersByPK("main"); // FIXME: Receive it from `setFullPackageInfo`.
    // let pPartY = Actor.createActor(repositoryPartitionIdl, {agent, canisterId: pPart0Y});

    let wasmPart0: string = await repositoryIndex.getLastCanistersByPK("wasms");
    let wasmPart = Actor.createActor(repositoryPartitionIdl, {agent, canisterId: wasmPart0});
    await wasmPart.putAttribute("0", "w", {blob: blob}); // FIXME: not 0 in general
    let pPart0 = await repositoryIndex.getLastCanistersByPK("main"); // FIXME: Receive it from `setFullPackageInfo`.
    let pPart = Actor.createActor(repositoryPartitionIdl, {agent, canisterId: pPart0});

    // const infoX: PackageInfo = {
    //     base: {
    //         name: "package-manager",
    //         version: "0.0.1",
    //         shortDescription: "Package manager",
    //         longDescription: "Package manager to install/remove software in a user's subnet",
    //     },
    //     specific: { real: {
    //         modules: [[Principal.fromText(wasmPart0X), "0"], [Principal.fromText(wasmPart0Y), "0"]], // FIXME: not 0 in general
    //         dependencies: [],
    //         functions: [],
    //         permissions: [],
    //     } },
    // };
    // const fullInfoX: FullPackageInfo = {
    //     packages: [["0.0.1", infoX]],
    //     versionsMap: [],
    // };
    // await pPart.setFullPackageInfo("package-manager", fullInfoX);

    const info: PackageInfo = {
        base: {
            name: "counter",
            version: "1.0.0",
            shortDescription: "Counter variable",
            longDescription: "Counter variable controlled by a shared method",
        },
        specific: { real: {
            modules: [{Wasm: [Principal.fromText(wasmPart0), "0"]}], // FIXME: not 0 in general
            dependencies: [],
            functions: [],
            permissions: [],
        } },
    };
    const fullInfo: FullPackageInfo = {
        packages: [["1.0.0", info]],
        versionsMap: [],
    };
    await pPart.setFullPackageInfo("counter", fullInfo);
}

main()