import { useContext, useEffect, useState } from "react";
import { SharedInstalledPackageInfo } from "../../declarations/package_manager/package_manager.did";
import { GlobalContext } from "./state";
import { MyLink } from "./MyNavigate";
import { Guid }  from "js-guid"
import { useAuth } from "./auth/use-auth-client";

function concatenateUint8Arrays(array1: Uint8Array, array2: Uint8Array): Uint8Array {
    const combinedArray = new Uint8Array(array1.length + array2.length);
    combinedArray.set(array1, 0);
    combinedArray.set(array2, array1.length);
    return combinedArray;
}

/// not the same as similarly named function in backend!
function myAmendedGUID(guid: Uint8Array, name: string): Uint8Array {
    const encoder = new TextEncoder();
    const encodedName = encoder.encode(name);
    const concatenated = concatenateUint8Arrays(guid, encodedName);
    // const hashBuffer = await crypto.subtle.digest('SHA-256', concatenated);
    // return new Uint8Array(hashBuffer);
    return concatenated;
}

function InstalledPackageLine(props: {
    packageName: string,
    guid: Uint8Array,
    allInstalled: Map<string/*Uint8Array*/, {installationId: bigint, pkg: SharedInstalledPackageInfo, pibn: {all: SharedInstalledPackageInfo[]; default: bigint}}[]
>}) {
    const pkgId = {guid: props.guid, name: props.packageName};
    const packages = props.allInstalled.get(myAmendedGUID(props.guid, props.packageName).toString());
    if (packages === undefined) { // TODO: Is this block needed?
        return ""; // hack
    }
    const versionsSet = new Set(packages!.map(p => p.pkg.version));
    const versions = Array.from(versionsSet); // TODO: Sort appropriately.
    const byVersion = new Map(versions.map(version => {
        const p: [string, {installationId: bigint, pkg: SharedInstalledPackageInfo, pibn: {all: SharedInstalledPackageInfo[]; default: bigint}}[]] =
            [version, Array.from(packages!.filter(p => p.pkg.version === version))];
        return p;
    }));
    const glob = useContext(GlobalContext);
    function setDefault(k: bigint) {
        glob.packageManager!.setDefaultInstalledPackage(props.packageName, props.guid, k);
    }
    const guid = props.guid; // TODO: Reduce.
    return (
        <li>
            <span title={Guid.parse(guid).toString()}><code>{props.packageName}</code></span>{" "}
            {/* TODO: Sort. */}
            {Array.from(byVersion.entries()).map(([version, packages]) => {
                return (
                    <span key={version}>
                        {packages.length === 1 ?
                            <MyLink to={'/installed/show/'+packages[0].installationId.toString()}>{version}</MyLink> :
                            <span>{version} ({Array.from(packages.entries()).map(([index, {installationId: k, pibn}]) =>
                                <span key={k}>
                                    <input
                                        type="radio"
                                        name={props.packageName}
                                        value={k.toString()}
                                        defaultChecked={k === pibn.default}
                                        onClick={() => setDefault(k)}
                                    />
                                    <MyLink to={'/installed/show/'+k.toString()}>{k.toString()}</MyLink>
                                    {index === packages.length - 1 ? "" : " "}
                                </span>
                            )})</span>
                        }
                    </span>
                );
            })}
        </li>
    )
}

export default function InstalledPackages(props: {}) {
    const [installedVersions, setInstalledVersions] =
        useState<Map<string/*Uint8Array*/, {installationId: bigint, pkg: SharedInstalledPackageInfo, pibn: {all: SharedInstalledPackageInfo[]; default: bigint}}[]> | undefined>();
    const glob = useContext(GlobalContext);
    const { isAuthenticated } = useAuth();
    useEffect(() => {
        if (glob.packageManager === undefined || !isAuthenticated) { // TODO: It seems to work but is a hack
            setInstalledVersions(undefined);
            return;
        }
        glob.packageManager.getAllInstalledPackages().then(async allPackages => {
            const guids2Set = await Promise.all(new Set(allPackages.map(p => { return {guid: p[1].package.base.guid, name: p[1].name} }) as Array<{guid: Uint8Array, name: string}>));
            const guids2 = Array.from(guids2Set);
            // guids2.sort(); // TODO: wrong order
            Promise.all(guids2.map(async guid2 => {
                const pibn = await glob.packageManager!.getInstalledPackagesInfoByName(guid2.name, guid2.guid); // TODO: inefficient
                // const guid2v = await amende\dGUID(guid2.guid, guid2.name);
                const p: [string/*Uint8Array*/, {installationId: bigint, pkg: SharedInstalledPackageInfo, pibn: {all: SharedInstalledPackageInfo[]; default: bigint}}[]] =
                    [
                        myAmendedGUID(guid2.guid, guid2.name).toString(), // TODO: `.toString` here is a crude hack.
                        Array.from(allPackages.filter(p => {
                            return p[1].package.base.guid === guid2.guid && p[1].name === guid2.name
                        }))
                            .map(p => {
                                return {installationId: p[0], pkg: p[1], pibn};
                            }),
                    ];
                return p;
            }))
                .then(byName0 => {
                    const byName = new Map(byName0);
                    setInstalledVersions(byName);
                });
        });
    }, [glob.packageManager, isAuthenticated]);

    return (
        <>
            <h2>Installed packages</h2>
            {installedVersions === undefined ? <p>No packages list (please, login).</p> :
                <ul>
                    {/* <li><input type='checkbox'/> All <Button>Uninstall</Button> <Button>Upgrade</Button></li> */}
                    {installedVersions !== undefined &&
                        Array.from(installedVersions.values()).map((info) =>
                            <InstalledPackageLine packageName={info[0].pkg.name} guid={info[0].pkg.package.base.guid as Uint8Array} key={info[0].pkg.name} allInstalled={installedVersions}/>
                    )}
                </ul>
            }
        </>
    );
}