// TODO: Rename this file.

import { Principal } from '@dfinity/principal';
import { InstallationId, PackageName, PackageManager, Version, SharedRealPackageInfo, CheckInitializedCallback } from '../declarations/package_manager/package_manager.did';
import { createActor as createRepositoryPartition } from '../declarations/RepositoryPartition';
import { createActor as createIndirectCaller } from '../declarations/Bootstrapper';
import { createActor as createPackageManager } from '../declarations/package_manager';
import { createActor as createFrontendActor } from '../declarations/bootstrapper_frontend';
import { IDL } from '@dfinity/candid';
import { Actor, Agent } from '@dfinity/agent';

export async function installPackageWithModules({
    package_manager_principal, packageName, repo, user, version, agent
}: {
    package_manager_principal: Principal,
    packageName: PackageName,
    repo: Principal,
    user: Principal,
    version: Version,
    agent: Agent,
}): Promise<{
    installationId: InstallationId;
}> {
    const package_manager: PackageManager = createPackageManager(package_manager_principal, {agent});
    const {installationId} = await package_manager.installPackage({
        packageName,
        version,
        repo,
        user,
    });
    const part = createRepositoryPartition(repo);
    const pkg = await part.getPackage(packageName, version); // TODO: a little inefficient
    const pkgReal = (pkg!.specific as any).real as SharedRealPackageInfo;
    const pkg2 = await package_manager.getInstalledPackage(BigInt(0)); // TODO: hard-coded package ID
    const indirectPrincipal = pkg2.modules.filter(x => x[0] === 'indirect')[0][1];
    const indirect = createIndirectCaller(indirectPrincipal, {agent});
    return {installationId};
}

/// Note that this can be checked only from frontend, because calling from backend hacker can hang.
export class InitializedChecker {
    private canister: Principal | undefined;
    private cb: CheckInitializedCallback | undefined;
    private defaultAgent: Agent;
    static async create(arg: {
        package_manager: Principal,
        installationId: InstallationId,
        defaultAgent: Agent,
    }) {
        // TODO: not very efficient
        const pkgMan: PackageManager = createPackageManager(arg.package_manager, {agent: arg.defaultAgent});
        console.log("arg.installationId", arg.installationId);
        const pkg = await pkgMan.getInstalledPackage(arg.installationId);
        console.log("pkg", pkg);
        const real = (pkg.package.specific as any).real as SharedRealPackageInfo;
        console.log("real", real);
        if (real.checkInitializedCallback.length === 0) {
            return new InitializedChecker(undefined, undefined, arg.defaultAgent);
        }
        const cb = real.checkInitializedCallback[0];
        console.log("A1", cb); // FIXME: Remove.

        const canister = pkg.modules.filter(([name, _m]) => name === cb.moduleName)[0][1];

        return new InitializedChecker(canister, cb, arg.defaultAgent);
    }
    private constructor(canister: Principal | undefined, cb: CheckInitializedCallback | undefined, defaultAgent: Agent) {
        this.canister = canister;
        this.cb = cb;
        this.defaultAgent = defaultAgent;
    }
    async check(): Promise<boolean> {
        console.log("B1", this.cb); // FIXME: Remove.
        if (this.cb === undefined) {
            return false; // TODO: Also check that all modules were installed.
                          // Note that it is easier to do here, in frontend.
        }

        const methodName: string | undefined = (this.cb.how as any).methodName;
        console.log("B2", methodName, this.canister); // FIXME: Remove.
        if (methodName !== undefined) {
            try {
                const idlFactory = ({ IDL }: { IDL: any }) => {
                    return IDL.Service({
                        [methodName]: IDL.Func([], [], ['query']),
                    });
                };
                const actor = Actor.createActor(idlFactory, {
                    agent: this.defaultAgent,
                    canisterId: this.canister!,
                });
                console.log("B3"); // FIXME: Remove.
                await actor[methodName](); // throws or doesn't
                console.log("B4"); // FIXME: Remove.
                return true;
            }
            catch (e) {
                console.log("B5"); // FIXME: Remove.
                console.log(e);
                console.log("B6"); // FIXME: Remove.
                return false;
            }
        }

        const urlPath: string | undefined = (this.cb.how as any).urlPath;
        if (urlPath !== undefined) {
            const frontend = createFrontendActor(this.canister!, {agent: this.defaultAgent});
            try {
                const res = await frontend.http_request({method: "GET", url: urlPath, headers: [], body: [], certificate_version: [2]});
                return res.status_code - res.status_code % 100 === 200;
            }
            catch (e) {
                console.log(e);
                return false;
            }
        }

        return true;
    }
}