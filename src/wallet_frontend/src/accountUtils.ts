import { Principal } from '@dfinity/principal';
import { encodeIcrcAccount } from '@dfinity/ledger-icrc';

export function principalToSubaccount(principal: Principal): Uint8Array {
  const bytes = principal.toUint8Array();
  const sub = new Uint8Array(bytes.length + 1);
  sub[0] = bytes.length;
  sub.set(bytes, 1);
  if (sub.length < 32) {
    const padded = new Uint8Array(32);
    padded.set(sub);
    return padded;
  }
  return sub;
}

export function userAccount(wallet: Principal, user: Principal) {
  return { owner: wallet, subaccount: principalToSubaccount(user) };
}

export function userAccountText(wallet: Principal, user: Principal): string {
  return encodeIcrcAccount(userAccount(wallet, user));
}
