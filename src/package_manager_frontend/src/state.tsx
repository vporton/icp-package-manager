import { Principal } from "@dfinity/principal";
import React, { createContext } from "react";
import { PackageManager } from "../../declarations/package_manager/package_manager.did";
import { package_manager } from "../../declarations/package_manager";
import { useAuth } from "./auth/use-auth-client";
import { idlFactory as packageManagerIDL } from '../../declarations/package_manager/package_manager.did.js';
import { Actor } from "@dfinity/agent";

export const GlobalContext = createContext<{
  frontend: Principal | undefined,
  backend: Principal | undefined,
  package_manager_ro: PackageManager | undefined,
  package_manager_rw: PackageManager | undefined,
}>({
  frontend: undefined,
  backend: undefined,
  package_manager_ro: undefined,
  package_manager_rw: undefined,
});

/**
 * @type {React.FC}
 */
export function GlobalContextProvider(props: { children: any }) {
  const params = new URLSearchParams(window.location.search);

  const backend_str = params.get('backend');
  const backend = backend_str !== null ? Principal.fromText(backend_str) : undefined;

  const canisterId = params.get('canisterId');
  const frontend_str = canisterId !== null ? canisterId : window.location.hostname.replace(/\..*/, ""); // TODO: doesn't work for custom domains
  let frontend = undefined;
  if (frontend_str !== null) {
    try {
      frontend = Principal.fromText(frontend_str);
    }
    catch(_) {
      const frontend_str2 = params.get('frontend');
      try {
        frontend = frontend_str2 !== null ? Principal.fromText(frontend_str2) : undefined;
      }
      catch(_) {
        frontend = Principal.fromText(process.env.CANISTER_ID_BOOTSTRAPPER_FRONTEND!);
      }
    }
  }
  const {agent, defaultAgent} = useAuth();
  const package_manager_ro: PackageManager | undefined = backend && Actor.createActor(packageManagerIDL, {canisterId: backend!, agent: defaultAgent});
  const package_manager_rw: PackageManager | undefined = backend && Actor.createActor(packageManagerIDL, {canisterId: backend!, agent});

  return (
    <GlobalContext.Provider value={{backend, frontend, package_manager_ro, package_manager_rw}}>
      {props.children}
    </GlobalContext.Provider>
  );
};

// export const useGlobalContext = () => useContext(GlobalContext);