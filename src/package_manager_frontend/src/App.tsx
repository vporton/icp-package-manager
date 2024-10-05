import { useContext, useState } from 'react';
import { Button, Container, Nav, NavDropdown, Navbar } from 'react-bootstrap';
import { bootstrapper } from '../../declarations/bootstrapper';
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

      const result = await bootstrapper.bootstrapBackend(glob.frontend!, firstPart); // TODO: `!`
      const backend_princ = result.canisterIds[0][1];
      const backend_str = backend_princ.toString();
      const base = getIsLocal() ? `http://${glob.frontend}.localhost:4943?` : `https://${glob.frontend}.icp0.io?`;
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
