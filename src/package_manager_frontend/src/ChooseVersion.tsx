import { useEffect, useState } from "react";
import { useParams } from "react-router-dom";
import { Location, ModuleCode, SharedFullPackageInfo } from '../../declarations/repository/repository.did.js';
import { Actor, Agent } from "@dfinity/agent";
import { useContext } from 'react';
import { useAuth } from "../../lib/use-auth-client.js";
import Button from "react-bootstrap/Button";
import { Principal } from "@dfinity/principal";
import { _SERVICE as Repository } from '../../declarations/repository/repository.did';
import { idlFactory as repositoryIndexIdl } from '../../declarations/repository';
import { createActor as createPackageManager } from '../../declarations/package_manager';
import { myUseNavigate } from "./MyNavigate";
import { GlobalContext } from "./state";
import { InitializedChecker, waitTillInitialized } from "../../lib/install";
import { ErrorContext } from "../../lib/ErrorContext";
import { InstallationId, PackageName, PackageManager, Version, SharedRealPackageInfo, CheckInitializedCallback, SharedModule } from '../../declarations/package_manager/package_manager.did';
import { BusyContext } from "../../lib/busy.js";
import Alert from "react-bootstrap/Alert";
import { ICManagementCanister } from "@dfinity/ic-management";
import { IDL } from "@dfinity/candid";

/// `oldInstallation === undefined` means that the package is newly installed rather than upgraded.
export default function ChooseVersion(props: {}) {
    const { packageName, repo, installationId: oldInstallation } = useParams();
    const glob = useContext(GlobalContext);
    const [packageName2, setPackageName2] = useState<string | undefined>(packageName);
    const [repo2, setRepo2] = useState<Principal | undefined>(repo === undefined ? undefined : Principal.fromText(repo));
    const [version2, setVersion2] = useState<string | undefined>();
    const [guid0, setGuid0] = useState<any | undefined>(); // TODO@P3: inconsistent
    useEffect(() => {
        if (oldInstallation !== undefined && glob.packageManager !== undefined) {
            glob.packageManager.getInstalledPackage(BigInt(oldInstallation)).then(installation => {
                setPackageName2(installation.package.base.name);
                setRepo2(installation.packageRepoCanister);
                setVersion2(installation.package.base.version);
                setGuid0(installation.package.base.guid);
            });
        }
    }, [oldInstallation, glob.packageManager]);
    return (
        <ChooseVersion2
            packageName={packageName2}
            repo={repo2}
            oldInstallation={oldInstallation === undefined ? undefined : BigInt(parseInt(oldInstallation))}
            currentVersion={version2}
            guid0={guid0}/>
    );
}

function ChooseVersion2(props: {
    packageName: PackageName | undefined,
    repo: Principal | undefined,
    oldInstallation: InstallationId | undefined,
    currentVersion: Version | undefined,
    guid0: any | undefined,
}) {
    const glob = useContext(GlobalContext);
    const {setError} = useContext(ErrorContext)!;
    const navigate = myUseNavigate();
    const {ok, principal, agent, defaultAgent} = useAuth();
    const [versions, setVersions] = useState<[string, string][] | undefined>();
    const [installedVersions, setInstalledVersions] = useState<Map<string, 1>>(new Map());
    // const [guidInfo, setGUIDInfo] = useState<Uint8Array | undefined>();
    // TODO@P3: I doubt consistency, and performance in the case if there is no such package.
    useEffect(() => {
        if (glob.packageManager !== undefined && props.packageName !== undefined) {
            const index: Repository = Actor.createActor(repositoryIndexIdl, {canisterId: props.repo!, agent: defaultAgent});
            index.getFullPackageInfo(props.packageName!).then(fullInfo => {
                const versionsMap = new Map(fullInfo.versionsMap);
                const p2: [string, string][] = fullInfo.packages.map(pkg => [pkg[0], versionsMap.get(pkg[0]) ?? pkg[0]]);
                const v = fullInfo.versionsMap.map(([name, version]) => [`${name} → ${version}`, version] as [string, string]).concat(p2);
                setVersions(v);
                const guid2 = fullInfo.packages[0][1].base.guid as Uint8Array;
                // setGUIDInfo(guid2);
                if (v !== undefined && glob.packageManager !== undefined) {
                    glob.packageManager!.getInstalledPackagesInfoByName(props.packageName!, guid2).then(installed => {
                        setInstalledVersions(new Map(installed.all.map(e => [e.package.base.version, 1])));
                    });
                }
            });
        }
    }, [glob.packageManager, props.packageName, props.repo]); // TODO@P3: Check if `agent` is needed here (without it, it doesn't work properly).
    const [chosenVersion, setChosenVersion] = useState<string | undefined>(undefined);
    const [installing, setInstalling] = useState(false);
    let errorContext = useContext(ErrorContext);
    let { setBusy } = useContext(BusyContext);
    async function install() {
        try {
            setBusy(true);
            setInstalling(true);

            // TODO@P3: hack
            const {minInstallationId: id} = await glob.packageManager!.installPackages({
                packages: [{
                    packageName: props.packageName!,
                    version: chosenVersion!,
                    repo: props.repo!,
                    arg: new Uint8Array(),
                    initArg: [],
                }],
                user: principal!,
                afterInstallCallback: [],
            });
            await waitTillInitialized(agent!, glob.backend!, id);
            navigate(`/installed/show/${id}`);
        }
        catch (e) {
            const msg = (e as object).toString();
            console.log(msg);
            setError(msg);
        }
        finally {
            setBusy(false);
        }
    }
    async function upgrade() {
        try {
            setBusy(true);
            setInstalling(true);

            // TODO@P3: hack
            const package_manager: PackageManager = createPackageManager(glob.backend!, {agent});
            
            // Use modular upgrade API for icpack package (to avoid attempt to upgrade a running canister),
            // regular upgrade for others
            if (props.packageName === "icpack") {
                // TODO@P2: Extract to a library function and unit test it.

                // Start modular upgrade for icpack
                const upgradeResult = await package_manager.startModularUpgrade({
                    installationId: BigInt(props.oldInstallation!),
                    packageName: props.packageName!,
                    version: chosenVersion!,
                    repo: props.repo!,
                    arg: new Uint8Array(),
                    initArg: [],
                    user: principal!,
                });
                
                console.log(`Started modular upgrade for icpack. Upgrade ID: ${upgradeResult.upgradeId}, Total modules: ${upgradeResult.totalModules}`);
                console.log(`Modules to upgrade: ${upgradeResult.modulesToUpgrade.join(', ')}`);
                console.log(`Modules to delete: ${upgradeResult.modulesToDelete.map(([name, _]) => name).join(', ')}`);

                const modulesMap = new Map<string, Principal>();

                // Upgrade modules one by one, because `icpack` cannot upgrade itself.
                const managementCanister = ICManagementCanister.create({ agent: agent! });

                // Create repository actor to get the package info
                const repositoryActor: Repository = Actor.createActor(repositoryIndexIdl, {
                    agent: agent!,
                    canisterId: props.repo!
                });

                // Get the new WASM module from the repository
                const packageInfo = await repositoryActor.getPackage(props.packageName!, chosenVersion!);
                const realPackage = packageInfo.specific as { real: any };
                if (realPackage === undefined || realPackage.real === undefined) {
                    setError(`Invalid package info for ${props.packageName!} version ${chosenVersion!}`);
                    return;
                }
                const pkgModules = new Map<string, SharedModule>(realPackage.real.modules);

                // Then upgrade or install modules
                for (const moduleName of upgradeResult.modulesToUpgrade) {
                    // Handle infrastructure modules directly via Management Canister
                    console.log(`Processing module ${moduleName} via Management Canister`);
                    
                    // Get the canister ID for this module if it exists
                    let moduleCanisterId: Principal | undefined;
                    try {
                        moduleCanisterId = await package_manager.getModulePrincipal(BigInt(props.oldInstallation!), moduleName);
                        console.log(`Module ${moduleName} canister ID: ${moduleCanisterId.toString()}`);
                    } catch (e) {
                        console.log(`Module ${moduleName} is new and will be installed`);
                    }
                    
                    if (realPackage.real.modules.filter((m: [string, SharedModule]) => m[0] == moduleName)[0][1]) {
                        const moduleInfo = pkgModules.get(moduleName)!;
                        const moduleCode = moduleInfo.code;
                        const wasmModuleLocation: Location = (moduleCode as any).Wasm !== undefined
                            ? (moduleCode as any).Wasm : (moduleCode as any).Assets.wasm;
                        
                        const [repoCanister, wasmId] = wasmModuleLocation;
                        const repositoryActor2: Repository = Actor.createActor(repositoryIndexIdl, {
                            agent: agent!,
                            canisterId: repoCanister,
                        });
                        const wasmModule = await repositoryActor2.getWasmModule(wasmId);
                        
                        // Upgrade or install via Management Canister
                        const wasmModuleBytes = Array.isArray(wasmModule) ? new Uint8Array(wasmModule) : wasmModule;

                        const pkg = await glob.packageManager!.getInstalledPackage(0n);
                        const modules = new Map(pkg.modulesInstalledByDefault);
                        // duplicate with backend:
                        const argType = IDL.Record({
                            packageManager: IDL.Principal,
                            mainIndirect: IDL.Principal,
                            simpleIndirect: IDL.Principal,
                            battery: IDL.Principal,
                            user: IDL.Principal,
                            installationId: IDL.Nat,
                            upgradeId: IDL.Nat,
                            userArg: IDL.Vec(IDL.Nat8),
                        });
                        const arg = {
                            packageManager: modules.get("backend")!,
                            mainIndirect: modules.get("main_indirect")!,
                            simpleIndirect: modules.get("simple_indirect")!,
                            battery: modules.get("battery")!,
                            user: principal!,
                            installationId: 0n,
                            upgradeId: upgradeResult.upgradeId,
                            userArg: IDL.encode([IDL.Record({})], [{}]),
                        };
                        const argEncoded = new Uint8Array(IDL.encode([argType], [arg]));

                        let ourCanisterId;
                        if (moduleCanisterId) {
                            ourCanisterId = moduleCanisterId;
                            // Upgrade existing module
                            try {
                                await managementCanister.installCode({
                                    canisterId: moduleCanisterId,
                                    wasmModule: wasmModuleBytes,
                                    arg: argEncoded,
                                    mode: moduleInfo.forceReinstall 
                                        ? { reinstall: null }
                                        : { upgrade: [{ wasm_memory_persistence: [], skip_pre_upgrade: [false] }] },
                                    senderCanisterVersion: undefined,
                                });
                            }
                            catch (e) {
                                const re = /Missing upgrade option: Enhanced orthogonal persistence requires the `wasm_memory_persistence` upgrade option\./;
                                if (re.test((e as object).toString())) {
                                    await managementCanister.installCode({
                                        canisterId: moduleCanisterId,
                                        wasmModule: wasmModuleBytes,
                                        arg: argEncoded,
                                        mode: moduleInfo.forceReinstall 
                                            ? { reinstall: null }
                                            : { upgrade: [{ wasm_memory_persistence: [{ keep: null }], skip_pre_upgrade: [false] }] },
                                        senderCanisterVersion: undefined,
                                    });
                                }
                            }                                    
                        } else {
                            // Install new module
                            const newCanisterId = await managementCanister.createCanister({
                                settings: {
                                    controllers: [principal!.toText()],
                                    computeAllocation: undefined,
                                    memoryAllocation: undefined,
                                    freezingThreshold: undefined,
                                    reservedCyclesLimit: undefined,
                                    wasmMemoryLimit: undefined,
                                    logVisibility: undefined,
                                },
                                senderCanisterVersion: undefined,
                            });
                            ourCanisterId = newCanisterId;
                            
                            await managementCanister.installCode({
                                canisterId: newCanisterId,
                                wasmModule: wasmModuleBytes,
                                arg: argEncoded,
                                mode: { install: null },
                                senderCanisterVersion: undefined,
                            });

                            // Update controllers after installation
                            await managementCanister.updateSettings({
                                canisterId: newCanisterId,
                                settings: {
                                    controllers: [
                                        principal!, modules.get("simple_indirect")!, modules.get("main_indirect")!
                                    ].map(p => p.toText()),
                                    computeAllocation: undefined,
                                    memoryAllocation: undefined,
                                    freezingThreshold: undefined,
                                    reservedCyclesLimit: undefined,
                                    wasmMemoryLimit: undefined,
                                    logVisibility: undefined,
                                },
                                senderCanisterVersion: undefined,
                            });

                            // Notify backend about the new module // TODO@P3: Notify for all modules at once.
                            await package_manager.onUpgradeOrInstallModule({
                                upgradeId: upgradeResult.upgradeId,
                                moduleName,
                                canister_id: newCanisterId,
                                afterUpgradeCallback: [],
                            });
                        }
                        console.log(`Successfully processed module ${moduleName}`);
                        modulesMap.set(moduleName, ourCanisterId);
                    } else {
                        console.error(`Module ${moduleName} not found in package info`); // TODO@P3: This should never happen as modulesToUpgrade is filtered
                    }
                }

                // Last, delete modules that are no longer needed // TODO@P3: Do it in background.
                for (const [moduleName, canisterId] of upgradeResult.modulesToDelete) {
                    console.log(`Deleting module: ${moduleName}`);
                    try {
                        // Stop and delete the canister
                        await managementCanister.stopCanister(canisterId);
                        await managementCanister.deleteCanister(canisterId); // TODO@P2: Withdraw cycles.
                        console.log(`Successfully deleted module ${moduleName}`);
                    } catch (e) {
                        console.error(`Error deleting module ${moduleName}:`, e);
                        // Continue with other modules even if one fails
                    }
                }

                // Notify backend that all modules are upgraded
                await package_manager.completeModularUpgrade(upgradeResult.upgradeId, Array.from(modulesMap.entries()));
            } else {
                // Use existing upgrade method for non-icpack packages
                const {minUpgradeId: id} = await package_manager.upgradePackages({
                    packages: [{
                        installationId: BigInt(props.oldInstallation!),
                        packageName: props.packageName!,
                        version: chosenVersion!,
                        repo: props.repo!,
                        arg: new Uint8Array(),
                        initArg: [],
                    }],
                    user: principal!,
                    afterUpgradeCallback: [],
                });

                // Wait for package to be updated in the system
                for (;;) {
                    const cur = await glob.packageManager!.getInstalledPackagesInfoByName(props.packageName!, props.guid0);
                    if (cur.all.find(v => v.package.base.version === chosenVersion) !== undefined) {
                        break;
                    }
                    console.log("Waiting till package upgrade...");
                    await new Promise((resolve) => setTimeout(resolve, 1000));
                }
            }
            navigate(`/installed/show/${props.oldInstallation}`);
        }
        catch(e) {
            console.log(e);
            setError((e as object).toString())
        }
        finally {
            setBusy(false);
        }
    }
    useEffect(() => {
        setChosenVersion(versions !== undefined && versions[0] ? versions[0][1] : undefined); // If there are zero versions, sets `undefined`.
    }, [versions]);
    return (
        <>
            <h2>Choose package version for installation</h2>
            {props.oldInstallation !== undefined &&
                <Alert variant="warning">
                    <p>Downgrading to a lower version than the current may lead to data loss!</p>
                    <p>You are strongly recommended to upgrade only to higher versions.</p>
                </Alert>
            }
            <p>Package: {props.packageName}</p> {/* TODO@P3: no "No such package." message, while the package loads */}
            {versions === undefined ? <p>No such package.</p> : <>
                <p>
                    {props.oldInstallation !== undefined && <>Current version: {props.currentVersion}{" "}</>}
                    Version to install:{" "}
                    <select onChange={e => setChosenVersion((e.target as HTMLSelectElement).value)}>
                        {Array.from(versions!.entries()).map(([i, [k, v]]) =>
                            <option key={i} value={v}>{k}</option>)}
                    </select>
                </p>
                <p>
                    {props.oldInstallation !== undefined ?
                        <Button onClick={upgrade} disabled={installing || chosenVersion === undefined}>Upgrade package</Button>
                        : installedVersions.size == 0
                        ? <Button onClick={install} disabled={installing || chosenVersion === undefined}>Install new package</Button>
                        : installedVersions.has(chosenVersion ?? "")
                        ? <>Already installed. <Button onClick={install} disabled={!ok || installing || chosenVersion === undefined}>Install an additional copy of this version</Button></>
                        : <>Already installed. <Button onClick={install} disabled={!ok || installing || chosenVersion === undefined}>Install it in addition to other versions of this package</Button></>
                    }
                    {!ok && <p>Sign in to install or upgrade packages.</p>}
                </p>
            </>}
        </>
    );
}