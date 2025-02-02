import { useParams } from "react-router-dom";
import { getIsLocal, useAuth } from "./auth/use-auth-client";
import { useContext, useEffect, useState } from "react";
import { SharedInstalledPackageInfo } from "../../declarations/package_manager/package_manager.did";
import Button from "react-bootstrap/Button";
import { SharedPackageInfo, SharedRealPackageInfo } from '../../declarations/RepositoryIndex/RepositoryIndex.did.js';
import { Actor } from "@dfinity/agent";
import { GlobalContext } from "./state";
import Accordion from "react-bootstrap/Accordion";
import { Alert } from "react-bootstrap";

export default function Installation(props: {}) {
    const { installationId } = useParams();
    const {agent, isAuthenticated} = useAuth();
    const [pkg, setPkg] = useState<SharedInstalledPackageInfo | undefined>();
    const [frontend, setFrontend] = useState<string | undefined>();
    const [pinned, setPinned] = useState(false);
    const [showDanger, setShowDanger] = useState(false);
    const glob = useContext(GlobalContext);
    // TODO: When logged out, show instead that logged out.
    useEffect(() => {
        if (glob.packageManager === undefined) { // TODO: `agent` is unused.
            return;
        }

        glob.packageManager!.getInstalledPackage(BigInt(installationId!)).then(pkg => {
            setPkg(pkg);
            setPinned(pkg.pinned);
        });
    }, [glob.packageManager]);
    useEffect(() => {
        // TODO: It seems to work but is a hack:
        if (glob.packageManager === undefined || !isAuthenticated || pkg === undefined) {
            return;
        }

        const piReal: SharedRealPackageInfo = (pkg.package.specific as any).real;
        if (piReal.frontendModule[0] !== undefined) { // There is a frontend module.
            glob.packageManager!.getInstalledPackage(BigInt(0)).then(pkg0 => {
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
    }, [glob.packageManager, glob.backend, pkg]);

    // TODO: Ask for confirmation.
    async function uninstall() {
        // TODO
        // let id = await glob.packageManager!.uninstallPackage(BigInt(installationId!));
        // TODO:
        alert("Uninstallation finished");
    }

    function setPinnedHandler(pinned: boolean) {
        if (pkg !== undefined) {
            setPinned(pinned);
            glob.packageManager!.setPinned(BigInt(installationId!), pinned);
        }
    }

    return (
        <>
            <h2>Installation</h2>
            {pkg === undefined ? <p>No such installed package.</p> : <>
                <p>
                    <label>
                        <input type="checkbox" checked={pinned} onChange={event => setPinnedHandler(event.target.checked)}/>{" "}
                        Pin.
                    </label>{" "}
                    <small>Pinned packages cannot be upgraded or removed.</small>
                </p>
                <p><strong>Frontend:</strong> {frontend === undefined ? <em>(none)</em> : <a href={frontend}>here</a>}</p>
                <p><strong>Installation ID:</strong> {installationId}</p>
                <p><strong>Package name:</strong> {pkg.name}</p>
                <p><strong>Package version:</strong> {pkg.version}</p>
                <p><strong>Short description:</strong> {pkg.package.base.shortDescription}</p>
                <p><strong>Long description:</strong> {pkg.package.base.longDescription}</p>
                <Accordion defaultActiveKey={undefined}> {/* FIXME: https://stackoverflow.com/q/79367323/856090 */}
                    <Accordion.Item eventKey="dangerZone" className="bg-red-500">
                        <Accordion.Header
                            onClick={() => setShowDanger(!showDanger)}                           
                        >{showDanger ? "Hide danger zone" : "Show danger zone"}
                        </Accordion.Header>
                        <Accordion.Body style={{background: 'red'}}>
                            <p><Button disabled={!isAuthenticated} onClick={uninstall}>REMOVE THE PACKAGE AND ALL ITS DATA</Button></p>
                        </Accordion.Body>
                    </Accordion.Item>
                </Accordion>
            </>}
        </>
    );
}