import { useState } from 'react';
import { Button, Container, Nav, NavDropdown, Navbar } from 'react-bootstrap';
import { package_manager } from '../../declarations/package_manager';
import 'bootstrap/dist/css/bootstrap.min.css';
import { BrowserRouter, Route, Routes, useNavigate } from 'react-router-dom';
import { AuthButton }  from './AuthButton';
import { InternetIdentityProvider } from '@internet-identity-labs/react-ic-ii-auth';
import { Link } from 'react-router-dom';
import { AuthProvider } from './auth/use-auth-client';

const packagesToRepair = [ // TODO
  {installationId: 3, name: "fineedit", version: "2.3.5"}
]

function App() {
  const identityProvider = true ? `http://${process.env.CANISTER_ID_INTERNET_IDENTITY}.localhost:4943` : `https://identity.ic0.app`; // FIXME
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
        <App2/>
      </AuthProvider>
    </BrowserRouter>
  );
}

function App2() {
  const navigate = useNavigate();

  return (
    <main id="main">
      <h1 style={{textAlign: 'center'}}>
        <img src="/internet-computer-icp-logo.png" alt="DFINITY logo" style={{width: '150px', display: 'inline'}} />
        {" "}
        Packages Repository
      </h1>
      <div>
        <Container>
          <p><AuthButton/></p>
          <Routes> {/* TODO: Refactor into sub-components. */}
            <Route path="/" element={
              <>
                <h2>Install</h2>
                <p>Copy the repository ID:{" "}
                {process.env.CANISTER_ID_REPOSITORYINDEX}
                </p>
              </>}/>
            </Routes>
        </Container>
      </div>
    </main>
 );
}

export default App;
