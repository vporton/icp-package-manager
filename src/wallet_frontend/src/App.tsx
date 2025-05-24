import Container from 'react-bootstrap/Container';
import Button from 'react-bootstrap/Button';
import Tab from 'react-bootstrap/Tab';
import Tabs from 'react-bootstrap/Tabs';
import 'bootstrap/dist/css/bootstrap.min.css';

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
                <table id='tokensTable'>
                    {/* <thead>
                        <tr>
                        </tr>
                    </thead> */}
                    <tbody>
                        <tr>
                            <td>ICP</td>
                            <td>Internet Computer</td>
                            <td>1000.00</td>
                            <td><Button>Send</Button> <Button>Receive</Button></td>
                        </tr>
                        <tr>
                            <td>-</td>
                            <td>-</td>
                            <td>-</td>
                        </tr>
                    </tbody>
                </table>
            </Tab>
            <Tab eventKey="settings" title="Settings">
            </Tab>
        </Tabs>
    </Container>
  );
}