/// Common code for package manager and bootstrapper.
import Principal "mo:base/Principal";
import Common "common";
import IndirectCaller "package_manager_backend/indirect_caller";

// TODO: Huh, module of just one function?
module {
    public func _installModulesGroup({
        indirectCaller: IndirectCaller.IndirectCaller;
        whatToInstall: {
            #package;
            #simplyModules : [(Text, Common.SharedModule)];
        };
        installationId: Common.InstallationId;
        packageName: Common.PackageName;
        packageVersion: Common.Version;
        pmPrincipal: ?Principal; /// `null` means that the first installed module is the PM (used in bootstrapping). // FIXME: It doesn't.
        repo: Common.RepositoryPartitionRO;
        user: Principal;
        preinstalledModules: [(Text, Principal)];
    })
        : async* {installationId: Common.InstallationId}
    {
        indirectCaller.installPackageWrapper({
            whatToInstall;
            installationId;
            packageName;
            version = packageVersion;
            pmPrincipal;
            repo;
            user;
            preinstalledModules;
        });

        {installationId};
    };
}