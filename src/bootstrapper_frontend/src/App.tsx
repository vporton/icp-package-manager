import { useEffect, useState } from 'react';
import { Button, Container, Nav, NavDropdown, Navbar } from 'react-bootstrap';
import 'bootstrap/dist/css/bootstrap.min.css';
import { AuthButton }  from './AuthButton';
import { AuthContext, AuthProvider } from './auth/use-auth-client';
import { Principal } from '@dfinity/principal';
import { Agent } from '@dfinity/agent';
// TODO: Remove react-router from this app

function App() {
  const identityProvider = true ? `http://${process.env.CANISTER_ID_INTERNET_IDENTITY}.localhost:4943` : `https://identity.ic0.app`; // FIXME
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

function App3(props: {isAuthenticated: boolean, principal: Principal | undefined, agent: Agent | undefined}) {
  const [installations, setInstallations] = useState<{pmFrontend: Principal; pmBackend: Principal}[]>([]);
  useEffect(() => {
    if (!props.isAuthenticated) {
      setInstallations([]);
      return;
    }
    // props.agent!.
    // TODO
  }, [props.isAuthenticated, props.principal]);
  return (
    <main id="main">
      <h1 style={{textAlign: 'center'}}>
        <img src="/internet-computer-icp-logo.png" alt="DFINITY logo" style={{width: '150px', display: 'inline'}} />
        {" "}
        Bootstrapper (Installer) of Package Manager
      </h1>
      <Container>
        <nav>
          <Navbar className="bg-body-secondary" style={{width: "auto"}}>
            <Nav>
              <AuthButton/>
            </Nav>
          </Navbar>
        </nav>
        <p><Button disabled={!props.isAuthenticated}>Install Package Manager IC Pack</Button></p>
        <h2>Installed Package Manager</h2>
      </Container>
    </main>
 );
}

export default App;
