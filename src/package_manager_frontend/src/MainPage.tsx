import { useEffect, useState } from "react";
import Button from "react-bootstrap/esm/Button";
import Modal from "react-bootstrap/esm/Modal";
import { canisterId, package_manager } from '../../declarations/package_manager';
import { Principal } from "@dfinity/principal";

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
    const packagesToRepair = [ // TODO
        {installationId: 3, name: "fineedit", version: "2.3.5"}
    ];

    const [distroAddShow, setDistroAddShow] = useState(false);
    const [distros, setDistros] = useState<{canister: Principal, name: string}[]>([]);
    const handleClose = () => setDistroAddShow(false);
    const reloadDistros = () => {
        package_manager.getRepositories().then((r) => setDistros(r));
    };
    useEffect(reloadDistros, []);

    return (
        <>
            <h2>Distribution</h2>
            <DistroAdd show={distroAddShow} handleClose={handleClose} handleReload={reloadDistros}/>
            <p>
            Distro:{" "}
            <select>
                {distros.map((entry: {canister: Principal, name: string}) =>
                    <option value={entry.canister.toString()}>{entry.name}</option>
                )}
            </select>{" "}
            <Button>Remove from the list</Button> (doesn't remove installed packages)
            </p>
            <p><Button onClick={() => setDistroAddShow(true)}>Add distro</Button></p>
            <h2>Install</h2>
            <form action="#" onSubmit={() => {}}>
            <label htmlFor="name">Enter package name to install:</label>{" "}
            <input id="name" alt="Name" type="text" />{" "}
            <Button type="submit">Start installation</Button>
            </form>
            {packagesToRepair.length !== 0 ?
            <>
                <h2>Partially Installed</h2>
                <ul className='checklist'>
                {packagesToRepair.map(p =>
                    <li key={p.installationId}>
                    <input type='checkbox'/>{" "}
                    <code>{p.name}</code> {p.version}
                    </li>
                )}
                </ul>
                <p><Button>Install checked</Button> <Button>Delete checked</Button></p>
            </>
            : ""}
        </>
            );
}