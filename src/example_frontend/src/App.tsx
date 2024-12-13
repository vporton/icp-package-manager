import { useContext, useState } from 'react';
import { Button, Container, Nav, NavDropdown, Navbar } from 'react-bootstrap';
import { createActor as createBootstrapperIndirectCallerActor } from '../../declarations/BootstrapperIndirectCaller';
import 'bootstrap/dist/css/bootstrap.min.css';
import { BrowserRouter, Route, Routes, useNavigate } from 'react-router-dom';
import MainPage from './MainPage';
import ChooseVersion from './ChooseVersion';
import { AuthProvider, useAuth, getIsLocal } from './auth/use-auth-client';
import InstalledPackages from './InstalledPackages';
import Installation from './Installation';
import { GlobalContext, GlobalContextProvider } from './state';
import { createActor as repoPartitionCreateActor } from '../../declarations/RepositoryPartition';
import { AuthButton } from './AuthButton';
import { Principal } from '@dfinity/principal';
import { RepositoryIndex } from '../../declarations/RepositoryIndex';
import { MyLink } from './MyNavigate';
import { createActor as createRepositoryIndexActor } from "../../declarations/RepositoryIndex";
import { createActor as createRepositoryPartitionActor } from "../../declarations/RepositoryPartition";
import { createActor as createBackendActor } from "../../declarations/package_manager";
import { createActor as createIndirectActor } from "../../declarations/BootstrapperIndirectCaller";
import { SharedPackageInfo, SharedRealPackageInfo } from '../../declarations/RepositoryPartition/RepositoryPartition.did';
import { IndirectCaller, RepositoryPartitionRO } from '../../declarations/BootstrapperIndirectCaller/BootstrapperIndirectCaller.did';
import { PackageManager } from '../../declarations/package_manager/package_manager.did';
// import { SharedHalfInstalledPackageInfo } from '../../declarations/package_manager';
import { IDL } from '@dfinity/candid';
import { ErrorBoundary, ErrorHandler } from "./ErrorBoundary";
import { ErrorProvider } from './ErrorContext';
// import { canister_status } from "@dfinity/ic-management";

function App() {
  const identityProvider = getIsLocal() ? `http://${process.env.CANISTER_ID_INTERNET_IDENTITY}.localhost:4943` : `https://identity.ic0.app`;
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
        <h1>Example</h1>
      </AuthProvider>
    </BrowserRouter>
  );
}

function GlobalUI() {
  const glob = useContext(GlobalContext);
  // const {isAuthenticated, agent, defaultAgent, principal} = useAuth();
  return <App2/>;
}

function App2() {
  return (
    <main id="main">
      <Container>
        <p>Test.</p>
      </Container>
    </main>
 );
}

export default App;
