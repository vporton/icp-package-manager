import { useState } from 'react';
import { Button, Container, Nav, NavDropdown, Navbar } from 'react-bootstrap';
import { package_manager } from '../../declarations/package_manager';
import 'bootstrap/dist/css/bootstrap.min.css';
import { BrowserRouter, Route, Routes, useNavigate } from 'react-router-dom';
import { AuthButton }  from './AuthButton';
import { InternetIdentityProvider } from '@identity-labs/react-ic-ii-auth';
import { Link } from 'react-router-dom';
import MainPage from './MainPage';
import ChooseVersion from './ChooseVersion';
import { AuthProvider } from './auth/use-auth-client';
import InstalledPackages from './InstalledPackages';

function App() {
  const identityProvider = true ? `http://${import.meta.env.CANISTER_ID_INTERNET_IDENTITY}.localhost:8000` : `https://identity.ic0.app`; // FIXME
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
      {/* <InternetIdentityProvider
        authClientOptions={{
          onSuccess: (identity) => console.log(
            ">> initialize your actors with", {identity}
          ),
          // FIXME
          // defaults to "https://identity.ic0.app/#authorize"
          identityProvider: `http://${process.env.CANISTER_ID_INTERNET_IDENTITY}.localhost:4943/#authorize`
        }}
      > */}
        <App2/>
      </AuthProvider>
    </BrowserRouter>
  );
}

function App2() {
  return (
    <main id="main">
      <h1 style={{textAlign: 'center'}}>
        <img src="/internet-computer-icp-logo.png" alt="DFINITY logo" style={{width: '150px', display: 'inline'}} />
        {" "}
        Package Manager
      </h1>
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
          <Routes> {/* TODO: Refactor into sub-components. */}
            <Route path="/" element={<MainPage/>}/>
            <Route path="/choose-version/:packageName" element={<ChooseVersion/>}/>
            <Route path="/installed" element={<InstalledPackages/>}/>
          </Routes>
        </Container>
      </div>
    </main>
 );
}

export default App;
