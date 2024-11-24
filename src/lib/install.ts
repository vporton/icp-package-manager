import { Principal } from '@dfinity/principal';
import { InstallationId, PackageName, PackageManager, Version, SharedRealPackageInfo } from '../declarations/package_manager/package_manager.did';
import { createActor as createRepositoryPartition } from '../declarations/RepositoryPartition';
import { createActor as createIndirectCaller } from '../declarations/BootstrapperIndirectCaller';
import { createActor as createPackageManager } from '../declarations/package_manager';
import { IDL } from '@dfinity/candid';
import { Agent } from '@dfinity/agent';

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
    console.log(`installPackage ${package_manager_principal} with ${user}`);
    const {installationId} = await package_manager.installPackage({
        packageName: packageName!,
        version,
        repo,
        user,
    });
    const part = createRepositoryPartition(repo);
    const pkg = await part.getPackage(packageName, version); // TODO: a little inefficient
    const pkgReal = (pkg!.specific as any).real as SharedRealPackageInfo;
    const pkg2 = await package_manager.getInstalledPackage(BigInt(0)); // FIXME: hard-coded package ID
    const indirectPrincipal = pkg2.modules.filter(x => x[0] === 'indirect')[0][1];
    const indirect = createIndirectCaller(indirectPrincipal);
    // Starting installation of all modules in parallel:
    for (const [name, [m, dfn]] of pkgReal.modules) {
        if (!dfn) {
          continue;
        }
        indirect.installModule({
          installPackage: true,
          moduleName: [name],
          installArg: new Uint8Array(IDL.encode([IDL.Record({})], [{}])),
          installationId,
          packageManagerOrBootstrapper: package_manager_principal, // FIXME: correct?
          // "backend" goes first, because it stores installation information.
          preinstalledCanisterId: [],
          user, // TODO: This argument seems superfluous for `installModule`.
          wasmModule: m,
          noPMBackendYet: false, // HACK
        });
    };
    return {installationId};
}