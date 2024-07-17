import { Agent, HttpAgent, Identity } from "@dfinity/agent";
import { AuthClient, AuthClientCreateOptions, AuthClientLoginOptions } from "@dfinity/auth-client";
import { Principal } from "@dfinity/principal";
import React, { createContext, useContext, useEffect, useMemo, useState } from "react";
// import { getIsLocal } from "../../util/client";
// import sha256 from 'crypto-js/sha256';
// import * as base64 from 'base64-js';

function getIsLocal() {
    return true; // FIXME
}

export const AuthContext = createContext<{
  isAuthenticated: boolean,
  authClient?: AuthClient,
  agent?: Agent,
  defaultAgent?: Agent,
  identity?: Identity,
  principal?: Principal,
  options?: UseAuthClientOptions,
  login?: (callback?: () => Promise<void>) => void,
  logout?: () => Promise<void>,
}>({isAuthenticated: false});

type UseAuthClientOptions = {
  createOptions?: AuthClientCreateOptions;
  loginOptions?: AuthClientLoginOptions;
};

const defaultOptions: UseAuthClientOptions = {
  createOptions: {
    idleOptions: {
      // Prevent page reload on timeout, not to lose form data:
			disableIdle: false,
			disableDefaultIdleCallback: true,
    },
  },
  loginOptions: {
    identityProvider:
    process.env.DFX_NETWORK === "ic" // FIXME
        ? `https://identity.ic0.app`
        : `http://${process.env.CANISTER_ID_INTERNET_IDENTITY}.localhost:4943`,
  },
};

/**
 * @type {React.FC}
 */
export function AuthProvider(props: { children: any, options?: UseAuthClientOptions }) {
  const [auth, setAuth] = useState<any>({options: props.options});

  const login = async () => {
    auth.authClient!.login({
      ...defaultOptions, ...auth.options.loginOptions,
      onSuccess: () => {
        updateClient(auth.authClient);
      },
    });
  };

  const logout = async () => {
    await auth.authClient?.logout();
    await updateClient(auth.authClient);
  }

  async function updateClient(client: any) { // TODO: `any`
    const isAuthenticated = await client.isAuthenticated();
    const identity = client.getIdentity();
    const principal = identity.getPrincipal();
    const agent = new HttpAgent({identity});
    if (getIsLocal()) {
      agent.fetchRootKey();
    }

    setAuth({authClient: client, agent, isAuthenticated, identity, principal, options: props.options});
  }

  const defaultAgent = useMemo<HttpAgent>(() => {
    const agent = new HttpAgent(); // TODO: options
    if (getIsLocal()) {
      agent.fetchRootKey();
    }
    return agent;
  }, []);

  useEffect(() => {
    // Initialize AuthClient
    const baseOptions = props.options?.createOptions ?? defaultOptions.createOptions;
    AuthClient.create({...baseOptions, idleOptions: {
        // Prevent page reload on timeout, not to lose form data:
        disableIdle: false,
        disableDefaultIdleCallback: true,
        // onIdle: () => logout(), // TODO: It crashes: "Cannot read properties of undefined (reading 'isAuthenticated')"
        // idleTimeout: 1000, // 1 sec
      }}).then(async (client) => {
      updateClient(client);
    });
  }, []);

  return <AuthContext.Provider value={{...auth, login, logout, defaultAgent}}>{props.children}</AuthContext.Provider>;
};

export const useAuth = () => useContext(AuthContext);