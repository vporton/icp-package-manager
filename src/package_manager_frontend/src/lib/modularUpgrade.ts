import { Location, ModuleCode, SharedFullPackageInfo } from '../../../declarations/repository/repository.did.js';
import { Actor, Agent } from "@dfinity/agent";
import { Principal } from "@dfinity/principal";
import { _SERVICE as Repository } from '../../../declarations/repository/repository.did';
import { idlFactory as repositoryIndexIdl } from '../../../declarations/repository';
import { PackageManager, SharedModule, SharedRealPackageInfo } from '../../../declarations/package_manager/package_manager.did';
import { GlobalContextType } from "../state";
import { ICManagementCanister } from '@dfinity/ic-management';
import { IDL } from '@dfinity/candid';

interface ModularUpgradeParams {
    package_manager: PackageManager;
    agent: Agent;
    glob: GlobalContextType;
    props: {
        packageName: string;
        oldInstallation: bigint;
        repo: Principal;
    };
    chosenVersion: string;
    principal: Principal;
    navigate: (path: string) => void;
}

export async function performModularUpgrade({
    package_manager,
    agent,
    glob,
    props,
    chosenVersion,
    principal,
    navigate
}: ModularUpgradeParams): Promise<void> {
    // Start modular upgrade for icpack
    const upgradeResult = await package_manager.startModularUpgrade({
        installationId: props.oldInstallation,
        packageName: props.packageName!,
        version: chosenVersion!,
        repo: props.repo!,
        arg: new Uint8Array(),
        initArg: [],
        user: principal!,
    });
    
    console.log(`Started modular upgrade for icpack. Upgrade ID: ${upgradeResult.upgradeId}, Total modules: ${upgradeResult.totalModules}`);
    console.log(`Modules to upgrade: ${upgradeResult.modulesToUpgradeOrInstall.join(', ')}`);
    console.log(`Modules to delete: ${upgradeResult.modulesToDelete.map(([name, _]: [string, Principal]) => name).join(', ')}`);

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
    const realPackage = packageInfo.specific as { real: SharedRealPackageInfo };
    if (realPackage === undefined || realPackage.real === undefined) {
        throw new Error(`Invalid package info for ${props.packageName!} version ${chosenVersion!}`);
    }
    const pkgModules = new Map<string, SharedModule>(realPackage.real.modules);
    // TODO@P3: inefficienct:
    const simpleIndirect = await package_manager.getModulePrincipal(props.oldInstallation, 'simple_indirect')!;
    const mainIndirect = await package_manager.getModulePrincipal(props.oldInstallation, 'main_indirect')!;
    const battery = await package_manager.getModulePrincipal(props.oldInstallation, 'battery')!;

    // Then upgrade or install modules
    for (const moduleName of upgradeResult.modulesToUpgradeOrInstall) {
        // Handle infrastructure modules directly via Management Canister
        console.log(`Processing module ${moduleName} via Management Canister`);
        
        // Get the canister ID for this module if it exists
        let moduleCanisterId: Principal | undefined;
        try {
            moduleCanisterId = await package_manager.getModulePrincipal(props.oldInstallation, moduleName);
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
            const arg = IDL.encode([argType], [{
                packageManager: glob.backend!,
                mainIndirect: modules.get("main_indirect")!,
                simpleIndirect: modules.get("simple_indirect")!,
                battery: modules.get("battery")!,
                user: principal!,
                installationId: 0n,
                upgradeId: upgradeResult.upgradeId,
                userArg: IDL.encode([IDL.Record({})], [{}]),
            }]);
            
            if (moduleCanisterId !== undefined) {
                // Upgrade existing module
                // await managementCanister.updateSettings({
                //     canisterId: moduleCanisterId,
                //     settings: {
                //         freezingThreshold: undefined,
                //         controllers: [glob.backend!.toText()],
                //         memoryAllocation: undefined,
                //         computeAllocation: undefined,
                //     },
                // });
                try {
                    await managementCanister.installCode({
                        mode: { upgrade: [{ wasm_memory_persistence: [], skip_pre_upgrade: [false] }] },
                        canisterId: moduleCanisterId,
                        wasmModule: wasmModuleBytes,
                        arg: new Uint8Array(arg),
                    });
                }
                catch (e) {
                    if (/Missing upgrade option: Enhanced orthogonal persistence requires the `wasm_memory_persistence` upgrade option\./
                        .test((e as any).toString()))
                    {
                        await managementCanister.installCode({
                            mode: { upgrade: [{ wasm_memory_persistence: [{keep: null}], skip_pre_upgrade: [false] }] },
                            canisterId: moduleCanisterId,
                            wasmModule: wasmModuleBytes,
                            arg: new Uint8Array(arg),
                        }); 
                    } else {
                        throw e;
                    }
                }
                modulesMap.set(moduleName, moduleCanisterId);
            } else {
                // Install new module
                const newCanisterId = await managementCanister.createCanister({
                    settings: {
                        freezingThreshold: undefined,
                        controllers: [simpleIndirect, mainIndirect, glob.backend!, battery].map(p => p.toText()),
                        memoryAllocation: undefined,
                        computeAllocation: undefined,
                    },
                });
                await managementCanister.installCode({
                    mode: { install: null },
                    canisterId: newCanisterId,
                    wasmModule: wasmModuleBytes,
                    arg: new Uint8Array(arg),
                });
                modulesMap.set(moduleName, newCanisterId);
            }
        }
    }

    // Delete modules that are no longer needed
    for (const [moduleName, moduleCanisterId] of upgradeResult.modulesToDelete) {
        console.log(`Deleting module ${moduleName} (${moduleCanisterId.toString()})`);
        await managementCanister.deleteCanister(moduleCanisterId);
    }

    // Complete the upgrade
    await package_manager.completeModularUpgrade(upgradeResult.upgradeId, Array.from(modulesMap.entries()));

    navigate(`/installed/show/${props.oldInstallation.toString()}`);
} 