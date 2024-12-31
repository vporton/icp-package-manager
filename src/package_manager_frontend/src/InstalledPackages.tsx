import { useContext, useEffect, useState } from "react";
import { SharedInstalledPackageInfo } from "../../declarations/package_manager/package_manager.did";
import { GlobalContext } from "./state";
import { MyLink } from "./MyNavigate";
import { useAuth } from "./auth/use-auth-client";

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
            {/* TODO: Sort. */}
            {Array.from(byVersion.entries()).map(([version, packages]) => {
                return (
                    <span key={version}>
                        {packages.length === 1 ?
                            <MyLink to={'/installed/show/'+packages[0][0].toString()}>{version}</MyLink> :
                            <span>{version} ({Array.from(packages.entries()).map(([index, [k, _]]) =>
                                <span key={k}>
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
    const [installedVersions, setInstalledVersions] = useState<Map<string, [bigint, SharedInstalledPackageInfo][]> | undefined>();
    const glob = useContext(GlobalContext);
    const { isAuthenticated } = useAuth();
    useEffect(() => {
        if (glob.package_manager_rw === undefined || !isAuthenticated) { // TODO: It seems to work but is a hack
            setInstalledVersions(undefined);
            return;
        }
        glob.package_manager_rw!.getAllInstalledPackages().then(allPackages => {
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
    }, [glob.package_manager_rw, isAuthenticated]);

    return (
        <>
            <h2>Installed packages</h2>
            {installedVersions === undefined ? <p>No packages list (please, login).</p> :
                <ul>
                    {/* <li><input type='checkbox'/> All <Button>Uninstall</Button> <Button>Upgrade</Button></li> */}
                    {Array.from(installedVersions!.entries()).map(([name, [id, info]]) =>
                        <InstalledPackageLine packageName={name} key={name} allInstalled={installedVersions!}/>
                    )}
                </ul>
            }
        </>
    );
}