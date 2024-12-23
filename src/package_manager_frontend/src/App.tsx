import { useContext, useState } from 'react';
import { Button, Container, Nav, NavDropdown, Navbar } from 'react-bootstrap';
import { createActor as createBootstrapperActor } from '../../declarations/Bootstrapper';
import 'bootstrap/dist/css/bootstrap.min.css';
import { BrowserRouter, Route, Routes, useNavigate } from 'react-router-dom';
import MainPage from './MainPage';
import ChooseVersion from './ChooseVersion';
import { AuthProvider, useAuth, getIsLocal } from './auth/use-auth-client';
import InstalledPackages from './InstalledPackages';
import Installation from './Installation';
import { GlobalContext, GlobalContextProvider } from './state';
import { createActor as repoPartitionCreateActor } from '../../declarations/RepositoryPartition';
import { AuthButton } from './AuthButton';
import { Principal } from '@dfinity/principal';
import { RepositoryIndex } from '../../declarations/RepositoryIndex';
import { MyLink } from './MyNavigate';
import { createActor as createRepositoryIndexActor } from "../../declarations/RepositoryIndex";
import { createActor as createRepositoryPartitionActor } from "../../declarations/RepositoryPartition";
import { createActor as createBackendActor } from "../../declarations/package_manager";
import { createActor as createIndirectActor } from "../../declarations/indirect_caller";
import { SharedPackageInfo, SharedRealPackageInfo } from '../../declarations/RepositoryPartition/RepositoryPartition.did';
import { Bootstrapper } from '../../declarations/Bootstrapper/Bootstrapper.did';
import { IndirectCaller, PackageManager } from '../../declarations/package_manager/package_manager.did';
// import { SharedHalfInstalledPackageInfo } from '../../declarations/package_manager';
import { IDL } from '@dfinity/candid';
import { ErrorBoundary, ErrorHandler } from "./ErrorBoundary";
import { ErrorProvider } from './ErrorContext';
// import { canister_status } from "@dfinity/ic-management";

function App() {
  const identityProvider = getIsLocal() ? `http://${process.env.CANISTER_ID_INTERNET_IDENTITY}.localhost:4943` : `https://identity.ic0.app`;
  return (
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
  );
}

function GlobalUI() {
  const glob = useContext(GlobalContext);
  const {isAuthenticated, agent, defaultAgent, principal} = useAuth();
  if (glob.backend === undefined) {
    async function installBackend() {
      try {
        const repoIndex = createRepositoryIndexActor(process.env.CANISTER_ID_REPOSITORYINDEX!, {agent: defaultAgent});
        // TODO: Duplicate code
        const repoParts = await repoIndex.getCanistersByPK("main");
        let pkg: SharedPackageInfo | undefined = undefined;
        let repoPart: Principal | undefined;
        const jobs = repoParts.map(async part => {
          const obj = createRepositoryPartitionActor(part, {agent: defaultAgent});
          try {
            pkg = await obj.getPackage('icpack', "0.0.1"); // TODO: `"stable"`
            repoPart = Principal.fromText(part);
          }
          catch (_) {}
        });
        await Promise.all(jobs);
        const pkgReal = (pkg!.specific as any).real as SharedRealPackageInfo;

        // const backend: PackageManager = createPackageManagerActor(glob.backend, {agent: defaultAgent});
        // const installedInfo = await backend.getInstalledPackage(glob.packageInstallationId);
        // const indirectCaller = installedInfo.modules[2][1]; // TODO: explicit value

        const bootstrapperIndirectCaller: Bootstrapper = createBootstrapperActor(process.env.CANISTER_ID_BOOTSTRAPPER!, {agent})
        // TODO: Are here modules needed? They are installed below, instead?
        const {backendPrincipal, indirectPrincipal, simpleIndirectPrincipal} = await bootstrapperIndirectCaller.bootstrapBackend({
          backendWasmModule: pkgReal.modules[0][1][0], // TODO: explicit values
          indirectWasmModule: pkgReal.modules[2][1][0],
          simpleIndirectWasmModule: pkgReal.modules[3][1][0],
          user: principal!, // TODO: `!`
          packageManagerOrBootstrapper: Principal.fromText(process.env.CANISTER_ID_BOOTSTRAPPER!),
          frontendTweakPrivKey: glob.frontendTweakPrivKey!,
          frontend: glob.frontend!,
        });
        const backend: PackageManager = createBackendActor(backendPrincipal, {agent});
        await backend.installPackageWithPreinstalledModules({ // TODO: Move this to backend.
          whatToInstall: { package: null },
          packageName: "icpack",
          version: "0.0.1", // TODO: should be `stable`.
          preinstalledModules: [
            ["backend", backendPrincipal],
            ["frontend", glob.frontend!],
            ["indirect", indirectPrincipal],
            ["simple_indirect", simpleIndirectPrincipal],
          ],
          repo: repoPart!,
          user: principal!, // TODO: `!`
          indirectCaller: indirectPrincipal,
        });
        const installationId = 0n; // TODO
        const indirect: IndirectCaller = createIndirectActor(indirectPrincipal, {agent});
        for (let i = 0; ; ++i) {
          try {
            await Promise.all([
              backend.b44c4a9beec74e1c8a7acbe46256f92f_isInitialized(),
              indirect.b44c4a9beec74e1c8a7acbe46256f92f_isInitialized(),
            ]);
            break;
          }
          catch (e) {}
          if (i == 30) {
            alert("Cannot initilize canisters"); // TODO
            return;
          }
          await new Promise<void>((resolve, _reject) => {
            setTimeout(() => resolve(), 1000);
          });
        }
        for (let i = 0; ; ++i) {
          try {
            await backend.getInstalledPackage(installationId);
            break;
          }
          catch (e) {}
          if (i == 30) {
            alert("Cannot get installation info"); // TODO
            return;
          }
          await new Promise<void>((resolve, _reject) => {
            setTimeout(() => resolve(), 1000);
          });
        }

        const backend_str = backendPrincipal.toString();
        const base = getIsLocal() ? `http://${glob.frontend}.localhost:4943?` : `https://${glob.frontend}.icp0.io?`;
        open(`${base}backend=${backend_str}`, '_self');
      }
      catch (e) {
        console.log(e); // TODO: Return an error.
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
            </Navbar>
          </nav>
          <Routes>
            <Route path="/" element={<MainPage/>}/>
            <Route path="/choose-version/:repo/:packageName" element={<ChooseVersion/>}/>
            <Route path="/installed" element={<InstalledPackages/>}/>
            <Route path="/installed/show/:installationId" element={<Installation/>}/>
            <Route path="*" element={<ErrorHandler error={"No such page"}/>}/>
          </Routes>
        </Container>
      </div>
    </main>
 );
}

export default App;
