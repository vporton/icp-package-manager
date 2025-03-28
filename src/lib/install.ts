// TODO: Rename this file.
import { Principal } from '@dfinity/principal';
import { InstallationId, PackageManager, SharedRealPackageInfo, SharedModule } from '../declarations/package_manager/package_manager.did';
import { createActor as createPackageManager } from '../declarations/package_manager';
import { createActor as createFrontendActor } from '../declarations/example_frontend';
import { Actor, Agent } from '@dfinity/agent';
import { createActor as createBootstrapperIndirectActor } from "../declarations/bootstrapper";
import { createActor as createRepositoryIndexActor } from "../declarations/repository";
import { IDL } from "@dfinity/candid";

async function getRandomValues(v: Uint8Array): Promise<Uint8Array> {
    const mycrypto = await import("crypto"); // TODO: This forces to use `"module": "ES2020"`.
    if (typeof window !== 'undefined') {
        return crypto.getRandomValues(v);
    } else {
        return mycrypto.webcrypto.getRandomValues(v);
    }
}

async function sha256(v: Uint8Array): Promise<Uint8Array> {
    const mycrypto = await import("crypto"); // TODO: This forces to use `"module": "ES2020"`.
    if (typeof window !== 'undefined') {
        return new Uint8Array(await crypto.subtle.digest('SHA-256', v));
    } else {
        const hash = mycrypto.createHash('sha256');
        hash.update(v);
        return new Uint8Array(hash.digest());
    }
}

export async function bootstrapFrontend(props: {agent: Agent}) { // TODO: Move to `useEffect`.
    const repoIndex = createRepositoryIndexActor(process.env.CANISTER_ID_REPOSITORY!, {agent: props.agent}); // TODO: `defaultAgent` here and in other places.
    try {// TODO: Duplicate code
        let pkg = await repoIndex.getPackage('icpack', "stable");
        const pkgReal = (pkg!.specific as any).real as SharedRealPackageInfo;

        const bootstrapper = createBootstrapperIndirectActor(process.env.CANISTER_ID_BOOTSTRAPPER!, {agent: props.agent});
        const frontendTweakPrivKey = await getRandomValues(new Uint8Array(32));
        const frontendTweakPubKey = await sha256(frontendTweakPrivKey);
        const frontendModule = pkgReal.modules.find(m => m[0] === "frontend")!;
        const {installedModules} = await bootstrapper.bootstrapFrontend({
            frontendTweakPubKey,
        });
        return {installedModules, frontendTweakPrivKey};
    }
    catch(e) {
      console.log(e);
      throw e; // TODO
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
            // TODO: very inefficient
            const pkgMan: PackageManager = createPackageManager(this.package_manager, {agent: this.agent});
            const pkg = await pkgMan.getInstalledPackage(this.installationId);
            const real = (pkg.package.specific as any).real as SharedRealPackageInfo;
            if (real.checkInitializedCallback.length === 0) {
                return; // TODO: Also check that all modules were installed.
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
            console.log("Waiting for initialization...");
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
                console.log("Waiting for initialization: " + (e as any).message); // TODO: shorter message
            }
            if (i == 30) {
                reject("Cannot initilialize canisters");
            }
            await new Promise<void>((resolve, _reject) => {
                setTimeout(() => resolve(), 1000);
            });
        }
    });
}