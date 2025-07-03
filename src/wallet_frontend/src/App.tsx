import Container from 'react-bootstrap/Container';
import Button from 'react-bootstrap/Button';
import Tab from 'react-bootstrap/Tab';
import Tabs from 'react-bootstrap/Tabs';
import 'bootstrap/dist/css/bootstrap.min.css';
import TokensTable from './TokensTable';
import Settings from './Settings';
import { lazy, Suspense, useContext } from 'react';
const Invest = lazy(() => import('./Invest'));
import { AuthProvider, useAuth } from '../../lib/use-auth-client';
import { AuthButton }  from '../../lib/AuthButton';
import { ErrorBoundary, ErrorHandler } from "../../lib/ErrorBoundary";
import { ErrorContext, ErrorProvider } from '../../lib/ErrorContext';
import { useState, useRef } from 'react';
import { GlobalContext, GlobalContextProvider } from './state';
import AddTokenDialog from './AddTokenDialog';
import { signPrincipal, getPublicKeyFromPrivateKey } from '../../lib/signatures';

function urlSafeBase64ToUint8Array(urlSafeBase64: string) {
    const cleaned = urlSafeBase64.trim();
    if (!/^[0-9A-Za-z_-]+$/.test(cleaned)) {
        throw new Error('Invalid Base64');
    }
    const base64String = cleaned
        .replace(/-/g, '+')
        .replace(/_/g, '/')
        .padEnd(cleaned.length + (4 - cleaned.length % 4) % 4, '=');
    const binaryString = atob(base64String);
    const binaryArray = new Uint8Array(binaryString.length);
    for (let i = 0; i < binaryString.length; i++) {
        binaryArray[i] = binaryString.charCodeAt(i);
    }
    return binaryArray;
}

export default function App() {
    return (
        <ErrorProvider>
            <ErrorBoundary>
                <AuthProvider>
                    <GlobalContextProvider>
                        <App2/>
                    </GlobalContextProvider>
                </AuthProvider>
            </ErrorBoundary>
        </ErrorProvider>
    );
}

function App2() {
    const {ok} = useAuth();
    const params = new URLSearchParams(window.location.search);
    const installKey = params.get('installationPrivKey');
    const [activeTab, setActiveTab] = useState('tokens');
    const [showAddTokenDialog, setShowAddTokenDialog] = useState(false);
    const [tokensKey, setTokensKey] = useState(0); // Used to force TokensTable refresh

    const handleAddToken = () => {
        setShowAddTokenDialog(true);
    };

    const handleTokenAdded = () => {
        setTokensKey(prev => prev + 1); // Force TokensTable to reload
    };

    return (
        <Container>
            <p style={{background: 'red', color: 'white', padding: '2px'}}>
                This is a preliminary release. No warranty is given for the correctness of this software.{" "}
                We are under no obligation to refund losses caused by possible errors in this software.
            </p>
            <h1>
                <img width="128" height="128" src="/img/wallet-256x256.png" alt="Payments Wallet logo" />
                {" "}Payments Wallet
            </h1>
            <p>
                <AuthButton/>{" "}
                <a target="_blank" href="https://github.com/vporton/icp-package-manager">
                    <img src="/github-mark.svg" width="24" height="24"/>
                </a>
            </p>
            {installKey ? <FinishInstallation installationPrivKey={installKey}/> : 
                <Tabs activeKey={activeTab} onSelect={(k) => setActiveTab(k || 'tokens')}>
                    <Tab eventKey="tokens" title="Tokens">
                        <p>
                            <Button disabled={!ok} onClick={handleAddToken}>Add token</Button>
                            {!ok && <>{" "}Login to add a token.</>}
                        </p>
                        {ok && <TokensTable key={tokensKey} />}
                    </Tab>
                    <Tab eventKey="settings" title="Settings">
                        <Settings/>
                    </Tab>
                    <Tab eventKey="invest" title="Invest">
                        <Suspense fallback={<div>Loading...</div>}>
                            <Invest/>
                        </Suspense>
                    </Tab>
                </Tabs>
            }

            <AddTokenDialog 
                show={showAddTokenDialog}
                onHide={() => setShowAddTokenDialog(false)}
                onTokenAdded={handleTokenAdded}
            />
        </Container>
    );
}

function FinishInstallation(props: {installationPrivKey: string}) {
    const {agent, principal, ok} = useAuth();
    const glob = useContext(GlobalContext);

    async function finish() {
        if (!ok || agent === undefined || glob.walletBackend === undefined || principal === undefined) {
            return;
        }
        let privBytes: Uint8Array;
        try {
            privBytes = urlSafeBase64ToUint8Array(props.installationPrivKey);
        } catch (_) {
            alert('Invalid installation key.');
            return;
        }
        const privKey = await window.crypto.subtle.importKey('pkcs8', privBytes, {name: 'ECDSA', namedCurve: 'P-256'}, true, ['sign']);
        // const pubKey = await getPublicKeyFromPrivateKey(privKey);
        // const pubKeyBytes = new Uint8Array(await window.crypto.subtle.exportKey('spki', pubKey));
        const signature = new Uint8Array(await signPrincipal(privKey, principal));
        await glob.walletBackend.setOwner(signature);
        const url = new URL(window.location.href);
        url.searchParams.delete('installationPrivKey');
        open(url.toString(), '_self');
    }

    return (
        <Container>
            <p><Button onClick={finish} disabled={!ok}>Finish installation</Button></p>
        </Container>
    );
}
