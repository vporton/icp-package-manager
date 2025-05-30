import { FormEventHandler, useContext, useEffect, useState } from 'react';
import Button from 'react-bootstrap/Button';
import Form from 'react-bootstrap/Form';
import { createActor as createWalletActor } from '../../declarations/wallet_backend'
import { Wallet } from '../../declarations/wallet_backend/wallet_backend.did'
import { useAuth } from '../../lib/use-auth-client';
import { Check } from 'react-bootstrap-icons';
import { ErrorContext } from '../../lib/ErrorContext';

export default function Settings() {
    const { setError } = useContext(ErrorContext)!;
    const {agent, ok} = useAuth();
    const [amountAddCheckbox, setAmountAddCheckbox] = useState<number | undefined>();
    const [amountAddInput, setAmountAddInput] = useState<number | undefined>();
    const [amountAddCheckboxText, setAmountAddCheckboxText] = useState<string>("");
    const [amountAddInputText, setAmountAddInputText] = useState<string>("");
    const amountAddCheckboxInput = (e: React.FormEvent<HTMLInputElement>) => {
        const value = (e.target as HTMLInputElement).value;
        setAmountAddCheckboxText(value);
        const num = Number(value);
        if (!isNaN(num) && num >= 0 && value !== "") {
            setAmountAddCheckbox(num);
        } else {
            setAmountAddCheckbox(undefined);
        }
    };
    const amountAddInputInput = (e: React.FormEvent<HTMLInputElement>) => {
        const value = (e.target as HTMLInputElement).value;
        setAmountAddInputText(value);
        const num = Number(value);
        if (!isNaN(num) && num >= 0 && value !== "") {
            setAmountAddInput(num);
        } else {
            setAmountAddInput(undefined);
        }
    };
    const params = new URLSearchParams(window.location.search);
    const backendPrincipalStr = params.get('_pm_pkg.backend') ?? process.env.CANISTER_ID_WALLET_BACKEND!;
    const [backend, setBackend] = useState<Wallet | undefined>();
    useEffect(() => {
        if (agent !== undefined) {
            setBackend(createWalletActor(backendPrincipalStr, {agent}));
        }
    }, [agent]);
    useEffect(() => {
        if (backend !== undefined) {
            backend.getLimitAmounts()
                .then((result: {amountAddCheckbox: [number] | [], amountAddInput: [number] | []}) => {
                    setAmountAddCheckbox(result.amountAddCheckbox[0]);
                    setAmountAddInput(result.amountAddInput[0]);
                });
        }
    }, [backend]);
    const [submitted, setSubmitted] = useState<boolean>(false);
    const handleSubmit = async (e: React.MouseEvent<HTMLButtonElement>) => {
        try {
            await backend!.setLimitAmounts({
                amountAddCheckbox: amountAddCheckbox ? [amountAddCheckbox] : [],
                amountAddInput: amountAddInput ? [amountAddInput] : [],
            });
            setSubmitted(true);
            setTimeout(() => setSubmitted(false), 3000);
        }
        catch (e) {
            console.error(e);
            setError((e as object).toString());
        }
    };
    return (
        <>
            <p>This form controls how much confirmations are asked when transferring tokens.</p>
            <p>All amounts are in SDR.</p>
            <Form>
                <Form.Group controlId="amountAddCheckbox">
                    <Form.Label>Starting from this payment amount, add a confirmation checkbox:</Form.Label>
                    <Form.Control
                        type="number"
                        min="0"
                        defaultValue={amountAddCheckbox}
                        disabled={!ok}
                        onInput={amountAddCheckboxInput}
                        isValid={amountAddCheckbox !== undefined || amountAddCheckboxText === ""}
                        isInvalid={amountAddCheckbox === undefined && amountAddCheckboxText !== ""}/>
                </Form.Group>
                <Form.Group controlId="amountAddInput">
                    <Form.Label>Starting from this payment amount, add a verification phrase:</Form.Label>
                    <Form.Control
                        type="number"
                        min="0"
                        defaultValue={amountAddInput}
                        disabled={!ok}
                        onInput={amountAddInputInput}
                        isValid={amountAddInput !== undefined || amountAddInputText === ""}
                        isInvalid={amountAddInput === undefined && amountAddInputText !== ""}/>
                </Form.Group>
                <p style={{marginTop: '1ex'}}>
                    <Button variant="primary" onClick={handleSubmit} disabled={!ok}>
                        Submit
                    </Button>
                    {submitted && <Check color="lightgreen"/>}
                </p>
            </Form>
        </>
    );
}