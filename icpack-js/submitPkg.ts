#!/usr/bin/env -S npx tsx

import fs from 'fs';
import { Principal } from '@dfinity/principal';
import { config as dotenv_config } from 'dotenv';
import readline from 'readline';
import { createActor as createPackageManager } from '../src/declarations/package_manager';
import { createActor as createRepository } from '../src/declarations/repository';
import { Location } from '../src/declarations/repository/repository.did';
import { HttpAgent, Identity } from '@dfinity/agent';
import { Repository, SharedModule, SharedPackageInfoTemplate } from '../src/declarations/repository/repository.did';
import canisterIds from '../canister_ids.json';
import { assert } from 'console';
import { exec } from 'child_process';
import { copyFile, rename } from 'fs/promises';
import { ICManagementCanister } from "@dfinity/ic-management";
import { IDL } from '@dfinity/candid';
import { waitTillInitialized } from '../src/lib/install';

dotenv_config({ path: '.env' });
dotenv_config({ path: `.icpack-config.${process.env.DFX_NETWORK}` });

function ask(question: string): Promise<string> {
    const rl = readline.createInterface({
        input: process.stdin,
        output: process.stdout
    });
    return new Promise((resolve) =>
        rl.question(question, (answer) => {
            rl.close();
            resolve(answer);
        })
    );
}

export function getRemoteCanisterId(name: string): Principal {
    return Principal.fromText(process.env[`CANISTER_ID_${name.toUpperCase()}`]!);
    // return Principal.fromText(useLocalRepo
    //     ? process.env[`CANISTER_ID_${name.toUpperCase()}`]!
    //     : (canisterIds[name as keyof typeof canisterIds] as {ic: string}).ic);
}

export async function submit(
    packages: {
        repo: Principal,
        tmpl: SharedPackageInfoTemplate,
        modules: [string, SharedModule][],
    }[],
    identity: Identity,
    version: string)
{
    const vars = new Map<string, string>();
    let pmStr = process.env.USER_SPECIFIED_CANISTER_ID_PACKAGE_MANAGER;
    if (pmStr === undefined || pmStr === "") {
        pmStr = await ask("Enter the package manager canister principal: ");
    }
    vars.set('USER_SPECIFIED_CANISTER_ID_PACKAGE_MANAGER', pmStr);
    for (const pkg of packages) {
        const instVarName = `USER_SPECIFIED_INSTALL_ID_${pkg.tmpl.base.name.toUpperCase()}`;
        let installationIdStr = process.env[instVarName];
        if (installationIdStr === undefined || installationIdStr === "") {
            installationIdStr = await ask(`Installation ID for ${pkg.tmpl.base.name}: `);
        }
        if (!/^[0-9]+$/.test(installationIdStr)) {
            throw new Error(`Invalid installation ID for ${pkg.tmpl.base.name}: ${installationIdStr} (must be a natural number)`);
        }
        vars.set(instVarName, installationIdStr);
    }
    fs.writeFileSync(
        `.icpack-config.${process.env.DFX_NETWORK}`,
        Array.from(vars.entries()).map(([k, v]) => `${k}=${v}`).join('\n')
    );

    const pm = Principal.fromText(pmStr!);

    const agent = await HttpAgent.create({
        host: process.env.DFX_NETWORK === 'local' ? "http://localhost:8080" : undefined,
        shouldFetchRootKey: process.env.DFX_NETWORK === 'local',
        identity,
    });

    const pmActor = createPackageManager(pm, {agent});

    for (const pkg of packages) {
        let installationIdStr = process.env[`USER_SPECIFIED_INSTALL_ID_${pkg.tmpl.base.name.toUpperCase()}`];
        if (installationIdStr === undefined) {
            throw new Error(`Installation ID for ${pkg.tmpl.base.name} is not specified.`);
        }
        if (installationIdStr !== 'none' && !/^[0-9]+$/.test(installationIdStr)) {
            throw new Error(`Invalid installation ID for ${pkg.tmpl.base.name}: ${installationIdStr} (must be a natural number or "none")`);
        }
        let installationId = installationIdStr === 'none' ? undefined : BigInt(installationIdStr);
        const repoActor: Repository = createRepository(pkg.repo, {agent});
        if (installationId === undefined) {
            const {minInstallationId: realInstallationId} = await pmActor.installPackages({
                packages: [{
                    packageName: pkg.tmpl.base.name,
                    version,
                    repo: pkg.repo,
                    arg: new Uint8Array(),
                    initArg: [],
                }],
                user: identity.getPrincipal(),
                afterInstallCallback: [],
            });
            await waitTillInitialized(agent, pm, realInstallationId);
            installationId = realInstallationId;
        }
        for (const [moduleName, m] of pkg.modules) {
            let canisterId = await pmActor.getModulePrincipal(installationId, moduleName);
            const { installCode, canisterStatus } = ICManagementCanister.create({
                agent,
            });
            const moduleCode = m.code;
            const wasmModuleLocation: Location = (moduleCode as any).Wasm !== undefined
                ? (moduleCode as any).Wasm : (moduleCode as any).Assets.wasm;
            const repoCanister = wasmModuleLocation[0];
            const wasmId = wasmModuleLocation[1];
            const wasmRepo = createRepository(repoCanister, {agent});
            const wasmModule = await wasmRepo.getWasmModule(wasmId);
            // TODO@P2: Don't transfer `wasmModuleBytes` through the browser.
            const wasmModuleBytes = Array.isArray(wasmModule) ? new Uint8Array(wasmModule) : wasmModule; // TODO@P3: Simplify.
            const {module_hash} = await canisterStatus(canisterId);
            /* block */ {
                // Convert both to Uint8Array for comparison and compare first 16 bytes
                const wasmIdArray = new Uint8Array(wasmId as any);
                const moduleHashArray = new Uint8Array(module_hash as any);
                // TODO@P1: Upgrade only if changed also in backend upgrade code. Use that code here instead of the below.
                if (wasmIdArray.slice(0, 16).every((byte, i) => byte === moduleHashArray[i])) { // Upgrade only if changed.
                    continue;
                }
            }
            // TODO@P3: Support only enhanced orthogonal persistence?
            try { // FIXME@P1: This is a partial installation code. It for example doesn't update the package version.
                await installCode({
                    mode: { upgrade: [{ wasm_memory_persistence: [], skip_pre_upgrade: [false] }] },
                    canisterId,
                    wasmModule: wasmModuleBytes,
                    arg: new Uint8Array(IDL.Record({}).encodeValue({})),
                });
            }
            catch (e) {
                if (/Missing upgrade option: Enhanced orthogonal persistence requires the `wasm_memory_persistence` upgrade option\./
                    .test((e as any).toString()))
                {
                    await installCode({
                        mode: { upgrade: [{ wasm_memory_persistence: [{keep: null}], skip_pre_upgrade: [false] }] },
                        canisterId: canisterId,
                        wasmModule: wasmModuleBytes,
                        arg: new Uint8Array(IDL.Record({}).encodeValue({})),
                    });
                } else {
                    throw e;
                }
            }
        }
        // TODO@P1: Copy frontend assets.
        if (await repoActor.addPackageVersion(pkg.tmpl, pkg.modules, version)) {
            console.log(`Package ${pkg.tmpl.base.name} code was updated.`);
        } else {
            console.log(`Package ${pkg.tmpl.base.name} code was not updated.`);
        }
    }
}
