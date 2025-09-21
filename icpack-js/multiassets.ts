import fs from 'fs';
import { readdirp } from "readdirp";
import { sha256 } from "../src/lib/crypto";
import { lookup } from "mime-types";
import { Principal } from "@dfinity/principal";

export async function fillMultiAssets(canisterId: Principal, {prefix, path}: {prefix: string, path: string}) {
    for await (const entry of readdirp(path)) {
        const fileContent = fs.readFileSync(entry.fullPath);
        const fileContentHash = sha256(fileContent);
        const contentType0 = lookup(entry.fullPath);
        const contentType = contentType0 === false ? "application/octet-stream" : contentType0;

        const store = 
    }
}