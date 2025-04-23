import { Button, Container, Dropdown, Nav, Navbar, OverlayTrigger, Tooltip } from 'react-bootstrap';
import 'bootstrap/dist/css/bootstrap.min.css';
import { AuthButton }  from './AuthButton';
import { AuthProvider, useAuth } from './auth/use-auth-client';
import { getIsLocal } from "../../lib/state";
import MainPage from './MainPage';
import { BrowserRouter, Route, Routes } from 'react-router-dom';
// import Bookmark from './Bookmark';
import { BusyProvider, BusyWidget } from '../../lib/busy';
import "../../lib/busy.css";
import { principalToSubAccount } from "../../lib/misc";
import {  useEffect, useState } from 'react';
import { bootstrapper } from '../../declarations/bootstrapper';
import { cycles_ledger } from '../../declarations/cycles_ledger';
import { Principal } from '@dfinity/principal';
import { ErrorBoundary, ErrorHandler } from "../../lib/ErrorBoundary";
import { ErrorProvider } from '../../lib/ErrorContext';

function App() {
  const identityProvider = getIsLocal() ? `http://${process.env.CANISTER_ID_INTERNET_IDENTITY}.localhost:4943` : `https://identity.internetcomputer.org`;
  return (
    <BusyProvider>
      <BusyWidget>
        <AuthProvider options={{loginOptions: {
            identityProvider,
            maxTimeToLive: BigInt(3600) * BigInt(1_000_000_000),
            windowOpenerFeatures: "toolbar=0,location=0,menubar=0,width=500,height=500,left=100,top=100",
            onSuccess: () => {
                console.log('Login Successful!');
            },
            onError: (error) => {
                console.error('Login Failed: ', error);
            },
        }}}>
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
  const {isAuthenticated, principal} = useAuth();
  const [cyclesAmount, setCyclesAmount] = useState<number | undefined>();
  const [cyclesPaymentAddress, setCyclesPaymentAddress] = useState<Uint8Array | undefined>();
  // TODO@P3: below correct `!` usage?
  function updateCyclesAmount() {
    setCyclesAmount(undefined);
    if (principal === undefined) {
      return;
    }
    cycles_ledger.icrc1_balance_of({
      owner: Principal.fromText(process.env.CANISTER_ID_BOOTSTRAPPER!),
      subaccount: [principalToSubAccount(principal!)],
    }).then((amount: bigint) => {
      setCyclesAmount(parseInt(amount.toString()))
    });
  }
  useEffect(updateCyclesAmount, [principal]);
  useEffect(() => {
    bootstrapper.userAccountBlob().then((b) => {
      setCyclesPaymentAddress(b as Uint8Array);
    });
  }, [principal]);
  function mint() {
    cycles_ledger.mint({
      to: {
        owner: Principal.fromText(process.env.CANISTER_ID_BOOTSTRAPPER!),
        subaccount: [principalToSubAccount(principal!)],  
      },
      amount: BigInt(100*10**12),
      memo: [],
      created_at_time: [],
    }).then(res => {
      console.log("Minted: ", res);
      if ((res as any).Err) {
        alert("Minting error!"); // TODO@P3
      } else {
        updateCyclesAmount();
      }
    });
  }
  return (
    <main id="main">
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
            <Nav style={{display: isAuthenticated ? undefined : 'none'}}>
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
            <Nav style={{display: isAuthenticated && getIsLocal() ? undefined : 'none'}}>
              <Button onClick={mint}>Mint</Button>
            </Nav>
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
