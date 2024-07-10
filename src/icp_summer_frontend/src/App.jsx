import { useState } from 'react';
import { Button, Container, Nav, NavDropdown, Navbar } from 'react-bootstrap';
import { package_manager } from '../../declarations/package_manager';
import 'bootstrap/dist/css/bootstrap.min.css';
import { BrowserRouter, Route, Routes, useNavigate } from 'react-router-dom';

const packagesToRepair = [ // TODO
  {installationId: 3, name: "fineedit", version: "2.3.5"}
]

function App() {
  return <BrowserRouter><App2/></BrowserRouter>;
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
      <p style={{textAlign: 'center'}}>
        <img src="/internet-computer-icp-logo.png" alt="DFINITY logo" style={{width: '150px', display: 'inline'}} />
      </p>
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
            </Navbar>
          </nav>
          <Routes> {/* TODO: Refactor into sub-components. */}
            <Route path="/" element={
              <div>
                <form action="#" onSubmit={handleSubmit}>
                  <label htmlFor="name">Enter package name to install:</label>{" "}
                  <input id="name" alt="Name" type="text" />
                  <button type="submit">Start installation</button>
                </form>
                {packagesToRepair.length !== 0 ?
                  <>
                    <h2>Partially Installed</h2>
                    <ul>
                      {packagesToRepair.map(p =>
                        <li key={p.installationId}>
                          <input type='checkbox'/>{" "}
                          <code>{p.name}</code> {p.version}
                        </li>
                      )}
                    </ul>
                    <p><button>Install checked</button> <button>Delete checked</button></p>
                  </>
                  : ""}
                </div>}/>
              <Route path="/installed" element={
                <ul><code>photoedit</code> 3.5.6 <button>uninstall  </button></ul>
              }/>
            </Routes>
        </Container>
      </div>
    </main>
 );
}

export default App;
