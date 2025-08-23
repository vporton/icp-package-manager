import { nns_ledger as icp_ledger } from '../../declarations/nns-ledger';
import { useContext, useEffect, useState } from 'react';
import Alert from 'react-bootstrap/Alert';
import Button from 'react-bootstrap/Button';
import Container from 'react-bootstrap/Container';
import Dropdown from 'react-bootstrap/Dropdown';
import Nav from 'react-bootstrap/Nav';
import Navbar from 'react-bootstrap/Navbar';
import OverlayTrigger from 'react-bootstrap/OverlayTrigger';
import Tab from 'react-bootstrap/Tab';
import Tabs from 'react-bootstrap/Tabs';
import Tooltip from 'react-bootstrap/Tooltip';
import { createActor as createBootstrapperActor } from '../../declarations/bootstrapper';
import 'bootstrap/dist/css/bootstrap.min.css';
import { BrowserRouter, Link, Route, Routes, useParams, useSearchParams } from 'react-router-dom';
import MainPage from './MainPage';
import ChooseVersion from './ChooseVersion';
import InstalledPackages from './InstalledPackages';
import { GlobalContext, GlobalContextProvider } from './state';
import { AuthButton } from '../../lib/AuthButton';
import { Principal } from '@dfinity/principal';
import { MyLink } from './MyNavigate';
import { createActor as createRepositoryIndexActor } from "../../declarations/repository";
import { createActor as createBatteryActor } from "../../declarations/battery";
import { SharedPackageInfo, SharedRealPackageInfo } from '../../declarations/repository/repository.did';
import { Bootstrapper } from '../../declarations/bootstrapper/bootstrapper.did';
import { ErrorBoundary, ErrorHandler } from "../../lib/ErrorBoundary";
import { ErrorContext, ErrorProvider } from '../../lib/ErrorContext';
import { waitTillInitialized } from '../../lib/install';
import InstalledPackage from './InstalledPackage';
import { BusyContext, BusyProvider, BusyWidget } from '../../lib/busy';
import "../../lib/busy.css";
import ModuleCycles from './ModuleCycles';
import { AuthProvider, getIsLocal, useAuth } from '../../lib/use-auth-client';
import { package_manager } from '../../declarations/package_manager';
import { cycles_ledger } from '../../declarations/cycles_ledger';
import { getPublicKeyFromPrivateKey, signPrincipal } from "../../../icpack-js";
import Settings from './Settings';

function App() {
  return (
    <BusyProvider>
      <BusyWidget>
        <BrowserRouter>
          <AuthProvider>
            <GlobalContextProvider>
              <h1 style={{textAlign: 'center'}}>
                <img src="/internet-computer-icp-logo.svg" alt="DFINITY logo" style={{width: '150px', display: 'inline'}} />
                {" "}
                Package Manager
              </h1>
              <ErrorProvider>
                <ErrorBoundary>
                  <GlobalUI/>
                </ErrorBoundary>
              </ErrorProvider>
            </GlobalContextProvider>
          </AuthProvider>
        </BrowserRouter>
      </BusyWidget>
    </BusyProvider>
  );
}


function GlobalUI() {
  const glob = useContext(GlobalContext);
  const spentStr: string | null = (new URLSearchParams(location.href)).get('spent');
  const spent = spentStr === null ? undefined : BigInt(spentStr);

  const {ok, agent, defaultAgent, principal} = useAuth();
  const { setBusy } = useContext(BusyContext);
  const { setError } = useContext(ErrorContext)!;
  const [searchParams, _] = useSearchParams();
  const moduleJSON = searchParams.get('modules');
  const installedModules: [string, Principal][] = moduleJSON !== null ?
    JSON.parse(moduleJSON).map(([s, p]: [string, string]) => [s, Principal.fromText(p)]) : undefined;
  if (glob.backend === undefined) {
    async function installBackend() {
      try {
        setBusy(true);
        const repoIndex = createRepositoryIndexActor(process.env.CANISTER_ID_REPOSITORY!, {agent: defaultAgent});
        let pkg: SharedPackageInfo = await repoIndex.getPackage('icpack', "stable");
        const pkgReal = (pkg!.specific as any).real as SharedRealPackageInfo;

        const bootstrapperMainIndirect: Bootstrapper = createBootstrapperActor(process.env.CANISTER_ID_BOOTSTRAPPER!, {agent});
        const modules = new Map(pkgReal.modules);
        const repo = Principal.fromText(process.env.CANISTER_ID_REPOSITORY!);
        const additionalPackages: {
          packageName: string;
          version: string;
          repo: Principal;
        }[] = searchParams.get('additionalPackages')
          ? JSON.parse(searchParams.get('additionalPackages')!)
            .map((p: any) => ({packageName: p.packageName, version: p.version, repo: Principal.fromText(p.repo)}))
          : [];
        const modulesJSON = searchParams.get('modules')!;
        const privKey = await window.crypto.subtle.importKey(
          "pkcs8", glob.frontendTweakPrivKey!, {name: 'ECDSA', namedCurve: 'P-256'/*prime256v1*/}, true, ["sign"]
        );
        const pubKeyUsable = await getPublicKeyFromPrivateKey(privKey);
        const signature = await signPrincipal(privKey, principal!);
        const {spentCycles: spentBackendStr} = await bootstrapperMainIndirect.bootstrapBackend({
          frontendTweakPubKey: new Uint8Array(await window.crypto.subtle.exportKey("spki", pubKeyUsable)),
          installedModules,
          user: principal!,
          signature: new Uint8Array(signature),
          additionalPackages,
        });
        const installedModulesMap = new Map(installedModules);
        const backendPrincipal = installedModulesMap.get('backend')!;
        const installationId = 0n; // TODO@P3
        const waitResult = await waitTillInitialized(agent!, backendPrincipal, installationId);
        if (waitResult !== undefined) {
          alert(waitResult);
          return;
        }

        const backend_str = backendPrincipal.toString();
        let base2 = `?_pm_pkg0.backend=${backend_str}`;
        if (modulesJSON !== undefined) {
          base2 += `&modules=${encodeURIComponent(modulesJSON)}`;
        }
        if (spentStr !== null) {
          base2 += `&spentFrontend=${spentStr}`;
        }
        const spentBackend = spentBackendStr === null ? undefined : BigInt(spentBackendStr);
        if (spentBackend !== undefined) {
          base2 += `&spentBackend=${spentBackend}`;
        }

        open(base2, '_self');
      }
      catch (e) {
        console.log(e);
        if (/Natural subtraction underflow/.test((e as object).toString())) {
          setError("Not enough cycles on the account. Please, add some cycles to your account and try again.");
        } else {
          setError((e as object).toString());
        }
      }
      finally {
        setBusy(false);
      }
    }

    let spentNum = spent !== undefined ? Number(spent.toString()) : undefined;
    if (getIsLocal() && spentNum !== undefined) {
      spentNum /= 0.95; // TODO@P3: hack
    }
    // TODO@P3: Start installation automatically, without clicking a button?
    return (
      <Container>
        <p>You first need to install the missing components (so called <q>backend</q>) for this software.
          This is just two buttons easy. You have around 45min to do this.</p>
        {getIsLocal() && spentNum !== undefined &&
              <Alert variant="info">You spent {spentNum / 10**12}T cycles for bootstrapping frontend.</Alert>
        }
        <ol>
          <li><AuthButton/></li>
          <li><Button disabled={!ok} onClick={installBackend}>Install</Button></li>
        </ol>
      </Container>
    );
  }
  return <App2/>;
}

function App2() {
  const {ok, agent} = useAuth();
  const {setError} = useContext(ErrorContext)!;
  const [cyclesAmount, setCyclesAmount] = useState<number | undefined>();
  const [cyclesLedgerAmount, setCyclesLedgerAmount] = useState<number | undefined>();
  const [icpAmount, setICPAmount] = useState<number | undefined>();
  const [cyclesPaymentAddress, setCyclesPaymentAddress] = useState<Principal | undefined>();
  const glob = useContext(GlobalContext);
  async function withdrawCycles() {
    try {
      // TODO@P3: `!`
      glob.packageManager!.getModulePrincipal(0n, 'battery').then((batteryPrincipal) => { // TODO@P3: Don't hardcode `installationId == 0n`.
        const battery = createBatteryActor(batteryPrincipal, {agent});
        battery.withdrawAllCycles().then(() => {
          updateCyclesAmount();
          updateCyclesLedgerAmount();
          // updateICPAmount();
        });
      });
    }
    catch (e) {
      console.error(e);
      setError((e as object).toString());
    }
  }
  async function convertICPToCycles() {
    try {
      // TODO@P3: `!`
      glob.packageManager!.getModulePrincipal(0n, 'battery').then((batteryPrincipal) => { // TODO@P3: Don't hardcode `installationId == 0n`.
        const battery = createBatteryActor(batteryPrincipal, {agent});
        battery.convertICPToCycles().then(() => {
          updateCyclesAmount();
          // updateCyclesLedgerAmount();
          updateICPAmount();
        });
      });
    }
    catch (e) {
      console.error(e);
      setError((e as object).toString());
    }
  }
  function updateCyclesAmount() {
    setCyclesAmount(undefined);
    if (glob.packageManager === undefined) {
      return;
    }
    glob.packageManager.getModulePrincipal(0n, 'battery').then((batteryPrincipal) => { // TODO@P3: Don't hardcode `installationId == 0n`.
      const battery = createBatteryActor(batteryPrincipal, {agent});
      battery.balance().then((amount) => {
        setCyclesAmount(parseInt(amount.toString()))
      });
    });
  }
  function updateCyclesLedgerAmount() {
    setCyclesLedgerAmount(undefined);
    if (glob.packageManager === undefined) {
      return;
    }
    glob.packageManager.getModulePrincipal(0n, 'battery').then((batteryPrincipal) => { // TODO@P3: Don't hardcode `installationId == 0n`.
      cycles_ledger.icrc1_balance_of({owner: batteryPrincipal, subaccount: []}).then((amount) => { // TODO@P3: Don't hardcode `installationId == 0n`.
        setCyclesLedgerAmount(parseInt(amount.toString()))
      });
    });
  }
  function updateICPAmount() {
    setICPAmount(undefined);
    if (glob.packageManager === undefined) {
      return;
    }
    glob.packageManager.getModulePrincipal(0n, 'battery').then((batteryPrincipal) => { // TODO@P3: Don't hardcode `installationId == 0n`.
      icp_ledger.icrc1_balance_of({owner: batteryPrincipal, subaccount: []}).then((amount) => { // TODO@P3: Don't hardcode `installationId == 0n`.
        setICPAmount(parseInt(amount.toString()))
      });
    });
  }
  function updateAllCyclesAmounts(event: React.MouseEvent) {
    updateCyclesAmount();
    updateCyclesLedgerAmount();
    updateICPAmount();
    event.stopPropagation(); // prevent closing the dropdown
  }
  useEffect(updateCyclesAmount, [glob.packageManager]);
  useEffect(updateCyclesLedgerAmount, [glob.backend]);
  useEffect(updateICPAmount, [glob.backend]);
  useEffect(() => {
    if (glob.packageManager !== undefined) {
      glob.packageManager.userAccountText().then((t) => {
        setCyclesPaymentAddress(t);
      });
    }
  }, [glob.packageManager]);
  function AddressPopup(props: {
    cyclesAmount: number | undefined,
    cyclesLedgerAmount: number | undefined,
    icpAmount: number | undefined,
    cyclesPaymentAddress: Principal | undefined,
    updateCyclesAmount: () => void;
    updateCyclesLedgerAmount: () => void;
    updateICPAmount: () => void;
  }) {
    const address = cyclesPaymentAddress!;
    const [copied, setCopied] = useState(false);
    const [activeTab, setActiveTab] = useState("icp");
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
    const renderTooltip = (props: any) => (
      <Tooltip {...props}>
        {copied ? 'Copied!' : 'Copy to clipboard'}
      </Tooltip>
    );
    return cyclesPaymentAddress !== undefined
      ? (
        <div>
          {/* <p>ICP balance: {props.icpAmount !== undefined ? `${String(props.icpAmount/10**8)}` : "Loading..."}</p> */}
          <p><strong>Warning: 5% fee applied.</strong></p>
          <Tabs activeKey={activeTab} onSelect={(k) => setActiveTab(k || "icp")}>
            <Tab eventKey="icp" title="ICP">
              <p>ICP to top-up:{" "}
                {props.icpAmount !== undefined ? `${String(props.icpAmount/10**8)}` : "Loading..."}
                {" "}<Button onClick={convertICPToCycles}>Use</Button>
              </p>
              <p>
                Send ICP to{" "}
                <OverlayTrigger placement="right" overlay={renderTooltip}>
                  <code style={{cursor: 'pointer'}} onClick={(e: React.MouseEvent) => {copyToClipboard(e)}}>{address.toText()}</code>
                </OverlayTrigger>
              </p>
              <p>
                You can use DFX command:{" "}
                <OverlayTrigger placement="right" overlay={renderTooltip}>
                  <code style={{cursor: 'pointer'}} onClick={(e: React.MouseEvent) => {copyToClipboard(e)}}>
                    {`dfx ledger --network ${process.env.DFX_NETWORK} transfer --memo 0 --to-principal ${address.toText().replace(/-[^-]+\..*/, "")} --amount`}
                    {" "}<em>AMOUNT</em>
                  </code>
                </OverlayTrigger>
              </p>
              <p>TODO@P3: QR-code</p>
            </Tab>
            <Tab eventKey="cycles" title="Cycles">
              <p>Cycles to top-up:{" "}
                {props.cyclesLedgerAmount !== undefined ? `${String(props.cyclesLedgerAmount/10**12)}T` : "Loading..."}
                {" "}<Button onClick={withdrawCycles}>Use</Button>
              </p>
              <p>
                Send cycles to{" "}
                <OverlayTrigger placement="right" overlay={renderTooltip}>
                  <code style={{cursor: 'pointer'}} onClick={(e: React.MouseEvent) => {copyToClipboard(e)}}>{address.toText()}</code>
                </OverlayTrigger>
              </p>
              <p>
                You can use DFX command:{" "}
                <OverlayTrigger placement="right" overlay={renderTooltip}>
                  <code style={{cursor: 'pointer'}} onClick={(e: React.MouseEvent) => {copyToClipboard(e)}}>
                    {`dfx cycles transfer ${address.toText()}`} <em>CYCLES</em>
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
  return (
    <main id="main">
      <div>
        <Container>
          <nav style={{marginBottom: '1ex'}}>
            <Navbar className="bg-body-secondary wrap-flex" style={{width: "auto"}}>
              <Nav>
                <MyLink className="nav-link" to="/">Main page</MyLink>
              </Nav>
              <Nav>
                <MyLink className="nav-link" to="/installed">Installed packages</MyLink>
              </Nav>
              <Nav>
                <MyLink className="nav-link" to="/cycles/modules">Cycles</MyLink>
              </Nav>
              <Nav>
                <MyLink className="nav-link" to="/settings">Settings</MyLink>
              </Nav>
              <Nav>
                <AuthButton/>
              </Nav>
              <Nav style={{display: ok ? undefined : 'none'}}>
                <Dropdown>
                  <Dropdown.Toggle>
                    Cycles balance: {cyclesAmount !== undefined ? `${String(cyclesAmount/10**12)}T` : "Loading..."}{" "}
                  </Dropdown.Toggle>
                  <Dropdown.Menu style={{padding: '10px'}}>
                    <AddressPopup cyclesAmount={cyclesAmount} cyclesLedgerAmount={cyclesLedgerAmount} icpAmount={icpAmount} cyclesPaymentAddress={cyclesPaymentAddress}
                      updateCyclesAmount={updateCyclesAmount} updateCyclesLedgerAmount={updateCyclesLedgerAmount} updateICPAmount={updateICPAmount}/>
                  </Dropdown.Menu>
                </Dropdown>
                <a onClick={updateAllCyclesAmounts} style={{padding: '0', textDecoration: 'none', cursor: 'pointer'}}>&#x27F3;</a>{" "}
              </Nav>
              <Nav className="ms-auto">
                <a target="_blank" href="https://github.com/vporton/icp-package-manager" style={{marginRight: '0.5em'}}>
                    <img src="/github-mark.svg" width="24" height="24"/>
                </a>
              </Nav>
            </Navbar>
          </nav>
          <Routes>
            <Route path="/" element={<MainPage/>}/>
            <Route path="/choose-version/:repo/:packageName" element={<ChooseVersion/>}/>
            <Route path="/choose-upgrade/:repo/:installationId" element={<ChooseVersion/>}/> {/* TODO@P3: repo and packageName can be deduces from installationId */}
            <Route path="/installed" element={<InstalledPackages/>}/>
            <Route path="/installed/show/:installationId" element={<InstalledPackage/>}/>
            <Route path="/cycles/modules" element={<ModuleCycles/>}/>
            <Route path="/settings" element={<Settings/>}/>
            <Route path="*" element={<ErrorHandler error={"No such page"}/>}/>
          </Routes>
        </Container>
      </div>
    </main>
 );
}

export default App;
