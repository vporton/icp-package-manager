import { useParams } from "react-router-dom";
import { useAuth } from "./auth/use-auth-client";
import { useContext, useEffect, useState } from "react";
import { SharedInstalledPackageInfo } from "../../declarations/package_manager/package_manager.did";
import Button from "react-bootstrap/Button";
import { SharedPackageInfo, SharedRealPackageInfo, RepositoryPartition, idlFactory as repositoryPartitionIDL } from '../../declarations/RepositoryPartition/RepositoryPartition.did.js';
import { Actor } from "@dfinity/agent";
import { GlobalContext } from "./state";

export default function Installation(props: {}) {
    const { installationId } = useParams();
    const {defaultAgent} = useAuth();
    const [pkg, setPkg] = useState<SharedInstalledPackageInfo | undefined>();
    const [pkg2, setPkg2] = useState<SharedPackageInfo | undefined>();
    const glob = useContext(GlobalContext);
    useEffect(() => {
        if (defaultAgent === undefined) {
            return;
        }
        // FIXME: Next line throws.
        glob.package_manager_ro!.getInstalledPackage(BigInt(installationId!)).then(pkg => {
            setPkg(pkg);
            const part: RepositoryPartition = Actor.createActor(repositoryPartitionIDL, {canisterId: pkg.packageRepoCanister!, agent: defaultAgent});
            part.getFullPackageInfo(pkg.name).then(fullInfo => {
                const pi = fullInfo.packages.filter(([version, _]) => version == pkg.version).map(([_, pkg]) => pkg)[0]; // TODO: undefined
                setPkg2(pi);
            });

        });
    }, [defaultAgent]);

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
            <p><strong>Installation ID:</strong> {installationId}</p>
            <p><strong>Package name:</strong> {pkg?.name}</p>
            <p><strong>Package version:</strong> {pkg?.version}</p>
            <p><strong>Short description:</strong> {pkg2?.base.shortDescription}</p>
            <p><strong>Long description:</strong> {pkg2?.base.longDescription}</p>
            { pkg2 && (pkg2.specific as { real: SharedRealPackageInfo }).real && 
                <p><strong>Dependencies:</strong> {(pkg2?.specific as { real: SharedRealPackageInfo }).real.dependencies.join(", ")}</p>
            }
            <p><Button onClick={uninstall}>Uninstall</Button></p>
        </>
    )
}