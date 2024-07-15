import { useParams } from "react-router-dom";
import { useAuth } from "./auth/use-auth-client";
import { useEffect, useState } from "react";
import { package_manager } from "../../declarations/package_manager";
import { InstalledPackageInfo } from "../../declarations/package_manager/package_manager.did";
import Button from "react-bootstrap/esm/Button";

export default function Installation(props: {}) {
    const { installationId } = useParams();
    const {defaultAgent} = useAuth();
    const [pkg, setPkg] = useState<InstalledPackageInfo | undefined>();
    useEffect(() => {
        if (defaultAgent === undefined) {
            return;
        }
        package_manager.getInstalledPackage(BigInt(installationId!)).then(pkg => {
            setPkg(pkg);
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
            {/* TODO: description is missing in `pkg`, why? */}
            <p><Button onClick={uninstall}>Uninstall</Button></p>
        </>
    )
}