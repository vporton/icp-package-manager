#!/bin/env python3

import json
import os
import time
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
    test_principal = j['test']['local']
    # pm_principal = j['package_manager']['local']

client = Client(url = "http://localhost:4943")
iden = Identity(anonymous=True)
agent = Agent(iden, client)

params = encode([{'type': Types.Vec(Types.Nat8), 'value': blob}])
result = agent.update_raw(test_principal, "main", params)
pm_principal, installation_id = result[0]['value'], result[1]['value']
print(f"Installation ID: {installation_id}")

print("Getting package info...");
result = agent.query_raw(pm_principal, "getInstalledPackage", encode([{'type': Types.Nat, 'value': installation_id}]))
print("BBB: ", result)
installed = result[0]['value']
counter = installed.modules[0]
print("Running the 'counter' software...");
for _ in range(20):
    try:
        agent.update_raw(counter, "increase", encode([]))
    except e:
        print(e)
    time.sleep(1)  # Wait till Counter installation finishes
result = agent.query_raw(counter, "get", encode([]))
test_value = decode(result)
print("COUNTER: " + test_value);
assert test_value == 1
print("Counter is equal to 1...");
