import { useContext, useState } from 'react';
import { Button, Container, Nav, NavDropdown, Navbar } from 'react-bootstrap';
import { createActor as createBootstrapperIndirectCallerActor } from '../../declarations/BootstrapperIndirectCaller';
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
import { SharedPackageInfo, SharedRealPackageInfo } from '../../declarations/RepositoryPartition/RepositoryPartition.did';
import { RepositoryPartitionRO } from '../../declarations/BootstrapperIndirectCaller/BootstrapperIndirectCaller.did';

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
          <GlobalUI/>
        </GlobalContextProvider>
      </AuthProvider>
    </BrowserRouter>
  );
}

function GlobalUI() {
  const glob = useContext(GlobalContext);
  const {isAuthenticated, agent, defaultAgent, principal} = useAuth();
  const repoIndex = createRepositoryIndexActor(process.env.CANISTER_ID_REPOSITORYINDEX!, {agent: defaultAgent});
  if (glob.backend === undefined) {
    async function installBackend() {
      // TODO: Duplicate code
      const repoParts = await repoIndex.getCanistersByPK("main");
      let pkg: SharedPackageInfo | undefined = undefined;
      let repo: RepositoryPartitionRO | undefined;
      const jobs = repoParts.map(async part => {
        const obj = createRepositoryPartitionActor(part, {agent: defaultAgent});
        try {
          pkg = await obj.getPackage('icpack', "0.0.1"); // TODO: `"stable"`
          repo = obj;
        }
        catch (_) {}
      });
      await Promise.all(jobs);
      const pkgReal = (pkg!.specific as any).real as SharedRealPackageInfo;

      const indirectCaller = createBootstrapperIndirectCallerActor(process.env.CANISTER_ID_BOOTSTRAPPERINDIRECTCALLER!, {agent})
      const {backendPrincipal} = await indirectCaller.bootstrapBackend({
        frontend: glob.frontend!, // TODO: `!`
        backendWasmModule: pkgReal.modules[1][1][0], // TODO: explicit values
        indirectWasmModule: pkgReal.modules[2][1][0],
        user: principal!, // TODO: `!`
        repo: Principal.from(repo!), // TODO: `!`
      });
      console.log("backendPrincipal", backendPrincipal); // FIXME: Remove.

      const backend_str = backendPrincipal.toString();
      // TODO: busy indicator
      // for (let i = 0;; ++i) { // TODO: Choose the value.
      //   if (i == 20) {
      //     alert("Module failed to initialize"); // TODO: better dialog
      //     return;
      //   }
      //   try {
      //     const initialized = await backendRO.b44c4a9beec74e1c8a7acbe46256f92f_isInitialized();
      //     if (initialized) {
      //       break;
      //     }
      //   }
      //   catch (e) {
      //     // TODO: more detailed error check
      //   }
      // }
      const base = getIsLocal() ? `http://${glob.frontend}.localhost:4943?` : `https://${glob.frontend}.icp0.io?`;
      open(`${base}backend=${backend_str}`, '_self');
    }
    // TODO: Start installation automatically, without clicking a button?
    return (
      <Container>
        <p>You first need to install the missing components (so called <q>backend</q>) for this software.
          This is just two buttons easy.</p>
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
          </Routes>
        </Container>
      </div>
    </main>
 );
}

export default App;
