#!/bin/env python3

import os
import subprocess

os.system("dfx deploy test")

with open(".dfx/local/canisters/counter/counter.wasm", "rb") as wasm:
    wasm = wasm.read()
    blob = 'blob "' + "".join(["\\{:02x}".format(c) for c in wasm]) + '"'

# os.system(f"echo dfx canister call test main '({blob})")
subprocess.run(["dfx", "canister", "call", "test", "main", blob])