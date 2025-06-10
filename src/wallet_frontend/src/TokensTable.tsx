import { useState, useEffect, forwardRef, useImperativeHandle, useContext } from 'react';
import Button from 'react-bootstrap/Button';
import Modal from 'react-bootstrap/Modal';
import Form from 'react-bootstrap/Form';
import { useAuth } from '../../lib/use-auth-client';
import { createActor } from '../../declarations/wallet_backend';
import { Principal } from '@dfinity/principal';
import { GlobalContext } from './state';
import { ErrorContext } from '../../lib/ErrorContext';
import OverlayTrigger from 'react-bootstrap/OverlayTrigger';
import Tooltip from 'react-bootstrap/Tooltip';

interface Token {
    symbol: string;
    name: string;
    canisterId: Principal | undefined;
    archiveCanisterId?: Principal;
}

export interface TokensTableRef {
    setShowAddModal: (show: boolean) => void;
}

const TokensTable = forwardRef<TokensTableRef>((props, ref) => {
    const glob = useContext(GlobalContext);
    const { setError } = useContext(ErrorContext)!;
    const { agent, principal } = useAuth();
    const [tokens, setTokens] = useState<Token[]>([]);
    const [showAddModal, setShowAddModal] = useState(false);
    const [showSendModal, setShowSendModal] = useState(false);
    const [showReceiveModal, setShowReceiveModal] = useState(false);
    const [showManageModal, setShowManageModal] = useState(false);
    const [selectedToken, setSelectedToken] = useState<Token | null>(null);
    const [sendAmount, setSendAmount] = useState('');
    const [sendTo, setSendTo] = useState('');
    const [archiveCanisterId, setArchiveCanisterId] = useState('');
    const [copied, setCopied] = useState(false);
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
            canisterId: t.canisterId!,
            archiveCanisterId: t.archiveCanisterId
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

    const handleSend = async () => {
        if (!selectedToken?.canisterId || !sendAmount || !sendTo) return;
        
        try {
            const tokenCanister = createActor(selectedToken.canisterId.toString(), { agent });
            await tokenCanister.icrc1_transfer({
                from_subaccount: null,
                to: { owner: Principal.fromText(sendTo), subaccount: null },
                amount: BigInt(sendAmount),
                fee: null,
                memo: null,
                created_at_time: null
            });
            
            setShowSendModal(false);
            setSendAmount('');
            setSendTo('');
            setSelectedToken(null);
        } catch (error: any) {
            setError(error?.toString() || 'Failed to send tokens');
        }
    };

    const handleRemoveToken = async () => {
        if (!selectedToken || !glob.walletBackend) return;
        
        try {
            await glob.walletBackend.removeToken(selectedToken.symbol);
            setShowManageModal(false);
            setSelectedToken(null);
            loadTokens();
        } catch (error: any) {
            setError(error?.toString() || 'Failed to remove token');
        }
    };

    const handleAddArchive = async () => {
        if (!selectedToken || !archiveCanisterId || !glob.walletBackend) return;
        
        try {
            await glob.walletBackend.addArchiveCanister(
                selectedToken.symbol,
                Principal.fromText(archiveCanisterId)
            );
            setShowManageModal(false);
            setSelectedToken(null);
            setArchiveCanisterId('');
            loadTokens();
        } catch (error: any) {
            setError(error?.toString() || 'Failed to add archive canister');
        }
    };

    const copyToClipboard = async (text: string) => {
        try {
            await navigator.clipboard.writeText(text);
            setCopied(true);
            setTimeout(() => setCopied(false), 2000);
        } catch (err) {
            setError('Failed to copy to clipboard');
        }
    };

    const renderTooltip = (props: any) => (
        <Tooltip {...props}>
            {copied ? 'Copied!' : 'Copy to clipboard'}
        </Tooltip>
    );

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
                                <Button 
                                    variant="primary" 
                                    size="sm" 
                                    className="me-2"
                                    onClick={() => {
                                        setSelectedToken(token);
                                        setShowSendModal(true);
                                    }}
                                >
                                    Send
                                </Button>
                                <Button 
                                    variant="success" 
                                    size="sm" 
                                    className="me-2"
                                    onClick={() => {
                                        setSelectedToken(token);
                                        setShowReceiveModal(true);
                                    }}
                                >
                                    Receive
                                </Button>
                                <Button 
                                    variant="info" 
                                    size="sm"
                                    onClick={() => {
                                        setSelectedToken(token);
                                        setShowManageModal(true);
                                    }}
                                >
                                    Manage
                                </Button>
                            </td>
                        </tr>
                    ))}
                </tbody>
            </table>

            {/* Send Modal */}
            <Modal show={showSendModal} onHide={() => setShowSendModal(false)}>
                <Modal.Header closeButton>
                    <Modal.Title>Send {selectedToken?.symbol}</Modal.Title>
                </Modal.Header>
                <Modal.Body>
                    <Form>
                        <Form.Group className="mb-3">
                            <Form.Label>Amount</Form.Label>
                            <Form.Control
                                type="number"
                                value={sendAmount}
                                onChange={(e) => setSendAmount(e.target.value)}
                                placeholder="Enter amount"
                                min="0"
                            />
                        </Form.Group>
                        <Form.Group className="mb-3">
                            <Form.Label>To Address</Form.Label>
                            <Form.Control
                                type="text"
                                value={sendTo}
                                onChange={(e) => setSendTo(e.target.value)}
                                placeholder="Enter recipient address"
                            />
                        </Form.Group>
                    </Form>
                </Modal.Body>
                <Modal.Footer>
                    <Button variant="secondary" onClick={() => setShowSendModal(false)}>
                        Cancel
                    </Button>
                    <Button 
                        variant="primary" 
                        onClick={handleSend}
                        disabled={!sendAmount || !sendTo}
                    >
                        Send
                    </Button>
                </Modal.Footer>
            </Modal>

            {/* Receive Modal */}
            <Modal show={showReceiveModal} onHide={() => setShowReceiveModal(false)}>
                <Modal.Header closeButton>
                    <Modal.Title>Receive {selectedToken?.symbol}</Modal.Title>
                </Modal.Header>
                <Modal.Body>
                    <p>Send {selectedToken?.symbol} to this address:</p>
                    <OverlayTrigger placement="right" overlay={renderTooltip}>
                        <code 
                            style={{cursor: 'pointer'}} 
                            onClick={() => copyToClipboard(principal?.toString() || '')}
                        >
                            {principal?.toString()}
                        </code>
                    </OverlayTrigger>
                </Modal.Body>
                <Modal.Footer>
                    <Button variant="secondary" onClick={() => setShowReceiveModal(false)}>
                        Close
                    </Button>
                </Modal.Footer>
            </Modal>

            {/* Manage Modal */}
            <Modal show={showManageModal} onHide={() => setShowManageModal(false)}>
                <Modal.Header closeButton>
                    <Modal.Title>Manage {selectedToken?.symbol}</Modal.Title>
                </Modal.Header>
                <Modal.Body>
                    <Form>
                        <Form.Group className="mb-3">
                            <Form.Label>Add Archive Canister ID</Form.Label>
                            <Form.Control
                                type="text"
                                value={archiveCanisterId}
                                onChange={(e) => setArchiveCanisterId(e.target.value)}
                                placeholder="Enter archive canister ID"
                            />
                            <Button 
                                variant="primary" 
                                className="mt-2"
                                onClick={handleAddArchive}
                                disabled={!archiveCanisterId}
                            >
                                Add Archive
                            </Button>
                        </Form.Group>
                        <hr />
                        <Button 
                            variant="danger" 
                            onClick={handleRemoveToken}
                        >
                            Remove Token
                        </Button>
                    </Form>
                </Modal.Body>
                <Modal.Footer>
                    <Button variant="secondary" onClick={() => setShowManageModal(false)}>
                        Close
                    </Button>
                </Modal.Footer>
            </Modal>
        </>
    );
});

export default TokensTable;