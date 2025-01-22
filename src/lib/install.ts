// TODO: Rename this file.
import { Principal } from '@dfinity/principal';
import { InstallationId, PackageManager, SharedRealPackageInfo } from '../declarations/package_manager/package_manager.did';
import { createActor as createPackageManager } from '../declarations/package_manager';
import { createActor as createFrontendActor } from '../declarations/bootstrapper_frontend';
import { Actor, Agent } from '@dfinity/agent';
import { createActor as createBootstrapperIndirectActor } from "../declarations/Bootstrapper";
import { createActor as createRepositoryIndexActor } from "../declarations/RepositoryIndex";
import { createActor as createRepositoryPartitionActor } from "../declarations/RepositoryPartition";
import { SharedPackageInfo } from "../declarations/RepositoryPartition/RepositoryPartition.did";
import { IDL } from "@dfinity/candid";
import { getRandomValues } from 'crypto';

export async function bootstrapFrontend(props: {user: Principal, agent: Agent}) { // TODO: Move to `useEffect`.
    const repoIndex = createRepositoryIndexActor(process.env.CANISTER_ID_REPOSITORYINDEX!, {agent: props.agent}); // TODO: `defaultAgent` here and in other places.
    try {// TODO: Duplicate code
        const repoParts = await repoIndex.getCanistersByPK("main");
        let pkg: SharedPackageInfo | undefined = undefined;
        const jobs = repoParts.map(async part => {
            const obj = createRepositoryPartitionActor(part, {agent: props.agent});
            try {
              pkg = await obj.getPackage('icpack', "0.0.1"); // TODO: `"stable"`
            }
            catch (e) {
                console.log(e); // TODO: return an error
            }
        });
        await Promise.all(jobs);
        const pkgReal = (pkg!.specific as any).real as SharedRealPackageInfo;

        const bootstrapper = createBootstrapperIndirectActor(process.env.CANISTER_ID_BOOTSTRAPPER!, {agent: props.agent});
        const frontendTweakPrivKey = getRandomValues(new Uint8Array(32));
        const frontendTweakPubKey = new Uint8Array(await crypto.subtle.digest('SHA-256', frontendTweakPrivKey));
        const {canister_id: frontendPrincipal} = await bootstrapper.bootstrapFrontend({
            wasmModule: pkgReal.modules[1][1],
            installArg: new Uint8Array(IDL.encode(
                [IDL.Record({user: IDL.Principal, installationId: IDL.Nat})],
                [{user: props.user, installationId: 0 /* TODO */}],
            )),
            user: props.user,
            initialIndirect: Principal.fromText(process.env.CANISTER_ID_BOOTSTRAPPER!), // FIXME
            simpleIndirect: Principal.fromText(process.env.CANISTER_ID_BOOTSTRAPPER!), // FIXME
            frontendTweakPubKey,
        });
        return {canister_id: frontendPrincipal, frontendTweakPrivKey};
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
    async check(): Promise<boolean> {
        // TODO: very inefficient
        try {
            const pkgMan: PackageManager = createPackageManager(this.package_manager, {agent: this.agent});
            const pkg = await pkgMan.getInstalledPackage(this.installationId);
            const real = (pkg.package.specific as any).real as SharedRealPackageInfo;
            if (real.checkInitializedCallback.length === 0) {
                return false; // TODO: Also check that all modules were installed.
                            // Note that it is easier to do here, in frontend.
            }
            const cb = real.checkInitializedCallback[0];
            const canister = pkg.modules.filter(([name, _m]) => name === cb.moduleName)[0][1];

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
                return true;
            }

            const urlPath: string | undefined = (cb.how as any).urlPath;
            if (urlPath !== undefined) {
                const frontend = createFrontendActor(canister!, {agent: this.agent});
                const res = await frontend.http_request({method: "GET", url: urlPath, headers: [], body: [], certificate_version: [2]});
                const status_code = parseInt(res.status_code.toString());
                return status_code - status_code % 100 === 200;
            }
        }
        catch (e) {
            // console.log(e);
            return false;
        }

        return true;
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
            catch (_) {} // TODO
            if (i == 30) {
                reject("Cannot initilialize canisters");
                return;
            }
            await new Promise<void>((resolve, _reject) => {
                setTimeout(() => resolve(), 1000);
            });
        }
    });
}