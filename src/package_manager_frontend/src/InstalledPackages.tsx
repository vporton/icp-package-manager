import Button from "react-bootstrap/esm/Button";
import { useContext, useEffect, useState } from "react";
import { SharedInstalledPackageInfo } from "../../declarations/package_manager/package_manager.did";
import { Link } from "react-router-dom";
import { GlobalContext } from "./state";
import { MyLink } from "./MyNavigate";

function InstalledPackageLine(props: {packageName: string, allInstalled: Map<string, [bigint, SharedInstalledPackageInfo][]>}) {
    console.log('allInstalled', props.allInstalled); // FIXME: Remove.
    const packages = props.allInstalled.get(props.packageName);
    const versionsSet = new Set(packages!.map(p => p[1].version));
    const versions = Array.from(versionsSet); // TODO: Sort appropriately.
    const byVersion = new Map(versions.map(version => {
        const p: [string, [bigint, SharedInstalledPackageInfo][]] = [version, Array.from(packages!.filter(p => p[1].version === version))];
        return p;
    }));
    return (
        <li>
            <code>{props.packageName}</code>{" "}
            {Array.from(byVersion.entries()).map(([version, packages]) => {
                return (
                    <span key={version}>
                        {packages.length === 1 ?
                            <MyLink to={'/installed/show/'+packages[0][0].toString()}>{version}</MyLink> :
                            <span>{version} ({packages.map(([k, _]) =>
                                <span key={k}>
                                    <MyLink to={'/installed/show/'+k.toString()}>{k.toString()}</MyLink>{" "}
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
    const [installedVersions, setInstalledVersions] = useState<Map<string, [bigint, SharedInstalledPackageInfo][]>>();
    const glob = useContext(GlobalContext);
    useEffect(() => {
        if (glob.package_manager_ro === undefined) { // Why is this check needed?
            return;
        }
        glob.package_manager_ro!.getAllInstalledPackages().then(allPackages => {
            console.log("allPackages", allPackages) // FIXME: Remove
            const namesSet = new Set(allPackages.map(p => p[1].name));
            console.log("namesSet", namesSet) // FIXME: Remove
            const names = Array.from(namesSet);
            console.log("names", names) // FIXME: Remove
            names.sort();
            console.log("names", names) // FIXME: Remove
            const byName0 = names.map(name => {
                const p: [string, [bigint, SharedInstalledPackageInfo][]] = [name, Array.from(allPackages.filter(p => p[1].name === name))];
                return p;
            });
            console.log("byName0", byName0) // FIXME: Remove
            const byName = new Map(byName0);
            console.log("byName", byName) // FIXME: Remove
            setInstalledVersions(byName);
        });
    }, [glob.package_manager_ro]);

    return (
        <>
            <h2>Installed packages</h2>
            <ul>
                {/* <li><input type='checkbox'/> All <Button>Uninstall</Button> <Button>Upgrade</Button></li> */}
                {installedVersions && Array.from(installedVersions!.entries()).map(([name, [id, info]]) =>
                    <InstalledPackageLine packageName={name} key={name} allInstalled={installedVersions!}/>
                )}
            </ul>
        </>
    );
}