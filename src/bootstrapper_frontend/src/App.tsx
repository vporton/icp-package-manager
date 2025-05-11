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
// import { createActor as cmcActor } from '../../declarations/nns-cycles-minting';
// import { nns_ledger as icp_ledger } from '../../declarations/nns-ledger';
import { Principal } from '@dfinity/principal';
import { ErrorBoundary, ErrorHandler } from "../../lib/ErrorBoundary";
import { ErrorProvider } from '../../lib/ErrorContext';
import { AuthProvider, useAuth } from '../../lib/use-auth-client';
import { createActor as createBootstrapperActor } from "../../declarations/bootstrapper";
import { createActor as createCyclesLedgerActor } from "../../declarations/cycles_ledger";

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

function AddressPopup(props: {
  cyclesAmount: number | undefined,
  cyclesLedgerAmount: number | undefined,
  // icpAmount: number | undefined,
  cyclesPaymentAddress: string | undefined,
  updateCyclesAmount: () => void;
  updateCyclesLedgerAmount: () => void;
  // updateICPAmount: () => void;
}) { // TODO@P3: duplicate code
  const {agent} = useAuth();
  const address = props.cyclesPaymentAddress!;
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
  async function convertToCycles() {
    const bootstrapper = createBootstrapperActor(process.env.CANISTER_ID_BOOTSTRAPPER!, {agent})!;
    await bootstrapper.convertICPToCycles(); // FIXME@P3: Rename the function.
    props.updateCyclesAmount();
    props.updateCyclesLedgerAmount();
    // props.updateICPAmount();
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
        {/* <p>ICP balance: {props.icpAmount !== undefined ? `${String(props.icpAmount/10**8)}` : "Loading..."}</p> */}
        <p>Cycles to top-up:
          {props.cyclesLedgerAmount !== undefined ? `${String(props.cyclesLedgerAmount/10**12)}T` : "Loading..."}
        </p>
        <p><Button onClick={convertToCycles}>Use top-up cycles</Button></p>
        <p><strong>Warning: 5% fee applied.</strong></p>
        <p>Fund it with 13T cycles, at least.</p>
        <p>
          Send cyles to{" "}
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
  const [cyclesLedgerAmount, setCyclesLedgerAmount] = useState<number | undefined>();
  // const [icpAmount, setICPAmount] = useState<number | undefined>();
  const [paymentAddress, setPaymentAddress] = useState<string | undefined>();
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
    bootstrapper.balance().then((amount) => {
      setCyclesAmount(parseInt(amount.toString()))
    });
  }
  function updateCyclesLedgerAmount() {
    setCyclesLedgerAmount(undefined);
    if (principal === undefined || bootstrapper === undefined) {
      return;
    }
    const cyclesLedger = createCyclesLedgerActor("um5iw-rqaaa-aaaaq-qaaba-cai", {agent})!; // TODO@P3: `defaultAgent` // TODO@P3: explicit?
    cyclesLedger.icrc1_balance_of({
      owner: Principal.fromText(process.env.CANISTER_ID_BOOTSTRAPPER!),
      subaccount: [principalToSubAccount(principal)],
    }).then((amount) => {
      setCyclesLedgerAmount(parseInt(amount.toString()));
    });
  }
  // function updateICPAmount() {
  //   setICPAmount(undefined);
  //   if (principal === undefined || bootstrapper === undefined) {
  //     return;
  //   }
  //   icp_ledger.icrc1_balance_of({
  //     owner: Principal.fromText(process.env.CANISTER_ID_BOOTSTRAPPER!),
  //     subaccount: [principalToSubAccount(principal!)],
  //   }).then((amount: bigint) => {
  //     setICPAmount(parseInt(amount.toString()));
  //   });
  // }
  function updateAmounts() {
    updateCyclesAmount();
    // updateICPAmount();
    updateCyclesLedgerAmount();''
  }
  useEffect(updateCyclesAmount, [principal, bootstrapper]);
  useEffect(updateCyclesLedgerAmount, [principal, bootstrapper]);
  // useEffect(updateICPAmount, [principal, bootstrapper]);
  useEffect(() => {
    if (bootstrapper !== undefined) {
      bootstrapper.userAccountText().then((t) => {
        setPaymentAddress(t);
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
        This is an alpha test, not a product. We explicitly disclaim all warranties, express or implied, including but not limited to the implied warranties of merchantability and fitness for a particular purpose. We are not liable for any damages arising from use of this software.
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
                  Cycles balance:{" "}
                    {cyclesAmount !== undefined ? `${String(cyclesAmount/10**12)}T` : "Loading..."}{" "}
                </Dropdown.Toggle>
                <Dropdown.Menu style={{padding: '10px'}}>
                  <AddressPopup cyclesAmount={cyclesAmount} cyclesLedgerAmount={cyclesLedgerAmount} cyclesPaymentAddress={paymentAddress}
                    updateCyclesAmount={updateCyclesAmount} updateCyclesLedgerAmount={updateCyclesLedgerAmount}/>
                </Dropdown.Menu>
              </Dropdown>
              <a onClick={updateAmounts} style={{padding: '0', textDecoration: 'none', cursor: 'pointer'}}>&#x27F3;</a>
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
