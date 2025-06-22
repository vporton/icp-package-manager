import { Principal } from '@dfinity/principal';
import { encodeIcrcAccount } from '@dfinity/ledger-icrc';
import { createHash } from 'crypto';

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

export function investmentAccount(pst: Principal, user: Principal) {
  const random = Buffer.from(
    'e9ad41820ff501db087a111f978ed69b16db557025d6e3cea07604cba63cefc5',
    'hex',
  );
  const principalBytes = user.toUint8Array();
  const joined = new Uint8Array(random.length + principalBytes.length);
  joined.set(random);
  joined.set(principalBytes, random.length);
  const sub = createHash('sha256').update(joined).digest();
  return { owner: pst, subaccount: sub };
}
