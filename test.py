#!/bin/env python3

import json
import os
from ic.client import Client
from ic.identity import Identity
from ic.agent import Agent
from ic.candid import encode, decode, Types

os.system("dfx deploy test --identity anonymous")  # TODO: Anonymous identity is a hack.
os.system("dfx ledger fabricate-cycles --amount 100000000 --canister test")
os.system("dfx ledger fabricate-cycles --amount 100000000 --canister package_manager")  # FIXME: hack

with open(".dfx/local/canisters/counter/counter.wasm", "rb") as wasm:
    wasm = wasm.read()
    blob = [c for c in wasm]

with open('.dfx/local/canister_ids.json') as ids:
    j = json.load(ids)
    principal = j['test']['local']

client = Client(url = "http://localhost:4943")
iden = Identity(anonymous=True)
agent = Agent(iden, client)

params = [{'type': Types.Vec(Types.Nat8), 'value': blob}]
params2 = encode(params)
result = agent.update_raw(principal, "main", params2)
print("COUNTER: " + decode(result, retTypes=[Types.Nat8]))