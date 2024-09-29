import { useContext, useState } from 'react';
import { Button, Container, Nav, NavDropdown, Navbar } from 'react-bootstrap';
import { bootstrapper } from '../../declarations/bootstrapper';
import 'bootstrap/dist/css/bootstrap.min.css';
import { BrowserRouter, Route, Routes, useNavigate } from 'react-router-dom';
import { InternetIdentityProvider } from '@internet-identity-labs/react-ic-ii-auth';
import { Link } from 'react-router-dom';
import MainPage from './MainPage';
import ChooseVersion from './ChooseVersion';
import { AuthProvider, useAuth, getIsLocal } from './auth/use-auth-client';
import InstalledPackages from './InstalledPackages';
import Installation from './Installation';
import { GlobalContext, GlobalContextProvider } from './state';
import { createActor as pmCreateActor } from '../../declarations/package_manager';
import { createActor as repoPartitionCreateActor } from '../../declarations/RepositoryPartition';
import { AuthButton } from './AuthButton';
import { Principal } from '@dfinity/principal';
import { RepositoryIndex } from '../../declarations/RepositoryIndex';

function App() {
  const identityProvider = true ? `http://${process.env.CANISTER_ID_INTERNET_IDENTITY}.localhost:4943` : `https://identity.ic0.app`; // FIXME
  return (
    <BrowserRouter>
      <GlobalContextProvider>
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
          <h1 style={{textAlign: 'center'}}>
            <img src="/internet-computer-icp-logo.svg" alt="DFINITY logo" style={{width: '150px', display: 'inline'}} />
            {" "}
            Package Manager
          </h1>
          <GlobalUI/>
        </AuthProvider>
      </GlobalContextProvider>
    </BrowserRouter>
  );
}

function GlobalUI() {
  const glob = useContext(GlobalContext);
  const {isAuthenticated, defaultAgent} = useAuth();
  if (glob.backend === undefined) {
    async function installBackend() {
      // TODO: hack
      const parts = (await RepositoryIndex.getCanistersByPK('main'))
        .map(s => Principal.fromText(s))
      const foundParts = await Promise.all(parts.map(part => {
        try {
          const part2 = repoPartitionCreateActor(part, {agent: defaultAgent});
          part2.getPackage("icpack", "0.0.1"); // TODO: Don't hardcode.
          return part;
        }
        catch(_) { // TODO: Check error.
          return null;
        }
      }));
      const firstPart = foundParts.filter(v => v !== null)[0];
      console.log("firstPart1", firstPart.toText()); // TODO: Remove.

      const result = await bootstrapper.bootstrapBackend(glob.frontend!, firstPart); // TODO: `!`
      const backend_princ = result.canisterIds[0][1];
      const backend_str = backend_princ.toString();
      const backendRO = pmCreateActor(backend_princ, {agent: defaultAgent}); // FIXME: Whqt happens if no WASM yet?
      const base = getIsLocal() ? `http://localhost:4943?canisterId=${glob.frontend}&` : `https://${glob.frontend}.icp0.io?`;
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
      open(`${base}backend=${backend_str}&bookmarkMsg=1`); // TODO: Don't open new tab.
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
          <nav>
            <Navbar className="bg-body-secondary" style={{width: "auto"}}>
              <Nav>
                <Link className="nav-link" to="/">Main page</Link>
              </Nav>
              <Nav>
                <Link className="nav-link" to="/installed">Installed packages</Link>
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
