import { Button, Container, Dropdown, Nav, Navbar, OverlayTrigger, Tooltip } from 'react-bootstrap';
import 'bootstrap/dist/css/bootstrap.min.css';
import { AuthButton }  from '../../lib/AuthButton';
import { getIsLocal } from "../../lib/state";
import MainPage from './MainPage';
import { BrowserRouter, Route, Routes } from 'react-router-dom';
// import Bookmark from './Bookmark';
import { BusyProvider, BusyWidget } from '../../lib/busy';
import "../../lib/busy.css";
import { principalToSubAccount } from "../../lib/misc";
import {  useEffect, useMemo, useState } from 'react';
import { cycles_ledger } from '../../declarations/cycles_ledger';
import { Principal } from '@dfinity/principal';
import { ErrorBoundary, ErrorHandler } from "../../lib/ErrorBoundary";
import { ErrorProvider } from '../../lib/ErrorContext';
import { AuthProvider, useAuth } from '../../lib/use-auth-client';
import { createActor as createBootstrapperActor } from "../../declarations/bootstrapper";

function App() {
  return (
    <BusyProvider>
      <BusyWidget>
        <AuthProvider>
          <ErrorProvider>
            <ErrorBoundary>
              <App2/>
            </ErrorBoundary>
          </ErrorProvider>
        </AuthProvider>
      </BusyWidget>
    </BusyProvider>
  );
}

function AddressPopup(props: {cyclesAmount: number | undefined, cyclesPaymentAddress: Uint8Array | undefined}) { // TODO@P3: duplicate code
  const address = Buffer.from(props.cyclesPaymentAddress!).toString('hex');
  const [copied, setCopied] = useState(false);
  const copyToClipboard = async () => {
    navigator.clipboard.writeText(address).then(() => {
      try {
        setCopied(true);
        setTimeout(() => setCopied(false), 2000);
      } catch (err) {
        console.error('Failed to copy: ', err);
      }
    });
  }
  const renderTooltip = (props: any) => (
    <Tooltip {...props}>
      {copied ? 'Copied!' : 'Copy to clipboard'}
    </Tooltip>
  );
  return props.cyclesPaymentAddress !== undefined
    ? (
      // TODO@P3: `stopPropagation` doesn't work in some reason.
      <div onMouseDown={e => e.stopPropagation()} onMouseUp={e => e.stopPropagation()}>
        <p><strong>Warning: 5% fee applied.</strong></p>
        <p>
          Send cycles to{" "}
          <OverlayTrigger placement="right" overlay={renderTooltip}>
            <code style={{cursor: 'pointer'}} onClick={(e) => {copyToClipboard(); e.stopPropagation()}}>{address}</code>
          </OverlayTrigger>
        </p>
        <p>TODO@P3: QR-code</p>
      </div>
    )
    : undefined;
}

function App2() {
  const {principal, ok, agent} = useAuth();
  const [cyclesAmount, setCyclesAmount] = useState<number | undefined>();
  const [cyclesPaymentAddress, setCyclesPaymentAddress] = useState<Uint8Array | undefined>();
  const bootstrapper = useMemo(() =>
    agent === undefined ? undefined : createBootstrapperActor(process.env.CANISTER_ID_BOOTSTRAPPER!, {agent}), // TODO@P3: or `defaultAgent`?
    [agent],
  );
  // TODO@P3: below correct `!` usage?
  function updateCyclesAmount() {
    setCyclesAmount(undefined);
    if (principal === undefined || bootstrapper === undefined) {
      return;
    }
    if (getIsLocal()) { // to ease debugging
      bootstrapper.balance().then((amount) => {
        setCyclesAmount(parseInt(amount.toString()))
      });
    } else {
      cycles_ledger.icrc1_balance_of({
        owner: Principal.fromText(process.env.CANISTER_ID_BOOTSTRAPPER!),
        subaccount: [principalToSubAccount(principal!)],
      }).then((amount: bigint) => {
        setCyclesAmount(parseInt(amount.toString()));
      });
    }
  }
  useEffect(updateCyclesAmount, [principal, bootstrapper]);
  useEffect(() => {
    if (bootstrapper !== undefined) {
      bootstrapper.userAccountBlob().then((b) => {
        setCyclesPaymentAddress(b as Uint8Array);
      });
    }
  }, [bootstrapper]);
  // function mint() {
  //   cycles_ledger.mint({
  //     to: {
  //       owner: Principal.fromText(process.env.CANISTER_ID_BOOTSTRAPPER!),
  //       subaccount: [principalToSubAccount(principal!)],  
  //     },
  //     amount: BigInt(100*10**12),
  //     memo: [],
  //     created_at_time: [],
  //   }).then(res => {
  //     if ((res as any).Err) {
  //       alert("Minting error!"); // TODO@P3
  //     } else {
  //       updateCyclesAmount();
  //     }
  //   });
  // }
  return (
    <main id="main">
      <p style={{background: 'red', color: 'white'}}>
        This is an alpha test, not a product. We explicitly disclaim all warranties, express or implied, including but not limited to the implied warranties of merchantability and fitness for a particular purpose. We are not liable for any damages arising from the use of this software.
      </p>
      <h1 style={{textAlign: 'center'}}>
        <img src="/internet-computer-icp-logo.svg" alt="DFINITY logo" style={{width: '150px', display: 'inline'}} />
        {" "}
        Bootstrapper (Installer) of Package Manager
      </h1>
      <Container>
        <nav>
          <Navbar className="bg-body-secondary" style={{width: "auto"}}>
            <Nav>
              <AuthButton/>
            </Nav>
            <Nav style={{display: ok ? undefined : 'none'}}>
              <Dropdown>
                <Dropdown.Toggle>
                  Cycles balance: {cyclesAmount !== undefined ? `${String(cyclesAmount/10**12)}T` : "Loading..."}{" "}
                </Dropdown.Toggle>
                <Dropdown.Menu>
                  <Dropdown.Item as="div">
                    <AddressPopup cyclesAmount={cyclesAmount} cyclesPaymentAddress={cyclesPaymentAddress}/>
                  </Dropdown.Item>
                </Dropdown.Menu>
              </Dropdown>
              <a onClick={updateCyclesAmount} style={{padding: '0', textDecoration: 'none', cursor: 'pointer'}}>&#x27F3;</a>
            </Nav>
            {/* <Nav style={{display: ok && getIsLocal() ? undefined : 'none'}}>
              <Button onClick={mint}>Mint</Button>
            </Nav> */}
          </Navbar>
        </nav>
        <BrowserRouter>
          <Routes>
            <Route path="/" element={<MainPage/>}/>
            {/* <Route path="/bookmark" element={<Bookmark/>}/> */}
            <Route path="*" element={<ErrorHandler error={"No such page"}/>}/>
          </Routes>
        </BrowserRouter>        
      </Container>
    </main>
 );
}

export default App;
