import Button from 'react-bootstrap/Button';
import Container from 'react-bootstrap/Container';
import Dropdown from 'react-bootstrap/Dropdown';
import Modal from 'react-bootstrap/Modal';
import Nav from 'react-bootstrap/Nav';
import Navbar from 'react-bootstrap/Navbar';
import OverlayTrigger from 'react-bootstrap/OverlayTrigger';
import Tab from 'react-bootstrap/Tab';
import Tabs from 'react-bootstrap/Tabs';
import Tooltip from 'react-bootstrap/Tooltip';
import 'bootstrap/dist/css/bootstrap.min.css';
import { AuthButton }  from '../../lib/AuthButton';
import MainPage from './MainPage';
import { BrowserRouter, Route, Routes } from 'react-router-dom';
import { BusyProvider, BusyWidget } from '../../lib/busy';
import "../../lib/busy.css";
import { principalToSubAccount } from "../../lib/misc";
import {  useContext, useEffect, useMemo, useState } from 'react';
// import { createActor as cmcActor } from '../../declarations/nns-cycles-minting';
import { nns_ledger as icp_ledger } from '../../declarations/nns-ledger';
import { Principal } from '@dfinity/principal';
import { ErrorBoundary, ErrorHandler } from "../../lib/ErrorBoundary";
import { ErrorContext, ErrorProvider } from '../../lib/ErrorContext';
import { AuthProvider, useAuth } from '../../lib/use-auth-client';
import { createActor as createBootstrapperActor } from "../../declarations/bootstrapper";
import { createActor as createCyclesLedgerActor } from "../../declarations/cycles_ledger";
import { init as swetrix_init, trackViews, track as swetrix_track } from 'swetrix';

function App() {
  useEffect(() => {
    swetrix_init('Iu7kSKSALIF3', {disabled: /localhost/.test(location.hostname)});
    trackViews();
  });

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
  icpAmount: number | undefined,
  cyclesPaymentAddress: string | undefined,
  updateCyclesAmount: () => void;
  updateCyclesLedgerAmount: () => void;
  updateICPAmount: () => void;
}) { // TODO@P3: duplicate code
  const {setError} = useContext(ErrorContext)!;
  const {agent} = useAuth();
  const address = props.cyclesPaymentAddress!;
  const [copied, setCopied] = useState(false);
  const copyToClipboard = async (event: React.MouseEvent) => {
    const str = (event.target as HTMLElement).innerText;
    navigator.clipboard.writeText(str).then(() => {
      try {
        setCopied(true);
        setTimeout(() => setCopied(false), 2000);
      } catch (err) {
        console.error('Failed to copy: ', err);
      }
    });
  }
  async function topUpCycles() {
    try {
      swetrix_track({ev: 'paidCycles', unique: false, meta: {amount: props.cyclesLedgerAmount!.toString()}});
      const bootstrapper = createBootstrapperActor(process.env.CANISTER_ID_BOOTSTRAPPER!, {agent})!;
      await bootstrapper.topUpCycles(); // FIXME@P3: Rename the function.
      props.updateCyclesAmount();
      props.updateCyclesLedgerAmount();
    }
    catch (e) {
      console.error(e);
      setError((e as object).toString());
    }
  }
  async function convertICPToCycles() {
    try {
      swetrix_track({ev: 'paidICP', unique: false, meta: {amount: props.icpAmount!.toString()}});
      const bootstrapper = createBootstrapperActor(process.env.CANISTER_ID_BOOTSTRAPPER!, {agent})!;
      await bootstrapper.topUpWithICP(); // FIXME@P3: Rename the function.
      props.updateCyclesAmount();
      props.updateICPAmount();
    }
    catch (e) {
      console.error(e);
      setError((e as object).toString());
    }
  }
  const renderTooltip = (props: any) => (
    <Tooltip {...props}>
      {copied ? 'Copied!' : 'Copy to clipboard'}
    </Tooltip>
  );
  return props.cyclesPaymentAddress !== undefined
    ? (
      <div>
        {/* <p>ICP balance: {props.icpAmount !== undefined ? `${String(props.icpAmount/10**8)}` : "Loading..."}</p> */}
        <p><strong>Warning: 5% fee applied.</strong></p>
        <p>Fund it with 13T cycles, at least.</p>
        <Tabs defaultActiveKey="icp">
          <Tab eventKey="icp" title="ICP">
            <p>ICP to top-up:{" "}
              {props.icpAmount !== undefined ? `${String(props.icpAmount/10**8)}` : "Loading..."}
              {" "}<Button onClick={convertICPToCycles}>Use</Button>
            </p>
            <p>
              Send ICP to{" "}
              <OverlayTrigger placement="right" overlay={renderTooltip}>
                <code style={{cursor: 'pointer'}} onClick={(e: React.MouseEvent) => {copyToClipboard(e)}}>{address}</code>
              </OverlayTrigger>
            </p>
            <p>
              You can use DFX command:{" "}
              <OverlayTrigger placement="right" overlay={renderTooltip}>
                {/* TODO: Do in backend. */}
                <code style={{cursor: 'pointer'}} onClick={(e: React.MouseEvent) => {copyToClipboard(e)}}>
                  {`dfx ledger --network ${process.env.DFX_NETWORK} transfer --to-principal ${address.replace(/-[^-]+\..*/, "")} --to-subaccount ${address.replace(/^[^.]*\./, "")} --memo 0 --amount`}
                  {" "}<em>AMOUNT</em>
                </code>
              </OverlayTrigger>
            </p>
            <p>TODO@P3: QR-code</p>
          </Tab>
          <Tab eventKey="cycles" title="Cycles">
            <p>Cycles to top-up:{" "}
              {props.cyclesLedgerAmount !== undefined ? `${String(props.cyclesLedgerAmount/10**12)}T` : "Loading..."}
              {" "}<Button onClick={topUpCycles}>Use</Button>
            </p>
            <p>
              Send cycles to{" "}
              <OverlayTrigger placement="right" overlay={renderTooltip}>
                <code style={{cursor: 'pointer'}} onClick={(e: React.MouseEvent) => {copyToClipboard(e)}}>{address}</code>
              </OverlayTrigger>
            </p>
            <p>
              You can use DFX command:{" "}
              <OverlayTrigger placement="right" overlay={renderTooltip}>
                {/* TODO: Do in backend. */}
                <code style={{cursor: 'pointer'}} onClick={(e: React.MouseEvent) => {copyToClipboard(e)}}>
                  {`dfx cycles --network ${process.env.DFX_NETWORK} transfer ${address.replace(/-[^-]+\..*/, "")} --to-subaccount ${address.replace(/^[^.]*\./, "")}`}
                  {" "}<em>CYCLES</em>
                </code>
              </OverlayTrigger>
            </p>
            <p>TODO@P3: QR-code</p>
          </Tab>
        </Tabs>
      </div>
    )
    : undefined;
}

function App2() {
  const {principal, ok, agent} = useAuth();
  const [cyclesAmount, setCyclesAmount] = useState<number | undefined>();
  const [cyclesLedgerAmount, setCyclesLedgerAmount] = useState<number | undefined>();
  const [icpAmount, setICPAmount] = useState<number | undefined>();
  const [paymentAddress, setPaymentAddress] = useState<string | undefined>();
  const bootstrapper = useMemo(() =>
    agent === undefined ? undefined : createBootstrapperActor(process.env.CANISTER_ID_BOOTSTRAPPER!, {agent}), // TODO@P3: or `defaultAgent`?
    [agent],
  );
  useEffect(() => {
    ok && swetrix_track({ev: 'bootstrapperLogin', unique: true});
  }, [ok]);
  // TODO@P3: below correct `!` usage?
  function updateCyclesAmount() {
    setCyclesAmount(undefined);
    if (principal === undefined || bootstrapper === undefined) {
      return;
    }
    bootstrapper.userCycleBalance().then((amount) => {
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
  function updateICPAmount() {
    setICPAmount(undefined);
    if (principal === undefined || bootstrapper === undefined) {
      return;
    }
    icp_ledger.icrc1_balance_of({
      owner: Principal.fromText(process.env.CANISTER_ID_BOOTSTRAPPER!),
      subaccount: [principalToSubAccount(principal!)],
    }).then((amount: bigint) => {
      setICPAmount(parseInt(amount.toString()));
    });
  }
  function updateAmounts(event: React.MouseEvent) {
    updateCyclesAmount();
    updateCyclesLedgerAmount();
    updateICPAmount();
    event.stopPropagation();
  }
  useEffect(updateCyclesAmount, [principal, bootstrapper]);
  useEffect(updateCyclesLedgerAmount, [principal, bootstrapper]);
  useEffect(updateICPAmount, [principal, bootstrapper]);
  // useEffect(updateICPAmount, [principal, bootstrapper]);
  useEffect(() => {
    if (bootstrapper !== undefined) {
      bootstrapper.userAccountText().then((t) => {
        setPaymentAddress(t);
      });
    }
  }, [bootstrapper]);
  const [showHelpLogin, setShowHelpLogin] = useState(false);
  return (
    <main id="main">
      <p style={{background: 'red', color: 'white', padding: "3px"}}>
        This is a beta version. We explicitly disclaim all warranties, express or implied, including but not limited to the implied warranties of merchantability and fitness for a particular purpose. We are not liable for any damages arising from use of this software. If your money is lost due to a software error, we have no obligation to refund it.
      </p>
      <h1 style={{textAlign: 'center'}}>
        <img src="/internet-computer-icp-logo.svg" alt="DFINITY logo" style={{width: '150px', display: 'inline'}} />
        {" "}
        Bootstrapper (Installer) of Package Manager
      </h1>
      <Container>
        <p>
          <a href="https://dev.package-manager.com">Docs</a> |{" "}
          <a href="#" onClick={(event) => {
            setShowHelpLogin(showHelpLogin => !showHelpLogin);
            event.preventDefault();
          }}>How to register/login (video)</a> |{" "}
          <a target="_blank" href="https://github.com/vporton/icp-package-manager">
              <img src="/github-mark.svg" width="24" height="24"/>
          </a>
        </p>
        <Modal show={showHelpLogin} onHide={() => setShowHelpLogin(false)} size="lg" centered>
          <Modal.Header closeButton>
            <Modal.Title>Login/Register Help</Modal.Title>
          </Modal.Header>
          <Modal.Body>
            <div className="ratio ratio-16x9">
              <iframe src="https://www.youtube.com/embed/oxEr8UzGeBo" title="Demo | Internet Identity: The End of Usernames and Passwords (Dominic Williams &amp; Joachim Breitner)" frameBorder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerPolicy="strict-origin-when-cross-origin" allowFullScreen></iframe>
            </div>
          </Modal.Body>
          <Modal.Footer>
            <Button variant="secondary" onClick={() => setShowHelpLogin(false)}>
              Close
            </Button>
          </Modal.Footer>
        </Modal>
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
                  <AddressPopup cyclesAmount={cyclesAmount} cyclesLedgerAmount={cyclesLedgerAmount} cyclesPaymentAddress={paymentAddress} icpAmount={icpAmount}
                    updateCyclesAmount={updateCyclesAmount} updateCyclesLedgerAmount={updateCyclesLedgerAmount} updateICPAmount={updateICPAmount}/>
                </Dropdown.Menu>
              </Dropdown>
              <a onClick={updateAmounts} style={{padding: '0', textDecoration: 'none', cursor: 'pointer'}}>&#x27F3;</a>
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
