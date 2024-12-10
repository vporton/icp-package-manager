import { useEffect, useState } from "react";
import { useParams } from "react-router-dom";
import { SharedFullPackageInfo, idlFactory as repositoryPartitionIDL } from '../../declarations/RepositoryPartition/RepositoryPartition.did.js';
import { Actor } from "@dfinity/agent";
import { useContext } from 'react';
import { useAuth } from "./auth/use-auth-client";
import Button from "react-bootstrap/Button";
import { Principal } from "@dfinity/principal";
import { _SERVICE as RepositoryIndex } from '../../declarations/RepositoryIndex/RepositoryIndex.did';
import { idlFactory as repositoryIndexIdl } from '../../declarations/RepositoryIndex';
import { createActor as repoPartitionCreateActor } from '../../declarations/RepositoryPartition';
import { myUseNavigate } from "./MyNavigate";
import { GlobalContext } from "./state";
import { installPackageWithModules } from "../../lib/install";
import { ErrorContext } from "./ErrorContext.js";

export default function ChooseVersion(props: {}) {
    const { packageName, repo } = useParams();
    const glob = useContext(GlobalContext);
    const navigate = myUseNavigate();
    const {principal, agent, defaultAgent} = useAuth();
    const [versions, setVersions] = useState<[string, string][]>([]);
    const [installedVersions, setInstalledVersions] = useState<Map<string, 1>>(new Map());
    const package_manager = glob.package_manager_ro!;
    useEffect(() => {
        try {
            const index: RepositoryIndex = Actor.createActor(repositoryIndexIdl, {canisterId: repo!, agent: defaultAgent});
            index.getCanistersByPK("main").then(async pks => {
                const res: [string, SharedFullPackageInfo][] = await Promise.all(pks.map(async pk => {
                    const part = repoPartitionCreateActor(pk, {agent: defaultAgent});
                    let fullInfo = undefined;
                    try {
                        fullInfo = await part.getFullPackageInfo(packageName!); // TODO: `!`
                    }
                    catch(_) {} // TODO: Handle exception type.
                    return [pk, fullInfo];
                })) as any;
                for (const [pk, fullInfo] of res) {
                    if (fullInfo === undefined) {
                        continue;
                    }
                    const versionsMap = new Map(fullInfo.versionsMap);
                    const p2: [string, string][] = fullInfo.packages.map(pkg => [pkg[0], versionsMap.get(pkg[0]) ?? pkg[0]]);
                    setVersions(fullInfo.versionsMap.concat(p2));
                    break;
                }
            });
            package_manager.getInstalledPackagesInfoByName(packageName!).then(installed => {
                setInstalledVersions(new Map(installed.map(e => [e.version, 1])));
            });
        }
        catch(_) { // TODO: Check error.
            setInstalledVersions(new Map());
        }
    }, []);
    const [chosenVersion, setChosenVersion] = useState<string | undefined>(undefined);
    const [installing, setInstalling] = useState(false);
    let errorContext = useContext(ErrorContext);
    async function install() {
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
        const {installationId: id} = await installPackageWithModules({
            package_manager_principal: glob.backend!,
            packageName: packageName!,
            version: chosenVersion!,
            repo: firstPart,
            user: principal!,
            agent: agent!,
        });
        navigate(`/installed/show/${id}`);
    }
    useEffect(() => {
        setChosenVersion(versions[0] ? versions[0][0] : undefined); // If there are zero versions, sets `undefined`.
    }, [versions]);
    return (
        <>
            <h2>Choose package version for installation</h2>
            <p>Package: {packageName}</p>
            <p>Version:{" "}
                <select>
                    {Array.from(versions.entries()).map(([i, [k, v]]) =>
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
        </>
    );
}