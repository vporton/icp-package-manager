import Button from "react-bootstrap/esm/Button";
import { package_manager } from "../../declarations/package_manager";
import { useEffect, useState } from "react";
import { InstalledPackageInfo } from "../../declarations/package_manager/package_manager.did";

function InstalledPackageLine(props: {packageName: string, allInstalled: Map<string, [bigint, InstalledPackageInfo][]>}) {
    const packages = props.allInstalled.get(props.packageName);
    const versionsSet = new Set(packages!.map(p => p[1].version));
    const versions = Array.from(versionsSet); // TODO: Sort appropriately.
    const byVersion = new Map(versions.map(version => {
        const p: [string, [bigint, InstalledPackageInfo][]] = [version, Array.from(packages!.filter(p => p[1].version === version))];
        return p;
    }));
    return (
        <>
            <input type='checkbox'/> <code>{props.packageName}</code>{" "}
            {Array.from(byVersion.entries()).map(([version, packages]) => {
                return (
                    <>
                        {byVersion.size > 1 && <input type='checkbox'/>}
                        {packages.length === 1 ?
                            <a href="#">{version}</a> :
                            <>{version} ({packages.map(([k, _]) => <>
                                <input type='checkbox'/>
                                <a href="#" key={k.toString()}>{k.toString()}</a>
                            </>)})</>
                        }
                    </>
                );
            })}
        </>
    )
}

export default function InstalledPackages(props: {}) {
    const [installedVersions, setInstalledVersions] = useState<Map<string, [bigint, InstalledPackageInfo][]>>();
    useEffect(() => {
        package_manager.getAllInstalledPackages().then(allPackages => {
            const namesSet = new Set(allPackages.map(p => p[1].name));
            const names = Array.from(namesSet);
            names.sort();
            const byName0 = names.map(name => {
                const p: [string, [bigint, InstalledPackageInfo][]] = [name, Array.from(allPackages.filter(p => p[1].name === name))];
                return p;
            });
            const byName = new Map(byName0);
            setInstalledVersions(byName);
        });
    }, []);

    return (
        <>
            <h2>Installed packages</h2>
            <ul className='checklist'>
                <li><input type='checkbox'/> All <Button>Uninstall</Button> <Button>Upgrade</Button></li>
                {installedVersions && Array.from(installedVersions!.entries()).map(([name, [id, info]]) =>
                <li key={name}>
                    <InstalledPackageLine packageName={name} allInstalled={installedVersions!}/>)
                </li>)}
            </ul>
        </>
    );
}