import { useState, useContext } from 'react';
import Modal from 'react-bootstrap/Modal';
import Button from 'react-bootstrap/Button';
import Form from 'react-bootstrap/Form';
import { GlobalContext } from './state';
import { Principal } from '@dfinity/principal';

interface AddTokenDialogProps {
    show: boolean;
    onHide: () => void;
    onTokenAdded: () => void;
}

export default function AddTokenDialog({ show, onHide, onTokenAdded }: AddTokenDialogProps) {
    const { walletBackend } = useContext(GlobalContext);
    const [symbol, setSymbol] = useState('');
    const [name, setName] = useState('');
    const [canisterId, setCanisterId] = useState('');
    const [archiveCanisterId, setArchiveCanisterId] = useState('');
    const [error, setError] = useState('');

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        setError('');

        try {
            // Validate inputs
            if (!symbol || !name || !canisterId) {
                setError('Symbol, name and canister ID are required');
                return;
            }

            if (!walletBackend) {
                setError('Wallet backend not initialized');
                return;
            }

            // Add token to backend
            await walletBackend.addToken({
                symbol,
                name,
                canisterId: Principal.fromText(canisterId),
                archiveCanisterId: archiveCanisterId ? [Principal.fromText(archiveCanisterId)] : []
            });

            // Reset form and close dialog
            setSymbol('');
            setName('');
            setCanisterId('');
            setArchiveCanisterId('');
            onTokenAdded();
            onHide();
        } catch (err) {
            setError(err instanceof Error ? err.message : 'Failed to add token');
        }
    };

    return (
        <Modal show={show} onHide={onHide}>
            <Modal.Header closeButton>
                <Modal.Title>Add New Token</Modal.Title>
            </Modal.Header>
            <Form onSubmit={handleSubmit}>
                <Modal.Body>
                    {error && <div className="alert alert-danger">{error}</div>}
                    <Form.Group className="mb-3">
                        <Form.Label>Symbol</Form.Label>
                        <Form.Control
                            type="text"
                            value={symbol}
                            onChange={(e) => setSymbol(e.target.value)}
                            placeholder="e.g. ICP"
                            required
                        />
                    </Form.Group>
                    <Form.Group className="mb-3">
                        <Form.Label>Name</Form.Label>
                        <Form.Control
                            type="text"
                            value={name}
                            onChange={(e) => setName(e.target.value)}
                            placeholder="e.g. Internet Computer"
                            required
                        />
                    </Form.Group>
                    <Form.Group className="mb-3">
                        <Form.Label>Canister ID</Form.Label>
                        <Form.Control
                            type="text"
                            value={canisterId}
                            onChange={(e) => setCanisterId(e.target.value)}
                            placeholder="e.g. ryjl3-tyaaa-aaaaa-aaaba-cai"
                            required
                        />
                    </Form.Group>
                    <Form.Group className="mb-3">
                        <Form.Label>Archive Canister ID (Optional)</Form.Label>
                        <Form.Control
                            type="text"
                            value={archiveCanisterId}
                            onChange={(e) => setArchiveCanisterId(e.target.value)}
                            placeholder="e.g. qoctq-giaaa-aaaaa-aaaea-cai"
                        />
                    </Form.Group>
                </Modal.Body>
                <Modal.Footer>
                    <Button variant="secondary" onClick={onHide}>
                        Cancel
                    </Button>
                    <Button variant="primary" type="submit">
                        Add Token
                    </Button>
                </Modal.Footer>
            </Form>
        </Modal>
    );
} 