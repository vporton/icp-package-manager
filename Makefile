#!/usr/bin/make -f

NETWORK = local
export MOPS_ENV = $(NETWORK)
USER = $(shell dfx identity get-principal)
# DEPLOY_FLAGS.bookmark = --argument "rec { bootstrapper = \"$$()\""; }"
DEPLOY_FLAGS.bootstrapper_data = --argument "principal \"$(USER)\""

.PHONY: deploy
deploy:

# Don't use dfx.json dependency, because package_manager is not to be installed.
# example_frontend is used here to deploy an asset canister.
build@bootstrapper_frontend: generate@example_frontend generate@package_manager generate@main_indirect generate@simple_indirect generate@bookmark generate@battery generate@bootstrapper

include deps.$(NETWORK).mk

.PHONY: deps
deps:
	dfx rules --network $(NETWORK) -o deps.$(NETWORK).mk

# INIT_BLOB = $(shell echo 'encode(record {})' | ic-repl-linux64)
INIT_BLOB = blob "\44\49\44\4c\01\6c\00\01\00"

.PHONY: deploy
deploy: deploy@bootstrapper_frontend deploy-self@package_manager_frontend deploy@example_frontend deploy@repository generate@battery \
  deploy@internet_identity generate@example_frontend generate@package_manager_frontend
	-dfx ledger fabricate-cycles --t 2000000 --canister repository
	-dfx canister call repository init "()"
	-dfx canister call bootstrapper_data setOwner "(principal \"`dfx canister id bootstrapper`\")"

.PHONY: deploy-test
deploy-test: deploy \
  deploy@upgrade_example_backend1_v1 deploy@upgrade_example_backend2_v1 \
  deploy@upgrade_example_backend2_v2 deploy@upgrade_example_backend3_v2
	npx tsx scripts/prepare-test.ts

deploy-self@bookmark:
	dfx deploy --no-compile --network $(NETWORK) $(DEPLOY_FLAGS) $(DEPLOY_FLAGS.bookmark) \
	  --argument "record { bootstrapper = principal \"$$(dfx canister id bootstrapper)\"; }" \
	  bookmark