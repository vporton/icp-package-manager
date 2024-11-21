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
        <GlobalContextProvider>
          <h1 style={{textAlign: 'center'}}>
            <img src="/internet-computer-icp-logo.svg" alt="DFINITY logo" style={{width: '150px', display: 'inline'}} />
            {" "}
            Package Manager
          </h1>
          <GlobalUI/>
        </GlobalContextProvider>
      </AuthProvider>
    </BrowserRouter>
  );
}

function GlobalUI() {
  const glob = useContext(GlobalContext);
  const {isAuthenticated, agent, defaultAgent, principal} = useAuth();
  const repoIndex = createRepositoryIndexActor(process.env.CANISTER_ID_REPOSITORYINDEX!, {agent: defaultAgent});
  if (glob.backend === undefined) {
    async function installBackend() {
      // TODO: Duplicate code
      const repoParts = await repoIndex.getCanistersByPK("main");
      let pkg: SharedPackageInfo | undefined = undefined;
      let repoPart: Principal | undefined;
      const jobs = repoParts.map(async part => {
        const obj = createRepositoryPartitionActor(part, {agent: defaultAgent});
        try {
          pkg = await obj.getPackage('icpack', "0.0.1"); // TODO: `"stable"`
          repoPart = Principal.fromText(part);
        }
        catch (_) {}
      });
      await Promise.all(jobs);
      const pkgReal = (pkg!.specific as any).real as SharedRealPackageInfo;

      // const backend: PackageManager = createPackageManagerActor(glob.backend, {agent: defaultAgent});
      // const installedInfo = await backend.getInstalledPackage(glob.packageInstallationId);
      // const indirectCaller = installedInfo.modules[2][1]; // TODO: explicit value

      const bootstrapperIndirectCaller: IndirectCaller = createBootstrapperIndirectCallerActor(process.env.CANISTER_ID_BOOTSTRAPPERINDIRECTCALLER!, {agent})
      // TODO: Are here modules needed? They are installed below, instead?
      const {backendPrincipal, indirectPrincipal} = await bootstrapperIndirectCaller.bootstrapBackend({
        frontend: glob.frontend!, // TODO: `!`
        backendWasmModule: pkgReal.modules[0][1][0], // TODO: explicit values
        indirectWasmModule: pkgReal.modules[2][1][0],
        user: principal!, // TODO: `!`
        repo: repoPart!, // TODO: `!`
        packageManagerOrBootstrapper: principal!,
      });
      console.log(`backendPrincipal = ${backendPrincipal}`);
      const backend: PackageManager = createBackendActor(backendPrincipal, {agent}); // TODO: `defaultAgent` instead?
      await backend.installPackageWithPreinstalledModules({
        whatToInstall: { package: null },
        packageName: "icpack",
        version: "0.0.1", // TODO: should be `stable`.
        preinstalledModules: [["backend", backendPrincipal], ["frontend", glob.frontend!], ["indirect", indirectPrincipal]],
        repo: repoPart!,
        user: principal!, // TODO: `!`
        indirectCaller: indirectPrincipal,
      });
      const installationId = 0n; // FIXME
      const indirect: IndirectCaller = createIndirectActor(indirectPrincipal, {agent});
      console.log("P1");
      for (let i = 0; ; ++i) {
        try {
          // const p2: [string, Principal][] = await canister_status({
          //   canister_id: backendPrincipal,
          // });
          console.log("P2");
          /*const r = */await Promise.all([
            backend.b44c4a9beec74e1c8a7acbe46256f92f_isInitialized(),
            indirect.b44c4a9beec74e1c8a7acbe46256f92f_isInitialized(),
          ]);
          // console.log("PX:", r);
          console.log("P3");
          break;
        }
        catch (e) {
          console.log("RRR", e); // FIXME: Remove.
        }
        if (i == 30) {
          alert("Cannot initilize canisters"); // TODO
          return;
        }
        await new Promise<void>((resolve, _reject) => {
          setTimeout(() => resolve(), 1000);
        });
      }
      console.log("P4");
      for (const [name, [m, dfn]] of pkgReal.modules) { // FIXME
        if (!dfn) {
          continue;
        }
        // Starting installation of all modules in parallel:
        indirect/*bootstrapperIndirectCaller*/.installModule({
          installPackage: true,
          moduleName: [name],
          installArg: new Uint8Array(IDL.encode([IDL.Record({})], [{}])),
          installationId,
          packageManagerOrBootstrapper: backendPrincipal,
          // "backend" goes first, because it stores installation information.
          preinstalledCanisterId: [{"backend": backendPrincipal, "frontend": glob.frontend, "indirect": indirectPrincipal}[name]!],
          user: principal!, // TODO: `!`
          wasmModule: m,
          noPMBackendYet: false, // HACK
        });
      };
      console.log("P5");
      for (let i = 0; ; ++i) {
        try {
          console.log("P6");
          const p2: [string, Principal][] = await backend.getHalfInstalledPackageModulesById(installationId);
          console.log("P7");
          console.log("UUU", p2); // FIXME: Remove.
          if (p2 && p2.length == 3) { // TODO: Improve code reliability.
            console.log("P8");
            break;
          }
        }
        catch (e) {
          console.log("RRR", e); // FIXME: Remove.
        }
        if (i == 30) {
          alert("Cannot get installation info"); // TODO
          return;
        }
        await new Promise<void>((resolve, _reject) => {
          setTimeout(() => resolve(), 1000);
        });
      }
      console.log("P4 ");

      const backend_str = backendPrincipal.toString();
      // FIXME: Do wait.
      // TODO: busy indicator
      // for (let i = 0;; ++i) { // TODO: Choose the value.
      //   if (i == 20) {
      //     alert("Module failed to initialize"); // TODO: better dialog
      //     return;
      //   }
      //   try {
      //     const initialized = await backendRO.b44c4a9beec74e1c8a7acbe46256f92f_isInitialized();
      //     if (initialized) {
      //       break;
      //     }
      //   }
      //   catch (e) {
      //     // TODO: more detailed error check
      //   }
      // }
      const base = getIsLocal() ? `http://${glob.frontend}.localhost:4943?` : `https://${glob.frontend}.icp0.io?`;
      open(`${base}backend=${backend_str}`, '_self');
    }
    // TODO: Start installation automatically, without clicking a button?
    return (
      <Container>
        <p>You first need to install the missing components (so called <q>backend</q>) for this software.
          This is just two buttons easy.</p>
        <ol>
          <li><AuthButton/></li>
          <li><Button disabled={!isAuthenticated} onClick={installBackend}>Install</Button></li>
        </ol>
      </Container>
    );
  }
  return <App2/>;
}

function App2() {
  return (
    <main id="main">
      <div>
        <Container>
          <nav style={{marginBottom: '1ex'}}>
            <Navbar className="bg-body-secondary" style={{width: "auto"}}>
              <Nav>
                <MyLink className="nav-link" to="/">Main page</MyLink>
              </Nav>
              <Nav>
                <MyLink className="nav-link" to="/installed">Installed packages</MyLink>
              </Nav>
              <Nav>
                <AuthButton/>
              </Nav>
            </Navbar>
          </nav>
          <Routes>
            <Route path="/" element={<MainPage/>}/>
            <Route path="/choose-version/:repo/:packageName" element={<ChooseVersion/>}/>
            <Route path="/installed" element={<InstalledPackages/>}/>
            <Route path="/installed/show/:installationId" element={<Installation/>}/>
          </Routes>
        </Container>
      </div>
    </main>
 );
}

export default App;
