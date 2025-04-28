import { Agent, HttpAgent, Identity } from "@dfinity/agent";
import { AuthClient, AuthClientCreateOptions, AuthClientLoginOptions } from "@dfinity/auth-client";
import { Principal } from "@dfinity/principal";
import { useInternetIdentity } from "ic-use-internet-identity";
import React, { createContext, useContext, useEffect, useMemo, useState } from "react";
// import sha256 from 'crypto-js/sha256';
// import * as base64 from 'base64-js';

// TODO@P3: Move this function to GlobalState
export function getIsLocal(): boolean {
  return /localhost/.test(document.location.hostname); // TODO@P3: Cache the result.
}

export function useAuth() {
  const v = useInternetIdentity();
  const host = getIsLocal() ? "http://localhost:4943" : undefined;
  // TODO@P3: Use `HttpAgent.create`.
  const [agentFetchedKey, setAgentFetchedKey] = useState(!getIsLocal());
  const [defaultAgentFetchedKey, setDefaultAgentFetchedKey] = useState(!getIsLocal());
  const agent = useMemo(
    () => v.identity && agentFetchedKey ? new HttpAgent({ host, identity: v.identity }) : undefined,
    [v.identity, agentFetchedKey]
  );
  const defaultAgent = useMemo(
    () => defaultAgentFetchedKey ? new HttpAgent({ host }) : undefined,
    [defaultAgentFetchedKey]
  );
  useEffect(() => {
    if (getIsLocal() && agent !== undefined && !agentFetchedKey) {
      agent.fetchRootKey().then(() => setAgentFetchedKey(true));
    }
  }, [agent]);
  useEffect(() => {
    if (getIsLocal() && defaultAgent !== undefined && !defaultAgentFetchedKey) {
      defaultAgent.fetchRootKey().then(() => setDefaultAgentFetchedKey(true));
    }
  }, [agent]);
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