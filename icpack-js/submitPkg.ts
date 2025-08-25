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
    // TODO@P1: Use save these two variables to `.env` (and for reliability to yet a location?)
    //          For non-local it should be also saved somewhere else because `.env` may be lost.
    let pmStr = process.env.TEST_CANISTER_ID_PACKAGE_MANAGER; // FIXME@P1: prefix not processed by Vite // FIXME@P1: `local` and `ic` values may be different.
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

    const repoActor: Repository = createRepository(pm, {agent});
    const pmActor = createPackageManager(pm, {agent});

    for (const pkg of packages) {
        try {
            // FIXME@P1: Upgrade only if changed.
            // pmActor.TODO@P1; // Upgrade
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
