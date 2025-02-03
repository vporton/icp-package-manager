import { Agent, HttpAgent } from "@dfinity/agent";
import { exec, execSync } from "child_process";
import { readFileSync } from "fs";
import node_fetch from 'node-fetch';
import { Principal } from "@dfinity/principal";
import { Ed25519KeyIdentity } from "@dfinity/identity";
import { bootstrapFrontend, waitTillInitialized } from "../src/lib/install";
import { createActor as createBootstrapperActor } from '../src/declarations/Bootstrapper';
import { createActor as createRepositoryIndexActor } from "../src/declarations/RepositoryIndex";
import { createActor as createSimpleIndirectActor } from '../src/declarations/simple_indirect';
import { SharedPackageInfo, SharedRealPackageInfo } from "../src/declarations/RepositoryIndex/RepositoryIndex.did";
import { config as dotenv_config } from 'dotenv';
import { Bootstrapper } from "../src/declarations/Bootstrapper/Bootstrapper.did";
import { IDL } from "@dfinity/candid";
import { it } from "mocha";
import { expect, Assertion } from "chai";
import { SimpleIndirect } from "../src/declarations/simple_indirect/simple_indirect.did";
import { PackageManager } from "../src/declarations/package_manager/package_manager.did";
import { createActor as createPackageManager } from '../src/declarations/package_manager';
import dfxConfig from "../dfx.json";
import canisterId from "../.dfx/local/canister_ids.json";

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

// function areEqualSets<T>(a: Set<T>, b: Set<T>): boolean {
//     if (a === b) return true;
//     if (a.size !== b.size) return false;
//     for (const value of a) if (!b.has(value)) return false;
//     return true;
// }

/// Human-readable canister names.
const canisterNames = new Map<string, string>(); // anti-pattern: a global variable

function getCanisterNameFromPrincipal(principal: Principal): string {
    if (canisterNames.has(principal.toText())) {
        return canisterNames.get(principal.toText())! + ' ' + principal.toText();
    }
    // Iterate through canisters in dfx config
    for (const [canisterName, _config] of Object.entries(dfxConfig.canisters)) {
        if ((canisterId as any)[canisterName].local === principal.toString()) {
            return canisterName;
        }
    }
    return principal.toString();
}

Assertion.addMethod('equalPrincipalSet', function (expected) {
    const actual = this._obj;
    const actualStrings = Array.from(actual).map(p => getCanisterNameFromPrincipal(p as Principal)).sort();
    const expectedStrings = Array.from(expected).map(p => getCanisterNameFromPrincipal(p as Principal)).sort();
    
    this.assert(
        expect(actualStrings).to.deep.equal(expectedStrings),
        // expect(actualStrings).to.have.same.members(expectedStrings),
        "expected #{act} to equal #{exp}",
        "expected #{act} to not equal #{exp}",
        expectedStrings,
        actualStrings
    );
});
  
declare global {
    namespace Chai {
        interface Assertion {
            equalPrincipalSet(expected: Set<any>): void;
        }
    }
}
  
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

    let defaultAgent: Agent;

    before("Init", () => {
        defaultAgent = new HttpAgent({host: icHost});
        if (process.env.DFX_NETWORK === 'local') {
            defaultAgent.fetchRootKey();
        }
    });

    it('misc', async function () {
        this.timeout(600_000); // 10 min

        const bootstrapperAgent = newAgent();
        const bootstrapperUser = await bootstrapperAgent.getPrincipal();
        canisterNames.set(bootstrapperUser.toText(), 'bootstrapperUser');

        const repoIndex = createRepositoryIndexActor(process.env.CANISTER_ID_REPOSITORYINDEX!, {agent: defaultAgent});
        canisterNames.set(process.env.CANISTER_ID_REPOSITORYINDEX!, 'repoIndex');

        let icPackPkg = await repoIndex.getPackage('icpack', "0.0.1");
        const icPackPkgReal = (icPackPkg!.specific as any).real as SharedRealPackageInfo;
        const icPackModules = new Map(icPackPkgReal.modules);

        console.log("Bootstrapping frontend...");
        const {canister_id: frontendPrincipal, frontendTweakPrivKey} =
            await bootstrapFrontend({user: bootstrapperUser, agent: bootstrapperAgent});
        canisterNames.set(frontendPrincipal.toText(), 'frontendPrincipal');

        const backendAgent = newAgent();
        const backendUser = await backendAgent.getPrincipal();
        canisterNames.set(backendUser.toText(), 'backendUser');
        const bootstrapper2: Bootstrapper = createBootstrapperActor(process.env.CANISTER_ID_BOOTSTRAPPER!, {agent: backendAgent});

        console.log("Bootstrapping backend...");
        const {backendPrincipal, indirectPrincipal, simpleIndirectPrincipal} =
            await bootstrapper2.bootstrapBackend({
                backendWasmModule: icPackModules.get("backend")!,
                indirectWasmModule: icPackModules.get("indirect")!,
                simpleIndirectWasmModule: icPackModules.get("simple_indirect")!,
                user: backendUser,
                packageManagerOrBootstrapper: Principal.fromText(process.env.CANISTER_ID_BOOTSTRAPPER!), // TODO: Don't forget to remove it.
                frontendTweakPrivKey,
                frontend: frontendPrincipal,
                repoPart: Principal.fromText(process.env.CANISTER_ID_REPOSITORYINDEX!),
            });
        canisterNames.set(backendPrincipal.toText(), 'backendPrincipal');
        canisterNames.set(indirectPrincipal.toText(), 'indirectPrincipal');
        canisterNames.set(simpleIndirectPrincipal.toText(), 'simpleIndirectPrincipal');
        const pmInstallationId = 0n; // TODO
        console.log("Wait till installed PM initializes...");
        await waitTillInitialized(backendAgent, backendPrincipal, pmInstallationId);

        const simpleIndirect: SimpleIndirect = createSimpleIndirectActor(simpleIndirectPrincipal, {agent: backendAgent});
        const simpleIndirectInfo = await simpleIndirect.canister_info(
            {canister_id: backendPrincipal, num_requested_changes: []}, 1000_000_000_000n);
        // TODO: Should have also `indirectPrincipal`?
        expect(new Set(simpleIndirectInfo.controllers)).to.equalPrincipalSet(new Set([simpleIndirectPrincipal, backendPrincipal, backendUser]));

        console.log("Installing `example` package...");
        const packageManager: PackageManager = createPackageManager(backendPrincipal, {agent: backendAgent});
        const {minInstallationId: exampleInstallationId} = await packageManager.installPackage({
            packages: [{
                packageName: "example",
                version: "0.0.1",
                repo: Principal.fromText(process.env.CANISTER_ID_REPOSITORYINDEX!),
            }],
            user: backendUser,
            afterInstallCallback: [],
        });
        await waitTillInitialized(backendAgent, backendPrincipal, exampleInstallationId);

        // TODO: Test also PM frontend controllers.

        // TODO: Test also example with backend modules.
        const examplePkg = await packageManager.getInstalledPackage(exampleInstallationId);
        const examplePrincipal = examplePkg.modules.filter(([name, principal]) => name === 'example1')[0][1];
        const exampleInfo = await simpleIndirect.canister_info(
            {canister_id: examplePrincipal, num_requested_changes: []}, 1000_000_000_000n);
        expect(new Set(exampleInfo.controllers)).to.equalPrincipalSet(new Set([simpleIndirectPrincipal, backendPrincipal, backendUser]));

        // TODO: Test also owners.
    });
});