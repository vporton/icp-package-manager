import { useEffect, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
// TODO; Delete "candb-client-typescript/dist/IndexClient"
// import { IndexClient } from "candb-client-typescript/dist/IndexClient";
// import { ActorClient } from "candb-client-typescript/dist/ActorClient";
import { /*RepositoryIndex,*/ idlFactory as repositoryIndexIDL } from '../../declarations/RepositoryIndex/RepositoryIndex.did';
import { FullPackageInfo, RepositoryPartition, idlFactory as repositoryPartitionIDL } from '../../declarations/RepositoryPartition/RepositoryPartition.did.js';
import { Actor } from "@dfinity/agent";
import { useAuth } from "./auth/use-auth-client";
import { package_manager } from "../../declarations/package_manager";
import Button from "react-bootstrap/Button";
import { Principal } from "@dfinity/principal";
import { _SERVICE as RepositoryIndex } from '../../declarations/RepositoryIndex/RepositoryIndex.did';
import { idlFactory as repositoryIndexIdl } from '../../declarations/RepositoryIndex';
import { createActor as repoPartitionCreateActor } from '../../declarations/RepositoryPartition';

export default function ChooseVersion(props: {}) {
    const { packageName, repo } = useParams();
    const navigate = useNavigate();
    const {principal, defaultAgent} = useAuth();
    const [versions, setVersions] = useState<string[]>([]);
    const [installedVersions, setInstalledVersions] = useState<Map<string, 1>>(new Map());
    const [packagePk, setPackagePk] = useState<Principal | undefined>();
    useEffect(() => {
        const index: RepositoryIndex = Actor.createActor(repositoryIndexIdl, {canisterId: repo!, agent: defaultAgent}); // FIXME: convert pk to Principal?
        index.getCanistersByPK("main").then(async pks => {
            const res: [string, FullPackageInfo][] = await Promise.all(pks.map(async pk => {
                const part = Actor.createActor(repositoryPartitionIDL, {canisterId: pk, agent: defaultAgent});
                return [pk, await part.getFullPackageInfo(packageName)]; // TODO: If package does not exist, this throws.
            })) as any;
            for (const [pk, fullInfo] of res) {
                if (fullInfo === undefined) {
                    continue;
                }
                // FIXME: Take into account `.versions` map from `FullPackageInfo`.
                setVersions(fullInfo.packages.map(pkg => pkg[0]));
                setPackagePk(Principal.fromText(pk));
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
                part2.getPackage("icpack", "0.0.1"); // TODO: Don't hardcode.
                return part;
            }
            catch(_) { // TODO: Check error.
                return null;
            }
        }));
        const firstPart = foundParts.filter(v => v !== null)[0];
        console.log("firstPart2", firstPart.toText()); // TODO: Remove.
    
        let id = await package_manager.installPackage({
            canister: packagePk!,
            packageName: packageName!,
            version: chosenVersion!,
            repo: firstPart,
        });
        navigate(`/installed/show/${id}`);
    }
    useEffect(() => {
        setChosenVersion(versions[0]); // FIXME: if there are zero versions?
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