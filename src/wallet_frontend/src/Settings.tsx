import { FormEventHandler, useState } from 'react';
import Button from 'react-bootstrap/Button';
import Form from 'react-bootstrap/Form';
// import FormControlElement from 'react-bootstrap/FormControlElement';

export default function Settings() {
    const [numberAddCheckbox, setNumberAddCheckbox] = useState<number | undefined>();
    const [numberAddInput, setNumberAddInput] = useState<number | undefined>();
    const [numberAddCheckboxText, setNumberAddCheckboxText] = useState<string>("");
    const [numberAddInputText, setNumberAddInputText] = useState<string>("");
    const numberAddCheckboxInput = (e: React.FormEvent<HTMLInputElement>) => {
        const value = (e.target as HTMLInputElement).value;
        setNumberAddCheckboxText(value);
        const num = Number(value);
        if (!isNaN(num) && num >= 0 && value !== "") {
            setNumberAddCheckbox(num);
        } else {
            setNumberAddCheckbox(undefined);
        }
    };
    const numberAddInputInput = (e: React.FormEvent<HTMLInputElement>) => {
        const value = (e.target as HTMLInputElement).value;
        setNumberAddInputText(value);
        const num = Number(value);
        if (!isNaN(num) && num >= 0 && value !== "") {
            setNumberAddInput(num);
        } else {
            setNumberAddInput(undefined);
        }
    };
    return (
        <>
            <p>This form controls how much confirmations are asked when transferring tokens.</p>
            <p>All amounts are in SDR.</p>
            <Form>
                <Form.Group controlId="numberAddCheckbox">
                    <Form.Label>Starting from this amount, add a confirmation checkbox:</Form.Label>
                    <Form.Control
                        type="number"
                        min="0"
                        onInput={numberAddCheckboxInput}
                        isValid={numberAddCheckbox !== undefined || numberAddCheckboxText === ""}
                        isInvalid={numberAddCheckbox === undefined && numberAddCheckboxText !== ""}/>
                </Form.Group>
                <Form.Group controlId="numberAddInput">
                    <Form.Label>Starting from this amount, add a verification phrase:</Form.Label>
                    <Form.Control
                        type="number"
                        min="0"
                        onInput={numberAddInputInput}
                        isValid={numberAddInput !== undefined || numberAddInputText === ""}
                        isInvalid={numberAddInput === undefined && numberAddInputText !== ""}/>
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