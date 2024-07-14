import { readFileSync } from 'fs';
import { exec, execSync } from "child_process";
import { Actor, HttpAgent } from "@dfinity/agent";
import { Principal } from "@dfinity/principal";
import { decodeFile } from "./lib/key";
import { _SERVICE as RepositoryPartition } from '../src/declarations/RepositoryPartition/RepositoryPartition.did';
import { idlFactory as repositoryPartitionIdl } from '../src/declarations/RepositoryPartition';
import { _SERVICE as RepositoryIndex } from '../src/declarations/RepositoryIndex/RepositoryIndex.did';
import { idlFactory as repositoryIndexIdl } from '../src/declarations/RepositoryIndex';
import { PackageInfo } from '../src/declarations/package_manager/package_manager.did';
import { FullPackageInfo } from '../src/declarations/RepositoryPartition/RepositoryPartition.did';
import { config as dotenv_config } from 'dotenv';

dotenv_config({ path: '.env' });

execSync("dfx ledger fabricate-cycles --amount 100000000 --canister RepositoryIndex")

function commandOutput(command: string): Promise<string> {
    return new Promise((resolve) => exec(command, function(error, stdout, stderr){ resolve(stdout); }));
}

async function main() {
    const key = await commandOutput("dfx identity export Zon");
    const identity = decodeFile(key);

    const wasm = readFileSync(".dfx/local/canisters/counter/counter.wasm");
    const blob = Uint8Array.from(wasm);

    // const ids = readFileSync('.dfx/local/canister_ids.json', {encoding: 'utf-8'});
    // const ids_j = JSON.parse(ids);
    // const repositoryIndex = ids_j['RepositoryIndex']['local']

    const agent = new HttpAgent({host: "http://localhost:4943", identity})
    agent.fetchRootKey(); // TODO: should not be used in production.

    const repositoryIndex: RepositoryIndex = Actor.createActor(repositoryIndexIdl, {agent, canisterId: process.env.CANISTER_ID_REPOSITORYINDEX!});
    console.log("Repository init...")
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
    let wasmPart0: string = await repositoryIndex.getLastCanistersByPK("wasms");
    let wasmPart = Actor.createActor(repositoryPartitionIdl, {agent, canisterId: wasmPart0});
    await wasmPart.putAttribute("0", "w", {blob: blob}); // FIXME: not 0 in general
    let pPart0 = await repositoryIndex.getLastCanistersByPK("main"); // FIXME: Receive it from `setFullPackageInfo`.
    let pPart = Actor.createActor(repositoryPartitionIdl, {agent, canisterId: pPart0});

    const info: PackageInfo = {
        base: {
            name: "counter",
            version: "1.0.0",
            shortDescription: "Counter variable",
            longDescription: "Counter variable controlled by a shared method",
        },
        specific: { real: {
            wasms: [[Principal.fromText(wasmPart0), "0"]], // FIXME: not 0 in general
            dependencies: [],
            functions: [],
            permissions: [],
        } },
    };
    const fullInfo: FullPackageInfo = {
        packages: [["stable", info]],
        versionsMap: [],
    };
    await pPart.setFullPackageInfo("counter", fullInfo);
}

main()