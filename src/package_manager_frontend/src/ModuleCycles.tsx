import { Principal } from "@dfinity/principal";
import { useEffect, useState } from "react";
import { useParams } from "react-router-dom";
import { createActor as createPackageManager } from '../../declarations/package_manager';
import { createActor as createCyclesLedger } from '../../declarations/cycles_ledger';
import { PackageManager } from "../../declarations/package_manager/package_manager.did";
import { useAuth } from "./auth/use-auth-client";
import { URLSearchParams } from "url";
import { setServers } from "dns";

export default function ModuleCycles() {
    const params = new URLSearchParams(window.location.search);
    const pmPrincipal = Principal.fromText(params.get('_pm_pkg0.backend')!);
    const { agent, isAuthenticated } = useAuth();
    type Module = {
        moduleName: string;
        cycles: bigint | undefined;
    };
    const [counter, setCounter] = useState(0);
    const [pkgs, setPkgs] = useState<{packageName: string, packageVersion: string, modules: Module[]}[]>([]);
    useEffect(() => {
        if (isAuthenticated) {
            const cyclesLedger = createCyclesLedger(process.env.CANISTER_ID_CYCLES_LEDGER!, {agent});
            const _pkgs: {packageName: string, packageVersion: string, modules: Module[]}[] = [];
            const packageManager: PackageManager = createPackageManager(pmPrincipal, {agent});
            packageManager.getAllInstalledPackages().then(packages => {
                for (const p of packages) {
                    if ((p[1].package.specific as any).real) {
                        const modules = p[1].modulesInstalledByDefault.map<{
                            moduleName: string,
                            principal: Principal,
                            cycles: bigint | undefined;
                        }>(m => {
                            return {
                                moduleName: m[0],
                                principal: m[1],
                                cycles: undefined,
                            };
                        });
                        for (const m of modules) {
                            cyclesLedger.icrc1_balance_of({owner: m.principal, subaccount: []}).then(balance => {
                                m.cycles = balance;
                                setCounter(counter + 1);
                            });
                        }
                        const h = {
                            packageName: p[1].package.base.name,
                            packageVersion: p[1].package.base.version,
                            // TODO@P3: `additionalModules`
                            modules,
                        };
                        _pkgs.push(h);
                    }
                }
                setPkgs(_pkgs);
            });
        } else {
            setPkgs([]);
        }
    }, [agent, isAuthenticated]);
    return (
        <>
            <h2>Modules Cycles</h2>
            {pkgs.map((pkg) => (
                <div key={pkg.packageName}>
                    <h3>{pkg.packageName}</h3>
                    <ul>
                        {pkg.modules.map((module) => (
                            <li key={module.moduleName}>
                                {module.moduleName}
                                {module.cycles !== undefined ?
                                    " "+Number(module.cycles.toString())/10**12+"T cycles"
                                : " Loading..."}
                            </li>
                        ))}
                    </ul>
                </div>
            ))}
        </>
    );
}