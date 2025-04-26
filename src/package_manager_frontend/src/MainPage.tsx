import { ChangeEvent, createRef, useContext, useEffect, useState } from "react";
import Button from "react-bootstrap/esm/Button";
import Modal from "react-bootstrap/esm/Modal";
import { Principal } from "@dfinity/principal";
import { useAuth } from "./auth/use-auth-client";
import { getIsLocal } from "../../lib/state";
import { InstallationId, SharedPackageInfo } from "../../declarations/package_manager/package_manager.did";
import { GlobalContext } from "./state";
import Alert from "react-bootstrap/esm/Alert";
import { createActor as createRepoIndexActor } from "../../declarations/repository";
import { createActor as repoPartitionCreateActor } from '../../declarations/repository';
import { createActor as createBookmarkActor } from "../../declarations/bookmark";
import { myUseNavigate } from "./MyNavigate";
import { Repository } from "../../declarations/repository/repository.did";
import { useParams } from "react-router-dom";

function DistroAdd(props: {show: boolean, handleClose: () => void, handleReload: () => void}) {
    const [name, setName] = useState("(Unnamed)"); // TODO@P3: button to rename it
    const [principal, setPrincipal] = useState(""); // TODO@P3: validate
    const glob = useContext(GlobalContext);
    const handleSave = async () => {
        // TODO@P3: Don't allow to add the same repo twice.
        props.handleClose();
        await glob.packageManager!.addRepository(Principal.fromText(principal), name);
        props.handleReload();
    };
    return (
        <Modal show={props.show} onHide={props.handleClose}>
            <Modal.Dialog>
                <Modal.Header closeButton>
                    <Modal.Title>Add distro</Modal.Title>
                </Modal.Header>
                <Modal.Body>
                    <p>Distro name: <input value={name} onInput={(event: any) => setName((event.target as HTMLInputElement).value)}/></p>
                    <p>Distro principal: <input value={principal} onInput={(event: any) => setPrincipal((event.target as HTMLInputElement).value)}/></p>
                </Modal.Body>
                <Modal.Footer>
                    <Button onClick={props.handleClose} variant="secondary">Close</Button>
                    <Button onClick={handleSave} variant="primary">Save changes</Button>
                </Modal.Footer>
            </Modal.Dialog>
        </Modal>
    );    
}

export default function MainPage() {
    const { agent, defaultAgent, principal, isLoginSuccess } = useInternetIdentity();
    const glob = useContext(GlobalContext);

    const spentFrontendStr = (new URLSearchParams(window.location.search)).get("spentFrontend");
    const spentBackendStr = (new URLSearchParams(window.location.search)).get("spentBackend");
    const spentFrontend = spentFrontendStr === null ? undefined : BigInt(spentFrontendStr);
    const spentBackend = spentBackendStr === null ? undefined : BigInt(spentBackendStr);
    const spentTotal = spentFrontend !== undefined && spentBackend !== undefined ? spentFrontend + spentBackend : undefined;

    const navigate = myUseNavigate();
    const [distroAddShow, setDistroAddShow] = useState(false);
    const [distros, setDistros] = useState<{canister: Principal, name: string}[] | undefined>();
    const [curDistro, setCurDistro] = useState<Principal | undefined>();
    const [distroVersions, setDistroVersions] = useState<string[]>([]);
    const [curDistroVersion, setCurDistroVersion] = useState(0);
    const [packageName, setPackageName] = useState("");
    const [packagesToRepair, setPackagesToRepair] = useState<{
        install: {installationId: bigint, package: SharedPackageInfo}[],
        uninstall: {uninstallationId: bigint, package: SharedPackageInfo}[],
        upgrade: {upgradeId: bigint, package: SharedPackageInfo}[],
    }>();
    const [repairedPackages, setRepairedPackages] = useState<{
        install: bigint[],
        uninstall: bigint[],
        upgrade: bigint[],
    }>({install: [], uninstall: [], upgrade: []});
    const [bookmarked, setBookmarked] = useState(true);
    useEffect(() => {
        if (glob.packageManager !== undefined) {
            const promise = Promise.all([
                glob.packageManager.getHalfInstalledPackages(),
                glob.packageManager.getHalfUninstalledPackages(),
                glob.packageManager.getHalfUpgradedPackages(),
            ]);
            promise.then(([ins, un, up]) => {
                setPackagesToRepair({install: ins, uninstall: un, upgrade: up});
            });
        }
    }, [glob.packageManager]);
    useEffect(() => {
        if (curDistro === undefined || agent === undefined) {
            setDistroVersions([]);
            setCurDistroVersion(0);
            return;
        }
        const repo: Repository = createRepoIndexActor(curDistro!, {agent});
        repo.getDefaultVersions().then(v => {
            setDistroVersions(v.versions);
            setCurDistroVersion(parseInt(v.defaultVersionIndex.toString()));
        });
    }, [curDistro, agent]);
    function doSetCurDistroVersion(i: number) {
        setCurDistroVersion(i);
        const repo = createRepoIndexActor(curDistro!, {agent});
        repo.setDefaultVersions({versions: distroVersions, defaultVersionIndex: BigInt(i)})
            .then(() => {});
    }
    const handleClose = () => setDistroAddShow(false);
    const distroSel = createRef<HTMLSelectElement>();
    const reloadDistros = () => {
        if (glob.packageManager === undefined || !isLoginSuccess) { // TODO@P3: It seems to work but is a hack
            setDistros(undefined);
            return;
        }
        glob.packageManager.getRepositories().then((r) => {
            setDistros(r);
            if (r.length !== 0) {
                setCurDistro(r[0].canister);
            }
        });
    };
    useEffect(reloadDistros, [glob.packageManager, isLoginSuccess]);

    async function deleteChecked() {
        await glob.packageManager!.removeStalled(repairedPackages);
    }
    async function removeRepository() {
        if (confirm("Remove installation media?")) {
            await glob.packageManager!.removeRepository(curDistro!);
            reloadDistros();
        }
    }
    const bookmark = {frontend: glob.frontend!, backend: glob.backend!}; // TODO@P3: Don't try to bookmark, if we are on a custom domain.
    const bookmarkingUrlBase = getIsLocal()
        ? `http://${process.env.CANISTER_ID_BOOTSTRAPPER_FRONTEND!}.localhost:4943/bookmark?`
        : `https://${process.env.CANISTER_ID_BOOTSTRAPPER_FRONTEND!}.icp0.io/bookmark?`;
    const bookmarkingUrl = `${bookmarkingUrlBase}_pm_pkg0.frontend=${bookmark.frontend}&_pm_pkg0.backend=${bookmark.backend}`;
    useEffect(() => {
        const bookmarks = createBookmarkActor(process.env.CANISTER_ID_BOOKMARK!, {agent});
        bookmarks.hasBookmark(bookmark).then((f: boolean) => setBookmarked(f));
    }, []);

    return (
        <>
            {!bookmarked &&
                <>
                    <Alert variant="warning">This page has not been bookmarked in our bookmark system.
                        You are <strong>strongly</strong> recommended to bookmark it, otherwise
                        you may lose this URL and be unable to find it.{" "}
                        <a className="btn btn-primary" href={bookmarkingUrl} target="_blank">Bookmark</a>
                    </Alert>
                    <Alert variant="info">If you lose the URL, you can find it at the bootstrapper site{" "}
                        (provided that you've bookmarked this page).</Alert>
                </>
            }
            {spentTotal !== undefined &&
                <Alert variant="info">
                    You spent total {Number(spentTotal.toString()) / 10**12}T cycles for bootstrapping.
                </Alert>
            }
            <h2>Distribution</h2>
            <DistroAdd show={distroAddShow} handleClose={handleClose} handleReload={reloadDistros}/>
            <p>
                Distro:{" "}
                {distros === undefined ? <em>(not loaded)</em> :
                    <select ref={distroSel} onChange={(event: ChangeEvent<HTMLSelectElement>) => setCurDistro(Principal.fromText((event.target as HTMLSelectElement).value))}>
                        {distros.map((entry: {canister: Principal, name: string}) =>
                            <option key={entry.canister.toString()} value={entry.canister.toString()} onClick={() => setCurDistro(entry.canister)}>{entry.name}</option>
                        )}
                    </select>
                }{" "}
                <Button disabled={distros === undefined} onClick={() => setDistroAddShow(true)}>Add distro</Button>{" "}
                <Button onClick={removeRepository} disabled={!curDistro}>Remove from the list</Button> (doesn't remove installed packages)
            </p>
            <p>
                &#x2514; Default version:{" "}
                <select>
                    {distroVersions.map((v, i) =>
                        <option key={i} value={i} onClick={() => doSetCurDistroVersion(i)}>{v}</option>
                    )}
                </select>
            </p>
            <h2>Install</h2>
            <p>
                <label htmlFor="name">Enter package name to install:</label>{" "}
                <input id="name" alt="Name" type="text" onInput={(event: any) => setPackageName((event.target as HTMLInputElement).value)}/>{" "}
                <Button disabled={!curDistro || packageName === ''} onClick={() => navigate(`/choose-version/${curDistro!.toString()}/${packageName}`)}>Start installation</Button>
            </p>
            {packagesToRepair !== undefined &&
                packagesToRepair.install.length + packagesToRepair.uninstall.length + packagesToRepair.upgrade.length !== 0 ?
            <>
                <h2>Partially Ran Operations</h2>
                <Alert variant="warning">
                    If you recently started an operation, wait for it to complete,{" "}
                    rather than using this form to stop it, because this way you spend some extra money{" "}
                    for duplicate operations on your packages.
                </Alert>
                <h3>Ongoing Installations</h3>
                <ul className='checklist' id="terminateInstall">
                {packagesToRepair.install.map(p =>
                    <li key={p.installationId}>
                        <input
                            type='checkbox'
                            data-value={p.installationId}
                            onClick={event => {
                                const checkedBoxes = document.querySelectorAll('input[id=terminateInstall]:checked');
                                const ids = Array.from(checkedBoxes).map((box: Element, _index, _array) => BigInt(box.getAttribute('data-value')!));
                                setRepairedPackages({...repairedPackages, install: ids});
                            } }/>{" "}
                        <code>{p.package.base.name}</code> {p.package.base.version}
                    </li>
                )}
                </ul>
                <h3>Ongoing Uninstallations</h3>
                <ul className='checklist' id="terminateUninstall">
                {packagesToRepair.uninstall.map(p =>
                    <li key={p.uninstallationId}>
                        <input
                            type='checkbox'
                            data-value={p.uninstallationId}
                            onClick={event => {
                                const checkedBoxes = document.querySelectorAll('input[id=terminateUninstall]:checked');
                                const ids = Array.from(checkedBoxes).map((box: Element, _index, _array) => BigInt(box.getAttribute('data-value')!));
                                setRepairedPackages({...repairedPackages, uninstall: ids});
                            } }/>{" "}
                        <code>{p.package.base.name}</code> {p.package.base.version}
                    </li>
                )}
                </ul>
                <h3>Ongoing Upgrades</h3>
                <ul className='checklist' id="terminateUpgrade">
                {packagesToRepair.upgrade.map(p =>
                    <li key={p.upgradeId}>
                        <input
                            type='checkbox'
                            data-value={p.upgradeId}
                            onClick={event => {
                                const checkedBoxes = document.querySelectorAll('input[id=terminateUpgrade]:checked');
                                const ids = Array.from(checkedBoxes).map((box: Element, _index, _array) => BigInt(box.getAttribute('data-value')!));
                                setRepairedPackages({...repairedPackages, upgrade: ids});
                            } }/>{" "}
                        <code>{p.package.base.name}</code> {p.package.base.version}
                    </li>
                )}
                </ul>
                <p><Button onClick={deleteChecked}>Stop checked processes</Button> (money not refunded!)</p>
            </>
            : ""}
        </>
    );
}