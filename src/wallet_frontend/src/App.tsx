import Container from 'react-bootstrap/Container';
import Button from 'react-bootstrap/Button';
import Tab from 'react-bootstrap/Tab';
import Tabs from 'react-bootstrap/Tabs';
import 'bootstrap/dist/css/bootstrap.min.css';
import TokensTable from './TokensTable';
import Settings from './Settings';
import { lazy, Suspense } from 'react';
const Invest = lazy(() => import('./Invest'));
import { AuthProvider, useAuth } from '../../lib/use-auth-client';
import { AuthButton }  from '../../lib/AuthButton';
import { ErrorBoundary, ErrorHandler } from "../../lib/ErrorBoundary";
import { ErrorContext, ErrorProvider } from '../../lib/ErrorContext';
import { useState, useRef } from 'react';
import { GlobalContextProvider } from './state';
import AddTokenDialog from './AddTokenDialog';

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

            <AddTokenDialog 
                show={showAddTokenDialog}
                onHide={() => setShowAddTokenDialog(false)}
                onTokenAdded={handleTokenAdded}
            />
        </Container>
    );
}