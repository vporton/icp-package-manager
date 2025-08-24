#!/usr/bin/env -S npx tsx

import { Principal } from '@dfinity/principal';
import { config as dotenv_config } from 'dotenv';
import readline from 'readline';
import { createActor as createPackageManager } from '../src/declarations/package_manager';
import { createActor as createRepository } from '../src/declarations/repository';
import { HttpAgent, Identity } from '@dfinity/agent';
import { Repository, SharedModule, SharedPackageInfoTemplate } from '../src/declarations/repository/repository.did';

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

export async function submit(packages: {
    name: string,
    tmpl: SharedPackageInfoTemplate,
    modules: [string, SharedModule][],
}[], identity: Identity) {
    let pmStr = process.env.TEST_CANISTER_ID_PACKAGE_MANAGER;
    if (pmStr === undefined || pmStr === "") {
        pmStr = await ask("Enter the package manager canister principal: ");
    }
    const pm = Principal.fromText(pmStr!);
    let repoStr = process.env.REMOTE_CANISTER_ID_REPOSITORY;
    if (repoStr === undefined || repoStr === "") {
        repoStr = await ask("Enter the package manager canister principal: ");
    }
    const repo = Principal.fromText(repoStr!);

    const localAgent = await HttpAgent.create({
        host: "http://localhost:8080",
        shouldFetchRootKey: true,
        identity,
    });
    const remoteAgent = await HttpAgent.create({identity});

    const repoActor: Repository = createRepository(pm, {agent: remoteAgent});
    const pmActor = createPackageManager(pm, {agent: localAgent});

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

// import { SharedPackageInfoTemplate, SharedPackageInfo, SharedModule } from "../src/declarations/repository/repository.did";

// export function submitPkg(pkg: SharedPackageInfoTemplate, modules: [string, SharedModule][]): SharedPackageInfo {
//     return XXX.
//     // TODO@P3: Implement
// }