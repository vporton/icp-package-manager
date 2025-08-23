import { Principal } from "@dfinity/principal";
import DisplayPrincipal from "../../lib/DisplayPrincipal";
import EditPrincipal from "../../lib/EditPrincipal";
import { useContext, useEffect, useState } from "react";
import { package_manager } from "../../declarations/package_manager";
import { GlobalContext } from "./state";
import Button from "react-bootstrap/Button";
import { assert } from "console";

export default function Settings() {
    const {packageManager} = useContext(GlobalContext);
    const [additionalOwners, setAdditionalOwners] = useState<Principal[] | undefined>([]);
    const [newPrincipal, setNewPrincipal] = useState<Principal | undefined>();
    const [newPrincipalError, setNewPrincipalError] = useState(false);

    function reloadAdditionalOwners() {
        packageManager!.getAdditionalOwners().then(setAdditionalOwners);
    }

    function removeAdditionalOwner(principal: Principal) {
        if (packageManager !== undefined) {
            packageManager.removeAdditionalOwner(principal).then(reloadAdditionalOwners);
        }
    }

    function addAdditionalOwner() {
        if (packageManager !== undefined && newPrincipal !== undefined) {
            packageManager.addAdditionalOwner(newPrincipal).then(reloadAdditionalOwners);
            setNewPrincipal(undefined); // FIXME@P3: It should reset the input field.
            setNewPrincipalError(false); // TODO@P3: Should be removed, but now needed as a hack.
        }
    }

    useEffect(() => {
        if (packageManager !== undefined) {
            reloadAdditionalOwners();
        }
    }, [packageManager]);

    return (
        <>
            <h2>Settings</h2>
            <h3>Additional controlling principals:</h3>
            {additionalOwners === undefined ? <p>Loading...</p> :
            <ul>
                {additionalOwners.map((principal) => (
                    <li key={principal.toString()}>
                        <DisplayPrincipal value={principal}/>{" "}
                        <Button onClick={() => removeAdditionalOwner(principal)}>Remove</Button>
                    </li>
                ))}
            </ul>}
            <p>
                <EditPrincipal onInput={setNewPrincipal} onSetError={setNewPrincipalError} />{" "}
                <Button
                    onClick={addAdditionalOwner} disabled={additionalOwners === undefined || newPrincipal === undefined || newPrincipalError}
                >
                    Add
                </Button>
            </p>
        </>
    );
}