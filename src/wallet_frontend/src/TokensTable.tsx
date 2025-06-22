import { useState, useEffect, forwardRef, useImperativeHandle, useContext, useMemo } from 'react';
import Button from 'react-bootstrap/Button';
import Modal from 'react-bootstrap/Modal';
import Form from 'react-bootstrap/Form';
import { useAuth } from '../../lib/use-auth-client';
import { createActor as createTokenActor } from '../../declarations/nns-ledger'; // TODO: hack
import { createActor as createPstActor } from '../../declarations/pst';
import { Account, _SERVICE as NNSLedger } from '../../declarations/nns-ledger/nns-ledger.did'; // TODO: hack
import { Principal } from '@dfinity/principal';
import { decodeIcrcAccount, encodeIcrcAccount, IcrcLedgerCanister } from "@dfinity/ledger-icrc";
import { GlobalContext } from './state';
import { ErrorContext } from '../../lib/ErrorContext';
import OverlayTrigger from 'react-bootstrap/OverlayTrigger';
import Tooltip from 'react-bootstrap/Tooltip';
import { Token, TransferError } from '../../declarations/wallet_backend/wallet_backend.did';
import { Actor } from '@dfinity/agent';
import { principalToSubaccount } from './accountUtils';

interface UIToken {
    symbol: string;
    name: string;
    canisterId: Principal | undefined;
    archiveCanisterId: Principal | undefined;
}

export interface TokensTableRef {
    setShowAddModal: (show: boolean) => void;
}

interface TokensTableProps {
    onInvest?: () => void;
}

const TokensTable = forwardRef<TokensTableRef, TokensTableProps>((props, ref) => {
    const glob = useContext(GlobalContext);
    const { setError } = useContext(ErrorContext)!;
    const { agent, defaultAgent, principal } = useAuth();
    const [tokens, setTokens] = useState<UIToken[]>([]);
    const [showAddModal, setShowAddModal] = useState(false);
    const [showSendModal, setShowSendModal] = useState(false);
    const [showReceiveModal, setShowReceiveModal] = useState(false);
    const [showManageModal, setShowManageModal] = useState(false);
    const [selectedToken, setSelectedToken] = useState<UIToken | null>(null);
    const [sendAmount, setSendAmount] = useState('');
    const [sendTo, setSendTo] = useState('');
    const [archiveCanisterId, setArchiveCanisterId] = useState('');
    const [copied, setCopied] = useState(false);
    const [newToken, setNewToken] = useState<UIToken>({
        symbol: '',
        name: '',
        canisterId: undefined,
        archiveCanisterId: undefined,
    });

    useImperativeHandle(ref, () => ({
        setShowAddModal: (show: boolean) => setShowAddModal(show)
    }));

    const loadTokens = async () => {
        if (!agent || !principal || !glob.walletBackend) return;
        
        const backendTokens = await glob.walletBackend.getTokens();
        setTokens(backendTokens.map((t: Token) => {
            return {
                symbol: t.symbol,
                name: t.name,
                canisterId: t.canisterId!,
                archiveCanisterId: t.archiveCanisterId![0],
            }
        }));
    };

    useEffect(() => {
        loadTokens();
    }, [agent, principal]);

    const handleAddToken = async () => {
        if (!agent || !principal || !glob.walletBackend) return;
        
        // TODO@P3: also `archiveCanisterId`:
        await glob.walletBackend.addToken({
            symbol: newToken.symbol,
            name: newToken.name,
            canisterId: newToken.canisterId!,
            archiveCanisterId: [],
        });
        
        setShowAddModal(false);
        loadTokens();
    };

    const handleSend = async () => {
        if (!selectedToken?.canisterId || !sendAmount || !sendTo) return;
        
        try {
            const to = decodeIcrcAccount(sendTo);
            const res = await glob.walletBackend!.do_icrc1_transfer(selectedToken?.canisterId, {
                from_subaccount: [],
                to: {owner: to.owner, subaccount: to.subaccount === undefined ? [] : [to.subaccount]},
                amount: BigInt(sendAmount),
                fee: [],
                memo: [],
                created_at_time: [],
            });
            setShowSendModal(false);
            setSendAmount('');
            setSendTo('');
            setSelectedToken(null);
            if ((res as any).Err) {
                throw "error sending token"; // TODO@P3: better error message (based on `Err`)
            }
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

    const [balances, setBalances] = useState(new Map<Principal, number>());
    const [userWallet, setUserWallet] = useState<Account | undefined>();
    const [userWalletText, setUserWalletText] = useState<string | undefined>();
    useEffect(() => {
        if (glob.walletBackendPrincipal !== undefined && principal !== undefined) {
            const account = { owner: glob.walletBackendPrincipal, subaccount: principalToSubaccount(principal) };
            setUserWallet({owner: account.owner, subaccount: [account.subaccount]});
            setUserWalletText(encodeIcrcAccount(account));
        }
    }, [glob.walletBackendPrincipal, principal]);
    useEffect(() => {
        if (tokens === undefined || userWallet === undefined) {
            return;
        }
        for (const token of tokens) {
            const actor = createTokenActor(token.canisterId!, { agent: defaultAgent });
            Promise.all([actor.icrc1_balance_of(userWallet), actor.icrc1_decimals()])
                .then(([balance, digits]) => {
                    balances.set(token.canisterId!, Number(balance.toString()) / 10**digits); // TODO@P3: Here `!` is superfluous.
                    setBalances(new Map(balances)); // create new value.
                });
        }
    }, [tokens, defaultAgent, userWallet]);

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
                            <td>
                                {token.name}
                                {props.onInvest && token.canisterId && token.canisterId.toText() === process.env.CANISTER_ID_PST! && (
                                    <>
                                        {" "}<Button
                                            variant="secondary"
                                            size="sm"
                                            className="me-2"
                                            onClick={() => props.onInvest && props.onInvest()}
                                        >
                                            Invest
                                        </Button>
                                    </>
                                )}
                            </td>
                            <td>{balances.get(token.canisterId!)}</td>
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
                            onClick={() => copyToClipboard(userWalletText!)}
                        >
                            {userWalletText}
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