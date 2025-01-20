    import { Agent, HttpAgent } from "@dfinity/agent";
import { exec, execSync } from "child_process";
import { readFileSync } from "fs";
import node_fetch from 'node-fetch';
import { Principal } from "@dfinity/principal";
import { Ed25519KeyIdentity } from "@dfinity/identity";
import { bootstrapFrontend } from "../src/lib/install";

global.fetch = node_fetch as any;

function myExecSync(command: string) {
    console.log(`Executing: ${command}`);
    execSync(command);
}

function commandOutput(command: string): Promise<string> {
    return new Promise(resolve => exec(command, function(error, stdout, stderr) {
        resolve(stdout);
    }));
}

// const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms))

describe('My Test Suite', () => {
    // const icHost = "http://localhost:4943";
    // function newAgent(): Agent {
    //     const identity = Ed25519KeyIdentity.generate();
    //     const agent = new HttpAgent({host: icHost, identity})
    //     if (process.env.DFX_NETWORK === 'local') {
    //         agent.fetchRootKey();
    //     }
    //     return agent;
    // };

    beforeEach(async () => {
    //     const key = await commandOutput("dfx identity export `dfx identity whoami`");
    //     const identity = decodeFile(key);
    });

    describe('misc', async () => {
        // const bootstrapperAgent = newAgent();
        // const bootstrapperUser = await bootstrapperAgent.getPrincipal();
        // const {canister_id: _, frontendTweakPrivKey} = await bootstrapFrontend({user: bootstrapperUser, agent: bootstrapperAgent});
        // expect(sum(1, 2)).toBe(3);
    });
});

async function doIt() {
    const counter_blob = readFileSync(".dfx/local/canisters/counter/counter.wasm");
    const pm_blob = readFileSync(".dfx/local/canisters/package_manager/package_manager.wasm");
    const frontend_blob = readFileSync(".dfx/local/canisters/package_manager_frontend/assetstorage.wasm.gz");

    const j = JSON.parse(readFileSync('.dfx/local/canister_ids.json', {encoding: 'utf-8'}));
    const pm_frontend_source_principal = Principal.fromText(j['package_manager_frontend']['local']);

}