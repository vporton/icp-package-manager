#!/usr/bin/make -f

USER = $(shell dfx identity get-principal)

.PHONY: deploy

# INIT_BLOB = $(shell echo 'encode(record {})' | ic-repl-linux64)
INIT_BLOB = blob "\44\49\44\4c\01\6c\00\01\00"

.PHONY: deploy
deploy:
	dfx canister create package_manager
	dfx canister create package_manager_frontend
	dfx canister create bootstrapper_frontend
	dfx canister create RepositoryIndex
	dfx canister create bookmark
	dfx canister create indirect_caller
	dfx canister create Bootstrapper
	dfx canister create BootstrapperData
	dfx canister create example_frontend
	dfx canister create internet_identity
	dfx canister create simple_indirect
	dfx canister create cycles_ledger
	dfx build cycles_ledger
# `generate` erases `.env`.
	dfx build internet_identity
	dfx build package_manager
	dfx generate package_manager
	dfx build bootstrapper_frontend
	dfx canister install -m auto bootstrapper_frontend
	dfx generate bootstrapper_frontend
	dfx canister install -m auto internet_identity
	dfx generate internet_identity
	dfx generate Bootstrapper
	dfx generate BootstrapperData
	dfx generate indirect_caller
	dfx generate RepositoryIndex
	dfx generate simple_indirect
	dfx generate RepositoryPartition
	dfx generate bookmark
	dfx build package_manager_frontend
	dfx generate package_manager_frontend
	dfx canister install -m auto package_manager_frontend # for a template
	-dfx canister install -m auto cycles_ledger
	dfx build Bootstrapper
	dfx build BootstrapperData
	dfx canister install -m auto Bootstrapper
	dfx canister install -m auto BootstrapperData --argument "(principal \"`dfx identity get-principal`\")"
	dfx build indirect_caller
#	dfx canister install -m auto package_manager
	dfx build RepositoryIndex
	dfx canister install -m auto RepositoryIndex
	dfx build simple_indirect
	dfx build bookmark
	dfx canister install -m auto bookmark
	dfx build example_frontend
	dfx canister install -m auto example_frontend
	-dfx ledger fabricate-cycles --t 2000000 --canister RepositoryIndex
	-dfx canister call RepositoryIndex init "()"
	-dfx canister call BootstrapperData setOwner "(principal \"`dfx canister id Bootstrapper`\")"
	npx tsx scripts/prepare.ts
