import { useState, useEffect, useContext } from 'react';
import Alert from 'react-bootstrap/Alert';
import Form from 'react-bootstrap/Form';
import Button from 'react-bootstrap/Button';
import { useAuth } from '../../lib/use-auth-client';
import { GlobalContext } from './state';

export default function Settings() {
    const { agent, ok, principal } = useAuth();
    const [amountAddCheckbox, setAmountAddCheckbox] = useState<number | undefined>();
    const [amountAddInput, setAmountAddInput] = useState<number | undefined>();
    const [isLoading, setIsLoading] = useState(false);
    const glob = useContext(GlobalContext);

    const loadSettings = async () => {
        if (!agent || !principal || !glob.walletBackend) return;

        const limits = await glob.walletBackend.getLimitAmounts();
        setAmountAddCheckbox(limits.amountAddCheckbox[0] ?? 10); // FIXME@P3: duplicate code
        setAmountAddInput(limits.amountAddInput[0] ?? 30);
    };

    function doSetAmountAddCheckbox(e: HTMLInputElement) {
        setAmountAddCheckbox(e.value === "" ? undefined : Number(e.value)) 
    }
    function doSetAmountAddInput(e: HTMLInputElement) {
        setAmountAddInput(e.value === "" ? undefined : Number(e.value)) 
    }

    useEffect(() => {
        loadSettings();
    }, [agent, principal]);

    const handleSave = async () => {
        if (!agent || !principal || !glob.walletBackend) return;
        
        setIsLoading(true);
        try {
            await glob.walletBackend.setLimitAmounts({
                amountAddCheckbox: amountAddCheckbox === undefined ? [] : [amountAddCheckbox],
                amountAddInput: amountAddInput === undefined ? [] : [amountAddInput],
            });
        } catch (error) {
            console.error('Failed to save settings:', error);
        } finally {
            setIsLoading(false);
        }
    };

    return (
        <div className="settings-container">
            <h3>Transaction Settings</h3>
            <Alert variant='danger'>These settings are not yet honored in the current version.</Alert>
            <Form>
                <Form.Group className="mb-3">
                    <Form.Label>Payment amount that requires checkbox confirmation</Form.Label>
                    <Form.Control
                        type="number"
                        onInput={(e) => doSetAmountAddCheckbox(e.target as HTMLInputElement)}
                        min="0"
                        defaultValue={amountAddCheckbox === undefined ? "" : amountAddCheckbox}
                        disabled={!ok}
                        isInvalid={amountAddCheckbox !== undefined && amountAddCheckbox < 0}
                    />
                    <Form.Text className="text-muted">
                        amount in XDR
                    </Form.Text>
                </Form.Group>

                <Form.Group className="mb-3">
                    <Form.Label>Payment amount that requires input confirmation</Form.Label>
                    <Form.Control
                        type="number"
                        onInput={(e) => doSetAmountAddInput(e.target as HTMLInputElement)}
                        min="0"
                        defaultValue={amountAddInput === undefined ? "" : amountAddInput}
                        disabled={!ok}
                        isInvalid={amountAddInput !== undefined && amountAddInput < 0}
                    />
                    <Form.Text className="text-muted">
                        amount in XDR
                    </Form.Text>
                </Form.Group>

                <Button 
                    variant="primary" 
                    onClick={handleSave}
                    disabled={isLoading ||
                        (amountAddCheckbox !== undefined && amountAddCheckbox < 0) || (amountAddInput !== undefined && amountAddInput < 0)
                    }>
                    {isLoading ? 'Saving...' : 'Save Settings'}
                </Button>
            </Form>
        </div>
    );
}