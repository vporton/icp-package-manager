import { useState } from 'react';
import { Button, Container, Nav, NavDropdown, Navbar } from 'react-bootstrap';
import { package_manager } from '../../declarations/package_manager';
import 'bootstrap/dist/css/bootstrap.min.css';
import { BrowserRouter, Route, Routes, useNavigate } from 'react-router-dom';
import LoginButton from './LoginButton';
import { InternetIdentityProvider } from "ic-use-internet-identity";

const packagesToRepair = [ // TODO
  {installationId: 3, name: "fineedit", version: "2.3.5"}
]

function App() {
  return (
    <BrowserRouter>
      <InternetIdentityProvider>
        <App2/>
      </InternetIdentityProvider>
    </BrowserRouter>
  );
}

function App2() {
  const [greeting, setGreeting] = useState('');

  function handleSubmit(event) {
    event.preventDefault();
    const name = event.target.elements.name.value;
    package_manager.greet(name).then((greeting) => {
      setGreeting(greeting);
    });
    return false;
  }

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
                <Nav.Link onClick={() => navigate("/")}>Main page</Nav.Link>{" "}
              </Nav>
              <Nav>
                <Nav.Link onClick={() => navigate("/installed")}>Installed packages</Nav.Link>{" "}
              </Nav>
              <Nav>
                <LoginButton/>
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
                <form action="#" onSubmit={handleSubmit}>
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
