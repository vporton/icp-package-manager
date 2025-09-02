import { readFileSync } from 'fs';
import { execSync } from "child_process";
import { Actor, HttpAgent } from "@dfinity/agent";
import { Principal } from "@dfinity/principal";
import { decodeFile } from "./lib/key";
import { commandOutput } from "../src/lib/scripts";
import { Repository, SharedFullPackageInfo } from '../src/declarations/repository/repository.did';
import { idlFactory as repositoryIdl } from '../src/declarations/repository';
import { config as dotenv_config } from 'dotenv';
import node_fetch from 'node-fetch';
import { pmInfo } from './lib/pkg-data';

dotenv_config({ path: '.env' });

global.fetch = node_fetch as any;

const net = process.env.DFX_NETWORK!;

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

    const repository: Repository = Actor.createActor(repositoryIdl, {agent, canisterId: process.env.CANISTER_ID_REPOSITORY!});
    console.log("repository init...");
    try {
        await repository.init();
    }
    catch (e) {
        if (!/already initialized/.test((e as any).toString())) {
            throw e;
        }
    }
    console.log("Setting repository name...")
    await repository.setRepositoryName("RedSocks");

    console.log("Setting repository versions...")
    await repository.setDefaultVersions({versions: ['stable'], defaultVersionIndex: BigInt(0)});

    console.log("Uploading WASM code..."); // FIXME@P3: duplicate code
    const frontendBlob = Uint8Array.from(readFileSync(`.dfx/${net}/canisters/bootstrapper_frontend/bootstrapper_frontend.wasm.gz`));
    const pmBackendBlob = Uint8Array.from(readFileSync(`.dfx/${net}/canisters/package_manager/package_manager.wasm`));
    const pmMainIndirectBlob = Uint8Array.from(readFileSync(`.dfx/${net}/canisters/main_indirect/main_indirect.wasm`));
    const pmSimpleIndirectBlob = Uint8Array.from(readFileSync(`.dfx/${net}/canisters/simple_indirect/simple_indirect.wasm`));
    const pmBatteryBlob = Uint8Array.from(readFileSync(`.dfx/${net}/canisters/battery/battery.wasm`));

    console.log("Uploading modules..."); // FIXME@P3: duplicate code
    const pmFrontendModule = await repository.uploadModule({Assets: {wasm: frontendBlob, assets: Principal.fromText(process.env.CANISTER_ID_PACKAGE_MANAGER_FRONTEND!)}});
    const pmBackendModule = await repository.uploadModule({Wasm: pmBackendBlob});
    const pmMainIndirectModule = await repository.uploadModule({Wasm: pmMainIndirectBlob});
    const pmSimpleIndirectModule = await repository.uploadModule({Wasm: pmSimpleIndirectBlob});
    const pmBatteryModule = await repository.uploadModule({Wasm: pmBatteryBlob});

    console.log("Creating PM package...");
    await repository.addPackageVersion( // TODO@P2: What if it already exists?
        pmInfo,
        [ // TODO@P3: duplicate code
            ["battery", pmBatteryModule],
            ["backend", pmBackendModule],
            ["frontend", pmFrontendModule],
            ["main_indirect", pmMainIndirectModule],
            ["simple_indirect", pmSimpleIndirectModule],
        ],
        "0.0.1",
    );

    console.log("Cleaning unused WASMs...");
    await repository.cleanUnusedWasms();
}

main()