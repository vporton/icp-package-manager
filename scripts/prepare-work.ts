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
    const net = process.env.DFX_NETWORK;

    const frontendBlob = Uint8Array.from(readFileSync(`.dfx/${net}/canisters/bootstrapper_frontend/bootstrapper_frontend.wasm.gz`));
    const pmBackendBlob = Uint8Array.from(readFileSync(`.dfx/${net}/canisters/package_manager/package_manager.wasm`));
    const pmMainIndirectBlob = Uint8Array.from(readFileSync(`.dfx/${net}/canisters/main_indirect/main_indirect.wasm`));
    const pmSimpleIndirectBlob = Uint8Array.from(readFileSync(`.dfx/${net}/canisters/simple_indirect/simple_indirect.wasm`));
    const pmBatteryBlob = Uint8Array.from(readFileSync(`.dfx/${net}/canisters/battery/battery.wasm`));
    const pmExampleFrontendBlob = Uint8Array.from(readFileSync(`.dfx/${net}/canisters/example_frontend/example_frontend.wasm.gz`));
    const pmExampleBackendBlob = Uint8Array.from(readFileSync(`.dfx/${net}/canisters/example_backend/example_backend.wasm`));
    const walletFrontendBlob = Uint8Array.from(readFileSync(`.dfx/${net}/canisters/wallet_frontend/wallet_frontend.wasm.gz`));
    const walletBackendBlob = Uint8Array.from(readFileSync(`.dfx/${net}/canisters/wallet_backend/wallet_backend.wasm`));

    const agent = new HttpAgent({host: isLocal ? "http://localhost:8080" : undefined, identity}); // TODO@P3: Use `HttpAgent.create`.
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
    const walletFrontend = await repositoryIndex.uploadModule({
        code: {Assets: {assets: Principal.fromText(process.env.CANISTER_ID_WALLET_FRONTEND!), wasm: walletFrontendBlob}},
        installByDefault: true,
        forceReinstall: false,
        canisterVersion: [],
        callbacks: [],
    });
    const walletBackend = await repositoryIndex.uploadModule({
        code: {Wasm: walletBackendBlob},
        installByDefault: true,
        forceReinstall: false,
        canisterVersion: [],
        callbacks: [
            [{WithdrawCycles: null}, {method: "withdrawCycles"}],
        ],
    });

    console.log("Creating packages...");
////// TODO@P1: Remove. [[
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
            version: "0.0.1", // FIXME@P1: It's superfluous here.
            price: 0n,
            upgradePrice: 0n,
            shortDescription: "Package manager",
            longDescription: "Manager for installing ICP app to user's subnet",
            guid: Uint8Array.from([83,  42, 115, 145, 27, 107,  70, 196, 150, 131,  3,  14, 110, 136, 210,  74]),
            developer: [],
        },
        specific: {real: pmReal},
    };
////// ]]
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
            price: 0n,
            upgradePrice: 0n,
            shortDescription: "Example package",
            longDescription: "Used as an example",
            guid: Uint8Array.from([39, 165, 164, 221, 113,  51,  73,  53, 145, 150,  31,  42, 238, 133, 124, 210]),
            developer: [],
        },
        specific: {real: efReal},
    };
    const pmEFFullInfo: SharedFullPackageInfo = {
        packages: [["0.0.1", pmEFInfo]],
        versionsMap: [["stable", "0.0.1"]],
    };
    await repositoryIndex.setFullPackageInfo("example", pmEFFullInfo);

    const walletReal: SharedRealPackageInfo = {
        modules: [
            ['frontend', walletFrontend],
            ['backend', walletBackend],
        ],
        dependencies: [],
        suggests: [],
        recommends: [],
        functions: [],
        permissions: [],
        checkInitializedCallback: [{moduleName: 'backend', how: {methodName: 'isAllInitialized'}}],
        frontendModule: ['frontend'],
    };
    const walletInfo: SharedPackageInfo = {
        base: {
            name: "wallet",
            version: "0.0.1",
            price: 0n,
            upgradePrice: 0n,
            shortDescription: "Wallet for IC Pack",
            longDescription: "Wallet for IC Pack, used among other for in-app payments",
            guid: Uint8Array.from([206,  18, 101,   7, 174, 170, 142, 240,  90, 165, 231, 131, 186, 119, 122,  57]),
            developer: [],
        },
        specific: {real: walletReal},
    };
    const walletFullInfo: SharedFullPackageInfo = {
        packages: [["0.0.1", walletInfo]],
        versionsMap: [["stable", "0.0.1"]],
    };
    await repositoryIndex.setFullPackageInfo("wallet", walletFullInfo);

    console.log("Cleaning unused WASMs...");
    await repositoryIndex.cleanUnusedWasms();
}

main()