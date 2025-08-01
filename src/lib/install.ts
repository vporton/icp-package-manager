import { Principal } from '@dfinity/principal';
import { InstallationId, PackageManager, SharedRealPackageInfo, SharedModule } from '../declarations/package_manager/package_manager.did';
import { createActor as createPackageManager } from '../declarations/package_manager';
import { createActor as createFrontendActor } from '../declarations/example_frontend';
import { Actor, Agent } from '@dfinity/agent';
import { createActor as createBootstrapperIndirectActor } from "../declarations/bootstrapper";
import { createActor as createRepositoryIndexActor } from "../declarations/repository";

const { subtle } = crypto ?? globalThis.crypto;

// TODO@P3: Can we simplify this function?
async function getRandomValues(v: Uint8Array): Promise<Uint8Array> {
    if (typeof window !== 'undefined') {
        return crypto.getRandomValues(v);
    } else {
        const mycrypto = await import("crypto"); // TODO@P3: This forces to use `"module": "ES2020"`.
        return mycrypto.webcrypto.getRandomValues(v);
    }
}

import { sha256 } from './crypto';

export async function bootstrapFrontend(props: {agent: Agent}) {
    const repoIndex = createRepositoryIndexActor(process.env.CANISTER_ID_REPOSITORY!, {agent: props.agent}); // TODO@P3: `defaultAgent` here and in other places.
    try { // TODO@P3: Duplicate code(?)
        const pair = await subtle.generateKey(
            {name: 'ECDSA', namedCurve: 'P-256'/*prime256v1*/}, true, ['sign']
        );

        const bootstrapper = createBootstrapperIndirectActor(process.env.CANISTER_ID_BOOTSTRAPPER!, {agent: props.agent});
        const {installedModules, spentCycles} = await bootstrapper.bootstrapFrontend({
            frontendTweakPubKey: new Uint8Array(await subtle.exportKey("spki", pair.publicKey)),
        });
        return {installedModules, frontendTweakPrivKey: pair.privateKey, frontendTweakPubKey: pair.publicKey, spentCycles};
    }
    catch(e) {
      console.log(e);
      throw e; // TODO@P3
    }
}

/// Check if the package is initialized.
///
/// Note that this can be checked only from frontend, because calling from backend hacker can hang.
export class InitializedChecker {
    private agent: Agent;
    private package_manager: Principal;
    private installationId: InstallationId;
    static async create(arg: {
        package_manager: Principal,
        installationId: InstallationId,
        agent: Agent,
    }) {
        return new InitializedChecker(arg.package_manager, arg.installationId, arg.agent);
    }
    private constructor(
        package_manager: Principal,
        installationId: bigint,
        agent: Agent
    ) {
        this.package_manager = package_manager;
        this.installationId = installationId;
        this.agent = agent;
    }
    /// Throws exception, if not yet installed.
    async check() {
        try {
            // TODO@P3: bring object creations outside this method, because it is typically called in a loop.
            const pkgMan: PackageManager = createPackageManager(this.package_manager, {agent: this.agent});
            const pkg = await pkgMan.getInstalledPackage(this.installationId);
            const real = (pkg.package.specific as any).real as SharedRealPackageInfo;
            if (real.checkInitializedCallback.length === 0) {
                return; // TODO@P3: Also check that all modules were installed.
                        // Note that it is easier to do here, in frontend.
            }
            const cb = real.checkInitializedCallback[0];
            const canister = pkg.modulesInstalledByDefault.filter(([name, _m]) => name === cb.moduleName)[0][1];

            const methodName: string | undefined = (cb.how as any).methodName;
            if (methodName !== undefined) {
                const idlFactory = ({ IDL }: { IDL: any }) => {
                    return IDL.Service({
                        [methodName]: IDL.Func([], [], ['query']),
                    });
                };
                const actor = Actor.createActor(idlFactory, {
                    agent: this.agent,
                    canisterId: canister!,
                });
                await actor[methodName](); // throws or doesn't
            }

            const urlPath: string | undefined = (cb.how as any).urlPath;
            if (urlPath !== undefined) {
                const frontend = createFrontendActor(canister!, {agent: this.agent});
                const res = await frontend.http_request({method: "GET", url: urlPath, headers: [], body: [], certificate_version: [2]});
                const status_code = parseInt(res.status_code.toString());
                if (status_code - status_code % 100 !== 200) {
                    throw "frontend not initialized";
                }
            }
        }
        catch (e) {
            // console.log("Waiting for initialization: " + e);
            throw e;
        }
    }
}

export async function waitTillInitialized(agent: Agent, package_manager: Principal, installationId: InstallationId) {
    return new Promise<void>(async (resolve, reject) => {
        const checker = await InitializedChecker.create({package_manager, installationId, agent});
        for (let i = 0; ; ++i) {
            try {
                await checker.check();
                resolve();
                return;
            }
            catch (e) {
                console.log("Waiting for initialization...");
            }
            if (i == 30) {
                reject("Cannot initialize canisters, possibly not enough cycles on battery, fund your account");
                return;
            }
            await new Promise<void>((resolve, _reject) => {
                setTimeout(() => resolve(), 1000);
            });
        }
    });
}