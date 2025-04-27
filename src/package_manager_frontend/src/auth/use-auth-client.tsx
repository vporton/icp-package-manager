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
  return {
    ...v,
    principal: useMemo(() => v.identity?.getPrincipal(), [v.identity]),
    agent: useMemo(() => new HttpAgent({ host, identity: v.identity }), [v.identity]),
    defaultAgent: useMemo(() => new HttpAgent({ host }), [v.identity]),
  };
}