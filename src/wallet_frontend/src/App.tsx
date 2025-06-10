import Container from 'react-bootstrap/Container';
import Button from 'react-bootstrap/Button';
import Tab from 'react-bootstrap/Tab';
import Tabs from 'react-bootstrap/Tabs';
import 'bootstrap/dist/css/bootstrap.min.css';
import TokensTable from './TokensTable';
import Settings from './Settings';
import { AuthProvider, useAuth } from '../../lib/use-auth-client';
import { AuthButton }  from '../../lib/AuthButton';
import { ErrorBoundary, ErrorHandler } from "../../lib/ErrorBoundary";
import { ErrorContext, ErrorProvider } from '../../lib/ErrorContext';
import { useState, useRef } from 'react';
import { GlobalContextProvider } from './state';

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
    const tokensTableRef = useRef<{ setShowAddModal: (show: boolean) => void }>(null);

    const handleAddToken = () => {
        if (tokensTableRef.current) {
            tokensTableRef.current.setShowAddModal(true);
        }
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
                    {ok && <TokensTable ref={tokensTableRef} />}
                </Tab>
                <Tab eventKey="settings" title="Settings">
                    <Settings/>
                </Tab>
                <Tab eventKey="invest" title="Invest">
                    <p>Investment features coming soon...</p>
                </Tab>
            </Tabs>
        </Container>
    );
}