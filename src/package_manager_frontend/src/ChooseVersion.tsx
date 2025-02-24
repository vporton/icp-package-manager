import { useEffect, useState } from "react";
import { useParams } from "react-router-dom";
import { SharedFullPackageInfo } from '../../declarations/Repository/Repository.did.js';
import { Actor, Agent } from "@dfinity/agent";
import { useContext } from 'react';
import { useAuth } from "./auth/use-auth-client";
import Button from "react-bootstrap/Button";
import { Principal } from "@dfinity/principal";
import { _SERVICE as Repository } from '../../declarations/Repository/Repository.did';
import { idlFactory as repositoryIndexIdl } from '../../declarations/Repository';
import { createActor as repoPartitionCreateActor } from '../../declarations/Repository';
import { createActor as createPackageManager } from '../../declarations/package_manager';
import { myUseNavigate } from "./MyNavigate";
import { GlobalContext } from "./state";
import { InitializedChecker, waitTillInitialized } from "../../lib/install";
import { ErrorContext } from "./ErrorContext.js";
import { InstallationId, PackageName, PackageManager, Version, SharedRealPackageInfo, CheckInitializedCallback } from '../../declarations/package_manager/package_manager.did';
import { BusyContext } from "../../lib/busy.js";

export default function ChooseVersion(props: {}) {
    const { packageName, repo } = useParams();
    const glob = useContext(GlobalContext);
    const navigate = myUseNavigate();
    const {principal, agent, defaultAgent} = useAuth();
    const [versions, setVersions] = useState<[string, string][] | undefined>();
    const [installedVersions, setInstalledVersions] = useState<Map<string, 1>>(new Map());
    const [guidInfo, setGUIDInfo] = useState<Uint8Array | undefined>();
    // TODO: I doubt consistency, and performance in the case if there is no such package.
    useEffect(() => {
        const index: Repository = Actor.createActor(repositoryIndexIdl, {canisterId: repo!, agent: defaultAgent});
        index.getFullPackageInfo(packageName!).then(fullInfo => {
            const versionsMap = new Map(fullInfo.versionsMap);
            const p2: [string, string][] = fullInfo.packages.map(pkg => [pkg[0], versionsMap.get(pkg[0]) ?? pkg[0]]);
            setVersions(fullInfo.versionsMap.concat(p2));
            setGUIDInfo(fullInfo.packages[0][1].base.guid as Uint8Array);
            if (versions !== undefined) {
                glob.packageManager!.getInstalledPackagesInfoByName(packageName!, guidInfo!).then(installed => {
                    setInstalledVersions(new Map(installed.all.map(e => [e.package.base.version, 1])));
                });
            }
        });
    }, []);
    const [chosenVersion, setChosenVersion] = useState<string | undefined>(undefined);
    const [installing, setInstalling] = useState(false);
    let errorContext = useContext(ErrorContext);
    let { setBusy } = useContext(BusyContext);
    async function install() {
        try {
            setBusy(true);
            setInstalling(true);

            // TODO: hack
            const package_manager: PackageManager = createPackageManager(glob.backend!, {agent});
            const {minInstallationId: id} = await package_manager.installPackages({
                packages: [{
                    packageName: packageName!,
                    version: chosenVersion!,
                    repo: Principal.fromText(process.env.CANISTER_ID_REPOSITORY!),
                }],
                user: principal!,
                afterInstallCallback: [],
            });
            await waitTillInitialized(agent!, glob.backend!, id);
            navigate(`/installed/show/${id}`);
        }
        catch(e) {
            console.log(e);
            throw e; // TODO
        }
        finally {
            setBusy(false);
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
                        : <>Already installed. <Button onClick={install} disabled={installing || chosenVersion === undefined}>Install it in addition to other versions of this package</Button></>
                    }
                </p>
            </>}
        </>
    );
}