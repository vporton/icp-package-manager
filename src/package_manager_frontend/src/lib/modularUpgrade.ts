import { Actor } from "@dfinity/agent";
import { Principal } from "@dfinity/principal";
import { ICManagementCanister } from "@dfinity/ic-management";
import { IDL } from "@dfinity/candid";
import { PackageManager } from "../../declarations/package_manager/package_manager.did.d.ts";
import { Repository } from "../../declarations/repository_index/repository_index.did.d.ts";
import { repositoryIndexIdl } from "../../declarations/repository_index/repository_index.did.js";
import { SharedModule, Location } from "../../declarations/package_manager/package_manager.did.d.ts";

interface ModularUpgradeParams {
    package_manager: PackageManager;
    agent: any;
    glob: any;
    props: {
        packageName: string;
        oldInstallation: string;
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
        installationId: BigInt(props.oldInstallation!),
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
    const realPackage = packageInfo.specific as { real: any };
    if (realPackage === undefined || realPackage.real === undefined) {
        throw new Error(`Invalid package info for ${props.packageName!} version ${chosenVersion!}`);
    }
    const pkgModules = new Map<string, SharedModule>(realPackage.real.modules);

    // Then upgrade or install modules
    for (const moduleName of upgradeResult.modulesToUpgradeOrInstall) {
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
            });
            const arg = IDL.encode([argType], [{
                packageManager: glob.backend!,
                mainIndirect: modules.get("main_indirect")!,
                simpleIndirect: modules.get("simple_indirect")!,
            }]);
            
            if (moduleCanisterId !== undefined) {
                // Upgrade existing module
                await managementCanister.updateSettings({
                    canisterId: moduleCanisterId,
                    settings: {
                        freezingThreshold: undefined,
                        controllers: [glob.backend!],
                        memoryAllocation: undefined,
                        computeAllocation: undefined,
                    },
                });
                await managementCanister.installCode({
                    mode: { upgrade: [] },
                    canisterId: moduleCanisterId,
                    wasmModule: wasmModuleBytes,
                    arg,
                });
            } else {
                // Install new module
                const newCanisterId = await managementCanister.createCanister({
                    settings: {
                        freezingThreshold: undefined,
                        controllers: [glob.backend!],
                        memoryAllocation: undefined,
                        computeAllocation: undefined,
                    },
                });
                await managementCanister.installCode({
                    mode: { install: [] },
                    canisterId: newCanisterId.canisterId,
                    wasmModule: wasmModuleBytes,
                    arg,
                });
                modulesMap.set(moduleName, newCanisterId.canisterId);
            }
        }
    }

    // Delete modules that are no longer needed
    for (const [moduleName, moduleCanisterId] of upgradeResult.modulesToDelete) {
        console.log(`Deleting module ${moduleName} (${moduleCanisterId.toString()})`);
        await managementCanister.deleteCanister({
            canisterId: moduleCanisterId,
        });
    }

    // Complete the upgrade
    await package_manager.completeModularUpgrade(upgradeResult.upgradeId, Array.from(modulesMap.entries()));

    navigate(`/installed/show/${props.oldInstallation}`);
} 