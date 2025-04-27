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
    allInstalled: Map<string/*Uint8Array*/, {all: SharedInstalledPackageInfo[], default: bigint}
>}) {
    const packages0 = props.allInstalled.get(myAmendedGUID(props.guid, props.packageName).toString())!; // TODO@P3: Instead, make it an argument in `props`.
    if (packages0 === undefined) { // TODO@P3: needed?
        return ""; // hack
    }
    const versionsSet = new Set(packages0.all.map(p => p.package.base.version));
    const versions = Array.from(versionsSet); // TODO@P3: Sort appropriately.
    const byVersion = new Map<string, SharedInstalledPackageInfo[]>();
    for (const v of versions) {
        byVersion.set(v, packages0.all.filter(p => p.package.base.version === v));
    }
    const glob = useContext(GlobalContext);
    function setDefault(k: bigint) {
        glob.packageManager!.setDefaultInstalledPackage(props.packageName, props.guid, k);
    }
    return (
        <li>
            <span title={Guid.parse(props.guid).toString()}><code>{props.packageName}</code></span>{" "}
            {/* TODO@P3: Sort. */}
            {Array.from(byVersion.entries()).map(([version, packages]) =>
                <span key={version}>
                    {packages.length === 1 ?
                        <MyLink to={'/installed/show/'+packages[0].id.toString()}>{version}</MyLink> :
                        <span>{version} {
                            Array.from(packages.entries()).map(([index, p]) =>
                                <span key={p.id.toString()}>
                                    <input
                                        type="radio"
                                        name={Guid.parse(props.guid).toString()}
                                        value={packages0.default.toString()}
                                        defaultChecked={p.id.toString() === packages0.default.toString()}
                                        onClick={() => setDefault(BigInt(p.id.toString()))}
                                    />
                                    <MyLink to={'/installed/show/'+p.id.toString()}>{p.id.toString()}</MyLink>
                                    {index === packages.length - 1 ? "" : " "}
                                </span>)
                        }</span>
                    }
                </span>
            )}
        </li>
    )
}

export default function InstalledPackages(props: {}) {
    const [installedVersions, setInstalledVersions] =
        useState<Map<string/*Uint8Array*/, {all: SharedInstalledPackageInfo[]; default: bigint}> | undefined>();
    const glob = useContext(GlobalContext);
    const { isLoginSuccess } = useAuth();
    useEffect(() => {
        if (glob.packageManager === undefined || !isLoginSuccess) { // TODO@P3: It seems to work but is a hack
            setInstalledVersions(undefined);
            return;
        }
        glob.packageManager.getAllInstalledPackages().then(async allPackages => {
            const guids2Set = await Promise.all(new Set(allPackages.map(p => { return {guid: p[1].package.base.guid, name: p[1].package.base.name} }) as Array<{guid: Uint8Array, name: string}>));
            const guids2 = Array.from(guids2Set);
            // guids2.sort(); // TODO@P3: wrong order
            Promise.all(guids2.map(async guid2 => {
                const pibn = await glob.packageManager!.getInstalledPackagesInfoByName(guid2.name, guid2.guid); // TODO@P3: inefficient
                const p: [string/*Uint8Array*/, {all: SharedInstalledPackageInfo[]; default: bigint}] =
                    [
                        myAmendedGUID(guid2.guid, guid2.name).toString(), // TODO@P3: `.toString` here is a crude hack.
                        pibn,
                    ];
                return p;
            }))
                .then(byName0 => {
                    const byName = new Map<string, {
                        all: SharedInstalledPackageInfo[];
                        default: bigint;
                    }>(byName0);
                    for (const p of byName0) {
                        byName.set(p[0], p[1]!);
                    }
                    setInstalledVersions(byName!);
                });
        });
    }, [glob.packageManager, isLoginSuccess]);

    return (
        <>
            <h2>Installed packages</h2>
            {installedVersions === undefined ? <p>No packages list (please, login).</p> :
                <ul>
                    {/* <li><input type='checkbox'/> All <Button>Uninstall</Button> <Button>Upgrade</Button></li> */}
                    {installedVersions !== undefined &&
                        Array.from(installedVersions.values()).map((info) =>
                            <InstalledPackageLine
                                packageName={info.all[0].package.base.name}
                                guid={info.all[0].package.base.guid as Uint8Array}
                                key={info.all[0].package.base.name}
                                allInstalled={installedVersions}/>
                    )}
                </ul>
            }
        </>
    );
}