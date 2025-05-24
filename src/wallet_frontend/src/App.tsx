import Container from 'react-bootstrap/Container';
import Button from 'react-bootstrap/Button';
import Tab from 'react-bootstrap/Tab';
import Tabs from 'react-bootstrap/Tabs';
import 'bootstrap/dist/css/bootstrap.min.css';
import TokensTable from './TokensTable';
import Settings from './Settings';

export default function App() {
  return (
    <Container>
        <h1>
            <img width="128" height="128" src="/img/wallet-256x256.png" alt="Payments Wallet logo" />
            {" "}Payments Wallet
        </h1>
        <Tabs>
            <Tab eventKey="tokens" title="Tokens">
                <p><Button>Add token</Button></p>
                <TokensTable />
            </Tab>
            <Tab eventKey="settings" title="Settings">
                <Settings/>
            </Tab>
            <Tab eventKey="settings" title="Invest">
            </Tab>
        </Tabs>
    </Container>
  );
}