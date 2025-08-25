import { readFileSync } from 'fs';
import { execSync } from "child_process";
import { Actor, HttpAgent } from "@dfinity/agent";
import { Principal } from "@dfinity/principal";
import { decodeFile } from "./lib/key";
import { commandOutput } from "../src/lib/scripts";
import { Repository, SharedRealPackageInfo } from '../src/declarations/repository/repository.did';
import { idlFactory as repositoryIndexIdl } from '../src/declarations/repository';
import { SharedPackageInfo } from '../src/declarations/repository/repository.did';
import { SharedFullPackageInfo } from '../src/declarations/repository/repository.did';
import { config as dotenv_config } from 'dotenv';
import node_fetch from 'node-fetch';

dotenv_config({ path: '.env' });

global.fetch = node_fetch as any;

const isLocal = process.env.DFX_NETWORK === 'local';

if (isLocal) {
    // TODO@P3: Is it necessary?
    // execSync("dfx ledger fabricate-cycles --amount 20000 --canister repository");
    // execSync("dfx ledger fabricate-cycles --amount 20000 --canister bootstrapper");
    // execSync("dfx ledger fabricate-cycles --amount 20000 --canister nns-ledger");
    // execSync("dfx ledger fabricate-cycles --amount 20000 --canister nns-cycles-minting");
}

async function main() {
    const key = await commandOutput("dfx identity export `dfx identity whoami`"); // secret key
    const identity = decodeFile(key);

    const agent = await HttpAgent.create({host: isLocal ? "http://localhost:8080" : undefined, identity, shouldFetchRootKey: isLocal});

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


    console.log("Creating packages...");

    console.log("Cleaning unused WASMs...");
    await repositoryIndex.cleanUnusedWasms();
}

main()