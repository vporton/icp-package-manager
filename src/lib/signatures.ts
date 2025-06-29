import { Principal } from '@dfinity/principal';

export type PubKey = Uint8Array;
export type PrivKey = CryptoKey;

export async function getPublicKeyFromPrivateKey(privateKey: CryptoKey): Promise<CryptoKey> {
  try {
    const jwkPrivate = await crypto.subtle.exportKey('jwk', privateKey);
    const jwkPublic = {
      kty: jwkPrivate.kty,
      crv: jwkPrivate.crv,
      x: jwkPrivate.x,
      y: jwkPrivate.y,
      alg: jwkPrivate.alg,
    } as JsonWebKey;
    const publicKey = await crypto.subtle.importKey(
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
    return publicKey;
  } catch (error) {
    console.error('Error deriving public key:', error);
    throw error;
  }
}

export async function signPrincipal(privateKey: CryptoKey, principal: Principal): Promise<Uint8Array> {
  const signature = await crypto.subtle.sign(
    {
      name: 'ECDSA',
      saltLength: 32,
      hash: 'SHA-256',
    },
    privateKey,
    principal.toUint8Array()
  );
  return new Uint8Array(signature);
}
