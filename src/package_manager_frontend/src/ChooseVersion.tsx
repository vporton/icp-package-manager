import { useEffect, useState } from "react";
import { useParams } from "react-router-dom";
// TODO; Delete "candb-client-typescript/dist/IndexClient"
// import { IndexClient } from "candb-client-typescript/dist/IndexClient";
// import { ActorClient } from "candb-client-typescript/dist/ActorClient";
import { /*RepositoryIndex,*/ idlFactory as repositoryIndexIDL } from '../../declarations/RepositoryIndex/RepositoryIndex.did';
import { FullPackageInfo, RepositoryPartition, idlFactory as repositoryPartitionIDL } from '../../declarations/RepositoryPartition/RepositoryPartition.did.js';
import { RepositoryIndex } from '../../declarations/RepositoryIndex';
import { Actor } from "@dfinity/agent";
import { useAuth } from "./auth/use-auth-client";
import { package_manager } from "../../declarations/package_manager";
import Button from "react-bootstrap/Button";
import { Principal } from "@dfinity/principal";

export default function ChooseVersion(props: {}) {
    const { packageName } = useParams();
    const {principal, defaultAgent} = useAuth();
    const [versions, setVersions] = useState<string[]>([]);
    const [installedVersions, setInstalledVersions] = useState<Map<string, 1>>(new Map());
    const [packagePk, setPackagePk] = useState<Principal | undefined>();
    useEffect(() => {
        // FIXME: Use the currently choosen repo, not `RepositoryIndex`.
        RepositoryIndex.getCanistersByPK("main").then(async pks => {
            const res: [string, FullPackageInfo][] = await Promise.all(pks.map(async pk => {
                const part = Actor.createActor(repositoryPartitionIDL, {canisterId: pk, agent: defaultAgent}); // FIXME: convert pk to Principal?
                return [pk, await part.getFullPackageInfo(packageName)]; // TODO: If package does not exist, this throws.
            })) as any;
            for (const [pk, fullInfo] of res) {
                console.log("PK", pk)
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
    async function install() {
        let id = await package_manager.installPackage({
            canister: packagePk!,
            packageName: packageName!,
            version: chosenVersion!,
        });
        // TODO:
        alert("Installation finished, installation ID "+id);
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
                    ? <Button onClick={install}>Install new package</Button>
                    : installedVersions.has(chosenVersion ?? "")
                    ? <>Already installed. <Button onClick={install}>Install an additional copy of this version</Button></>
                    : <>Already installed. <Button onClick={install}>Install it in addition to other versions of this package</Button></>
                }
            </p>
        </>
    );
}