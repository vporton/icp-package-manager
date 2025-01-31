#!/usr/bin/make -f

NETWORK = local
USER = $(shell dfx identity get-principal)
DEPLOY_FLAGS.BootstrapperData = --argument "principal \"$(USER)\""

.PHONY: deploy
deploy:

include deps.$(NETWORK).mk

.PHONY: deps
deps:
	dfx rules -o deps.$(NETWORK).mk

# INIT_BLOB = $(shell echo 'encode(record {})' | ic-repl-linux64)
INIT_BLOB = blob "\44\49\44\4c\01\6c\00\01\00"

.PHONY: deploy
deploy: deploy@bootstrapper_frontend deploy-self@package_manager_frontend deploy@example_frontend deploy@RepositoryIndex \
  deploy@internet_identity canister@package_manager canister@indirect_caller canister@simple_indirect
	-dfx ledger fabricate-cycles --t 2000000 --canister RepositoryIndex
	-dfx canister call RepositoryIndex init "()"
	-dfx canister call BootstrapperData setOwner "(principal \"`dfx canister id Bootstrapper`\")"
	npx tsx scripts/prepare.ts