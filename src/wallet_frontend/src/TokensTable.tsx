import { useState, useEffect, forwardRef, useImperativeHandle, useContext, useMemo, useRef } from 'react';
import Button from 'react-bootstrap/Button';
import Modal from 'react-bootstrap/Modal';
import Form from 'react-bootstrap/Form';
import { useAuth } from '../../lib/use-auth-client';
import { createActor as createTokenActor } from '../../declarations/nns-ledger'; // TODO: hack
import { createActor as createSwapFactory } from '../../declarations/swap-factory';
import { createActor as createSwapPool } from '../../declarations/swap-pool';
import { Account, _SERVICE as NNSLedger } from '../../declarations/nns-ledger/nns-ledger.did'; // TODO: hack
import { Principal } from '@dfinity/principal';
import { decodeIcrcAccount, IcrcLedgerCanister } from "@dfinity/ledger-icrc";
import { GlobalContext } from './state';
import { ErrorContext } from '../../lib/ErrorContext';
import OverlayTrigger from 'react-bootstrap/OverlayTrigger';
import Tooltip from 'react-bootstrap/Tooltip';
import Accordion from 'react-bootstrap/Accordion';
import { Token } from '../../declarations/wallet_backend/wallet_backend.did';
import { HttpAgent } from '@dfinity/agent';
import { userAccount, userAccountText } from './accountUtils';

interface UIToken {
    symbol: string;
    name: string;
    canisterId: Principal | undefined; // TODO@P3: `undefined` is not a good idea.
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
    const [selectedToken, setSelectedToken] = useState<UIToken | undefined>(undefined);
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
            await glob.walletBackend.removeToken(selectedToken.canisterId!);
            setShowManageModal(false);
            setSelectedToken(undefined);
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
            setSelectedToken(undefined);
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
    const dfxCommand = principal === undefined
        ? ''
        : `dfx ledger --network ${process.env.DFX_NETWORK} transfer --to-principal ${principal.toText()} --memo 0 --amount`;
    useEffect(() => {
        setUserWallet({ owner: principal!, subaccount: [] });
        setUserWalletText(principal!.toText()); // TODO@P1: Remove this code.
    }, [principal]);
    useEffect(() => {
        if (tokens === undefined || userWallet === undefined) {
            return;
        }
        for (const token of tokens) {
            const actor = createTokenActor(token.canisterId!, { agent: defaultAgent });
            Promise.all([actor.icrc1_balance_of({owner: principal!, subaccount: []}), actor.icrc1_decimals()])
                .then(([balance, digits]) => {
                    balances.set(token.canisterId!, Number(balance.toString()) / 10**digits); // TODO@P3: Here `!` is superfluous.
                    setBalances(new Map(balances)); // create new value.
                });
        }
    }, [tokens, defaultAgent, userWallet]);

    async function initSendModal(token: any) { // TODO@P3: `any`
        setSelectedToken(token);
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

            <SendModal showSendModal={showSendModal} setShowSendModal={setShowSendModal} selectedToken={selectedToken}/>
 
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
function SendModal(props: {showSendModal: boolean, setShowSendModal: (show: boolean) => void, selectedToken: any}) {
    const glob = useContext(GlobalContext);
    const {agent, defaultAgent, principal} = useAuth();
    const { setError } = useContext(ErrorContext)!;
    const [price, setPrice] = useState<number | undefined>();
    const [sendAmount, setSendAmount] = useState('');
    const [sendTo, setSendTo] = useState('');

    // console.log("WW", props.selectedToken); // FIXME
    // return; // FIXME

    // FIXME@P3: For a diapason of time, `limits` takes a wrong value.
    const [limits, setLimits] = useState<{amountAddCheckbox?: number, amountAddInput?: number}>({amountAddCheckbox: 10, amountAddInput: 30}); // FIXME@P3: duplicate code
    useEffect(() => {
        if (glob.walletBackend) {
            glob.walletBackend.getLimitAmounts().then(v =>
                setLimits({amountAddCheckbox: v.amountAddCheckbox[0], amountAddInput: v.amountAddInput[0]})
            );
        }
    }, [glob.walletBackend]);
    const amountInBase = useMemo(
        () => price === undefined || sendAmount === undefined ? undefined : Number(sendAmount) * price,
        [price, sendAmount],
    );
    const showCheckboxConfirmation = useMemo(() =>
        limits.amountAddCheckbox === undefined || amountInBase === undefined ? false : amountInBase >= limits.amountAddCheckbox,
        [limits, amountInBase]
    );
    const showInputConfirmation = useMemo(() =>
        limits.amountAddInput === undefined || amountInBase === undefined ? false : amountInBase >= limits.amountAddInput,
        [limits, amountInBase]
    );
    const [checkboxConfirmation, setCheckboxConfirmation] = useState(false)
    const [inputConfirmation, setInputConfirmation] = useState(false);
    const checkboxConfirmationRef = useRef<HTMLInputElement | null>(null);
    const inputConfirmationRef = useRef<HTMLInputElement | null>(null);
    function updateCheckboxConfirmation() {
        setCheckboxConfirmation(checkboxConfirmationRef.current!.checked);
    }
    function updateInputConfirmation() {
        setInputConfirmation(inputConfirmationRef.current!.value === "pay");
    }

    const [decimals, setDecimals] = useState<number | undefined>();
    useEffect(() => {
        if (props.selectedToken !== undefined) {
            const token = createTokenActor(props.selectedToken.canisterId, {agent: defaultAgent});
            token.icrc1_decimals().then(n => setDecimals(Number(n.toString())));
        }
    }, [props.selectedToken]);

    useEffect(() => {
        if (props.selectedToken === undefined) {
            return;
        }
        glob.walletBackend!.isAnonymous().then(async f => {
            if (!f || glob.walletBackend === undefined || props.selectedToken === undefined || sendAmount === undefined || decimals === undefined) {
                const baseToken = "ryjl3-tyaaa-aaaaa-aaaba-cai";
                let ourPrice;
                if (props.selectedToken.canisterId.toString() === baseToken) {
                    ourPrice = 1.0;
                } else {
                    const mainnetAgent = await HttpAgent.create();
                    const swapFactory = await createSwapFactory("4mmnk-kiaaa-aaaag-qbllq-cai", {agent: mainnetAgent});
                    const pair = await swapFactory.getPool({
                        fee: 0n,
                        token0: {address: baseToken, standard: "ICP"},
                        token1: {address: props.selectedToken.canisterId, standard: "ICRC1"},
                    });
                    if ((pair as any).ok) {
                        const swapPool = await createSwapPool((pair as any).ok.canisterId, {agent: mainnetAgent});
                        const icpSwap = await swapPool.quote({
                            amountIn: (Number(sendAmount) * 10**decimals!).toString(), // TODO@P3: `!`
                            zeroForOne: false,
                            amountOutMinimum: "0",
                        });
                        if ((icpSwap as any).ok) {
                            ourPrice = (icpSwap as any).ok;
                        }
                    }
                }
                console.log("Our price:", ourPrice);
                setPrice(ourPrice);
            }
        })
    }, [glob.walletBackend, props.selectedToken, sendAmount, decimals]);

    const handleSend = async () => {
        if (!props.selectedToken.canisterId || !sendAmount || !sendTo) return;
        
        try {
            const to = decodeIcrcAccount(sendTo);
            const token = createTokenActor(props.selectedToken?.canisterId, {agent});
            const decimals = await token.icrc1_decimals();
            console.log(`decimals=${decimals} sendAmount=${sendAmount} amount=${BigInt(Number(sendAmount) * 10**decimals)}`);
            await token.icrc1_transfer({
                from_subaccount: [],
                to: {owner: to.owner, subaccount: to.subaccount === undefined ? [] : [to.subaccount]},
                amount: BigInt(Number(sendAmount) * 10**decimals), // FIXME@P3: `!` // TODO@P2: Does Number convert right? // TODO@P3: duplicate code
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
            // TODO: Update amounts in token table here.
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
                        onChange={updateCheckboxConfirmation}
                        ref={checkboxConfirmationRef}
                    />
                </Form.Group>}
                {showInputConfirmation && <Form.Group className="mb-3">
                    <Form.Label>Enter "pay":</Form.Label>
                    <Form.Control
                        type="text"
                        defaultValue={''}
                        onInput={updateInputConfirmation}
                        ref={inputConfirmationRef}
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