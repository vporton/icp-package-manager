import { Agent, HttpAgent } from "@dfinity/agent";
import { exec, execSync } from "child_process";
import { readFileSync } from "fs";
import node_fetch from 'node-fetch';
import { Principal } from "@dfinity/principal";
import { Ed25519KeyIdentity } from "@dfinity/identity";
import { bootstrapFrontend } from "../src/lib/install";
import { createActor as createBootstrapperActor } from '../src/declarations/Bootstrapper';
import { createActor as createRepositoryIndexActor } from "../src/declarations/RepositoryIndex";
import { createActor as createRepositoryPartitionActor } from "../src/declarations/RepositoryPartition";
import { SharedPackageInfo, SharedRealPackageInfo } from "../src/declarations/RepositoryPartition/RepositoryPartition.did";
import { config as dotenv_config } from 'dotenv';

global.fetch = node_fetch as any;

dotenv_config({ path: '.env' });

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
    const icHost = "http://localhost:4943";
    function newAgent(): Agent {
        const identity = Ed25519KeyIdentity.generate();
        const agent = new HttpAgent({host: icHost, identity})
        if (process.env.DFX_NETWORK === 'local') {
            agent.fetchRootKey();
        }
        return agent;
    };

    let user: Principal;
    let defaultAgent: Agent;
    // const key = await commandOutput("dfx identity export `dfx identity whoami`");
    // const identity = decodeFile(key);

    beforeEach(async () => {
        defaultAgent = new HttpAgent({host: icHost});
    });

    describe('misc', async () => {
        const repoIndex = createRepositoryIndexActor(process.env.CANISTER_ID_REPOSITORYINDEX!, {agent: defaultAgent});
        const bootstrapperIndirectCaller: Bootstrapper = createBootstrapperActor(process.env.CANISTER_ID_BOOTSTRAPPER!, {agent});
        // TODO: Duplicate code
        const repoParts = await repoIndex.getCanistersByPK("main");
        let pkg: SharedPackageInfo | undefined = undefined;
        let repoPart: Principal | undefined;
        const jobs = repoParts.map(async part => {
          const obj = createRepositoryPartitionActor(part, {agent: defaultAgent});
          try {
            pkg = await obj.getPackage('icpack', "0.0.1"); // TODO: `"stable"`
            repoPart = Principal.fromText(part);
          }
          catch (_) {}
        });
        await Promise.all(jobs);
        const pkgReal = (pkg!.specific as any).real as SharedRealPackageInfo;
        const modules = new Map(pkgReal.modules);

        const bootstrapperAgent = newAgent();
        const bootstrapperUser = await bootstrapperAgent.getPrincipal();
        const {backendPrincipal, indirectPrincipal, simpleIndirectPrincipal} = await bootstrapperIndirectCaller.bootstrapBackend({
          backendWasmModule: modules.get("backend")!,
          indirectWasmModule: modules.get("indirect")!,
          simpleIndirectWasmModule: modules.get("simple_indirect")!,
          user: bootstrapperUser,
          packageManagerOrBootstrapper: Principal.fromText(process.env.CANISTER_ID_BOOTSTRAPPER!), // TODO: Don't forget to remove it.
          frontendTweakPrivKey: glob.frontendTweakPrivKey!,
          frontend: glob.frontend!,
          repoPart: repoPart!,
        });
        const backend: PackageManager = createBackendActor(backendPrincipal, {agent});
        const {canister_id: _, frontendTweakPrivKey} = await bootstrapFrontend({user: bootstrapperUser, agent: bootstrapperAgent});
        await waitTillInitialized(bootstrapperAgent, package_manager: Principal, installationId: InstallationId)
        
        const backendAgent = newAgent();

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