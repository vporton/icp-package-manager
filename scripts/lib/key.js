// import { Secp256k1KeyIdentity } from '@dfinity/identity-secp256k1';
import {Ed25519KeyIdentity} from '@dfinity/identity';
import {Secp256k1KeyIdentity} from '@dfinity/identity-secp256k1';
import { decode } from 'pem-file';

export function decodeFile(rawKey) {
    console.log("A1");
    let buf/*: Buffer*/ = decode(rawKey);
    console.log("A2");
    if (rawKey.includes('EC PRIVATE KEY')) {
        if (buf.length != 118) {
                throw 'expecting byte length 118 but got ' + buf.length;
        }
        console.log("A3");
        return Secp256k1KeyIdentity.fromSecretKey(buf.subarray(7, 39));
    }
    console.log("A4");
    if (buf.length != 85) {
        throw 'expecting byte length 85 but got ' + buf.length;
    }
    console.log("A5");
    let secretKey = Buffer.concat([buf.subarray(16, 48), buf.subarray(53, 85)]);
    console.log("A6");
    const identity = Ed25519KeyIdentity.fromSecretKey(secretKey);
    return identity;
}
