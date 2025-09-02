import fs from 'fs';
import { Principal } from '@dfinity/principal';
import { config as dotenv_config } from 'dotenv';
import readline from 'readline';
import { createActor as createPackageManager } from '../src/declarations/package_manager';
import { createActor as createRepository } from '../src/declarations/repository';
import { HttpAgent, Identity } from '@dfinity/agent';
import { ModuleCode, Repository, SharedModule, SharedPackageInfoTemplate } from '../src/declarations/repository/repository.did';
import { waitTillInitialized } from '../src/lib/install';

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
        modules: [string, ModuleCode][],
    }[],
    identity: Identity,
    version: string)
{
    console.log("Starting submitting packages...");
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
            installationIdStr = await ask(`Installation ID for ${pkg.tmpl.base.name} (empty string to install anew): `); // FIXME@P1
        }
        if (!/^([0-9]+|none|)$/.test(installationIdStr)) {
            throw new Error(`Invalid installation ID for ${pkg.tmpl.base.name}: ${installationIdStr} (must be a natural number)`);
        }
        if (installationIdStr === "") {
            installationIdStr = 'none';
        }
        vars.set(instVarName, installationIdStr);
    }
    console.log("Outputting config...");
    fs.writeFileSync(
        `.icpack-config.${process.env.DFX_NETWORK}`,
        Array.from(vars.entries()).map(([k, v]) => `${k}=${v}`).join('\n')
    );

    console.log("Creating agents...");
    const pm = Principal.fromText(pmStr!);

    const agent = await HttpAgent.create({
        host: process.env.DFX_NETWORK === 'local' ? "http://localhost:8080" : undefined,
        shouldFetchRootKey: process.env.DFX_NETWORK === 'local',
        identity,
    });

    const pmActor = createPackageManager(pm, {agent});

    for (const pkg of packages) {
        console.log(`Starting to submit package ${pkg.tmpl.base.name}...`);
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
            const {minInstallationId: realInstallationId} = await pmActor.installPackage({
                package: {
                    version,
                    repo: pkg.repo,
                    packageName: pkg.tmpl.base.name,
                    arg: new Uint8Array(),
                    initArg: [],
                },
                user: identity.getPrincipal(),
                afterInstallCallback: [],
            });
            await waitTillInitialized(agent, pm, realInstallationId);
            installationId = realInstallationId;
        } else {
            await pmActor.upgradePackage({
                package: {
                    installationId,
                    version,
                    repo: pkg.repo,
                    arg: new Uint8Array(),
                    initArg: [],
                },
                user: identity.getPrincipal(),
                afterUpgradeCallback: [],
            });
        }
        if (await repoActor.addPackageVersion(pkg.tmpl, pkg.modules, version)) {
            console.log(`Package ${pkg.tmpl.base.name} code was updated.`);
        } else {
            console.log(`Package ${pkg.tmpl.base.name} code was not updated.`);
        }
    }
}
