// TODO: Rename this file.

import { Principal } from '@dfinity/principal';
import { InstallationId, PackageName, PackageManager, Version, SharedRealPackageInfo, CheckInitializedCallback, SharedInstalledPackageInfo } from '../declarations/package_manager/package_manager.did';
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
    // const part = createRepositoryPartition(repo);
    // const pkg = await part.getPackage(packageName, version); // TODO: a little inefficient
    // const pkgReal = (pkg!.specific as any).real as SharedRealPackageInfo;
    // const pkg2 = await package_manager.getInstalledPackage(BigInt(0)); // TODO: hard-coded package ID
    // const indirectPrincipal = pkg2.modules.filter(x => x[0] === 'indirect')[0][1];
    // const indirect = createIndirectCaller(indirectPrincipal, {agent});
    return {installationId};
}

/// Note that this can be checked only from frontend, because calling from backend hacker can hang.
export class InitializedChecker {
    private defaultAgent: Agent;
    private package_manager: Principal;
    private installationId: InstallationId;
    static async create(arg: {
        package_manager: Principal,
        installationId: InstallationId,
        defaultAgent: Agent,
    }) {
        return new InitializedChecker(arg.package_manager, arg.installationId, arg.defaultAgent);
    }
    private constructor(
        package_manager: Principal,
        installationId: bigint,
        defaultAgent: Agent
    ) {
        this.package_manager = package_manager;
        this.installationId = installationId;
        this.defaultAgent = defaultAgent;
    }
    async check(): Promise<boolean> {
        // TODO: very inefficient
        try {
            const pkgMan: PackageManager = createPackageManager(this.package_manager, {agent: this.defaultAgent});
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
                    agent: this.defaultAgent,
                    canisterId: canister!,
                });
                await actor[methodName](); // throws or doesn't
                return true;
            }

            const urlPath: string | undefined = (cb.how as any).urlPath;
            if (urlPath !== undefined) {
                const frontend = createFrontendActor(canister!, {agent: this.defaultAgent});
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