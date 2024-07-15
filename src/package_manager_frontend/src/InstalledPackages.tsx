import Button from "react-bootstrap/esm/Button";
import { package_manager } from "../../declarations/package_manager";
import { useEffect, useState } from "react";
import { InstalledPackageInfo } from "../../declarations/package_manager/package_manager.did";
import { AlertLink } from "react-bootstrap";

function InstalledPackageLine(props: {packageName: string, allInstalled: Map<string, [bigint, InstalledPackageInfo][]>}) {
    const packages = props.allInstalled.get(props.packageName);
    const versionsSet = new Set(packages!.map(p => p[1].version));
    const versions = Array.from(versionsSet); // TODO: Sort appropriately.
    const byVersion = new Map(versions.map(version => {
        const p: [string, [bigint, InstalledPackageInfo][]] = [version, Array.from(packages!.filter(p => p[1].version === version))];
        return p;
    }));
    return (
        <li>
            <input type='checkbox'/> <code>{props.packageName}</code>{" "}
            {packages?.map(([id, pkg]) => {
                console.log(byVersion, pkg.version);
                const thisByVersion = byVersion.get(pkg.version)!;
                return (
                    <>
                        {packages.length > 1 ? <input type='checkbox'/> : ""}{" "}
                        {thisByVersion.length > 1 && <input type='checkbox'/>}
                        {thisByVersion.length === 1 ?
                            <a href="#">{pkg.version}</a> :
                            <>{pkg.version} ({thisByVersion.map(([k, _]) => <a href="#" key={k.toString()}>{k.toString()}</a>,)})</>
                        }
                    </>
                );
            })}
        </li>
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
                {installedVersions && Array.from(installedVersions!.entries()).map(([name, [id, info]]) => <InstalledPackageLine packageName={name} allInstalled={installedVersions!}/>)}
                <li>The following are examples for the demo, not real packages:</li>
                <li><input type='checkbox'/> <code>photoedit</code> <input type='checkbox'/> 3.5.6{" "}
                    (<input type='checkbox'/> <a href='#'>1</a>, <input type='checkbox'/> <a href='#'>2</a>),
                    {" "}<input type='checkbox'/> <a href='#'>3.5.7</a></li>
                <li><input type='checkbox'/> <code>altcoin</code> 4.1.6</li>
            </ul>
        </>
    );
}