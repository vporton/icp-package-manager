// import { Secp256k1KeyIdentity } from '@dfinity/identity-secp256k1';
import {Ed25519KeyIdentity} from '@dfinity/identity';
import {Secp256k1KeyIdentity} from '@dfinity/identity-secp256k1';
import { decode } from 'pem-file';

export function decodeFile(rawKey) {
    let buf/*: Buffer*/ = decode(rawKey);
    if (rawKey.includes('EC PRIVATE KEY')) {
        if (buf.length != 118) {
            throw 'expecting byte length 118 but got ' + buf.length;
        }
        return Secp256k1KeyIdentity.fromSecretKey(buf.subarray(7, 39));
    }
    if (buf.length != 85) {
        throw 'expecting byte length 85 but got ' + buf.length;
    }
    let secretKey = Buffer.concat([buf.subarray(16, 48), buf.subarray(53, 85)]);
    const identity = Ed25519KeyIdentity.fromSecretKey(secretKey);
    return identity;
}
