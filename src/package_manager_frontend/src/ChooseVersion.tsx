import { useEffect, useState } from "react";
import { useParams } from "react-router-dom";
import { SharedFullPackageInfo } from '../../declarations/repository/repository.did.js';
import { Actor, Agent } from "@dfinity/agent";
import { useContext } from 'react';
import { useAuth } from "./auth/use-auth-client";
import Button from "react-bootstrap/Button";
import { Principal } from "@dfinity/principal";
import { _SERVICE as Repository } from '../../declarations/repository/repository.did';
import { idlFactory as repositoryIndexIdl } from '../../declarations/repository';
import { createActor as createPackageManager } from '../../declarations/package_manager';
import { myUseNavigate } from "./MyNavigate";
import { GlobalContext } from "./state";
import { InitializedChecker, waitTillInitialized } from "../../lib/install";
import { ErrorContext } from "../../lib/ErrorContext";
import { InstallationId, PackageName, PackageManager, Version, SharedRealPackageInfo, CheckInitializedCallback } from '../../declarations/package_manager/package_manager.did';
import { BusyContext } from "../../lib/busy.js";
import { Alert } from "react-bootstrap";
import { init } from "@dfinity/agent/lib/cjs/canisters/management_service.js";

/// `oldInstallation === undefined` means that the package is newly installed rather than upgraded.
export default function ChooseVersion(props: {}) {
    const { packageName, repo, installationId: oldInstallation } = useParams();
    const glob = useContext(GlobalContext);
    const [packageName2, setPackageName2] = useState<string | undefined>(packageName);
    const [repo2, setRepo2] = useState<Principal | undefined>(repo === undefined ? undefined : Principal.fromText(repo));
    const [version2, setVersion2] = useState<string | undefined>();
    const [guid0, setGuid0] = useState<any | undefined>(); // TODO@P3: inconsistent
    useEffect(() => {
        if (oldInstallation !== undefined && glob.packageManager !== undefined) {
            glob.packageManager.getInstalledPackage(BigInt(oldInstallation)).then(installation => {
                setPackageName2(installation.package.base.name);
                setRepo2(installation.packageRepoCanister);
                setVersion2(installation.package.base.version);
                setGuid0(installation.package.base.guid);
            });
        }
    }, [oldInstallation, glob.packageManager]);
    return (
        <ChooseVersion2
            packageName={packageName2}
            repo={repo2}
            oldInstallation={oldInstallation === undefined ? undefined : BigInt(parseInt(oldInstallation))}
            currentVersion={version2}
            guid0={guid0}/>
    );
}

function ChooseVersion2(props: {
    packageName: PackageName | undefined,
    repo: Principal | undefined,
    oldInstallation: InstallationId | undefined,
    currentVersion: Version | undefined,
    guid0: any | undefined,
}) {
    const glob = useContext(GlobalContext);
    const navigate = myUseNavigate();
    const {isLoginSuccess} = useInternetIdentity();
    const {principal, agent, defaultAgent} = useInternetIdentity();
    const [versions, setVersions] = useState<[string, string][] | undefined>();
    const [installedVersions, setInstalledVersions] = useState<Map<string, 1>>(new Map());
    // const [guidInfo, setGUIDInfo] = useState<Uint8Array | undefined>();
    // TODO@P3: I doubt consistency, and performance in the case if there is no such package.
    useEffect(() => {
        if (glob.packageManager !== undefined && props.packageName !== undefined) {
            const index: Repository = Actor.createActor(repositoryIndexIdl, {canisterId: props.repo!, agent: defaultAgent});
            index.getFullPackageInfo(props.packageName!).then(fullInfo => {
                const versionsMap = new Map(fullInfo.versionsMap);
                const p2: [string, string][] = fullInfo.packages.map(pkg => [pkg[0], versionsMap.get(pkg[0]) ?? pkg[0]]);
                const v = fullInfo.versionsMap.map(([name, version]) => [`${name} → ${version}`, version] as [string, string]).concat(p2);
                setVersions(v);
                const guid2 = fullInfo.packages[0][1].base.guid as Uint8Array;
                // setGUIDInfo(guid2);
                if (v !== undefined && glob.packageManager !== undefined) {
                    glob.packageManager!.getInstalledPackagesInfoByName(props.packageName!, guid2).then(installed => {
                        setInstalledVersions(new Map(installed.all.map(e => [e.package.base.version, 1])));
                    });
                }
            });
        }
    }, [glob.packageManager, props.packageName, props.repo]);
    const [chosenVersion, setChosenVersion] = useState<string | undefined>(undefined);
    const [installing, setInstalling] = useState(false);
    let errorContext = useContext(ErrorContext);
    let { setBusy } = useContext(BusyContext);
    async function install() {
        try {
            setBusy(true);
            setInstalling(true);

            // TODO@P3: hack
            const package_manager: PackageManager = createPackageManager(glob.backend!, {agent});
            const {minInstallationId: id} = await package_manager.installPackages({
                packages: [{
                    packageName: props.packageName!,
                    version: chosenVersion!,
                    repo: props.repo!,
                    arg: new Uint8Array(),
                    initArg: [],
                }],
                user: principal!,
                afterInstallCallback: [],
            });
            await waitTillInitialized(agent!, glob.backend!, id);
            navigate(`/installed/show/${id}`);
        }
        catch(e) {
            console.log(e);
            throw e; // TODO@P3
        }
        finally {
            setBusy(false);
        }
    }
    async function upgrade() {
        try {
            setBusy(true);
            setInstalling(true);

            // TODO@P3: hack
            const package_manager: PackageManager = createPackageManager(glob.backend!, {agent});
            const {minUpgradeId: id} = await package_manager.upgradePackages({
                packages: [{
                    installationId: BigInt(props.oldInstallation!),
                    packageName: props.packageName!,
                    version: chosenVersion!,
                    repo: props.repo!,
                    arg: new Uint8Array(),
                    initArg: [],
                }],
                user: principal!,
                afterUpgradeCallback: [],
            });
            for (;;) {
                const cur = await glob.packageManager!.getInstalledPackagesInfoByName(props.packageName!, props.guid0);
                if (cur.all.find(v => v.package.base.version === chosenVersion) !== undefined) {
                    break;
                }
                console.log("Waiting till package upgrade...");
                await new Promise((resolve) => setTimeout(resolve, 1000));
            }
            navigate(`/installed/show/${props.oldInstallation}`);
        }
        catch(e) {
            console.log(e);
            throw e; // TODO@P3
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
            {props.oldInstallation !== undefined &&
                <Alert variant="warning">
                    <p>Downgrading to a lower version than the current may lead to data loss!</p>
                    <p>You are strongly recommended to upgrade only to higher versions.</p>
                </Alert>
            }
            <p>Package: {props.packageName}</p> {/* TODO@P3: no "No such package." message, while the package loads */}
            {versions === undefined ? <p>No such package.</p> : <>
                <p>
                    {props.oldInstallation !== undefined && <>Current version: {props.currentVersion}{" "}</>}
                    Version to install:{" "}
                    <select onChange={e => setChosenVersion((e.target as HTMLSelectElement).value)}>
                        {Array.from(versions!.entries()).map(([i, [k, v]]) =>
                            <option key={i} value={v}>{k}</option>)}
                    </select>
                </p>
                <p>
                    {props.oldInstallation !== undefined ?
                        <Button onClick={upgrade} disabled={installing || chosenVersion === undefined}>Upgrade package</Button>
                        : installedVersions.size == 0
                        ? <Button onClick={install} disabled={installing || chosenVersion === undefined}>Install new package</Button>
                        : installedVersions.has(chosenVersion ?? "")
                        ? <>Already installed. <Button onClick={install} disabled={!isLoginSuccess || installing || chosenVersion === undefined}>Install an additional copy of this version</Button></>
                        : <>Already installed. <Button onClick={install} disabled={!isLoginSuccess || installing || chosenVersion === undefined}>Install it in addition to other versions of this package</Button></>
                    }
                    {!isLoginSuccess && <p>Sign in to install or upgrade packages.</p>}
                </p>
            </>}
        </>
    );
}