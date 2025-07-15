import { Principal } from '@dfinity/principal';

export type PubKey = Uint8Array;
export type PrivKey = CryptoKey;

export function urlSafeBase64ToUint8Array(urlSafeBase64: string): Uint8Array {
  const cleaned = urlSafeBase64.trim();
  if (!/^[0-9A-Za-z_-]+$/.test(cleaned)) {
    throw new Error('Invalid Base64');
  }
  const base64String = cleaned
    .replace(/-/g, '+')
    .replace(/_/g, '/')
    .padEnd(cleaned.length + (4 - cleaned.length % 4) % 4, '=');
  const binaryString = atob(base64String);
  const binaryArray = new Uint8Array(binaryString.length);
  for (let i = 0; i < binaryString.length; i++) {
    binaryArray[i] = binaryString.charCodeAt(i);
  }
  return binaryArray;
}

export async function getPublicKeyFromPrivateKey(privateKey: CryptoKey): Promise<CryptoKey> {
  const jwkPrivate = await crypto.subtle.exportKey('jwk', privateKey);
  const jwkPublic = {
    kty: jwkPrivate.kty,
    crv: jwkPrivate.crv,
    x: jwkPrivate.x,
    y: jwkPrivate.y,
    alg: jwkPrivate.alg,
  } as JsonWebKey;
  return crypto.subtle.importKey(
    'jwk',
    jwkPublic,
    {
      name: 'ECDSA',
      namedCurve: jwkPrivate.crv,
      hash: { name: 'SHA-256' },
    },
    true,
    ['verify']
  );
}

export async function signPrincipal(privateKey: CryptoKey, principal: Principal): Promise<Uint8Array> {
  const signature = await crypto.subtle.sign(
    {
      name: 'ECDSA',
      hash: { name: 'SHA-256' },
    },
    privateKey,
    principal.toUint8Array(),
  );
  return new Uint8Array(signature);
}
