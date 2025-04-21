import { Principal } from "@dfinity/principal";

export function principalToSubAccount(principal: Principal): Uint8Array {
    const bytes = new Uint8Array(32).fill(0);
    const principalBytes = principal.toUint8Array();
    bytes[0] = principalBytes.length;
    
    for (let i = 0; i < principalBytes.length; i++) {
      bytes[1 + i] = principalBytes[i];
    }
    
    return bytes;
}
  