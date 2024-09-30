import { useEffect, useState } from 'react';
import { Button, Container, Nav, NavDropdown, Navbar } from 'react-bootstrap';
import 'bootstrap/dist/css/bootstrap.min.css';
import { AuthButton }  from './AuthButton';
import { AuthContext, AuthProvider, getIsLocal } from './auth/use-auth-client';
import { Principal } from '@dfinity/principal';
import { Agent } from '@dfinity/agent';
import { createActor as createBootstrapperActor } from "../../declarations/bootstrapper";
import {  createActor as createBookmarkActor } from "../../declarations/bookmark";
import { Bookmark } from '../../declarations/bookmark/bookmark.did';
// TODO: Remove react-router dependency from this app

function App() {
  const identityProvider = getIsLocal() ? `http://${process.env.CANISTER_ID_INTERNET_IDENTITY}.localhost:4943` : `https://identity.ic0.app`;
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
  const [installations, setInstallations] = useState<Bookmark[]>([]);
  useEffect(() => {
    if (!props.isAuthenticated || props.agent === undefined) {
      setInstallations([]);
      return;
    }
    const bootstrapper = createBookmarkActor(process.env.CANISTER_ID_BOOKMARK!, {agent: props.agent});
    bootstrapper.getUserBookmarks().then(list => {
      setInstallations(list);
    });
  }, [props.isAuthenticated, props.principal]);
  async function bootstrap() {
    const bootstrapper = createBootstrapperActor(process.env.CANISTER_ID_BOOTSTRAPPER!, {agent: props.agent});
    const frontendPrincipal = await bootstrapper.bootstrapFrontend();
    // TODO: Wait till frontend is bootstrapped and go to it.
    const url = getIsLocal()
      ? `http://${frontendPrincipal}.localhost:4943`
      : `https://${frontendPrincipal}.ic0.app`;
    alert("You may need press reload (press F5) the page one or more times before it works."); // TODO
    open(url);
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
              <AuthButton/>
            </Nav>
          </Navbar>
        </nav>
        <p><Button disabled={!props.isAuthenticated} onClick={bootstrap}>Install Package Manager IC Pack</Button></p>
        <h2>Installed Package Manager</h2>
        {installations.length === 0 ? <i>None</i> :
          <ul>
            {installations.map(inst => {
              let url = `https://${inst.frontend}.ic0.app?backend=${inst.backend}`;
              return <li><a href={url}>{url}</a></li>;
            })}
          </ul>
        }
      </Container>
    </main>
 );
}

export default App;
