import { Principal } from "@dfinity/principal";
import { useEffect, useState } from "react";
import { useParams } from "react-router-dom";
import { createActor as createPackageManager } from '../../declarations/package_manager';
import { PackageManager, SharedInstalledPackageInfo } from "../../declarations/package_manager/package_manager.did";
import { useAuth } from "./auth/use-auth-client";
import { URLSearchParams } from "url";

export default function ModuleCycles() {
    const params = new URLSearchParams(window.location.search);
    const pmPrincipal = Principal.fromText(params.get('_pm_pkg0.backend')!);
    const { agent } = useAuth();
    type Module = {
        moduleName: string;
        cycles: bigint | undefined;
    };
    const [pkgs, setPkgs] = useState<{packageName: string, packageVersion: string, modules: Module[]}[]>([]);
    useEffect(() => {
        const _pkgs: {packageName: string, packageVersion: string, modules: Module[]}[] = [];
        const packageManager: PackageManager = createPackageManager(pmPrincipal, {agent});
        packageManager.getAllInstalledPackages().then(packages => {
            for (const p of packages) {
                if ((p[1].package.specific as any).real) {
                    const real = (p[1].package.specific as any).real as SharedInstalledPackageInfo;
                    _pkgs.push({
                        packageName: p[1].package.base.name,
                        packageVersion: p[1].package.base.version,
                        // TODO@P3: `additionalModules`
                        modules: real.modulesInstalledByDefault.map(m => {
                            return {
                                moduleName: m[0],
                                cycles: undefined,
                            }
                        }),
                    });
                }
            }
            setPkgs(_pkgs);
        });

        // Get ICRC1 cycles for each module:
    }, []);
    return (
        <>
            <h2>Modules Cycles</h2>
            {pkgs.map((pkg) => (
                <div key={pkg.packageName}>
                    <h2>{pkg.packageName}</h2>
                    <ul>
                        {pkg.modules.map((module) => (
                            <li key={module.moduleName}>{module.moduleName}</li>
                        ))}
                    </ul>
                </div>
            ))}
        </>
    );
}