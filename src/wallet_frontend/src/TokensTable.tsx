import { useState, useEffect, forwardRef, useImperativeHandle, useContext, useMemo } from 'react';
import Button from 'react-bootstrap/Button';
import Modal from 'react-bootstrap/Modal';
import Form from 'react-bootstrap/Form';
import { useAuth } from '../../lib/use-auth-client';
import { createActor as createTokenActor } from '../../declarations/nns-ledger'; // TODO: hack
import { createActor as createPstActor } from '../../declarations/pst';
import { Account, _SERVICE as NNSLedger } from '../../declarations/nns-ledger/nns-ledger.did'; // TODO: hack
import { Principal } from '@dfinity/principal';
import { decodeIcrcAccount, IcrcLedgerCanister } from "@dfinity/ledger-icrc";
import { GlobalContext } from './state';
import { ErrorContext } from '../../lib/ErrorContext';
import OverlayTrigger from 'react-bootstrap/OverlayTrigger';
import Tooltip from 'react-bootstrap/Tooltip';
import Accordion from 'react-bootstrap/Accordion';
import { Token, TransferError } from '../../declarations/wallet_backend/wallet_backend.did';
import { Actor } from '@dfinity/agent';
import { userAccount, userAccountText } from './accountUtils';

interface UIToken {
    symbol: string;
    name: string;
    canisterId: Principal | undefined;
    archiveCanisterId: Principal | undefined;
}

export interface TokensTableRef {
    setShowAddModal: (show: boolean) => void;
}

interface TokensTableProps {}

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
    const [archiveCanisterId, setArchiveCanisterId] = useState('');
    const [copied, setCopied] = useState(false);
    const [showAdvanced, setShowAdvanced] = useState(false);
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
    const subaccount = userWalletText === undefined || !/\./.test(userWalletText) ? undefined : userWalletText?.replace(/^[^.]*\./, '');
    const dfxCommand = userWalletText === undefined
        ? ''
        : `dfx ledger --network ${process.env.DFX_NETWORK} transfer --to-principal ${userWalletText.replace(/-[^-]+\..*/, '')} ${subaccount !== undefined ? `--to-subaccount ${subaccount}` : ''} --memo 1 --amount`;
    useEffect(() => {
        if (glob.walletBackendPrincipal !== undefined && principal !== undefined) {
            userAccount(glob.walletBackendPrincipal, principal, agent).then(account => {
                setUserWallet(account);
                userAccountText(glob.walletBackendPrincipal!, principal, agent).then(setUserWalletText);
            });
        }
    }, [glob.walletBackendPrincipal, principal, agent]);
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

    const [xr, setXr] = useState<number | undefined>();
    async function initSendModal(token: any) { // TODO@P3: `any`
        setSelectedToken(token);
        if (!await glob.walletBackend!.isAnonymous()) {
            const rate = await glob.walletBackend!.get_exchange_rate(token.symbol);
            if ((rate as any).Ok !== undefined) {
                setXr((rate as any).Ok);
            }
        }
        setShowSendModal(true);
    }

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
                            </td>
                            <td>{balances.get(token.canisterId!)}</td>
                            <td>
                                <Button 
                                    variant="primary" 
                                    size="sm" 
                                    className="me-2"
                                    onClick={async () => await initSendModal(token)}
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

            <SendModal showSendModal={showSendModal} setShowSendModal={setShowSendModal} selectedToken={selectedToken} xr={xr}/>
 
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
                    {dfxCommand && (
                        <Accordion defaultActiveKey={undefined} className="mt-3">
                            <Accordion.Item eventKey="advanced">
                                <Accordion.Header onClick={() => setShowAdvanced(!showAdvanced)}>
                                    {showAdvanced ? 'Hide advanced' : 'Show advanced'}
                                </Accordion.Header>
                                <Accordion.Body>
                                    <p>
                                        You can use DFX command:{' '}
                                        <OverlayTrigger placement="right" overlay={renderTooltip}>
                                            <code
                                                style={{cursor: 'pointer'}}
                                                onClick={() => copyToClipboard(dfxCommand)}
                                            >
                                                {dfxCommand} <em>AMOUNT</em>
                                            </code>
                                        </OverlayTrigger>
                                    </p>
                                </Accordion.Body>
                            </Accordion.Item>
                        </Accordion>
                    )}
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

// TODO@P3: `any`
function SendModal(props: {showSendModal: boolean, setShowSendModal: (show: boolean) => void, selectedToken: any, xr: number | undefined}) {
    const glob = useContext(GlobalContext);
    const {agent,  defaultAgent, principal} = useAuth();
    const { setError } = useContext(ErrorContext)!;
    const [sendAmount, setSendAmount] = useState('');
    const [sendTo, setSendTo] = useState('');

    const [showCheckboxConfirmation, setShowCheckboxConfirmation] = useState(true)
    const [showInputConfirmation, setShowInputConfirmation] = useState(true);
    const [checkboxConfirmation, setCheckboxConfirmation] = useState(true)
    const [inputConfirmation, setInputConfirmation] = useState(true);

    const [amountAddCheckbox, setAmountAddCheckbox] = useState<number | undefined>();
    const [amountAddInput, setAmountAddInput] = useState<number | undefined>();

    const loadSettings = async () => {
        if (!agent || !principal || !glob.walletBackend) return;

        const limits = await glob.walletBackend.getLimitAmounts();
        setAmountAddCheckbox(limits.amountAddCheckbox[0] ?? 10); // FIXME@P3: duplicate code
        setAmountAddInput(limits.amountAddInput[0] ?? 30);
    };

    useEffect(() => {
        if (!props.xr) return;
        // FIXME@P2: Conversion to number may fail?
        setShowCheckboxConfirmation(amountAddCheckbox === undefined || Number(sendAmount) * props.xr < amountAddCheckbox);
        setShowInputConfirmation(amountAddInput === undefined || Number(sendAmount) * props.xr < amountAddInput);
    }, [props.xr]); // FIXME@P2: Update `xr` from time to time.

    const handleSend = async () => {
        if (!props.selectedToken?.canisterId || !sendAmount || !sendTo) return;
        
        try {
            const to = decodeIcrcAccount(sendTo);
            const token = createTokenActor(props.selectedToken?.canisterId, {agent: defaultAgent});
            const decimals = await token.decimals();
            /*const res = */await glob.walletBackend!.do_icrc1_transfer(props.selectedToken?.canisterId, {
                from_subaccount: [],
                to: {owner: to.owner, subaccount: to.subaccount === undefined ? [] : [to.subaccount]},
                amount: BigInt(Number(sendAmount) * 10**decimals.decimals), // TODO@P2: Does Number convert right?
                fee: [],
                memo: [],
                created_at_time: [],
            });
            props.setShowSendModal(false);
            setSendAmount('');
            setSendTo('');
            // setSelectedToken(null);
            // if ((res as any).Err) {
            //     // console.log((res as any).Err);
            //     throw 'Failed to send tokens';
            // }
            // TODO: Update amounts in token table here (after a pause, because of no-return function `do_icrc1_transfer`).
        } catch (error: any) {
            setError(error?.toString() || 'Failed to send tokens');
        }
    };

    return <Modal show={props.showSendModal} onHide={() => props.setShowSendModal(false)}>
        <Modal.Header closeButton>
            <Modal.Title>Send {props.selectedToken?.symbol}</Modal.Title>
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
                {showCheckboxConfirmation && <Form.Group className="mb-3">
                    <Form.Check
                        label="Confirm Payment"
                        onChange={(e) => setCheckboxConfirmation(e.target.checked)}
                    />
                </Form.Group>}
                {showInputConfirmation && <Form.Group className="mb-3">
                    <Form.Label>Enter "pay":</Form.Label>
                    <Form.Control
                        type="text"
                        defaultValue={''}
                        onInput={(e) => setInputConfirmation((e.target as HTMLInputElement).value === "pay")}
                    />
                </Form.Group>}
            </Form>
        </Modal.Body>
        <Modal.Footer>
            <Button variant="secondary" onClick={() => props.setShowSendModal(false)}>
                Cancel
            </Button>
            <Button 
                variant="primary" 
                onClick={handleSend}
                disabled={!sendAmount || !sendTo || (showCheckboxConfirmation && !checkboxConfirmation) || (showInputConfirmation && !inputConfirmation)}
            >
                Send
            </Button>
        </Modal.Footer>
    </Modal>
}

export default TokensTable;