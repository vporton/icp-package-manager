import { ChangeEvent, createRef, useEffect, useState } from "react";
import Button from "react-bootstrap/esm/Button";
import Modal from "react-bootstrap/esm/Modal";
import { canisterId, package_manager } from '../../declarations/package_manager';
import { Principal } from "@dfinity/principal";
import { useNavigate } from "react-router-dom";
import { useAuth } from "./auth/use-auth-client";
import { InstallationId } from "../../declarations/package_manager/package_manager.did";

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

    const navigate = useNavigate();
    const [distroAddShow, setDistroAddShow] = useState(false);
    const [distros, setDistros] = useState<{canister: Principal, name: string}[]>([]);
    const [curDistro, setCurDistro] = useState<Principal | undefined>();
    const [packageName, setPackageName] = useState("");
    const [packagesToRepair, setPackagesToRepair] = useState<{installationId: bigint, name: string, version: string, packageCanister: Principal}[]>();
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
            setCurDistro(r[0].canister);
        });
    };
    useEffect(reloadDistros, []);

    const [checkedHalfInstalled, setCheckedHalfInstalled] = useState<Set<InstallationId>>();
    async function installChecked() {
        for (const p of packagesToRepair!) {
            if (checkedHalfInstalled?.has(p.installationId)) {
                await package_manager.installPackage({
                    packageName: p.name,
                    version: p.version,
                    canister: p.packageCanister,
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

    return (
        <>
            <h2>Distribution</h2>
            <DistroAdd show={distroAddShow} handleClose={handleClose} handleReload={reloadDistros}/>
            <p>
            Distro:{" "}
            <select ref={distroSel} onChange={(event: ChangeEvent<HTMLSelectElement>) => setCurDistro(Principal.fromText((event.target as HTMLSelectElement).value))}>
                {distros.map((entry: {canister: Principal, name: string}) =>
                    <option value={entry.canister.toString()} onClick={() => setCurDistro(entry.canister)}>{entry.name}</option>
                )}
            </select>{" "}
            <Button>Remove from the list</Button> (doesn't remove installed packages)
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