import { useState, useEffect, useContext } from 'react';
import Form from 'react-bootstrap/Form';
import Button from 'react-bootstrap/Button';
import { useAuth } from '../../lib/use-auth-client';
import { createActor } from '../../declarations/wallet_backend';
import { GlobalContext } from './state';

export default function Settings() {
    const { agent, ok, principal } = useAuth();
    const [amountAddCheckbox, setAmountAddCheckbox] = useState<number>(10);
    const [amountAddInput, setAmountAddInput] = useState<number>(30);
    const [isLoading, setIsLoading] = useState(false);
    const glob = useContext(GlobalContext);

    const loadSettings = async () => {
        if (!agent || !principal || !glob.walletBackend) return;

        const limits = await glob.walletBackend.getLimitAmounts();
        setAmountAddCheckbox(limits.amountAddCheckbox[0] ?? 10);
        setAmountAddInput(limits.amountAddInput[0] ?? 30);
    };

    useEffect(() => {
        loadSettings();
    }, [agent, principal]);

    const handleSave = async () => {
        if (!agent || !principal || !glob.walletBackend) return;
        
        setIsLoading(true);
        try {
            await glob.walletBackend.setLimitAmounts({
                amountAddCheckbox: [amountAddCheckbox],
                amountAddInput: [amountAddInput]
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
            <Form>
                <Form.Group className="mb-3">
                    <Form.Label>Default Amount for Quick Add (Checkbox)</Form.Label>
                    <Form.Control
                        type="number"
                        value={amountAddCheckbox}
                        onChange={(e) => setAmountAddCheckbox(Number(e.target.value))}
                        min="0"
                        defaultValue={amountAddCheckbox}
                        disabled={!ok}
                    />
                    <Form.Text className="text-muted">
                        Default amount to add when using quick add checkbox
                    </Form.Text>
                </Form.Group>

                <Form.Group className="mb-3">
                    <Form.Label>Default Amount for Manual Input</Form.Label>
                    <Form.Control
                        type="number"
                        value={amountAddInput}
                        onChange={(e) => setAmountAddInput(Number(e.target.value))}
                        min="0"
                        defaultValue={amountAddInput}
                        disabled={!ok}
                    />
                    <Form.Text className="text-muted">
                        Default amount to show in manual input field
                    </Form.Text>
                </Form.Group>

                <Button 
                    variant="primary" 
                    onClick={handleSave}
                    disabled={isLoading}
                >
                    {isLoading ? 'Saving...' : 'Save Settings'}
                </Button>
            </Form>
        </div>
    );
}