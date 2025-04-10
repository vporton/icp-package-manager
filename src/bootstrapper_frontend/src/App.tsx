import { Container, Nav, Navbar } from 'react-bootstrap';
import 'bootstrap/dist/css/bootstrap.min.css';
import { AuthButton }  from './AuthButton';
import { AuthProvider, getIsLocal } from './auth/use-auth-client';
import MainPage from './MainPage';
import { BrowserRouter, Route, Routes } from 'react-router-dom';
import Bookmark from './Bookmark';
import { BusyProvider, BusyWidget } from '../../lib/busy';
import "../../lib/busy.css";

function App() {
  const identityProvider = getIsLocal() ? `http://${process.env.CANISTER_ID_INTERNET_IDENTITY}.localhost:4943` : `https://identity.ic0.app`;
  return (
    <BusyProvider>
      <BusyWidget>
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
      </BusyWidget>
    </BusyProvider>
  );
}

function App2() {
  return (
    <main id="main">
      <h1 style={{textAlign: 'center'}}>
        <img src="/internet-computer-icp-logo.svg" alt="DFINITY logo" style={{width: '150px', display: 'inline'}} />
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
        <BrowserRouter>
          <Routes>
            <Route path="/" element={<MainPage/>}/>
            <Route path="/bookmark" element={<Bookmark/>}/>
          </Routes>
        </BrowserRouter>        
      </Container>
    </main>
 );
}

export default App;
