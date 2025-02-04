import { ChangeEvent, createRef, useContext, useEffect, useState } from "react";
import Button from "react-bootstrap/esm/Button";
import Modal from "react-bootstrap/esm/Modal";
import { Principal } from "@dfinity/principal";
import { useNavigate } from "react-router-dom";
import { getIsLocal, useAuth } from "./auth/use-auth-client";
import { InstallationId, RepositoryIndexRO } from "../../declarations/package_manager/package_manager.did";
import { GlobalContext } from "./state";
import Alert from "react-bootstrap/esm/Alert";
import { createActor as createRepoIndexActor } from "../../declarations/Repository";
import { createActor as repoPartitionCreateActor } from '../../declarations/Repository';
import { createActor as createBookmarkActor } from "../../declarations/bookmark";
import { myUseNavigate } from "./MyNavigate";
import { Repository } from "../../declarations/Repository/Repository.did";

function DistroAdd(props: {show: boolean, handleClose: () => void, handleReload: () => void}) {
    const [name, setName] = useState("(Unnamed)"); // TODO: button to rename it
    const [principal, setPrincipal] = useState(""); // TODO: validate
    const glob = useContext(GlobalContext);
    const handleSave = async () => {
        // TODO: Don't allow to add the same repo twice.
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
    const { agent, defaultAgent, principal, isAuthenticated } = useAuth();
    const glob = useContext(GlobalContext);

    const navigate = myUseNavigate();
    const [distroAddShow, setDistroAddShow] = useState(false);
    const [distros, setDistros] = useState<{canister: Principal, name: string}[] | undefined>();
    const [curDistro, setCurDistro] = useState<Principal | undefined>();
    const [distroVersions, setDistroVersions] = useState<string[]>([]);
    const [curDistroVersion, setCurDistroVersion] = useState(0);
    const [packageName, setPackageName] = useState("");
    const [packagesToRepair, setPackagesToRepair] = useState<{installationId: bigint, name: string, version: string, packageRepoCanister: Principal}[]>();
    const [bookmarked, setBookmarked] = useState(true);
    useEffect(() => {
        if (glob.packageManager !== undefined) {
            glob.packageManager.getHalfInstalledPackages().then(h => {
                setPackagesToRepair(h);
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
        if (glob.packageManager === undefined || !isAuthenticated) { // TODO: It seems to work but is a hack
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
    useEffect(reloadDistros, [glob.packageManager, glob.backend]);

    const [checkedHalfInstalled, setCheckedHalfInstalled] = useState<Set<InstallationId>>();
    async function installChecked() {
        // TODO: hack
        // TODO
        // for (const p of packagesToRepair!) {
        //     if (checkedHalfInstalled?.has(p.installationId)) {
        //         await glob.packageManager!.installPackage({
        //             repo: index,
        //             packageName: p.name,
        //             version: p.version,
        //             user: principal!,
        //             afterInstallCallback: [],
        //         });
        //     }
        // }
    }
    async function deleteChecked() {
        for (const p of packagesToRepair!) {
            // TODO
            // if (checkedHalfInstalled?.has(p.installationId)) {
            //     await glob.packageManager!.uninstallPackage(BigInt(p.installationId));
            // }
        }
    }
    async function removeRepository() {
        if (confirm("Remove installation media?")) {
            await glob.packageManager!.removeRepository(curDistro!);
            reloadDistros();
        }
    }
    const bookmark = {frontend: glob.frontend!, backend: glob.backend!};
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
            {packagesToRepair !== undefined && packagesToRepair.length !== 0 ?
            <>
                <h2>Partially Installed</h2>
                <Alert variant="warning">
                    If you recently started an operation, wait for it to complete,{" "}
                    rather than using this form to force it, because this way you spend some extra money{" "}
                    for duplicate operations on your packages.
                </Alert>
                <ul className='checklist'>
                {packagesToRepair.map(p =>
                    <li key={p.installationId}>
                    <input
                        type='checkbox'
                        onClick={event => {
                            (event.target as HTMLInputElement).checked ? checkedHalfInstalled!.add(p.installationId) : checkedHalfInstalled!.delete(p.installationId);
                            setCheckedHalfInstalled(checkedHalfInstalled);
                        } }/>{" "}
                    <code>{p.name}</code> {p.version}
                    </li>
                )}
                </ul>
                <p><Button onClick={installChecked}>Install checked</Button> <Button onClick={deleteChecked}>Delete checked</Button></p>
            </>
            : ""}
        </>
    );
}