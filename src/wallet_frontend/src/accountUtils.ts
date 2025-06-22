import { Principal } from '@dfinity/principal';
import { encodeIcrcAccount } from '@dfinity/ledger-icrc';

export function principalToSubaccount(principal: Principal): Uint8Array {
  const bytes = principal.toUint8Array();
  const sub = new Uint8Array(32);
  // copy the principal bytes directly, padding the rest with zeros
  for (let i = 0; i < 32; i++) {
    sub[i] = i < bytes.length ? bytes[i] : 0;
  }
  return sub;
}

export function userAccount(wallet: Principal, user: Principal) {
  return { owner: wallet, subaccount: principalToSubaccount(user) };
}

export function userAccountText(wallet: Principal, user: Principal): string {
  return encodeIcrcAccount(userAccount(wallet, user));
}
