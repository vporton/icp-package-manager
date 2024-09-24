import { useEffect, useState } from 'react';
import { Button, Container, Nav, NavDropdown, Navbar } from 'react-bootstrap';
import 'bootstrap/dist/css/bootstrap.min.css';
import { AuthButton }  from './AuthButton';
import { AuthContext, AuthProvider, getIsLocal } from './auth/use-auth-client';
import { Principal } from '@dfinity/principal';
import { Agent } from '@dfinity/agent';
import { bootstrapper, createActor as createBootstrapperActor } from "../../declarations/bootstrapper";
// TODO: Remove react-router dependency from this app

function App() {
  const identityProvider = getIsLocal() ? `http://${process.env.CANISTER_ID_INTERNET_IDENTITY}.localhost:3000` : `https://identity.ic0.app`;
  return (
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
      <App2/>
    </AuthProvider>
  );
}

function App2() {
  return (
    <AuthContext.Consumer>{
      ({isAuthenticated, principal, agent}) =>
        <App3 isAuthenticated={isAuthenticated} principal={principal} agent={agent}/>
      }
    </AuthContext.Consumer>
  );
}

function bootstrapPM() {
  const frontendPrincipal = bootstrapper.bootstrapFrontend();
  const url = getIsLocal()
    ? `http://${frontendPrincipal}.localhost:4943`
    : `https://${frontendPrincipal}.ic0.app`;
  open(url);
}

function App3(props: {isAuthenticated: boolean, principal: Principal | undefined, agent: Agent | undefined}) {
  const [installations, setInstallations] = useState<[Principal, Principal][]>([]);
  useEffect(() => {
    if (!props.isAuthenticated || props.agent === undefined) {
      setInstallations([]);
      return;
    }
    const bootstrapper = createBootstrapperActor(process.env.CANISTER_ID_BOOTSTRAPPER!, {agent: props.agent});
    bootstrapper.getUserPMInfo().then(list => {
      setInstallations(list);
    });
  }, [props.isAuthenticated, props.principal]);
  function bootstrap() {
    const bootstrapper = createBootstrapperActor(process.env.CANISTER_ID_BOOTSTRAPPER!, {agent: props.agent});
    bootstrapper.bootstrapFrontend();
    // TODO: Wait till frontend is bootstrapped and go to it.
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
              <AuthButton onClick={bootstrapPM}/>
            </Nav>
          </Navbar>
        </nav>
        <p><Button disabled={!props.isAuthenticated} onClick={bootstrap}>Install Package Manager IC Pack</Button></p>
        <h2>Installed Package Manager</h2>
        {installations.length === 0 && <i>None</i>}
        {installations.map(inst => `https://${inst[0]}.ic0.app?backend=${inst[1]}`)}
      </Container>
    </main>
 );
}

export default App;
