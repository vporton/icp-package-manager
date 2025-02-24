import { Agent, HttpAgent } from "@dfinity/agent";
import { inspect } from "util";
import node_fetch from 'node-fetch';
import { Principal } from "@dfinity/principal";
import { Ed25519KeyIdentity } from "@dfinity/identity";
import { bootstrapFrontend, waitTillInitialized } from "../src/lib/install";
import { createActor as createBootstrapperActor } from '../src/declarations/Bootstrapper';
import { createActor as createRepositoryIndexActor } from "../src/declarations/Repository";
import { createActor as createIndirectActor } from '../src/declarations/main_indirect';
import { createActor as createSimpleIndirectActor } from '../src/declarations/simple_indirect';
import { createActor as createPMFrontend } from '../src/declarations/package_manager_frontend';
import { createActor as createExampleFrontend } from '../src/declarations/example_frontend';
import { SharedPackageInfo, SharedRealPackageInfo } from "../src/declarations/Repository/Repository.did";
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

const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms))

function areEqualSets<T>(a: Set<T>, b: Set<T>): boolean {
    if (a === b) return true;
    if (a.size !== b.size) return false;
    for (const value of a) if (!b.has(value)) return false;
    return true;
}

async function waitForValue(fn: () => any, expectedValue: any, compare: (x: any, y: any) => boolean = (x, y) => x === y, timeout = 10000, interval = 1000) {
    const startTime = Date.now();
    let value;
    while (Date.now() - startTime < timeout) {
        value = await fn(); // Call the async function
        if (compare(value, expectedValue)) {
            return value;
        }
        await new Promise((resolve) => setTimeout(resolve, interval)); // Wait before retrying
    }
    throw new Error(`Timed out waiting for value: ${inspect(expectedValue)}. Latest value produced was ${inspect(value)}`);
}

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

        const repoIndex = createRepositoryIndexActor(process.env.CANISTER_ID_REPOSITORY!, {agent: defaultAgent});
        canisterNames.set(process.env.CANISTER_ID_REPOSITORY!, 'repoIndex');

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
        const repo = Principal.fromText(process.env.CANISTER_ID_REPOSITORY!);
        const {backendPrincipal, indirectPrincipal, simpleIndirectPrincipal} =
            await bootstrapper2.bootstrapBackend({
                backendWasmModule: icPackModules.get("backend")!,
                indirectWasmModule: icPackModules.get("indirect")!,
                simpleIndirectWasmModule: icPackModules.get("simple_indirect")!,
                user: backendUser,
                packageManagerOrBootstrapper: Principal.fromText(process.env.CANISTER_ID_BOOTSTRAPPER!),
                frontendTweakPrivKey,
                frontend: frontendPrincipal,
                repo,
                additionalPackages: [{packageName: "example", version: "0.0.1", repo}],
            });
        canisterNames.set(backendPrincipal.toText(), 'backendPrincipal');
        canisterNames.set(indirectPrincipal.toText(), 'indirectPrincipal');
        canisterNames.set(simpleIndirectPrincipal.toText(), 'simpleIndirectPrincipal');
        const pmInstallationId = 0n; // TODO
        console.log("Wait till installed PM initializes...");
        await waitTillInitialized(backendAgent, backendPrincipal, pmInstallationId);
        const packageManager: PackageManager = createPackageManager(backendPrincipal, {agent: backendAgent});

        console.log("Testing controllers of the PM modules...");
        const simpleIndirect: SimpleIndirect = createSimpleIndirectActor(simpleIndirectPrincipal, {agent: backendAgent});
        for (const canister_id of [simpleIndirectPrincipal, indirectPrincipal, backendPrincipal, frontendPrincipal]) {
            const simpleIndirectInfo = await simpleIndirect.canister_info(
                {canister_id, num_requested_changes: []}, 1000_000_000_000n);
            // `indirectPrincipal` here is only for the package manager package:
            expect(new Set(simpleIndirectInfo.controllers)).to.equalPrincipalSet(
                new Set([simpleIndirectPrincipal, indirectPrincipal, backendPrincipal, backendUser])
            );
        }
        for (const [principal, create] of [
            [simpleIndirectPrincipal, createSimpleIndirectActor],
            [indirectPrincipal, createIndirectActor],
            [backendPrincipal, createPackageManager]
        ]) {
            const canister = (create as any)(principal, {agent: backendAgent});
            const owners = await canister.getOwners();
            console.log(`Checking ${getCanisterNameFromPrincipal(principal as Principal)}...`);
            expect(new Set(owners)).to.equalPrincipalSet(
                new Set([simpleIndirectPrincipal, indirectPrincipal, backendPrincipal, backendUser])
            );
        }
        console.log("Checking PM frontend owners...");
        const pmFrontend = createPMFrontend(frontendPrincipal, {agent: backendAgent});
        for (const permission of [{Commit: null}, {ManagePermissions: null}, {Prepare: null}]) {
            const owners = await pmFrontend.list_permitted({permission});
            expect(new Set(owners)).to.equalPrincipalSet(
                new Set([simpleIndirectPrincipal, indirectPrincipal, backendPrincipal, backendUser])
            );
        }

        console.log("Installing `example` package...");
        const {minInstallationId: exampleInstallationId} = await packageManager.installPackages({
            packages: [{
                packageName: "example",
                version: "0.0.1",
                repo: Principal.fromText(process.env.CANISTER_ID_REPOSITORY!),
            }],
            user: backendUser,
            afterInstallCallback: [],
        });
        await waitTillInitialized(backendAgent, backendPrincipal, exampleInstallationId);

        const examplePkg = await packageManager.getInstalledPackage(exampleInstallationId);
        for (const moduleName of ['example1', 'example2']) {
            const examplePrincipal = examplePkg.namedModules.filter(([name, _principal]) => name === moduleName)[0][1];
            const exampleInfo = await simpleIndirect.canister_info(
                {canister_id: examplePrincipal, num_requested_changes: []}, 1000_000_000_000n);
            expect(new Set(exampleInfo.controllers)).to.equalPrincipalSet(new Set([simpleIndirectPrincipal, backendUser]));
        }

        const examplePrincipal = examplePkg.namedModules.filter(([name, _principal]) => name === 'example1')[0][1];
        const exampleFrontend = createExampleFrontend(examplePrincipal, {agent: backendAgent});
        console.log("Checking example frontend owners...");
        for (const permission of [{Commit: null}, {ManagePermissions: null}, {Prepare: null}]) {
            const owners = await exampleFrontend.list_permitted({permission});
            expect(new Set(owners)).to.equalPrincipalSet(new Set([simpleIndirectPrincipal, backendUser]));
        }

        console.log("Installing `upgradeable` package...");
        const {minInstallationId: upgradeableInstallationId} = await packageManager.installPackages({
            packages: [{
                packageName: "upgradeable",
                version: "0.0.1",
                repo: Principal.fromText(process.env.CANISTER_ID_REPOSITORY!),
            }],
            user: backendUser,
            afterInstallCallback: [],
        });
        await waitTillInitialized(backendAgent, backendPrincipal, upgradeableInstallationId);
        await sleep(10000); // FIXME: Should not be needed.
        console.log("Upgrading `upgradeable` package...");
        await packageManager.upgradePackages({
            packages: [{
                installationId: upgradeableInstallationId,
                packageName: "upgradeable",
                version: "0.0.2",
                repo: Principal.fromText(process.env.CANISTER_ID_REPOSITORY!),
            }],
            user: backendUser,
        });
        console.log("Testing upgraded package `upgradeable`...");
        // We will wait till `m1` is removed, because this signifie the upgrade is done. // TODO: a better way
        // TODO: More detailed test:
        async function myNamedModules(): Promise<Set<string>> {
            const upgradeablePkg = await packageManager.getInstalledPackage(upgradeableInstallationId);
            return new Set(Array.from(upgradeablePkg.namedModules.values()).map(([name, _principal]) => name));
        }
        await waitForValue(myNamedModules, new Set(['m2', 'm3']), areEqualSets);
    });
});