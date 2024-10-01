import { ChangeEvent, createRef, useContext, useEffect, useState } from "react";
import Button from "react-bootstrap/esm/Button";
import Modal from "react-bootstrap/esm/Modal";
import { canisterId, package_manager } from '../../declarations/package_manager';
import { Principal } from "@dfinity/principal";
import { useNavigate } from "react-router-dom";
import { getIsLocal, useAuth } from "./auth/use-auth-client";
import { InstallationId } from "../../declarations/package_manager/package_manager.did";
import { GlobalContext } from "./state";
import Alert from "react-bootstrap/esm/Alert";
import { RepositoryIndex } from "../../declarations/RepositoryIndex";
import { createActor as repoPartitionCreateActor } from '../../declarations/RepositoryPartition';
import { createActor as createBookmarkActor } from "../../declarations/bookmark";

function DistroAdd(props: {show: boolean, handleClose: () => void, handleReload: () => void}) {
    const [name, setName] = useState("TODO");
    const [principal, setPrincipal] = useState(""); // TODO: validate
    const handleSave = async () => {
        // TODO: Don't allow to add the same repo twice.
        props.handleClose();
        await package_manager.addRepository(Principal.fromText(principal), name);
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
    const { defaultAgent } = useAuth();
    const glob = useContext(GlobalContext);

    const navigate = useNavigate();
    const [distroAddShow, setDistroAddShow] = useState(false);
    const [distros, setDistros] = useState<{canister: Principal, name: string}[]>([]);
    const [curDistro, setCurDistro] = useState<Principal | undefined>();
    const [packageName, setPackageName] = useState("");
    const [packagesToRepair, setPackagesToRepair] = useState<{installationId: bigint, name: string, version: string, packageCanister: Principal}[]>();
    const [bookmarked, setBookmarked] = useState(true);
    useEffect(() => {
        package_manager.getHalfInstalledPackages().then(h => {
            setPackagesToRepair(h);
        });
    });
    const handleClose = () => setDistroAddShow(false);
    const distroSel = createRef<HTMLSelectElement>();
    const reloadDistros = () => {
        package_manager.getRepositories().then((r) => {
            setDistros(r);
            if (r.length !== 0) {
                setCurDistro(r[0].canister);
            }
        });
    };
    useEffect(reloadDistros, []);

    const [checkedHalfInstalled, setCheckedHalfInstalled] = useState<Set<InstallationId>>();
        async function installChecked() {
        // TODO: hack
        const parts = (await RepositoryIndex.getCanistersByPK('main'))
            .map(s => Principal.fromText(s))
        const foundParts = await Promise.all(parts.map(part => {
            try {
                const part2 = repoPartitionCreateActor(part, {agent: defaultAgent});
                part2.getPackage("icpack", "0.0.1"); // TODO: Don't hardcode.
                return part;
            }
            catch(_) { // TODO: Check error.
                return null;
            }
        }));
        const firstPart = foundParts.filter(v => v !== null)[0];
        console.log("firstPart3", firstPart.toText()); // TODO: Remove.

        for (const p of packagesToRepair!) {
            if (checkedHalfInstalled?.has(p.installationId)) {
                await package_manager.installPackage({
                    packageName: p.name,
                    version: p.version,
                    canister: p.packageCanister,
                    repo: firstPart,
                });
            }
        }
    }
    async function deleteChecked() {
        for (const p of packagesToRepair!) {
            if (checkedHalfInstalled?.has(p.installationId)) {
                await package_manager.uninstallPackage(BigInt(p.installationId));
            }
        }
    }
    async function removeRepository() {
        if (confirm("Remove installation media?")) {
            await package_manager.removeRepository(curDistro!);
            reloadDistros();
        }
    }
    const bookmark = {frontend: glob.frontend!, backend: glob.backend!};
    const bookmarkingUrlBase = getIsLocal() ? `http://localhost:4943?canisterId=${process.env.CANISTER_ID_BOOKMARK!}&` : `https://${process.env.CANISTER_ID_BOOKMARK!}.icp0.io?`;
    const bookmarkingUrl = `${bookmarkingUrlBase}frontend=${bookmark.frontend}&backend=${bookmark.backend}`;
    useEffect(() => {
        const bookmarks = createBookmarkActor(process.env.CANISTER_ID_BOOKMARK!, {agent: defaultAgent});
        bookmarks.hasBookmark(bookmark).then((f: boolean) => setBookmarked(f));
        
    }, []);

    return (
        <>
            {!bookmarked &&
                <>
                    <Alert variant="warning">This page was not bookmarked in our bookmark system.
                        You are <strong>strongly</strong> recommended to bookmark it, otherwise
                        you may lose this URL and be unable to find it.
                        <a className="btn" href={bookmarkingUrl} target="_blank">Bookmark</a>
                    </Alert>
                    <Alert variant="info">If you lose the URL, you can find it at the bootstrapper site.</Alert>
                </>
            }
            <h2>Distribution</h2>
            <DistroAdd show={distroAddShow} handleClose={handleClose} handleReload={reloadDistros}/>
            <p>
            Distro:{" "}
            <select ref={distroSel} onChange={(event: ChangeEvent<HTMLSelectElement>) => setCurDistro(Principal.fromText((event.target as HTMLSelectElement).value))}>
                {distros.map((entry: {canister: Principal, name: string}) =>
                    <option key={entry.canister.toString()} value={entry.canister.toString()} onClick={() => setCurDistro(entry.canister)}>{entry.name}</option>
                )}
            </select>{" "}
            <Button onClick={removeRepository} disabled={!curDistro}>Remove from the list</Button> (doesn't remove installed packages)
            </p>
            <p><Button onClick={() => setDistroAddShow(true)}>Add distro</Button></p>
            <h2>Install</h2>
            <label htmlFor="name">Enter package name to install:</label>{" "}
            <input id="name" alt="Name" type="text" onInput={(event: any) => setPackageName((event.target as HTMLInputElement).value)}/>{" "}
            <Button disabled={!curDistro || packageName === ''} onClick={() => navigate(`/choose-version/${curDistro!.toString()}/${packageName}`)}>Start installation</Button>
            {packagesToRepair !== undefined && packagesToRepair.length !== 0 ?
            <>
                <h2>Partially Installed</h2>
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