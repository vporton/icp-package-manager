import { Agent, HttpAgent } from "@dfinity/agent";
import { inspect } from "util";
import node_fetch from 'node-fetch';
import { Principal } from "@dfinity/principal";
import { Ed25519KeyIdentity } from "@dfinity/identity";
import { bootstrapFrontend, waitTillInitialized } from "../src/lib/install";
import { createActor as createBootstrapperActor } from '../src/declarations/bootstrapper';
import { createActor as createCyclesLedger } from "../src/declarations/cycles_ledger";
import { createActor as createIndirectActor } from '../src/declarations/main_indirect';
import { createActor as createSimpleIndirectActor } from '../src/declarations/simple_indirect';
import { createActor as createBattery } from '../src/declarations/battery';
import { createActor as createPMFrontend } from '../src/declarations/package_manager_frontend';
import { createActor as createExampleFrontend } from '../src/declarations/example_frontend';
import { SharedRealPackageInfo } from "../src/declarations/repository/repository.did";
import { config as dotenv_config } from 'dotenv';
import { Bootstrapper } from "../src/declarations/bootstrapper/bootstrapper.did";
import { it } from "mocha";
import { expect, Assertion } from "chai";
import { SimpleIndirect } from "../src/declarations/simple_indirect/simple_indirect.did";
import { PackageManager } from "../src/declarations/package_manager/package_manager.did";
import { createActor as createPackageManager } from '../src/declarations/package_manager';
import dfxConfig from "../dfx.json";
import canisterId from "../.dfx/local/canister_ids.json";
import { cycles_ledger } from "../src/declarations/cycles_ledger";
import { principalToSubAccount } from "../src/lib/misc";
import { commandOutput } from "../src/lib/scripts";
import { decodeFile } from "../scripts/lib/key";
import { ICManagementCanister } from "@dfinity/ic-management";
import { signPrincipal } from "../src/lib/signatures";

global.fetch = node_fetch as any;
const { subtle } = crypto ?? globalThis.crypto;

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

async function waitForValue(fn: () => any, expectedValue: any, compare: (x: any, y: any) => boolean = (x, y) => x === y, timeout = 30000, interval = 1000) {
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
    const actual = this._obj as Set<any>;
    const actualStrings = Array.from(actual).map(p => getCanisterNameFromPrincipal(p as Principal));
    const expectedStrings = Array.from(expected).map(p => getCanisterNameFromPrincipal(p as Principal));

    const isEqual = areEqualSets(new Set(actualStrings), new Set(expectedStrings));

    this.assert(
        isEqual,
        "expected #{act} to equal #{exp}",
        "expected #{act} to not equal #{exp}",
        expectedStrings.sort(),
        actualStrings.sort()
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
    const icHost = "http://localhost:8080";

    async function newAgent(): Promise<Agent> {
        const identity = Ed25519KeyIdentity.generate();
        const agent = await HttpAgent.create({host: icHost, identity, shouldFetchRootKey: true})
        if (process.env.DFX_NETWORK === 'local') {
            agent.fetchRootKey();
        }
        return agent;
    };

    let defaultAgent: Agent;

    before("Init", async () => {
        defaultAgent = await HttpAgent.create({host: icHost, shouldFetchRootKey: true});
    });

    it('misc', async function () {
        this.timeout(600_000); // 10 min

        const bootstrapperAgent = await newAgent();
        const bootstrapperUser = await bootstrapperAgent.getPrincipal();

        canisterNames.set(bootstrapperUser.toText(), 'bootstrapperUser');

        canisterNames.set(process.env.CANISTER_ID_REPOSITORY!, 'repoIndex');

        const key = await commandOutput("dfx identity export Zon"); // secret key
        const identity = decodeFile(key);
        const mainUserAgent = await HttpAgent.create({host: "http://localhost:8080", identity, shouldFetchRootKey: true});
        const CyclesLedger = createCyclesLedger(process.env.CANISTER_ID_CYCLES_LEDGER!, {agent: mainUserAgent});
        const initialTransferResult = await CyclesLedger.icrc1_transfer({
            to: {
                owner: Principal.fromText(process.env.CANISTER_ID_BOOTSTRAPPER!),
                subaccount: [principalToSubAccount(bootstrapperUser)],
            },
            fee: [],
            memo: [],
            from_subaccount: [],
            created_at_time: [],
            amount: BigInt(100 * 10**12),
        });
        if ((initialTransferResult as any).Err !== undefined) {
            console.log((initialTransferResult as any).Err);
            throw "transfer failed: " + (initialTransferResult as any).Err.toString();
        }
        const bootstrapper = createBootstrapperActor(process.env.CANISTER_ID_BOOTSTRAPPER!, {agent: bootstrapperAgent});
        await bootstrapper.topUpCycles();

        console.log("Bootstrapping frontend...");
        const {installedModules, frontendTweakPrivKey, frontendTweakPubKey} =
            await bootstrapFrontend({agent: bootstrapperAgent});
        const pmInst = new Map(installedModules);
        canisterNames.set(pmInst.get("frontend")!.toText(), 'frontendPrincipal');

        const backendAgent = await newAgent();
        const backendUser = await backendAgent.getPrincipal();
        canisterNames.set(backendUser.toText(), 'backendUser');
        const bootstrapper2: Bootstrapper = createBootstrapperActor(process.env.CANISTER_ID_BOOTSTRAPPER!, {agent: backendAgent});

        console.log("Bootstrapping backend...");
        const repo = Principal.fromText(process.env.CANISTER_ID_REPOSITORY!);
        const signature = await signPrincipal(frontendTweakPrivKey, backendUser);
        await bootstrapper2.bootstrapBackend({
            frontendTweakPubKey: new Uint8Array(await subtle.exportKey('spki', frontendTweakPubKey)),
            installedModules,
            user: backendUser,
            signature: new Uint8Array(signature),
            additionalPackages: [],
        });
        for (const [name, m] of pmInst.entries()) {
            canisterNames.set(m.toText(), name);
        }
        // TODO@P3: Check installation IDs of bootstrapper and of regularly installed `example` package.
        const pmInstallationId = 0n; // TODO@P3
        console.log("Wait till installed PM initializes...");
        await waitTillInitialized(backendAgent, pmInst.get('backend')!, pmInstallationId);
        const packageManager: PackageManager = createPackageManager(pmInst.get('backend')!, {agent: backendAgent});

        console.log("Testing controllers of the PM modules...");
        const simpleIndirect: SimpleIndirect = createSimpleIndirectActor(pmInst.get('simple_indirect')!, {agent: backendAgent});
        for (const canister_id of pmInst.values()) {
            console.log(`Checking controllers of ${getCanisterNameFromPrincipal(canister_id)}...`);
            const simpleIndirectInfo = await simpleIndirect.canister_info(
                {canister_id, num_requested_changes: []}, 1000_000_000_000n);
            // `mainIndirectPrincipal` here is only for the package manager package:
            expect(new Set(simpleIndirectInfo.controllers)).to.equalPrincipalSet(
                new Set([
                    pmInst.get('simple_indirect')!,
                    pmInst.get('main_indirect')!,
                    pmInst.get('backend')!,
                    pmInst.get('battery')!,
                    backendUser,
                ])
            );
        }
        console.log("Testing owners of the PM modules...");
        for (const [principal, create] of [
            [pmInst.get('simple_indirect')!, createSimpleIndirectActor],
            [pmInst.get('main_indirect')!, createIndirectActor],
            [pmInst.get('backend')!, createPackageManager],
            [pmInst.get('battery')!, createBattery],
        ]) {
            const canister = (create as any)(principal, {agent: backendAgent});
            const owners = await canister.getOwners();
            console.log(`Checking ${getCanisterNameFromPrincipal(principal as Principal)}...`);
            const expectedOwners = [
                pmInst.get('simple_indirect')!,
                pmInst.get('main_indirect')!,
                pmInst.get('backend')!,
                pmInst.get('battery')!, // Battery is self-dependent:
                backendUser,
            ];
            expect(new Set(owners)).to.equalPrincipalSet(
                new Set(expectedOwners)
            );
        }
        console.log("Checking PM frontend owners...");
        const pmFrontend = createPMFrontend(pmInst.get("frontend")!, {agent: backendAgent});
        for (const permission of [{Commit: null}, {ManagePermissions: null}, {Prepare: null}]) {
            const owners = await pmFrontend.list_permitted({permission});
            expect(new Set(owners)).to.equalPrincipalSet(
                new Set([
                    pmInst.get('simple_indirect')!,
                    pmInst.get('main_indirect')!,
                    pmInst.get('backend')!,
                    pmInst.get('battery')!, // Battery is self-dependent:
                    backendUser,
                ])
            );
        }

        console.log("Installing `example` package...");
        const { canisterStatus } = ICManagementCanister.create({agent: backendAgent});
        for (const [moduleName, canister_id] of pmInst.entries()) {
            const { cycles } = await canisterStatus(canister_id);
            console.log(`Cycles in canister '${moduleName}': ${Number(cycles.toString())/10**12}T`);
        }
        const {minInstallationId: exampleInstallationId} = await packageManager.installPackages({
            packages: [{
                packageName: "example",
                version: "0.0.1",
                repo: Principal.fromText(process.env.CANISTER_ID_REPOSITORY!),
                arg: new Uint8Array(),
                initArg: [],
            }],
            user: backendUser,
            afterInstallCallback: [],
        });
        await waitTillInitialized(backendAgent, pmInst.get('backend')!, exampleInstallationId);

        const examplePkg = await packageManager.getInstalledPackage(exampleInstallationId);
        for (const moduleName of ['example1', 'example2']) {
            const examplePrincipal = examplePkg.modulesInstalledByDefault.filter(([name, _principal]) => name === moduleName)[0][1];
            const exampleInfo = await simpleIndirect.canister_info(
                {canister_id: examplePrincipal, num_requested_changes: []}, 1000_000_000_000n);
            expect(new Set(exampleInfo.controllers)).to.equalPrincipalSet(new Set([
                pmInst.get('simple_indirect')!, backendUser, pmInst.get('main_indirect')!, pmInst.get('battery')! 
            ]));
        }

        const examplePrincipal = examplePkg.modulesInstalledByDefault.filter(([name, _principal]) => name === 'example1')[0][1];
        const exampleFrontend = createExampleFrontend(examplePrincipal, {agent: backendAgent});
        console.log("Checking example frontend owners...");
        for (const permission of [{Commit: null}, {ManagePermissions: null}, {Prepare: null}]) {
            const owners = await exampleFrontend.list_permitted({permission});
            expect(new Set(owners)).to.equalPrincipalSet(new Set([pmInst.get('simple_indirect')!, pmInst.get('main_indirect')!, backendUser]));
        }

        console.log("Installing `upgradeable` package...");
        const {minInstallationId: upgradeableInstallationId} = await packageManager.installPackages({
            packages: [{
                packageName: "upgradeable",
                version: "0.0.1",
                repo: Principal.fromText(process.env.CANISTER_ID_REPOSITORY!),
                arg: new Uint8Array(),
                initArg: [],
            }],
            user: backendUser,
            afterInstallCallback: [],
        });
        await waitTillInitialized(backendAgent, pmInst.get('backend')!, upgradeableInstallationId);
        console.log("Upgrading `upgradeable` package...");
        await packageManager.upgradePackages({
            packages: [{
                installationId: upgradeableInstallationId,
                packageName: "upgradeable",
                version: "0.0.2",
                repo: Principal.fromText(process.env.CANISTER_ID_REPOSITORY!),
                arg: new Uint8Array(),
                initArg: [],
            }],
            afterUpgradeCallback: [],
            user: backendUser,
        });
        console.log("Testing upgraded package `upgradeable`...");
        // We will wait till `m1` is removed, because this signifie the upgrade is done. // TODO@P3: a better way
        // TODO@P3: More detailed test:
        async function myNamedModules(): Promise<Set<string>> {
            const upgradeablePkg = await packageManager.getInstalledPackage(upgradeableInstallationId);
            return new Set(Array.from(upgradeablePkg.modulesInstalledByDefault.values()).map(([name, _principal]) => name));
        }
        await waitForValue(myNamedModules, new Set(['m2', 'm3']), areEqualSets, 120000);
    });
    // TODO@P3: Test `removeStalled()`.
});