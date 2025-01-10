import { useEffect, useState } from "react";
import { useParams } from "react-router-dom";
import { SharedFullPackageInfo, idlFactory as repositoryPartitionIDL } from '../../declarations/RepositoryPartition/RepositoryPartition.did.js';
import { Actor, Agent } from "@dfinity/agent";
import { useContext } from 'react';
import { useAuth } from "./auth/use-auth-client";
import Button from "react-bootstrap/Button";
import { Principal } from "@dfinity/principal";
import { _SERVICE as RepositoryIndex } from '../../declarations/RepositoryIndex/RepositoryIndex.did';
import { idlFactory as repositoryIndexIdl } from '../../declarations/RepositoryIndex';
import { createActor as repoPartitionCreateActor } from '../../declarations/RepositoryPartition';
import { createActor as createPackageManager } from '../../declarations/package_manager';
import { myUseNavigate } from "./MyNavigate";
import { GlobalContext } from "./state";
import { InitializedChecker } from "../../lib/install";
import { ErrorContext } from "./ErrorContext.js";
import { InstallationId, PackageName, PackageManager, Version, SharedRealPackageInfo, CheckInitializedCallback } from '../../declarations/package_manager/package_manager.did';

export default function ChooseVersion(props: {}) {
    const { packageName, repo } = useParams();
    const glob = useContext(GlobalContext);
    const navigate = myUseNavigate();
    const {principal, agent, defaultAgent} = useAuth();
    const [versions, setVersions] = useState<[string, string][] | undefined>();
    const [installedVersions, setInstalledVersions] = useState<Map<string, 1>>(new Map());
    // TODO: I doubt consistency, and performance in the case if there is no such package.
    useEffect(() => {
        const index: RepositoryIndex = Actor.createActor(repositoryIndexIdl, {canisterId: repo!, agent: defaultAgent});
        index.getCanistersByPK("main").then(async pks => {
            const res: ([string, SharedFullPackageInfo] | undefined)[] = await Promise.all(pks.map(async pk => {
                const part = repoPartitionCreateActor(pk, {agent: defaultAgent});
                let fullInfo = undefined;
                try {
                    fullInfo = await part.getFullPackageInfo(packageName!); // TODO: `!`
                }
                catch(_) { // TODO: Handle exception type.
                    return undefined;
                }
                return [pk, fullInfo];
            })) as any;
            for (const [_pk, fullInfo] of res.filter(x => x !== undefined)) {
                const versionsMap = new Map(fullInfo.versionsMap);
                const p2: [string, string][] = fullInfo.packages.map(pkg => [pkg[0], versionsMap.get(pkg[0]) ?? pkg[0]]);
                setVersions(fullInfo.versionsMap.concat(p2));
                break;
            }
        });
        if (versions !== undefined) {
            glob.packageManager!.getInstalledPackagesInfoByName(packageName!).then(installed => {
                setInstalledVersions(new Map(installed.map(e => [e.version, 1])));
            });
        }
    }, []);
    const [chosenVersion, setChosenVersion] = useState<string | undefined>(undefined);
    const [installing, setInstalling] = useState(false);
    let errorContext = useContext(ErrorContext);
    async function install() {
        try {
            setInstalling(true);

            // TODO: hack
            const index: RepositoryIndex = Actor.createActor(repositoryIndexIdl, {canisterId: repo!, agent: defaultAgent});
            const parts = (await index.getCanistersByPK('main'))
                .map(s => Principal.fromText(s))
            const foundParts = await Promise.all(parts.map(async part => {
                try {
                    const part2 = repoPartitionCreateActor(part, {agent: defaultAgent});
                    await part2.getFullPackageInfo(packageName!); // TODO: `!`
                    return part;
                }
                catch(_) { // TODO: Check error.
                    return null;
                }
            }));
            const firstPart = foundParts ? foundParts.filter(v => v !== null)[0] : null;
            if (firstPart === null) {
                errorContext?.setError("no such package");
                return null;
            }

            // TODO: `!`
            const {minInstallationId: id} = await installPackageWithModules({
                package_manager_principal: glob.backend!,
                packageName: packageName!,
                version: chosenVersion!,
                repo: firstPart,
                user: principal!,
                agent: agent!,
            });
            const checker = await InitializedChecker.create({package_manager: glob.backend!, installationId: id, agent: agent!});
            for (let i = 0; ; ++i) {
                if (await checker.check()) {
                    break;
                }
                if (i == 30) {
                    alert("Cannot initilize canisters"); // TODO
                    return;
                }
                await new Promise<void>((resolve, _reject) => {
                    setTimeout(() => resolve(), 1000);
                });
            }
            navigate(`/installed/show/${id}`);
        }
        catch(e) {
            console.log(e);
            throw e; // TODO
        }
    }
    useEffect(() => {
        setChosenVersion(versions !== undefined && versions[0] ? versions[0][1] : undefined); // If there are zero versions, sets `undefined`.
    }, [versions]);
    return (
        <>
            <h2>Choose package version for installation</h2>
            <p>Package: {packageName}</p> {/* TODO: no "No such package." message, while the package loads */}
            {versions === undefined ? <p>No such package.</p> : <>
                <p>Version:{" "}
                    <select>
                        {Array.from(versions!.entries()).map(([i, [k, v]]) =>
                            <option onChange={e => setChosenVersion((e.target as HTMLSelectElement).value)} key={i} value={v}>{k}</option>)}
                    </select>
                </p>
                <p>
                    {/* TODO: Disable the button when executing it. */}
                    {installedVersions.size == 0
                        ? <Button onClick={install} disabled={installing || chosenVersion === undefined}>Install new package</Button>
                        : installedVersions.has(chosenVersion ?? "")
                        ? <>Already installed. <Button onClick={install} disabled={installing || chosenVersion === undefined}>Install an additional copy of this version</Button></>
                        : <>Already installed. <Button onClick={install} disabled={installing || chosenVersion === undefined    }>Install it in addition to other versions of this package</Button></>
                    }
                </p>
            </>}
        </>
    );
}

export async function installPackageWithModules({
    package_manager_principal, packageName, repo, user, version, agent
}: {
    package_manager_principal: Principal,
    packageName: PackageName,
    repo: Principal,
    user: Principal,
    version: Version,
    agent: Agent,
}): Promise<{
    minInstallationId: InstallationId;
}> {
    const package_manager: PackageManager = createPackageManager(package_manager_principal, {agent});
    const {minInstallationId} = await package_manager.installPackage({
        packages: [{
            packageName,
            version,
            repo,
        }],
        user,
        afterInstallCallback: [],
    });
    // const part = createRepositoryPartition(repo);
    // const pkg = await part.getPackage(packageName, version); // TODO: a little inefficient
    // const pkgReal = (pkg!.specific as any).real as SharedRealPackageInfo;
    // const pkg2 = await package_manager.getInstalledPackage(BigInt(0)); // TODO: hard-coded package ID
    // const indirectPrincipal = pkg2.modules.filter(x => x[0] === 'indirect')[0][1];
    // const indirect = createIndirectCaller(indirectPrincipal, {agent});
    return {minInstallationId};
}
