/**
 * Shared crypto utilities for the icpack project
 */

/**
 * Computes SHA-256 hash of the given data
 * Works in both browser and Node.js environments
 */
export async function sha256(v: Uint8Array): Promise<Uint8Array> {
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