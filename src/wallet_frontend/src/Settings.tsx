import { FormEventHandler, useState } from 'react';
import Button from 'react-bootstrap/Button';
import Form from 'react-bootstrap/Form';
// import FormControlElement from 'react-bootstrap/FormControlElement';

export default function Settings() {
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
    return (
        <>
            <p>This form controls how much confirmations are asked when transferring tokens.</p>
            <p>All amounts are in SDR.</p>
            <Form>
                <Form.Group controlId="amountAddCheckbox">
                    <Form.Label>Starting from this amount, add a confirmation checkbox:</Form.Label>
                    <Form.Control
                        type="number"
                        min="0"
                        onInput={amountAddCheckboxInput}
                        isValid={amountAddCheckbox !== undefined || amountAddCheckboxText === ""}
                        isInvalid={amountAddCheckbox === undefined && amountAddCheckboxText !== ""}/>
                </Form.Group>
                <Form.Group controlId="amountAddInput">
                    <Form.Label>Starting from this amount, add a verification phrase:</Form.Label>
                    <Form.Control
                        type="number"
                        min="0"
                        onInput={amountAddInputInput}
                        isValid={amountAddInput !== undefined || amountAddInputText === ""}
                        isInvalid={amountAddInput === undefined && amountAddInputText !== ""}/>
                </Form.Group>
                <p style={{marginTop: '1ex'}}>
                    <Button
                        variant="primary"
                    >
                        Submit
                    </Button>
                </p>
            </Form>
        </>
    );
}