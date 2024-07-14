import { useState } from 'react';
import { Button, Container, Nav, NavDropdown, Navbar } from 'react-bootstrap';
import { package_manager } from '../../declarations/package_manager';
import 'bootstrap/dist/css/bootstrap.min.css';
import { BrowserRouter, Route, Routes, useNavigate } from 'react-router-dom';
import { AuthButton }  from './AuthButton';
import { InternetIdentityProvider } from '@identity-labs/react-ic-ii-auth';
import { Link } from 'react-router-dom';
import process from 'process';

const packagesToRepair = [ // TODO
  {installationId: 3, name: "fineedit", version: "2.3.5"}
]

function App() {
  return (
    <BrowserRouter>
      <InternetIdentityProvider
        authClientOptions={{
          onSuccess: (identity) => console.log(
            ">> initialize your actors with", {identity}
          ),
          // FIXME
          // defaults to "https://identity.ic0.app/#authorize"
          identityProvider: `http://${process.env.CANISTER_ID_INTERNET_IDENTITY}.localhost:4943/#authorize`
        }}
      >
        <App2/>
      </InternetIdentityProvider>
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
          <Routes> {/* TODO: Refactor into sub-components. */}
            <Route path="/" element={
              <>
                <h2>Install</h2>
                <p>Copy the repository ID:{" "}
                {import.meta.env.CANISTER_ID_REPOSITORYINDEX}
                </p>
              </>}/>
            </Routes>
        </Container>
      </div>
    </main>
 );
}

export default App;
