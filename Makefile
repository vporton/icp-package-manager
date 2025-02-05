#!/usr/bin/make -f

NETWORK = local
USER = $(shell dfx identity get-principal)
DEPLOY_FLAGS.BootstrapperData = --argument "principal \"$(USER)\""

.PHONY: deploy
deploy:

# Don't use dfx.json dependency, because package_manager is not to be installed.
# example_frontend is used here to deploy an asset canister.
canister@bootstrapper_frontend: generate@example_frontend generate@package_manager generate@indirect_caller generate@simple_indirect generate@bookmark

include deps.$(NETWORK).mk

.PHONY: deps
deps:
	dfx rules --network $(NETWORK) -o deps.$(NETWORK).mk

# INIT_BLOB = $(shell echo 'encode(record {})' | ic-repl-linux64)
INIT_BLOB = blob "\44\49\44\4c\01\6c\00\01\00"

.PHONY: deploy
deploy: deploy@bootstrapper_frontend deploy-self@package_manager_frontend deploy@example_frontend deploy@Repository \
  deploy@internet_identity generate@example_frontend generate@package_manager_frontend
	-dfx ledger fabricate-cycles --t 2000000 --canister Repository
	-dfx canister call Repository init "()"
	-dfx canister call BootstrapperData setOwner "(principal \"`dfx canister id Bootstrapper`\")"
	npx tsx scripts/prepare.ts