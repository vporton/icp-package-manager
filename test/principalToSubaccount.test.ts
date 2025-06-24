import { expect } from 'chai';
import { Principal } from '@dfinity/principal';
import { principalToSubaccount as tsImplementation } from '../src/wallet_frontend/src/accountUtils';

/**
 * Reference implementation based on `src/common.mo`.
 */
function motokoEquivalent(principal: Principal): Uint8Array {
  const bytes = principal.toUint8Array();
  const result = new Uint8Array(32);
  result[0] = bytes.length;
  result.set(bytes, 1);
  return result;
}

describe('principalToSubaccount: Motoko vs TypeScript', () => {
  const testPrincipals = [
    Principal.anonymous(),
    Principal.fromText('aaaaa-aa'),
    Principal.fromText('aovwi-4maaa-aaaaa-qaagq-cai'),
    Principal.fromText('asrmz-lmaaa-aaaaa-qaaeq-cai'),
    Principal.fromText('by6od-j4aaa-aaaaa-qaadq-cai'),
  ];

  for (const p of testPrincipals) {
    it(`matches Motoko for ${p.toText()}`, () => {
      const tsResult = tsImplementation(p);
      const moResult = motokoEquivalent(p);
      expect(Array.from(tsResult)).to.deep.equal(Array.from(moResult));
    });
  }
});
