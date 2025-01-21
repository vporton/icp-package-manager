import { Agent, HttpAgent } from "@dfinity/agent";
import { exec, execSync } from "child_process";
import { readFileSync } from "fs";
import node_fetch from 'node-fetch';
import { Principal } from "@dfinity/principal";
import { Ed25519KeyIdentity } from "@dfinity/identity";
import { bootstrapFrontend, waitTillInitialized } from "../src/lib/install";
import { createActor as createBootstrapperActor } from '../src/declarations/Bootstrapper';
import { createActor as createRepositoryIndexActor } from "../src/declarations/RepositoryIndex";
import { createActor as createRepositoryPartitionActor } from "../src/declarations/RepositoryPartition";
import { SharedPackageInfo, SharedRealPackageInfo } from "../src/declarations/RepositoryPartition/RepositoryPartition.did";
import { config as dotenv_config } from 'dotenv';
import { Bootstrapper } from "../src/declarations/Bootstrapper/Bootstrapper.did";
import { IDL } from "@dfinity/candid";
import { it } from "mocha";

global.fetch = node_fetch as any;

dotenv_config({ path: '.env' });

// function myExecSync(command: string) {
//     console.log(`Executing: ${command}`);
//     execSync(command);
// }

// function commandOutput(command: string): Promise<string> {
//     return new Promise(resolve => exec(command, function(error, stdout, stderr) {
//         resolve(stdout);
//     }));
// }

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

    const defaultAgent = new HttpAgent({host: icHost});
    if (process.env.DFX_NETWORK === 'local') {
        defaultAgent.fetchRootKey();
    }

    it('misc', async function () {
        this.timeout(1800000); // 30 min
        console.log("A1");

        const bootstrapperAgent = newAgent();
        const bootstrapperUser = await bootstrapperAgent.getPrincipal();
        console.log("A2");

        const repoIndex = createRepositoryIndexActor(process.env.CANISTER_ID_REPOSITORYINDEX!, {agent: defaultAgent});
        const bootstrapper: Bootstrapper = createBootstrapperActor(process.env.CANISTER_ID_BOOTSTRAPPER!, {agent: bootstrapperAgent});
        console.log("A3");

        // TODO: Duplicate code
        const repoParts = await repoIndex.getCanistersByPK("main");
        console.log("A4");
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
        console.log("A5");
        await Promise.all(jobs);
        console.log("A6");
        const pkgReal = (pkg!.specific as any).real as SharedRealPackageInfo;
        const modules = new Map(pkgReal.modules);
        console.log("A7");

        // const bootstrapper = createBootstrapperActor(process.env.CANISTER_ID_BOOTSTRAPPER!, {agent: bootstrapperAgent});
        const {canister_id: frontendPrincipal, frontendTweakPrivKey} =
            await bootstrapFrontend({user: bootstrapperUser, agent: bootstrapperAgent});
        console.log("A8");

        const {backendPrincipal, indirectPrincipal, simpleIndirectPrincipal} =
            await bootstrapper.bootstrapBackend({
                backendWasmModule: modules.get("backend")!,
                indirectWasmModule: modules.get("indirect")!,
                simpleIndirectWasmModule: modules.get("simple_indirect")!,
                user: bootstrapperUser,
                packageManagerOrBootstrapper: Principal.fromText(process.env.CANISTER_ID_BOOTSTRAPPER!), // TODO: Don't forget to remove it.
                frontendTweakPrivKey,
                frontend: frontendPrincipal,
                repoPart: repoPart!,
            });
        console.log("A9");
        const installationId = 0n; // TODO
        await waitTillInitialized(bootstrapperAgent, backendPrincipal, installationId)
        console.log("A10");
        
        const backendAgent = newAgent();

        // expect(sum(1, 2)).toBe(3);

        // done();
    });
});