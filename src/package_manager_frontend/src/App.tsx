import { useContext, useEffect, useState } from 'react';
import { Button, Container, Dropdown, Nav, NavDropdown, Navbar, OverlayTrigger, Tooltip } from 'react-bootstrap';
import { createActor as createBootstrapperActor } from '../../declarations/bootstrapper';
import 'bootstrap/dist/css/bootstrap.min.css';
import { BrowserRouter, Link, Route, Routes, useSearchParams } from 'react-router-dom';
import MainPage from './MainPage';
import ChooseVersion from './ChooseVersion';
import { AuthProvider, useAuth, getIsLocal } from './auth/use-auth-client';
import InstalledPackages from './InstalledPackages';
import { GlobalContext, GlobalContextProvider } from './state';
import { AuthButton } from './AuthButton';
import { Principal } from '@dfinity/principal';
import { MyLink } from './MyNavigate';
import { createActor as createRepositoryIndexActor } from "../../declarations/repository";
import { createActor as createBackendActor } from "../../declarations/package_manager";
import { createActor as createIndirectActor } from "../../declarations/main_indirect";
import { SharedPackageInfo, SharedRealPackageInfo } from '../../declarations/repository/repository.did';
import { Bootstrapper } from '../../declarations/bootstrapper/bootstrapper.did';
import { MainIndirect, PackageManager } from '../../declarations/package_manager/package_manager.did';
import { ErrorBoundary, ErrorHandler } from "./ErrorBoundary";
import { ErrorProvider } from './ErrorContext';
import { waitTillInitialized } from '../../lib/install';
import InstalledPackage from './InstalledPackage';
import { BusyContext, BusyProvider, BusyWidget } from '../../lib/busy';
import "../../lib/busy.css";

function App() {
  const identityProvider = getIsLocal() ? `http://${process.env.CANISTER_ID_INTERNET_IDENTITY}.localhost:4943` : `https://identity.ic0.app`;
  return (
    <BusyProvider>
      <BusyWidget>
        <BrowserRouter>
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
  const {isAuthenticated, agent, defaultAgent, principal} = useAuth();
  const { setBusy } = useContext(BusyContext);
  const [searchParams, _] = useSearchParams();
  const installedModules: [string, Principal][] = JSON.parse(searchParams.get('modules')!);
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
        // TODO: Use "version" field from `additionalPackages`.
        await bootstrapperMainIndirect.bootstrapBackend({
          packageManagerOrBootstrapper: Principal.fromText(process.env.CANISTER_ID_BOOTSTRAPPER!), // TODO: Don't forget to remove it.
          frontendTweakPrivKey: glob.frontendTweakPrivKey!,
          installedModules,
          additionalPackages,
        });
        const installedModulesMap = new Map(installedModules);
        const backendPrincipal = installedModulesMap.get('backend')!;
        const installationId = 0n; // TODO
        const waitResult = await waitTillInitialized(agent!, backendPrincipal, installationId);
        if (waitResult !== undefined) {
          alert(waitResult);
          return;
        }

        const backend_str = backendPrincipal.toString();
        const base = getIsLocal() ? `http://${glob.frontend}.localhost:4943?` : `https://${glob.frontend}.icp0.io?`;
        open(`${base}_pm_pkg0.backend=${backend_str}`, '_self');
      }
      catch (e) {
        console.log(e); // TODO: Return an error.
      }
      finally {
        setBusy(false);
      }
    }
    // TODO: Start installation automatically, without clicking a button?
    return (
      <Container>
        <p>You first need to install the missing components (so called <q>backend</q>) for this software.
          This is just two buttons easy. You have around 45min to do this.</p>
        <ol>
          <li><AuthButton/></li>
          <li><Button disabled={!isAuthenticated} onClick={installBackend}>Install</Button></li>
        </ol>
      </Container>
    );
  }
  return <App2/>;
}

function App2() {
  const {isAuthenticated} = useAuth();
  const [cyclesAmount, setCyclesAmount] = useState<number | undefined>();
  const [cyclesPaymentAddress, setCyclesPaymentAddress] = useState<Uint8Array | undefined>();
  const glob = useContext(GlobalContext);
  function updateCyclesAmount() {
    setCyclesAmount(undefined); 
    if (glob.packageManager !== undefined) {
      glob.packageManager.userBalance().then((amount) => {
        setCyclesAmount(parseInt(amount.toString()))
      });
    }
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
        // TODO: `stopPropagation` doesn't work in some reason.
        <div onMouseDown={e => e.stopPropagation()} onMouseUp={e => e.stopPropagation()}>
          <p><strong>Warning: 5% fee applied.</strong></p>
          <p>
            Send cycles to{" "}
            <OverlayTrigger placement="right" overlay={renderTooltip}>
              <code style={{cursor: 'pointer'}} onClick={(e) => {copyToClipboard(); e.stopPropagation()}}>{address}</code>
            </OverlayTrigger>
          </p>
          <p>TODO: QR-code</p>
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
                <AuthButton/>
              </Nav>
              <Nav style={{display: isAuthenticated ? undefined : 'none'}}>
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
            <Route path="/choose-upgrade/:repo/:installationId" element={<ChooseVersion/>}/> {/* TODO: repo and packageName can be deduces from installationId */}
            <Route path="/installed" element={<InstalledPackages/>}/>
            <Route path="/installed/show/:installationId" element={<InstalledPackage/>}/>
            <Route path="*" element={<ErrorHandler error={"No such page"}/>}/>
          </Routes>
        </Container>
      </div>
    </main>
 );
}

export default App;
