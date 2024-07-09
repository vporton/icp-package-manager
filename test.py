#!/bin/env python3

import os

os.system("dfx deploy test")

with open(".dfx/local/canisters/counter/counter.wasm", "rb") as wasm:
    wasm = wasm.read()
    blob = 'blob "' + "".join(["0x{:02x}".format(c) for c in wasm]) + '"'

os.system(f"dfx call test main {blob}")