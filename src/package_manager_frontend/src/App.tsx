import { useContext, useEffect, useState } from 'react';
import { Alert, Button, Container, Dropdown, Nav, NavDropdown, Navbar, OverlayTrigger, Tooltip } from 'react-bootstrap';
import { createActor as createBootstrapperActor } from '../../declarations/bootstrapper';
import 'bootstrap/dist/css/bootstrap.min.css';
import { BrowserRouter, Link, Route, Routes, useParams, useSearchParams } from 'react-router-dom';
import MainPage from './MainPage';
import ChooseVersion from './ChooseVersion';
import { useInternetIdentity } from "ic-use-internet-identity";
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
import { AuthProvider, useAuth } from '../../lib/use-auth-client';

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
        const {spentCycles: spentBackendStr} = await bootstrapperMainIndirect.bootstrapBackend({
          frontendTweakPrivKey: glob.frontendTweakPrivKey!,
          installedModules,
          user: principal!,
          additionalPackages: additionalPackages.map(v => {return {...v, arg: new Uint8Array(), initArg: []}}), // TODO@P3: Support `arg`.
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

    // TODO@P3: Start installation automatically, without clicking a button?
    return (
      <Container>
        <p>You first need to install the missing components (so called <q>backend</q>) for this software.
          This is just two buttons easy. You have around 45min to do this.</p>
        {spent !== undefined &&
              <Alert variant="info">You spent {Number(spent.toString()) / 10**12}T cycles for bootstrapping frontend.</Alert>
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
  const [cyclesAmount, setCyclesAmount] = useState<number | undefined>();
  const [cyclesPaymentAddress, setCyclesPaymentAddress] = useState<Uint8Array | undefined>();
  const glob = useContext(GlobalContext);
  function updateCyclesAmount() {
    setCyclesAmount(undefined);
    if (glob.packageManager === undefined) {
      return;
    } 
    glob.packageManager.getModulePrincipal(0n, 'battery').then((batteryPrincipal) => { // TODO@P3: Don't hardcode `installationId == 0n`.
      const battery = createBatteryActor(batteryPrincipal, {agent});
      battery.getBalance().then((amount) => {
        setCyclesAmount(parseInt(amount.toString()))
      });
    });
    // if (glob.packageManager !== undefined) {
    //   glob.packageManager.userBalance().then((amount) => {
    //     setCyclesAmount(parseInt(amount.toString()))
    //   });
    // }
  }
  useEffect(updateCyclesAmount, [glob.packageManager]);
  useEffect(() => {
    if (glob.packageManager !== undefined) {
      glob.packageManager.userAccountBlob().then((b) => {
        setCyclesPaymentAddress(b as Uint8Array);
      });
    }
  }, [glob.packageManager]);
  // const cyclesPaymentAddress = AccountIdentifier.fromPrincipal({ principal: Principal.fromText(process.env.CANISTER_ID_BATTERY!) });
  function AddressPopup() {
    const address = Buffer.from(cyclesPaymentAddress!).toString('hex');
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
    return cyclesPaymentAddress !== undefined
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
  return (
    <main id="main">
      <div>
        <Container>
          <nav style={{marginBottom: '1ex'}}>
            <Navbar className="bg-body-secondary" style={{width: "auto"}}>
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
                <AuthButton/>
              </Nav>
              <Nav style={{display: ok ? undefined : 'none'}}>
                <Dropdown>
                  <Dropdown.Toggle>
                    Cycles balance: {cyclesAmount !== undefined ? `${String(cyclesAmount/10**12)}T` : "Loading..."}{" "}
                  </Dropdown.Toggle>
                  <Dropdown.Menu>
                    <Dropdown.Item as="div">
                      <AddressPopup/>
                    </Dropdown.Item>
                  </Dropdown.Menu>
                </Dropdown>
                <a onClick={updateCyclesAmount} style={{padding: '0', textDecoration: 'none', cursor: 'pointer'}}>&#x27F3;</a>
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
            <Route path="*" element={<ErrorHandler error={"No such page"}/>}/>
          </Routes>
        </Container>
      </div>
    </main>
 );
}

export default App;
