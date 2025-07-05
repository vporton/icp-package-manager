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

function pad32(buf: Uint8Array): Uint8Array {
  if (buf.length === 32) return buf;
  if (buf.length > 32) return buf.slice(buf.length - 32);
  const out = new Uint8Array(32);
  out.set(buf, 32 - buf.length);
  return out;
}

function derToRawSignature(der: Uint8Array): Uint8Array {
  if (der[0] !== 0x30) throw new Error('Invalid DER');
  let offset = 2; // skip 0x30 and length
  if (der[offset] !== 0x02) throw new Error('Invalid DER');
  offset += 1;
  const rLen = der[offset++];
  const r = der.slice(offset, offset + rLen);
  offset += rLen;
  if (der[offset] !== 0x02) throw new Error('Invalid DER');
  offset += 1;
  const sLen = der[offset++];
  const s = der.slice(offset, offset + sLen);
  const out = new Uint8Array(64);
  out.set(pad32(r), 0);
  out.set(pad32(s), 32);
  return out;
}

export async function signPrincipal(privateKey: CryptoKey, principal: Principal): Promise<Uint8Array> {
  const derSig = new Uint8Array(
    await crypto.subtle.sign(
      {
        name: 'ECDSA',
        hash: 'SHA-256',
      },
      privateKey,
      principal.toUint8Array(),
    ),
  );
  return derToRawSignature(derSig);
}
