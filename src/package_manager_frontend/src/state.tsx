import { Principal } from "@dfinity/principal";
import React, { createContext } from "react";

export const GlobalContext = createContext<{
  frontend: Principal | undefined,
  backend: Principal | undefined,
  bookmarkMsg: boolean,
}>({
  frontend: undefined,
  backend: undefined,
  bookmarkMsg: false,
});

/**
 * @type {React.FC}
 */
export function GlobalContextProvider(props: { children: any }) {
  const params = new URLSearchParams(window.location.search);

  const bookmarkMsg = params.get('bookmarkMsg') !== null;

  const backend_str = params.get('backend');
  const backend = backend_str !== null ? Principal.fromText(backend_str) : undefined;

  const frontend_str = window.location.hostname.replace(/\..*/, ""); // TODO: doesn't work for custom domains
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

  return <GlobalContext.Provider value={{backend, frontend, bookmarkMsg}}>{props.children}</GlobalContext.Provider>;
};

// export const useGlobalContext = () => useContext(GlobalContext);