import { useState } from 'react';
import { Button, Container, Nav, NavDropdown, Navbar } from 'react-bootstrap';
import 'bootstrap/dist/css/bootstrap.min.css';
import { BrowserRouter, Route, Routes } from 'react-router-dom';
import { AuthButton }  from './AuthButton';
import { InternetIdentityProvider } from 'ic-use-internet-identity';
import { AuthProvider } from './auth/use-auth-client';
import { myUseNavigate } from "./MyNavigate";

function App() {
  const identityProvider = true ? `http://${process.env.CANISTER_ID_INTERNET_IDENTITY}.localhost:4943` : `https://identity.internetcomputer.org`;
  return (
    <BrowserRouter>
      <InternetIdentityProvider>
        <App2/>
      </InternetIdentityProvider>
    </BrowserRouter>
  );
}

function App2() {
  const navigate = myUseNavigate();

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
          <Routes> {/* TODO@P3: Refactor into sub-components. */}
            <Route path="/" element={
              <>
                <h2>Install</h2>
                <p>Copy the repository ID:{" "}
                {process.env.CANISTER_ID_REPOSITORY}
                </p>
              </>}/>
            </Routes>
        </Container>
      </div>
    </main>
 );
}

export default App;
