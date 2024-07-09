#!/bin/env python3

import json
import os
from ic.client import Client
from ic.identity import Identity
from ic.agent import Agent
from ic.candid import encode, decode, Types

os.system("dfx deploy test")

with open(".dfx/local/canisters/counter/counter.wasm", "rb") as wasm:
    wasm = wasm.read()
    blob = [c for c in wasm][0:100]

with open('.dfx/local/canister_ids.json') as ids:
    j = json.load(ids)
    principal = j['test']['local']

client = Client(url = "http://localhost:4943")
iden = Identity()
agent = Agent(iden, client)

params = [{'type': Types.Vec(Types.Nat8), 'value': blob}]
params2 = encode(params)
result = agent.update_raw(principal, "main", params2)
print(result)