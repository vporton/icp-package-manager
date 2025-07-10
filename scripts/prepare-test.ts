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
    // execSync("dfx ledger fabricate-cycles --amount 100000000 --canister repository");
    // execSync("dfx ledger fabricate-cycles --amount 100000000 --canister bootstrapper");
    // execSync("dfx ledger fabricate-cycles --amount 100000000 --canister cycles_ledger");
    // execSync("dfx ledger fabricate-cycles --amount 100000000 --canister cmc");
}

async function main() {
    const key = await commandOutput("dfx identity export `dfx identity whoami`"); // secret key
    const identity = decodeFile(key);
    const net = process.env.DFX_NETWORK;

    const upgradeable1V1Blob = Uint8Array.from(readFileSync(`.dfx/${net}/canisters/upgrade_example_backend1_v1/upgrade_example_backend1_v1.wasm`));
    const upgradeable2V1Blob = Uint8Array.from(readFileSync(`.dfx/${net}/canisters/upgrade_example_backend2_v1/upgrade_example_backend2_v1.wasm`));
    const upgradeable2V2Blob = Uint8Array.from(readFileSync(`.dfx/${net}/canisters/upgrade_example_backend2_v2/upgrade_example_backend2_v2.wasm`));
    const upgradeable3V2Blob = Uint8Array.from(readFileSync(`.dfx/${net}/canisters/upgrade_example_backend3_v2/upgrade_example_backend3_v2.wasm`));
    const paidExampleFrontendBlob = Uint8Array.from(readFileSync(`.dfx/${net}/canisters/example_frontend/example_frontend.wasm.gz`));
    const paidExampleBackendBlob = Uint8Array.from(readFileSync(`.dfx/${net}/canisters/example_backend/example_backend.wasm`));

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
    const upgradeable1V1 = await repositoryIndex.uploadModule({
        code: {Wasm: upgradeable1V1Blob},
        installByDefault: true,
        forceReinstall: false,
        canisterVersion: [],
        callbacks: [
            [{WithdrawCycles: null}, {method: "withdrawCycles"}],
        ],
    });
    const upgradeable2V1 = await repositoryIndex.uploadModule({
        code: {Wasm: upgradeable2V1Blob},
        installByDefault: true,
        forceReinstall: false,
        canisterVersion: [],
        callbacks: [
            [{WithdrawCycles: null}, {method: "withdrawCycles"}],
        ],
    });
    const upgradeable2V2 = await repositoryIndex.uploadModule({
        code: {Wasm: upgradeable2V2Blob},
        installByDefault: true,
        forceReinstall: false,
        canisterVersion: [],
        callbacks: [
            [{WithdrawCycles: null}, {method: "withdrawCycles"}],
        ],
    });
    const upgradeable3V2 = await repositoryIndex.uploadModule({
        code: {Wasm: upgradeable3V2Blob},
        installByDefault: true,
        forceReinstall: false,
        canisterVersion: [],
        callbacks: [
            [{WithdrawCycles: null}, {method: "withdrawCycles"}],
        ],
    });
    const paidExampleFrontend = await repositoryIndex.uploadModule({
        code: {Assets: {assets: Principal.fromText(process.env.CANISTER_ID_EXAMPLE_FRONTEND!), wasm: paidExampleFrontendBlob}},
        installByDefault: true,
        forceReinstall: false,
        canisterVersion: [],
        callbacks: [],
    });
    const paidExampleBackend = await repositoryIndex.uploadModule({
        code: {Wasm: paidExampleBackendBlob},
        installByDefault: true,
        forceReinstall: false,
        canisterVersion: [],
        callbacks: [
            [{WithdrawCycles: null}, {method: "withdrawCycles"}],
        ],
    });

    console.log("Creating packages...");
    const upgradeableV1Real: SharedRealPackageInfo = {
        modules: [
            ['m1', upgradeable1V1],
            ['m2', upgradeable2V1],
        ],
        dependencies: [],
        suggests: [],
        recommends: [],
        functions: [],
        permissions: [],
        checkInitializedCallback: [],
        frontendModule: [],
    };
    const upgradeableV1Info: SharedPackageInfo = {
        base: {
            name: "upgradeable",
            version: "0.0.1",
            price: 0n,
            shortDescription: "Example upgradeable package",
            longDescription: "Used as an example",
            guid: Uint8Array.from([109, 30, 239, 245, 65, 4, 168, 138, 77, 89, 159, 205, 146, 220, 143, 20]),
        },
        specific: {real: upgradeableV1Real},
    };
    const upgradeableV2Real: SharedRealPackageInfo = {
        modules: [
            ['m2', upgradeable2V2],
            ['m3', upgradeable3V2],
        ],
        dependencies: [],
        suggests: [],
        recommends: [],
        functions: [],
        permissions: [],
        checkInitializedCallback: [],
        frontendModule: [],
    };
    const upgradeableV2Info: SharedPackageInfo = {
        base: {
            name: "upgradeable",
            version: "0.0.2",
            price: 0n,
            shortDescription: "Example upgradeable package",
            longDescription: "Used as an example",
            guid: Uint8Array.from([109, 30, 239, 245, 65, 4, 168, 138, 77, 89, 159, 205, 146, 220, 143, 20]),
        },
        specific: {real: upgradeableV2Real},
    };
    const upgradeableFullInfo: SharedFullPackageInfo = {
        packages: [["0.0.1", upgradeableV1Info], ["0.0.2", upgradeableV2Info]],
        versionsMap: [["stable", "0.0.1"], ["beta", "0.0.2"]],
    };
    await repositoryIndex.setFullPackageInfo("upgradeable", upgradeableFullInfo);

    const paidExampleReal: SharedRealPackageInfo = {
        modules: [
            ['example1', paidExampleFrontend],
            ['example2', paidExampleBackend],
        ],
        dependencies: [],
        suggests: [],
        recommends: [],
        functions: [],
        permissions: [],
        checkInitializedCallback: [{moduleName: 'example1', how: {urlPath: '/index.html'}}],
        frontendModule: ['example1'],
    };
    const paidExampleInfo: SharedPackageInfo = {
        base: {
            name: "paid-example",
            version: "0.0.1",
            price: BigInt(0.1 * 10**12),
            shortDescription: "Example package",
            longDescription: "Used as an example",
            guid: Uint8Array.from([4, 222, 95, 192, 252, 162, 223, 235, 230, 55, 16, 42, 26, 177, 208, 208]),
        },
        specific: {real: paidExampleReal},
    };
    const paidExampleFullInfo: SharedFullPackageInfo = {
        packages: [["0.0.1", paidExampleInfo]],
        versionsMap: [["stable", "0.0.1"]],
    };
    await repositoryIndex.setFullPackageInfo("paid-example", paidExampleFullInfo);

    console.log("Cleaning unused WASMs...");
    await repositoryIndex.cleanUnusedWasms();
}

main()