import { useState } from 'react';
import { Button, Container, Nav, NavDropdown, Navbar } from 'react-bootstrap';
import { package_manager } from '../../declarations/package_manager';
import 'bootstrap/dist/css/bootstrap.min.css';
import { BrowserRouter, Route, Routes, useNavigate } from 'react-router-dom';
import { AuthButton }  from './AuthButton';
import { InternetIdentityProvider } from '@identity-labs/react-ic-ii-auth';
import { Link } from 'react-router-dom';
import MainPage from './MainPage';

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
            <Route path="/installed" element={
              <>
                <h2>Installed packages</h2>
                <ul className='checklist'>
                  <li><input type='checkbox'/> All <Button>Uninstall</Button> <Button>Upgrade</Button></li>
                  <li><input type='checkbox'/> <code>photoedit</code> <input type='checkbox'/> 3.5.6{" "}
                    (<input type='checkbox'/> <a href='#'>1</a>, <input type='checkbox'/> <a href='#'>2</a>),
                    {" "}<input type='checkbox'/> <a href='#'>3.5.7</a></li>
                  <li><input type='checkbox'/> <code>altcoin</code> 4.1.6</li>
                </ul>
              </>
            }/>
          </Routes>
        </Container>
      </div>
    </main>
 );
}

export default App;
