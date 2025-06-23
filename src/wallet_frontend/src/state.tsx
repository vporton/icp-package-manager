import { Principal } from "@dfinity/principal";
import React, { createContext, useEffect, useMemo, useState } from "react";
import { Wallet } from "../../declarations/wallet_backend/wallet_backend.did";
import { createActor as createWallet } from '../../declarations/wallet_backend';
import { useAuth } from "../../lib/use-auth-client";

export type GlobalContextType = {
  walletBackendPrincipal: Principal | undefined,
  walletBackend: Wallet | undefined,
  walletIsAnonymous: boolean | undefined,
};

export const GlobalContext = createContext<GlobalContextType>({
  walletBackendPrincipal: undefined,
  walletBackend: undefined,
  walletIsAnonymous: undefined,
});

/**
 * @type {React.FC}
 */
export function GlobalContextProvider(props: { children: any }) {
  const params = new URLSearchParams(window.location.search);

  const backend_str = params.get('_pm_pkg.backend') ?? process.env.CANISTER_ID_WALLET_BACKEND;
  const backend = backend_str ? Principal.fromText(backend_str) : undefined;

  const canisterId = params.get('canisterId');
  const {agent, ok} = useAuth();
  const wallet: Wallet | undefined = useMemo(() =>
    backend !== undefined && ok ? createWallet(backend, {agent}) : undefined,
    [agent]);
  const [walletIsAnonymous, setWalletIsAnonymous] = useState<boolean | undefined>();
  useEffect(() => {
    if (wallet !== undefined) {
      wallet.isAnonymous().then(f => setWalletIsAnonymous(f));
    }
  }, [wallet]);

  return (
    <GlobalContext.Provider value={{walletBackendPrincipal: backend, walletBackend: wallet, walletIsAnonymous}}>
      {props.children}
    </GlobalContext.Provider>
  );
};

// export const useGlobalContext = () => useContext(GlobalContext);