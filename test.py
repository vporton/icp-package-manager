#!/bin/env python3

import json
import os
from ic.client import Client
from ic.identity import Identity
from ic.agent import Agent
from ic.candid import encode, decode, Types

def my_run(cmd):
    if os.system(cmd) != 0:
        raise f"Can't run: {cmd}"

my_run("dfx deploy test --identity anonymous") # TODO: Anonymous identity is a hack.
my_run("dfx ledger fabricate-cycles --amount 100000000 --canister test")

with open(".dfx/local/canisters/counter/counter.wasm", "rb") as wasm:
    wasm = wasm.read()
    blob = [c for c in wasm]

with open('.dfx/local/canister_ids.json') as ids:
    j = json.load(ids)
    principal = j['test']['local']

client = Client(url = "http://localhost:4943")
iden = Identity(anonymous=True)
agent = Agent(iden, client)

params = encode([{'type': Types.Vec(Types.Nat8), 'value': blob}])
result = agent.update_raw(principal, "main", params)
# print("COUNTER: " + decode(result), retTypes=[Types.Nat])