import { Principal } from "@dfinity/principal";
import { useContext, useEffect, useState } from "react";
import { useParams } from "react-router-dom";
import { createActor as createPackageManager } from '../../declarations/package_manager';
import { createActor as createCyclesLedger } from '../../declarations/cycles_ledger';
import { PackageManager } from "../../declarations/package_manager/package_manager.did";
import { useAuth } from "./auth/use-auth-client";
import { URLSearchParams } from "url";
import { setServers } from "dns";
import { Button } from "react-bootstrap";
import { Actor } from "@dfinity/agent";
import { ErrorContext } from "../../lib/ErrorContext";

export default function ModuleCycles() {
    const params = new URLSearchParams(window.location.search);
    const pmPrincipal = Principal.fromText(params.get('_pm_pkg0.backend')!);
    const { agent, isAuthenticated, principal } = useAuth();
    const { setError } = useContext(ErrorContext)!;
    type Module = {
        moduleName: string;
        principal: Principal;
        cycles: bigint | undefined;
    };
    const [counter, setCounter] = useState(0);
    const [pkgs, setPkgs] = useState<{packageName: string, packageVersion: string, modules: Module[]}[]>([]);
    const reloadPackages = () => {
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
    };
    useEffect(reloadPackages, [agent, isAuthenticated]);
    async function sendTo(module: {
        moduleName: string,
        principal: Principal,
        cycles: bigint | undefined;
    }, to: Principal) {
        try {
            const cyclesLedger = createCyclesLedger(process.env.CANISTER_ID_CYCLES_LEDGER!, {agent});
            const balance = await cyclesLedger.icrc1_balance_of({owner: module.principal, subaccount: []});

            const methodName = "withdrawCycles"; // FIXME@P3: Use the correct method name from package specs.
            const interfaceFactory = ({ IDL }: { IDL: any }) => { // TODO@P3: `any`
                return IDL.Service({
                    [methodName]: IDL.Func([IDL.Nat, IDL.Principal], [], ["update"])
                });
            };
            const withdrawer = Actor.createActor(interfaceFactory, {
                agent,
                canisterId: module.principal,
            });
            await withdrawer[methodName](balance - 100_000_000n, to); // minus the fee

            reloadPackages();
        }
        catch (e) {
            console.error(e);
            setError((e as object).toString());
        }
    }
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
                                {isAuthenticated && <>
                                    {" "}
                                    <Button onClick={() => sendTo(module, principal!)}>
                                        to user
                                    </Button>
                                    {" "}
                                    <Button onClick={() => sendTo(module, Principal.fromText(process.env.CANISTER_ID_BATTERY!))}>
                                        to battery
                                    </Button>
                                    {/* Cannot transfer to package manager backend module, because it is not a controller. */}
                                    {/* {" "}
                                    <Button onClick={() => sendTo(module, Principal.fromText(process.env.CANISTER_ID_PACKAGE_MANAGER!))}>
                                        to backend
                                    </Button> */}
                                </>}
                            </li>
                        ))}
                    </ul>
                </div>
            ))}
        </>
    );
}