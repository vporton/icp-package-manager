import { useParams } from "react-router-dom";
import { useAuth } from "./auth/use-auth-client";
import { useEffect, useState } from "react";
import { package_manager } from "../../declarations/package_manager";
import { InstalledPackageInfo } from "../../declarations/package_manager/package_manager.did";
import Button from "react-bootstrap/esm/Button";
import { FullPackageInfo, PackageInfo, RealPackageInfo, RepositoryPartition, idlFactory as repositoryPartitionIDL } from '../../declarations/RepositoryPartition/RepositoryPartition.did.js';
import { Actor } from "@dfinity/agent";

export default function Installation(props: {}) {
    const { installationId } = useParams();
    const {defaultAgent} = useAuth();
    const [pkg, setPkg] = useState<InstalledPackageInfo | undefined>();
    const [pkg2, setPkg2] = useState<PackageInfo | undefined>();
    useEffect(() => {
        if (defaultAgent === undefined) {
            return;
        }
        package_manager.getInstalledPackage(BigInt(installationId!)).then(pkg => {
            setPkg(pkg);
            const part: RepositoryPartition = Actor.createActor(repositoryPartitionIDL, {canisterId: pkg.packageCanister!, agent: defaultAgent});
            part.getFullPackageInfo(pkg.name).then(fullInfo => {
                const pi = fullInfo.packages.filter(([version, _]) => version == pkg.version).map(([version, pkg]) => pkg)[0]; // TODO: undefined
                setPkg2(pi);
            });

        });
    }, [defaultAgent]);

    // TODO: Ask for confirmation.
    async function uninstall() {
        let id = await package_manager.uninstallPackage(BigInt(installationId!));
        // TODO:
        alert("Uninstallation finished");
    }

    return (
        <>
            <h2>Installation</h2>
            <p><strong>Installation ID:</strong> {installationId}</p>
            <p><strong>Package name:</strong> {pkg?.name}</p>
            <p><strong>Package version:</strong> {pkg?.version}</p>
            <p><strong>Short description:</strong> {pkg2?.base.shortDescription}</p>
            <p><strong>Long description:</strong> {pkg2?.base.longDescription}</p>
            { (pkg2?.specific as { real: RealPackageInfo }).real && 
                <p><strong>Dependencies:</strong> {(pkg2?.specific as { real: RealPackageInfo }).real.dependencies.join(", ")}</p>
            }
            {/* TODO: description is missing in `pkg`, why? */}
            <p><Button onClick={uninstall}>Uninstall</Button></p>
        </>
    )
}