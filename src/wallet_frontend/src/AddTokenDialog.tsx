import { useState, useContext, useEffect } from 'react';
import Modal from 'react-bootstrap/Modal';
import Button from 'react-bootstrap/Button';
import Form from 'react-bootstrap/Form';
import { GlobalContext } from './state';
import { Principal } from '@dfinity/principal';
import { createActor as createTokenActor } from '../../declarations/nns-ledger';
import { useAuth } from '../../lib/use-auth-client';

interface AddTokenDialogProps {
    show: boolean;
    onHide: () => void;
    onTokenAdded: () => void;
}

interface TokenInfo {
    symbol: string;
    name: string;
}

export default function AddTokenDialog({ show, onHide, onTokenAdded }: AddTokenDialogProps) {
    const { walletBackend } = useContext(GlobalContext);
    const { defaultAgent } = useAuth();
    const [canisterId, setCanisterId] = useState('');
    const [archiveCanisterId, setArchiveCanisterId] = useState('');
    const [error, setError] = useState('');
    const [tokenInfo, setTokenInfo] = useState<TokenInfo | null>(null);
    const [isLoading, setIsLoading] = useState(false);

    // Reset state when dialog is closed
    useEffect(() => {
        if (!show) {
            setCanisterId('');
            setArchiveCanisterId('');
            setError('');
            setTokenInfo(null);
        }
    }, [show]);

    // Fetch token info when canister ID changes
    useEffect(() => {
        const fetchTokenInfo = async () => {
            if (!canisterId || !defaultAgent) {
                setTokenInfo(null);
                return;
            }

            try {
                setIsLoading(true);
                setError('');
                const tokenActor = createTokenActor(Principal.fromText(canisterId), { agent: defaultAgent });
                const [symbol, name] = await Promise.all([
                    tokenActor.icrc1_symbol(),
                    tokenActor.icrc1_name()
                ]);
                setTokenInfo({ symbol, name });
            } catch (err) {
                setError('Failed to fetch token information. Please check the canister ID.');
                setTokenInfo(null);
            } finally {
                setIsLoading(false);
            }
        };

        fetchTokenInfo();
    }, [canisterId, defaultAgent]);

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        setError('');

        try {
            // Validate inputs
            if (!canisterId || !tokenInfo) {
                setError('Valid canister ID is required');
                return;
            }

            if (!walletBackend) {
                setError('Wallet backend not initialized');
                return;
            }

            // Add token to backend
            await walletBackend.addToken({
                symbol: tokenInfo.symbol,
                name: tokenInfo.name,
                canisterId: Principal.fromText(canisterId),
                archiveCanisterId: archiveCanisterId ? [Principal.fromText(archiveCanisterId)] : []
            });

            // Reset form and close dialog
            setCanisterId('');
            setArchiveCanisterId('');
            setTokenInfo(null);
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

                    {isLoading && (
                        <div className="text-center">
                            <div className="spinner-border" role="status">
                                <span className="visually-hidden">Loading...</span>
                            </div>
                        </div>
                    )}

                    {tokenInfo && !isLoading && (
                        <div className="alert alert-info">
                            <p><strong>Symbol:</strong> {tokenInfo.symbol}</p>
                            <p><strong>Name:</strong> {tokenInfo.name}</p>
                        </div>
                    )}
                </Modal.Body>
                <Modal.Footer>
                    <Button variant="secondary" onClick={onHide}>
                        Cancel
                    </Button>
                    <Button 
                        variant="primary" 
                        type="submit"
                        disabled={!tokenInfo || isLoading}
                    >
                        Add Token
                    </Button>
                </Modal.Footer>
            </Form>
        </Modal>
    );
} 