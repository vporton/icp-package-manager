import { useState } from 'react';
import { Button, Container, Nav, NavDropdown, Navbar } from 'react-bootstrap';
import 'bootstrap/dist/css/bootstrap.min.css';
import { AuthButton }  from './AuthButton';
import { AuthContext, AuthProvider } from './auth/use-auth-client';
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
        <AuthContext.Consumer>
          {({isAuthenticated}) =>
          <p><Button disabled={!isAuthenticated}>Install Package Manager IC Pack</Button></p>
        }
        </AuthContext.Consumer>
      </Container>
    </main>
 );
}

export default App;
