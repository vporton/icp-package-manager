import { Principal } from "@dfinity/principal";
import { useContext, useEffect, useState } from "react";
import { useParams } from "react-router-dom";
import { createActor as createPackageManager } from '../../declarations/package_manager';
import { createActor as createCyclesLedger } from '../../declarations/cycles_ledger';
import { PackageManager } from "../../declarations/package_manager/package_manager.did";
import { useAuth } from "../../lib/use-auth-client";
import { URLSearchParams } from "url";
import { setServers } from "dns";
import Button from "react-bootstrap/Button";
import { Actor } from "@dfinity/agent";
import { ICManagementCanister } from "@dfinity/ic-management";
import { ErrorContext } from "../../lib/ErrorContext";
import { GlobalContext } from "./state";

export default function ModuleCycles() {
    const params = new URLSearchParams(window.location.search);
    const pmPrincipal = Principal.fromText(params.get('_pm_pkg0.backend')!);
    const { agent, ok, principal } = useAuth();
    const { setError } = useContext(ErrorContext)!;
    const glob = useContext(GlobalContext);
    type Module = {
        moduleName: string;
        principal: Principal;
        cycles: bigint | undefined;
    };
    const [counter, setCounter] = useState(0);
    const [pkgs, setPkgs] = useState<{packageName: string, packageVersion: string, modules: Module[]}[]>([]);
    const reloadPackages = () => {
        if (glob.packageManager === undefined || agent === undefined || !ok) {
            setPkgs([]);
            return;
        }
        const _pkgs: {packageName: string, packageVersion: string, modules: Module[]}[] = [];
        glob.packageManager.getAllInstalledPackages().then(packages => {
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
                    const { canisterStatus } = ICManagementCanister.create({agent});
                    for (const m of modules) {
                        canisterStatus(m.principal).then(({cycles}) => {
                            m.cycles = cycles;
                            setCounter(prev => prev + 1);
                        }).catch(e => {
                            setError(e.toString());
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
    };
    useEffect(reloadPackages, [agent, ok, glob.packageManager]);
    async function sendTo(module: {
        moduleName: string,
        principal: Principal,
        cycles: bigint | undefined;
    }, to: Principal) {
        try {
            const cyclesLedger = createCyclesLedger(process.env.CANISTER_ID_CYCLES_LEDGER!, {agent});
            const balance = await cyclesLedger.icrc1_balance_of({owner: module.principal, subaccount: []});

            const methodName = "withdrawCycles3"; // Method name from package specs
            const interfaceFactory = ({ IDL }: { IDL: any }) => { // TODO@P3: `any`
                return IDL.Service({
                    [methodName]: IDL.Func([IDL.Nat, IDL.Principal], [], ["update"])
                });
            };
            const withdrawer = Actor.createActor(interfaceFactory, {
                agent,
                canisterId: module.principal,
            });
            console.log(`Trying to send ${balance} cycles from ${module.principal} to ${to}`);
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
            <p>TODO@P3: This page is a mess now. Transfers can be performed through several canisters.</p>
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
                                {ok && <>
                                    {" "}
                                    <Button onClick={() => sendTo(module, principal!)}>
                                        to user
                                    </Button>
                                    {" "}
                                    <Button onClick={() => sendTo(module, pkgs[0].modules.filter(m => m.moduleName === "battery")[0].principal)}>
                                        to battery
                                    </Button>
                                    {/* Cannot transfer to package manager backend module, because it is not a controller. */}
                                    {" "}
                                    <Button onClick={() => sendTo(module, pkgs[0].modules.filter(m => m.moduleName === "backend")[0].principal)}>
                                        to backend
                                    </Button>
                                    {" "}
                                    <Button onClick={() => sendTo(module, pkgs[0].modules.filter(m => m.moduleName === "simple_indirect")[0].principal)}>
                                        to simple indirect
                                    </Button>
                                </>}
                            </li>
                        ))}
                    </ul>
                </div>
            ))}
        </>
    );
}