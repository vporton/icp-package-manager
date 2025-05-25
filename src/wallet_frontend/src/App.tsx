import Container from 'react-bootstrap/Container';
import Button from 'react-bootstrap/Button';
import Tab from 'react-bootstrap/Tab';
import Tabs from 'react-bootstrap/Tabs';
import 'bootstrap/dist/css/bootstrap.min.css';
import TokensTable from './TokensTable';
import Settings from './Settings';
import { AuthProvider, useAuth } from '../../lib/use-auth-client';
import { AuthButton }  from '../../lib/AuthButton';

export default function App() {
    const {ok} = useAuth();
  return (
    <AuthProvider>
        <Container>
            <p style={{background: 'red', color: 'white', padding: '2px'}}>
                This is a preliminary release. No warranty is given for the correctness of this software.{" "}
                We are under no obligation to refund losses caused by possible errors in this software.
            </p>
            <h1>
                <img width="128" height="128" src="/img/wallet-256x256.png" alt="Payments Wallet logo" />
                {" "}Payments Wallet
            </h1>
            <p><AuthButton/></p>
            <Tabs>
                <Tab eventKey="tokens" title="Tokens">
                    <p>
                        <Button>Add token</Button>
                        {!ok && <>{" "}Login to add a token.</>}
                    </p>
                    <TokensTable />
                </Tab>
                <Tab eventKey="settings" title="Settings">
                    <Settings/>
                </Tab>
                <Tab eventKey="invest" title="Invest">
                </Tab>
            </Tabs>
        </Container>
    </AuthProvider>
  );
}