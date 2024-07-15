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

export default function ChooseVersion(props: {}) {
    const { packageName } = useParams();
    const {principal, defaultAgent} = useAuth();
    const [versions, setVersions] = useState<string[]>([]);
    const [installedVersions, setInstalledVersions] = useState<Map<string, 1>>(new Map());
    useEffect(() => {
        // const index = new IndexClient<RepositoryIndex>({
        //     IDL: RepositoryIndexIDL,
        //     canisterId: import.meta.env.CANISTER_ID_REPOSITORYINDEX!,
        //     agentOptions: {/*source:*/},
        // });
        // const repositoryPartition = new ActorClient<RepositoryIndex, RepositoryPartition>({
        //     actorOptions: {
        //       IDL: RepositoryPartitionIDL,
        //       agentOptions: {/*source:*/},
        //     },
        //     indexClient: index, 
        // });
        // FIXME: Use the currently choosen repo, not `RepositoryIndex`.
        RepositoryIndex.getCanistersByPK("main").then(async pks => {
            const res: FullPackageInfo[] = await Promise.all(pks.map(async pk => {
                const part = Actor.createActor(repositoryPartitionIDL, {canisterId: pk, agent: defaultAgent}); // FIXME: convert pk to Principal?
                return await part.getFullPackageInfo(packageName);
            })) as any;
            for (const fullInfo of res) {
                if (fullInfo === undefined) {
                    continue;
                }
                // FIXME: Take into account `.versions` map from `FullPackageInfo`.
                setVersions(fullInfo.packages.map(pkg => pkg[0]));
            }
        });
        package_manager.getInstalledPackagesInfoByName(packageName!).then(installed => {
            setInstalledVersions(new Map(installed.map(e => [e.version, 1])));
        });
    });
    const [chosenVersion, setChosenVersion] = useState<string | undefined>(undefined);
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
                <Button>
                {installedVersions.size == 0
                    ? "Install new package"
                    : installedVersions.has(chosenVersion ?? "")
                    ? "Install an additional copy of this version " + chosenVersion
                    : `Install '${chosenVersion}' in addition to other versions of this package`}
                </Button>
            </p>
        </>
    );
}