#!/bin/env python3

import json
import os
import time
from ic import Canister
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
# pm_did = open(".dfx/local/canisters/package_manager/package_manager.did").read()
pm_did = open(".dfx/local/canisters/package_manager/service.did").read()
pm = Canister(agent=agent, canister_id=str(pm_principal), candid=pm_did)
# result = agent.query_raw(str(pm_principal), "getInstalledPackage", encode([{'type': Types.Nat, 'value': installation_id}]))
result = pm.getInstalledPackage(installation_id)
counter = str(result[0]['modules'][0])
# FIXME: It seems to wait is unnecessary for `ic-py`.
wait = 20 # secs
print(f"Waiting {wait} sec")
time.sleep(wait)
print(f"Running the 'counter' ({counter}) software...");
agent.update_raw(counter, "increase", encode([]))
# for i in range(20):
#     print(f"... attempt {i}")
#     try:
#         agent.update_raw(counter, "increase", encode([]))  # stalls on canister without WASM
#         time.sleep(1)  # Wait till Counter installation finishes
#     except Exception as e:
#         print(e)
#         continue
#     break
result = agent.query_raw(counter, "get", encode([]))
test_value = result[0]['value']
print(f"COUNTER: {test_value}");
assert test_value == 1
print("Counter is equal to 1...");
