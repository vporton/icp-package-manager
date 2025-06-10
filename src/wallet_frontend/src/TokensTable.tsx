import { useState, useEffect, forwardRef, useImperativeHandle, useContext } from 'react';
import Button from 'react-bootstrap/Button';
import Modal from 'react-bootstrap/Modal';
import Form from 'react-bootstrap/Form';
import { useAuth } from '../../lib/use-auth-client';
import { createActor } from '../../declarations/wallet_backend';
import { Principal } from '@dfinity/principal';
import { GlobalContext } from './state';

interface Token {
    symbol: string;
    name: string;
    canisterId: Principal | undefined;
}

export interface TokensTableRef {
    setShowAddModal: (show: boolean) => void;
}

const TokensTable = forwardRef<TokensTableRef>((props, ref) => {
    const glob = useContext(GlobalContext);
    const { agent, principal } = useAuth();
    const [tokens, setTokens] = useState<Token[]>([]);
    const [showAddModal, setShowAddModal] = useState(false);
    const [newToken, setNewToken] = useState<Token>({
        symbol: '',
        name: '',
        canisterId: undefined,
    });

    useImperativeHandle(ref, () => ({
        setShowAddModal: (show: boolean) => setShowAddModal(show)
    }));

    const loadTokens = async () => {
        if (!agent || !principal || !glob.walletBackend) return;
        
        const backendTokens = await glob.walletBackend.getTokens();
        setTokens(backendTokens.map((t: Token) => ({
            symbol: t.symbol,
            name: t.name,
            canisterId: t.canisterId!
        })));
    };

    useEffect(() => {
        loadTokens();
    }, [agent, principal]);

    const handleAddToken = async () => {
        if (!agent || !principal || !glob.walletBackend) return;
        
        await glob.walletBackend.addToken({
            symbol: newToken.symbol,
            name: newToken.name,
            canisterId: newToken.canisterId!,
        });
        
        setShowAddModal(false);
        loadTokens();
    };

    return (
        <>
            <table className="table">
                <thead>
                    <tr>
                        <th>Symbol</th>
                        <th>Name</th>
                        <th>Balance</th>
                        <th>Actions</th>
                    </tr>
                </thead>
                <tbody>
                    {tokens.map((token, index) => (
                        <tr key={index}>
                            <td>{token.symbol}</td>
                            <td>{token.name}</td>
                            <td>TODO</td>
                            <td>
                                <Button variant="primary" size="sm" className="me-2">Send</Button>
                                <Button variant="success" size="sm" className="me-2">Receive</Button>
                                <Button variant="info" size="sm">Manage</Button>
                            </td>
                        </tr>
                    ))}
                </tbody>
            </table>

            <Modal show={showAddModal} onHide={() => setShowAddModal(false)}>
                <Modal.Header closeButton>
                    <Modal.Title>Add New Token</Modal.Title>
                </Modal.Header>
                <Modal.Body>
                    <Form>
                        <Form.Group className="mb-3">
                            <Form.Label>Canister ID (Optional)</Form.Label>
                            <Form.Control
                                type="text"
                                onChange={(e) => setNewToken(newToken)}
                                placeholder="e.g. rrkah-fqaaa-aaaaa-aaaaq-cai"
                            />
                        </Form.Group>
                    </Form>
                </Modal.Body>
                <Modal.Footer>
                    <Button variant="secondary" onClick={() => setShowAddModal(false)}>
                        Cancel
                    </Button>
                    <Button variant="primary" onClick={handleAddToken}>
                        Add Token
                    </Button>
                </Modal.Footer>
            </Modal>
        </>
    );
});

export default TokensTable;