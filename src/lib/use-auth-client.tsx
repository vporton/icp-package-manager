import { Agent, HttpAgent, Identity } from "@dfinity/agent";
import { AuthClient, AuthClientCreateOptions, AuthClientLoginOptions } from "@dfinity/auth-client";
import { Principal } from "@dfinity/principal";
import { InternetIdentityProvider, useInternetIdentity } from "ic-use-internet-identity";
import React, { createContext, useContext, useEffect, useMemo, useState } from "react";
// import sha256 from 'crypto-js/sha256';
// import * as base64 from 'base64-js';

// TODO@P3: Move this function to GlobalState
export function getIsLocal(): boolean {
  return /localhost/.test(document.location.hostname); // TODO@P3: Cache the result.
}

type AuthContextType = {
  identity: Identity | undefined,
  ok: boolean,
  principal: Principal | undefined,
  agent: Agent | undefined,
  defaultAgent: Agent | undefined,
  login: () => Promise<void>,
  clear: () => Promise<void>,
};

function createAuth(): AuthContextType {
  const v = useInternetIdentity();
  const host = getIsLocal() ? "http://localhost:4943" : undefined;
  // TODO@P3: Use `HttpAgent.create`.
  const agent = useMemo(
    () => v.identity ? new HttpAgent({ host, identity: v.identity, shouldFetchRootKey: getIsLocal() }) : undefined,
    [v.identity],
  );
  const defaultAgent = useMemo(() => new HttpAgent({ host, shouldFetchRootKey: getIsLocal() }), []);
  return {
    identity: v.identity,
    ok: v.identity !== undefined,
    principal: useMemo(() => v.identity?.getPrincipal(), [v.identity]),
    agent,
    defaultAgent,
    login: v.login,
    clear: v.clear,
  };
}

export const AuthContext = createContext<AuthContextType | undefined>(undefined);

export function AuthProvider(props: { children: any }) {
  const auth = createAuth();
  return (
    <InternetIdentityProvider>
      <AuthContext.Provider value={auth!}>
        {props.children}
      </AuthContext.Provider>
    </InternetIdentityProvider>
  );
}

export function useAuth() {
  return useContext(AuthContext)!;
}