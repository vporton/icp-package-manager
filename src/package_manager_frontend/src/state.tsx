import { Principal } from "@dfinity/principal";
import React, { createContext, useEffect, useState } from "react";
import { PackageManager } from "../../declarations/package_manager/package_manager.did";
import { package_manager } from "../../declarations/package_manager";
import { useAuth } from "./auth/use-auth-client";
import { idlFactory as packageManagerIDL } from '../../declarations/package_manager/package_manager.did.js';
import { Actor } from "@dfinity/agent";

export const GlobalContext = createContext<{
  frontend: Principal | undefined,
  backend: Principal | undefined,
  packageManager: PackageManager | undefined,
  frontendTweakPrivKey: Uint8Array | undefined,
}>({
  frontend: undefined,
  backend: undefined,
  packageManager: undefined,
  frontendTweakPrivKey: undefined,
});

function urlSafeBase64ToUint8Array(urlSafeBase64: string) {
  // Make the string standard Base64 by reversing the URL-safe replacements
  const base64String = urlSafeBase64
      .replace(/-/g, '+') // Replace '-' with '+'
      .replace(/_/g, '/') // Replace '_' with '/'
      .padEnd(urlSafeBase64.length + (4 - urlSafeBase64.length % 4) % 4, '='); // Add padding '='

  // Decode Base64 to binary string
  const binaryString = atob(base64String);

  // Convert binary string to Uint8Array
  const binaryArray = new Uint8Array(binaryString.length);
  for (let i = 0; i < binaryString.length; i++) {
      binaryArray[i] = binaryString.charCodeAt(i);
  }

  return binaryArray;
}

/**
 * @type {React.FC}
 */
export function GlobalContextProvider(props: { children: any }) {
  const params = new URLSearchParams(window.location.search);

  const backend_str = params.get('_pm_pkg0.backend');
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
  const {agent} = useAuth();
  const [packageManager, setPackageManager] = useState<PackageManager | undefined>();
  useEffect(() => {
    setPackageManager(backend !== undefined && agent !== undefined
      ? Actor.createActor(packageManagerIDL, {canisterId: backend!, agent})
      : undefined);
  }, [agent]);

  const frontendTweakPrivKeyEncoded = params.get('frontendTweakPrivKey');
  const frontendTweakPrivKey: Uint8Array | undefined =
    frontendTweakPrivKeyEncoded === null ? undefined : urlSafeBase64ToUint8Array(frontendTweakPrivKeyEncoded);

  return (
    <GlobalContext.Provider value={{backend, frontend, packageManager, frontendTweakPrivKey}}>
      {props.children}
    </GlobalContext.Provider>
  );
};

// export const useGlobalContext = () => useContext(GlobalContext);