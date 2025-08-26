#!/usr/bin/env -S npx tsx

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

// TODO@P1: Use the Git hash (and ask user for more version strings?)
export async function submit(packages: {
    name: string,
    tmpl: SharedPackageInfoTemplate,
    modules: [string, SharedModule][],
}[], identity: Identity) {
    // TODO@P1: Use save this variable to `.env`.
    //          It should be also saved somewhere else because `.env` may be lost.
    // TODO@P1: Also prevent the user from "inheriting" the `TEST_CANISTER_ID_PACKAGE_MANAGER` between `local` and `ic` networks.
    let pmStr = process.env.USER_SPECIFIED_CANISTER_ID_PACKAGE_MANAGER; // FIXME@P1: prefix not processed by Vite
    if (pmStr === undefined || pmStr === "") {
        pmStr = await ask("Enter the package manager canister principal: ");
    }

    const pm = Principal.fromText(pmStr!);
    let repo = getRemoteCanisterId('repository');

    const agent = await HttpAgent.create({
        host: process.env.DFX_NETWORK === 'local' ? "http://localhost:8080" : undefined,
        shouldFetchRootKey: process.env.DFX_NETWORK === 'local',
        identity,
    });

    const repoActor: Repository = createRepository(repo, {agent});
    const pmActor = createPackageManager(pm, {agent});

    for (const pkg of packages) {
        let installationIdStr = process.env[`USER_SPECIFIED_INSTALL_ID_${pkg.name.toUpperCase()}`]; // FIXME@P1: prefix not processed by Vite
        if (installationIdStr === undefined) {
            throw new Error(`Installation ID for ${pkg.name} is not specified.`);
        }
        if (installationIdStr !== 'none' && !/^[0-9]+$/.test(installationIdStr)) {
            throw new Error(`Invalid installation ID for ${pkg.name}: ${installationIdStr} (must be a natural number or "none")`);
        }
        let installationId = installationIdStr === 'none' ? undefined : Number.parseInt(installationIdStr);
        for (const [moduleName, m] of pkg.modules) {
        const canisterId = await pmActor.getModulePrincipal(installationId, moduleName); // FIXME@P1: Where to store `installationId`?
        const moduleCode = m.code;
        const wasmModuleLocation: Location = (moduleCode as any).Wasm !== undefined
            ? (moduleCode as any).Wasm : (moduleCode as any).Assets.wasm; // TODO@P1: Check that it's correct.
        const [repoCanister, wasmId] = wasmModuleLocation;
        const wasmModule = await repoActor.getWasmModule(wasmId); // TODO@P1: Should use `repoCanister` instead.
        const wasmModuleBytes = Array.isArray(wasmModule) ? new Uint8Array(wasmModule) : wasmModule;
        try { // FIXME: Also needs to create a new installation if it doesn't exist (with caution).
            // FIXME@P1: Upgrade only if changed.
            // TODO@P3: Support only enhanced orthogonal persistence?
            const { installCode } = ICManagementCanister.create({
                agent,
            });
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
            // TODO@P1: Copy frontend assets.
        } catch (e) {
            console.error(`Failed to upgrade package ${pkg.name}: ${e}`);
            alert(`Failed to upgrade package ${pkg.name}: ${e}`); // TODO@P3: better dialog box
            return;
        }
        if (await repoActor.addPackageVersion(pkg.name, pkg.tmpl, pkg.modules)) {
            console.log(`Package ${pkg.name} code was updated.`);
        } else {
            console.log(`Package ${pkg.name} code was not updated.`);
        }
    }
}
