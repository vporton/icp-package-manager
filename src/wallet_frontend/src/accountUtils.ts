import { Principal } from '@dfinity/principal';
import { encodeIcrcAccount } from '@dfinity/ledger-icrc';
import { createActor as createWalletActor } from '../../declarations/wallet_backend'; // TODO: hack
import { Wallet } from '../../declarations/wallet_backend/wallet_backend.did';

// TODO@P3: duplicate code
async function sha256(v: Uint8Array): Promise<Uint8Array> {
  if (typeof window !== 'undefined') {
    // In browsers prefer the WebCrypto API. Avoid importing the Node
    // `crypto` polyfill which pulls in heavy dependencies and may rely on
    // `process.version` being defined.
    return new Uint8Array(await crypto.subtle.digest('SHA-256', v));
  } else {
    // Node.js environment
    const { createHash } = await import('crypto');
    const hash = createHash('sha256');
    hash.update(v);
    return new Uint8Array(hash.digest());
  }
}

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

export async function userAccount(wallet: Principal, user: Principal, agent?: any) {
  // return { owner: wallet, subaccount: principalToSubaccount(user) }; // `subaccount` should be `undefined`, if the wallet is personal.
  const walletActor: Wallet = createWalletActor(wallet, agent ? { agent } : {});
  return await walletActor.getUserWallet(user);
}

export async function userAccountText(wallet: Principal, user: Principal, agent?: any): Promise<string> {
  // return encodeIcrcAccount(await userAccount(wallet, user));
  const walletActor: Wallet = createWalletActor(wallet, agent ? { agent } : {});
  return await walletActor.getUserWalletText(user);
}

export async function investmentAccount(pst: Principal, user: Principal) {
  const random = Buffer.from(
    'e9ad41820ff501db087a111f978ed69b16db557025d6e3cea07604cba63cefc5',
    'hex',
  );
  const principalBytes = user.toUint8Array();
  const joined = new Uint8Array(random.length + principalBytes.length);
  joined.set(random);
  joined.set(principalBytes, random.length);
  const sub = await sha256(joined); // createHash('sha256').update(joined).digest();
  return { owner: pst, subaccount: [sub] as [Uint8Array] };
}
