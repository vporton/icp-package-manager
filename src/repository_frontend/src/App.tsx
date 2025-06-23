import Container from 'react-bootstrap/Container';
import 'bootstrap/dist/css/bootstrap.min.css';
import { BrowserRouter, Route, Routes } from 'react-router-dom';
import { AuthButton }  from './AuthButton';
import { AuthProvider } from 'ic-use-internet-identity';

function App() {
  return (
    <BrowserRouter>
      <AuthProvider>
        <App2 />
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
        Packages Repository
      </h1>
      <div>
        <Container>
          <p><AuthButton/></p>
          <Routes> {/* TODO@P3: Refactor into sub-components. */}
            <Route
              path="/"
              element={
                <>
                  <h2>Install</h2>
                  <p>Copy the repository ID: {process.env.CANISTER_ID_REPOSITORY}</p>
                </>
              }
            />
          </Routes>
        </Container>
      </div>
    </main>
 );
}

export default App;
