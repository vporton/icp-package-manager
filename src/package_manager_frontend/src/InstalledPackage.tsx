import { useParams } from "react-router-dom";
import { getIsLocal, useAuth } from "./auth/use-auth-client";
import { useContext, useEffect, useState } from "react";
import { SharedInstalledPackageInfo } from "../../declarations/package_manager/package_manager.did";
import Button from "react-bootstrap/Button";
import { SharedPackageInfo, SharedRealPackageInfo } from '../../declarations/RepositoryPartition/RepositoryPartition.did.js';
import { Actor } from "@dfinity/agent";
import { GlobalContext } from "./state";

export default function Installation(props: {}) {
    const { installationId } = useParams();
    const {agent, isAuthenticated} = useAuth();
    const [pkg, setPkg] = useState<SharedInstalledPackageInfo | undefined>();
    const [frontend, setFrontend] = useState<string | undefined>();
    const glob = useContext(GlobalContext);
    useEffect(() => {
        if (glob.package_manager_rw === undefined) { // TODO: `agent` is unused.
            return;
        }

        glob.package_manager_rw!.getInstalledPackage(BigInt(installationId!)).then(pkg => {
            setPkg(pkg);
        });
    }, [glob.package_manager_rw]);
    useEffect(() => {
        // TODO: It seems to work but is a hack:
        if (glob.package_manager_rw === undefined || !isAuthenticated || pkg === undefined) { // TODO: `agent` is unused?
            return;
        }

        const piReal: SharedRealPackageInfo = (pkg.package.specific as any).real;
        if (piReal.frontendModule[0] !== undefined) { // There is a frontend module.
            glob.package_manager_rw!.getInstalledPackage(BigInt(0)).then(pkg0 => {
                const piReal0: SharedRealPackageInfo = (pkg0.package.specific as any).real;
                const modules0 = new Map(pkg0.modules);
                const modules = new Map(pkg.modules);
                const frontendStr = modules.get(piReal.frontendModule[0]!)!.toString();
                let url = getIsLocal() ? `http://${frontendStr}.localhost:4943` : `https://${frontendStr}.icp0.io`;
                url += `?_pm_inst=${installationId}`;
                for (let m of piReal.modules) {
                    url += `&_pm_pkg.${m[0]}=${modules.get(m[0])!.toString()}`;
                }
                for (let m of piReal0.modules) {
                    url += `&_pm_pkg0.${m[0]}=${modules0.get(m[0])!.toString()}`;
                }
                setFrontend(url);
            });
        }
    }, [glob.package_manager_rw, glob.backend, pkg]);

    // TODO: Ask for confirmation.
    async function uninstall() {
        // TODO
        // let id = await glob.package_manager_rw!.uninstallPackage(BigInt(installationId!));
        // TODO:
        alert("Uninstallation finished");
    }

    return (
        <>
            <h2>Installation</h2>
            {pkg === undefined ? <p>No such installed package.</p> : <>
                <p><strong>Frontend:</strong> {frontend === undefined ? <em>(none)</em> : <a href={frontend}>here</a>}</p>
                <p><strong>Installation ID:</strong> {installationId}</p>
                <p><strong>Package name:</strong> {pkg.name}</p>
                <p><strong>Package version:</strong> {pkg.version}</p>
                <p><strong>Short description:</strong> {pkg.package.base.shortDescription}</p>
                <p><strong>Long description:</strong> {pkg.package.base.longDescription}</p>
                { pkg.package && (pkg.package.specific as { real: SharedRealPackageInfo }).real && 
                    <p><strong>Dependencies:</strong> {(pkg.package.specific as { real: SharedRealPackageInfo }).real.dependencies.join(", ")}</p>
                }
                <p><Button onClick={uninstall}>Uninstall</Button></p>
            </>}
        </>
    )
}