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

my_run("dfx identity use default")
my_run("dfx deploy test")
my_run("dfx ledger fabricate-cycles --amount 100000000 --canister test")

counter_blob = open(".dfx/local/canisters/counter/counter.wasm", "rb").read()
pm_blob = open(".dfx/local/canisters/package_manager/package_manager.wasm", "rb").read()
frontend_blob = open(".dfx/local/canisters/package_manager_frontend/assetstorage.wasm.gz", "rb").read()

with open('.dfx/local/canister_ids.json') as ids:
    j = json.load(ids)
    test_principal = j['test']['local']
    pm_frontend_source_principal = j['package_manager_frontend']['local']

client = Client(url = "http://localhost:4943")
iden = Identity(anonymous=True)
agent = Agent(iden, client)

test_did = open(".dfx/local/canisters/test/service.did").read()
test = Canister(agent=agent, canister_id=str(test_principal), candid=test_did)
result = test.main(pm_blob, frontend_blob, pm_frontend_source_principal, counter_blob)
print("XXX: ", result)
counter_installation_id = result[0][1]['installationId']
pm_canisters = result[0][0]['canisterIds']
pm_principal = str(pm_canisters[0])
print(f"Counter installation ID: {counter_installation_id}")

wait = 15 # secs
print(f"Waiting {wait} sec")
time.sleep(wait)

print("Getting package info...");

pm_did = open(".dfx/local/canisters/package_manager/service.did").read()
pm = Canister(agent=agent, canister_id=str(pm_principal), candid=pm_did)
result = pm.getInstalledPackage(counter_installation_id)

# result = agent.query_raw(str(pm_principal), "getInstalledPackage", encode([{'type': Types.Nat, 'value': counter_installation_id}]))
print("YYY: ", result)
counter = str(result[0]['modules'][0])
# `ic-py` hangs if called on a canister without WASM code, so make enough pause.
wait = 5 # secs
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
