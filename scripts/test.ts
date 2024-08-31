import { Actor, HttpAgent } from "@dfinity/agent";
import { exec, execSync } from "child_process";
import { readFileSync } from "fs";
import { decodeFile } from "./lib/key";
import { createActor as createTestActor } from "../src/declarations/test";
import { createActor as createPackageManagerActor } from "../src/declarations/package_manager";
import { createActor as createCounterActor } from "../src/declarations/counter";
import { config as dotenv_config } from 'dotenv';
import node_fetch from 'node-fetch';
import { Principal } from "@dfinity/principal";

dotenv_config({ path: '.env' });

global.fetch = node_fetch as any;

function myExecSync(command: string) {
    console.log(`Executing: ${command}`);
    execSync(command);
}
function commandOutput(command: string): Promise<string> {
    return new Promise((resolve) => exec(command, function(error, stdout, stderr){
        resolve(stdout);
    }));
}

const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms))

async function doIt() {
    myExecSync("dfx identity use Zon")
    myExecSync("dfx deploy test")
    myExecSync("dfx ledger fabricate-cycles --amount 100000000 --canister test")

    const counter_blob = readFileSync(".dfx/local/canisters/counter/counter.wasm");
    const pm_blob = readFileSync(".dfx/local/canisters/package_manager/package_manager.wasm");
    const frontend_blob = readFileSync(".dfx/local/canisters/package_manager_frontend/assetstorage.wasm.gz");

    const j = JSON.parse(readFileSync('.dfx/local/canister_ids.json', {encoding: 'utf-8'}));
    // const test_principal = j['test']['local'];
    const pm_frontend_source_principal = Principal.fromText(j['package_manager_frontend']['local']);

    const key = await commandOutput("dfx identity export Zon");
    const identity = decodeFile(key);
    const agent = new HttpAgent({host: "http://localhost:4943", identity})
    agent.fetchRootKey(); // TODO: should not be used in production.

    const test = createTestActor(process.env.CANISTER_ID_TEST!, {agent})
    const result = await test.main(pm_blob, frontend_blob, pm_frontend_source_principal, counter_blob)
    const counter_installation_id = result[1]['installationId']
    const pm_canisters = result[0]['canisterIds']
    const pm_principal = pm_canisters[0]
    console.log(`Counter installation ID: ${counter_installation_id}`)

    const wait = 15000 // msecs
    console.log(`Waiting ${wait} msec`)
    await sleep(wait)

    console.log("Getting package info...");

    const pm = createPackageManagerActor(pm_principal, {agent})
    const result2 = await pm.getInstalledPackage(counter_installation_id)

    const counter_principal = result2['modules'][0]
    // `ic-py` hangs if called on a canister without WASM code, so make enough pause.
    const wait2 = 5000 // msecs
    console.log(`Waiting ${wait2} msec`)
    await sleep(wait2)
    console.log(`Running the 'counter' (${counter_principal}) software...`);
    const counter = createCounterActor(counter_principal, {agent})
    await counter.increase()
    // # for i in range(20):
    // #     print(f"... attempt {i}")
    // #     try:
    // #         agent.update_raw(counter, "increase", encode([]))  # stalls on canister without WASM
    // #         time.sleep(1)  # Wait till Counter installation finishes
    // #     except Exception as e:
    // #         print(e)
    // #         continue
    // #     break
    const result3 = await counter.get()
    const test_value = result3
    console.log(`COUNTER: ${test_value}`);
    console.assert(test_value.toString() === '1')
    console.log("Counter is equal to 1...");
}

doIt();