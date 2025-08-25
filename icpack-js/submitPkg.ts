#!/usr/bin/env -S npx tsx

import { Principal } from '@dfinity/principal';
import { config as dotenv_config } from 'dotenv';
import readline from 'readline';
import { createActor as createPackageManager } from '../src/declarations/package_manager';
import { createActor as createRepository } from '../src/declarations/repository';
import { HttpAgent, Identity } from '@dfinity/agent';
import { Repository, SharedModule, SharedPackageInfoTemplate } from '../src/declarations/repository/repository.did';
import canisterIds from '../canister_ids.json';
import { assert } from 'console';
import { exec } from 'child_process';
import { copyFile, rename } from 'fs/promises';

dotenv_config({ path: '.env' });

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

export function getRemoteCanisterId(name: string, useLocalRepo: boolean): Principal {
    return Principal.fromText(useLocalRepo
        ? process.env[`CANISTER_ID_${name.toUpperCase()}`]!
        : (canisterIds[name as keyof typeof canisterIds] as {ic: string}).ic);
}

// TODO@P1: Use the Git hash (and ask user for more version strings?)
export async function submit(packages: {
    name: string,
    tmpl: SharedPackageInfoTemplate,
    modules: [string, SharedModule][],
}[], identity: Identity, useLocalRepo: boolean, recompileCommand: string) {
    // TODO@P1: Use save these two variables to `.env` (and for reliability to yet a location?)
    // FIXME@P1: `local` and `ic` may be compiled with different settings by `MOPS_ENV` in `mops.toml`.
    let pmStr = process.env.TEST_CANISTER_ID_PACKAGE_MANAGER; // FIXME@P1: prefix not processed by Vite
    if (pmStr === undefined || pmStr === "") {
        pmStr = await ask("Enter the package manager canister principal: ");
    }
    const pm = Principal.fromText(pmStr!);
    let repo = getRemoteCanisterId('repository', useLocalRepo);

    const agent = await HttpAgent.create({
        host: process.env.DFX_NETWORK === 'local' ? "http://localhost:8080" : undefined,
        shouldFetchRootKey: process.env.DFX_NETWORK === 'local',
        identity,
    });

    const repoActor: Repository = createRepository(pm, {agent});
    const pmActor = createPackageManager(pm, {agent});

    // Recompile the remote version.
    // FIXME@P1: needed?
    await exec(recompileCommand, {
        env: {
            'DFX_NETWORK': 'ic', // TODO@P1: Ensure that it overrides `.env`.
            'MOPS_ENV': 'ic',
        },
    });

    for (const pkg of packages) {
        try {
            // pmActor.TODO@P1; // Upgrade
        } catch (e) {
            console.error(`Failed to upgrade package ${pkg.name}: ${e}`);
            return;
        }
        if (await repoActor.addPackageVersion(pkg.name, pkg.tmpl, pkg.modules)) {
            console.log(`Package ${pkg.name} code was updated.`);
        } else {
            console.log(`Package ${pkg.name} code was not updated.`);
        }
    }
}
