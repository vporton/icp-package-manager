#!/usr/bin/env -S npx tsx

import { readFileSync } from "fs";
import { submit } from "../icpack-js/submitPkg";
import { CheckInitializedCallback, SharedModule, SharedModuleBase_1, SharedPackageInfoTemplate, SharedRealPackageInfoBase_1 } from "../src/declarations/repository/repository.did";
import { decodeFile } from "./lib/key";
import { commandOutput } from "../src/lib/scripts";
import { createActor as createRepository } from '../src/declarations/repository';
import { Principal } from "@dfinity/principal";
import { HttpAgent } from "@dfinity/agent";
import { pmInfo, pmEFInfo, walletInfo } from "./lib/pkg-data";

dotenv_config({ path: '.env' });
dotenv_config({ path: `.icpack-config.${process.env.DFX_NETWORK}` });

const net = process.env.DFX_NETWORK!;

const frontendBlob = Uint8Array.from(readFileSync(`.dfx/${net}/canisters/bootstrapper_frontend/bootstrapper_frontend.wasm.gz`));
const pmBackendBlob = Uint8Array.from(readFileSync(`.dfx/${net}/canisters/package_manager/package_manager.wasm`));
const pmMainIndirectBlob = Uint8Array.from(readFileSync(`.dfx/${net}/canisters/main_indirect/main_indirect.wasm`));
const pmSimpleIndirectBlob = Uint8Array.from(readFileSync(`.dfx/${net}/canisters/simple_indirect/simple_indirect.wasm`));
const pmBatteryBlob = Uint8Array.from(readFileSync(`.dfx/${net}/canisters/battery/battery.wasm`));
const pmExampleFrontendBlob = Uint8Array.from(readFileSync(`.dfx/${net}/canisters/example_frontend/example_frontend.wasm.gz`));
const pmExampleBackendBlob = Uint8Array.from(readFileSync(`.dfx/${net}/canisters/example_backend/example_backend.wasm`));
const walletFrontendBlob = Uint8Array.from(readFileSync(`.dfx/${net}/canisters/wallet_frontend/wallet_frontend.wasm.gz`));
const walletBackendBlob = Uint8Array.from(readFileSync(`.dfx/${net}/canisters/wallet_backend/wallet_backend.wasm`));

async function main() {
    console.log("Getting identity and initializing agent...");
    const key = await commandOutput("dfx identity export `dfx identity whoami`"); // secret key
    const identity = decodeFile(key);
    const agent = await HttpAgent.create({
        identity,
        host: net === 'local' ? "http://localhost:8080" : undefined,
        shouldFetchRootKey: net === 'local',
    });
    console.log("Creating repository actor...");
    const repository = createRepository(Principal.fromText(process.env.CANISTER_ID_REPOSITORY!), {agent});
    // FIXME@P1: Check asset canisters.
    console.log("Uploading modules..."); // FIXME@P3: duplicate code
    const pmFrontendModule = await repository.uploadModule({Assets: {wasm: frontendBlob, assets: Principal.fromText(process.env.CANISTER_ID_PACKAGE_MANAGER_FRONTEND!)}});
    const pmBackendModule = await repository.uploadModule({Wasm: pmBackendBlob});
    const exampleFrontend = await repository.uploadModule({Assets: {assets: Principal.fromText(process.env.CANISTER_ID_EXAMPLE_FRONTEND!), wasm: pmExampleFrontendBlob}});
    const exampleBackend = await repository.uploadModule({Wasm: pmExampleBackendBlob});
    const walletFrontend = await repository.uploadModule({Assets: {assets: Principal.fromText(process.env.CANISTER_ID_WALLET_FRONTEND!), wasm: walletFrontendBlob}});
    const walletBackend = await repository.uploadModule({Wasm: walletBackendBlob});
    const pmMainIndirectModule = await repository.uploadModule({Wasm: pmMainIndirectBlob});
    const pmSimpleIndirectModule = await repository.uploadModule({Wasm: pmSimpleIndirectBlob});
    const pmBatteryModule = await repository.uploadModule({Wasm: pmBatteryBlob});

    // FIXME@P1: Ask for more version strings. (Hm, there are several packages.)
    const version = await commandOutput("git rev-parse HEAD"); // FIXME@P1: Use it AFTER commit.
    console.log(`Version from Git: ${version}`);

    await submit([{
        repo: Principal.fromText(process.env.CANISTER_ID_REPOSITORY!),
        tmpl: pmInfo,
        modules: [
            ["battery", pmBatteryModule],
            ["backend", pmBackendModule],
            ["frontend", pmFrontendModule],
            ["main_indirect", pmMainIndirectModule],
            ["simple_indirect", pmSimpleIndirectModule],
        ],
    }, {
        repo: Principal.fromText(process.env.CANISTER_ID_REPOSITORY!),
        tmpl: pmEFInfo,
        modules: [
            ["example1", exampleFrontend],
            ["example2", exampleBackend],
        ],
    }, {
        repo: Principal.fromText(process.env.CANISTER_ID_REPOSITORY!),
        tmpl: walletInfo,
        modules: [
            ["frontend", walletFrontend],
            ["backend", walletBackend],
        ],
    }], identity, version);
}

main();