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

export default function ChooseVersion(props: {}) {
    const { packageName, repo } = useParams();
    const glob = useContext(GlobalContext);
    const navigate = myUseNavigate();
    const {principal, defaultAgent} = useAuth();
    const [versions, setVersions] = useState<string[]>([]);
    const [installedVersions, setInstalledVersions] = useState<Map<string, 1>>(new Map());
    const package_manager = glob.package_manager_rw!;
    useEffect(() => {
        const index: RepositoryIndex = Actor.createActor(repositoryIndexIdl, {canisterId: repo!, agent: defaultAgent});
        index.getCanistersByPK("main").then(async pks => {
            const res: [string, SharedFullPackageInfo][] = await Promise.all(pks.map(async pk => {
                const part = Actor.createActor(repositoryPartitionIDL, {canisterId: pk, agent: defaultAgent});
                return [pk, await part.getFullPackageInfo(packageName)]; // TODO: If package does not exist, this throws.
            })) as any;
            for (const [pk, fullInfo] of res) {
                if (fullInfo === undefined) {
                    continue;
                }
                // FIXME: Take into account `.versions` map from `SharedFullPackageInfo`.
                setVersions(fullInfo.packages.map(pkg => pkg[0]));
                break;
            }
        });
        package_manager.getInstalledPackagesInfoByName(packageName!).then(installed => {
            setInstalledVersions(new Map(installed.map(e => [e.version, 1])));
        });
    }, []);
    const [chosenVersion, setChosenVersion] = useState<string | undefined>(undefined);
    const [installing, setInstalling] = useState(false);
    async function install() {
        setInstalling(true);

        // TODO: hack
        const index: RepositoryIndex = Actor.createActor(repositoryIndexIdl, {canisterId: repo!, agent: defaultAgent});
        const parts = (await index.getCanistersByPK('main'))
            .map(s => Principal.fromText(s))
        const foundParts = await Promise.all(parts.map(part => {
            try {
                const part2 = repoPartitionCreateActor(part, {agent: defaultAgent});
                part2.getFullPackageInfo(packageName!); // TODO: `!`
                return part;
            }
            catch(_) { // TODO: Check error.
                return null;
            }
        }));
        const firstPart = foundParts.filter(v => v !== null)[0];

        const {installationId: id} = await installPackageWithModules({
            package_manager_principal: glob.backend!,
            packageName: packageName!,
            version: chosenVersion!,
            repo: firstPart,
            user: principal!,
        });
        navigate(`/installed/show/${id}`);
    }
    useEffect(() => {
        setChosenVersion(versions[0]); // If there are zero versions, sets `undefined`.
    }, [versions]);
    return (
        <>
            <h2>Choose package version for installation</h2>
            <p>Package: {packageName}</p>
            <p>Version:
                <select>
                    {versions.map((v: string) => <option onSelect={() => setChosenVersion(v)} key={v} value={v}>{v}</option>)} {/* FIXME: v may be non unique. */}
                </select>
            </p>
            <p>
                
                {/* TODO: Disable the button when executing it. */}
                {installedVersions.size == 0
                    ? <Button onClick={install} disabled={installing}>Install new package</Button>
                    : installedVersions.has(chosenVersion ?? "")
                    ? <>Already installed. <Button onClick={install} disabled={installing}>Install an additional copy of this version</Button></>
                    : <>Already installed. <Button onClick={install} disabled={installing}>Install it in addition to other versions of this package</Button></>
                }
            </p>
        </>
    );
}