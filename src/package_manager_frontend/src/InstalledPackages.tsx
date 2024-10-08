import Button from "react-bootstrap/esm/Button";
import { package_manager } from "../../declarations/package_manager";
import { useEffect, useState } from "react";
import { SharedInstalledPackageInfo } from "../../declarations/package_manager/package_manager.did";
import { Link } from "react-router-dom";

function InstalledPackageLine(props: {packageName: string, allInstalled: Map<string, [bigint, SharedInstalledPackageInfo][]>}) {
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
                            <Link to={'/installed/show/'+packages[0][0].toString()}>{version}</Link> :
                            <span>{version} ({packages.map(([k, _]) =>
                                <span key={k}>
                                    <Link to={'/installed/show/'+k.toString()}>{k.toString()}</Link>{" "}
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
    useEffect(() => {
        package_manager.getAllInstalledPackages().then(allPackages => {
            const namesSet = new Set(allPackages.map(p => p[1].name));
            const names = Array.from(namesSet);
            names.sort();
            const byName0 = names.map(name => {
                const p: [string, [bigint, SharedInstalledPackageInfo][]] = [name, Array.from(allPackages.filter(p => p[1].name === name))];
                return p;
            });
            const byName = new Map(byName0);
            setInstalledVersions(byName);
        });
    }, []);

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