#!/usr/bin/make -f

USER = $(shell dfx identity get-principal)

.PHONY: deploy

# TODO:
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
	dfx canister create example_frontend
	dfx canister create internet_identity
# `generate` erases `.env`.
	dfx build internet_identity
	dfx build bootstrapper_frontend
	dfx canister install -m auto bootstrapper_frontend
	dfx generate bootstrapper_frontend
	dfx build package_manager_frontend
	dfx canister install -m auto internet_identity
	dfx generate package_manager_frontend
	dfx generate internet_identity
	dfx generate Bootstrapper
	dfx generate indirect_caller
	dfx generate RepositoryIndex
	dfx generate simple_indirect
	dfx generate RepositoryPartition
	dfx generate package_manager
	dfx generate bookmark
	dfx canister install -m auto package_manager_frontend # for a template
	# TODO: What does it do with cycles_ledger on mainnet?
	dfx canister create simple_indirect
	dfx canister create cycles_ledger
	dfx build cycles_ledger
	dfx canister install -m auto cycles_ledger
	dfx build Bootstrapper
	dfx canister install -m auto Bootstrapper
	dfx build indirect_caller
	dfx build package_manager
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
	npx ts-node scripts/prepare.ts
