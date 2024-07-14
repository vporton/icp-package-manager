import { useState } from 'react';
import { Button, Container, Nav, NavDropdown, Navbar } from 'react-bootstrap';
import { package_manager } from '../../declarations/package_manager';
import 'bootstrap/dist/css/bootstrap.min.css';
import { BrowserRouter, Route, Routes, useNavigate } from 'react-router-dom';
import { AuthButton }  from './AuthButton';
import { InternetIdentityProvider } from '@identity-labs/react-ic-ii-auth';
import { Link } from 'react-router-dom';

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
            <Route path="/" element={
              <>
                <h2>Distribution</h2>
                <p>
                  Distro:{" "}
                  <select>
                    <option>RedSocks</option>
                    <option>Batuto</option>
                    <option>Bedian</option>
                  </select>{" "}
                  <Button>Remove from the list</Button> (doesn't remove installed packages)
                </p>
                <p><Button>Add distro</Button></p>
                <h2>Install</h2>
                <form action="#" onSubmit={() => {}}>
                  <label htmlFor="name">Enter package name to install:</label>{" "}
                  <input id="name" alt="Name" type="text" />{" "}
                  <Button type="submit">Start installation</Button>
                </form>
                {packagesToRepair.length !== 0 ?
                  <>
                    <h2>Partially Installed</h2>
                    <ul className='checklist'>
                      {packagesToRepair.map(p =>
                        <li key={p.installationId}>
                          <input type='checkbox'/>{" "}
                          <code>{p.name}</code> {p.version}
                        </li>
                      )}
                    </ul>
                    <p><Button>Install checked</Button> <Button>Delete checked</Button></p>
                  </>
                  : ""}
                </>}/>
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
