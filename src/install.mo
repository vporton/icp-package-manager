/// Common code for package manager and bootstrapper.
import Cycles "mo:base/ExperimentalCycles";
import Principal "mo:base/Principal";
import Debug "mo:base/Debug";
import Blob "mo:base/Blob";
import HashMap "mo:base/HashMap";
import Buffer "mo:base/Buffer";
import Asset "mo:assets-api";
import copy_assets "copy_assets";
import Common "common";
import RepositoryPartition "repository_backend/RepositoryPartition";
import IndirectCaller "package_manager_backend/indirect_caller";

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
        noPMBackendYet: Bool;
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
            noPMBackendYet;
        });

        {installationId};
    };
}