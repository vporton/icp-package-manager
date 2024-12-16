#!/usr/bin/make -f

USER = $(shell dfx identity get-principal)

.PHONY: deploy

INIT_BLOB = $(shell echo 'encode(record {user = principal "aaaaa-aa"; initialOwner = principal "aaaaa-aa"; installationId = 0: nat})' | ic-repl-linux64)

.PHONY: deploy
deploy:
	dfx canister create package_manager
	# dfx canister create bootstrapper
	dfx canister create package_manager_frontend
	dfx canister create bootstrapper_frontend
	dfx canister create RepositoryIndex
	dfx canister create bookmark
	dfx canister create BootstrapperIndirectCaller
	dfx canister create example_frontend
	dfx canister create internet_identity
	# TODO: What does it do with cycles_ledger on mainnet?
	dfx canister create cycles_ledger
	dfx build BootstrapperIndirectCaller
	dfx generate BootstrapperIndirectCaller
	dfx canister install -m auto BootstrapperIndirectCaller --argument \
	  'record {packageManagerOrBootstrapper = principal "aaaaa-aa"; initialIndirect = principal "aaaaa-aa"; userArg = blob $(INIT_BLOB)}'
	dfx build package_manager
#	dfx canister install -m auto package_manager
	# dfx build bootstrapper
	dfx build RepositoryIndex
	dfx generate RepositoryIndex
	dfx canister install -m auto RepositoryIndex
	dfx generate RepositoryPartition
	dfx generate package_manager
	# dfx generate bootstrapper
	# dfx canister install -m auto bootstrapper
	dfx generate bookmark
	dfx build package_manager_frontend
	dfx canister install -m auto package_manager_frontend
	dfx build bootstrapper_frontend
	dfx canister install -m auto bootstrapper_frontend
	dfx build bookmark
	dfx canister install -m auto bookmark
	dfx build example_frontend
	dfx canister install -m auto example_frontend
	dfx deploy internet_identity
	dfx deploy cycles_ledger
	dfx ledger fabricate-cycles --t 2000000 --canister RepositoryIndex
	dfx ledger fabricate-cycles --t 2000000 --canister cycles_ledger
	dfx ledger fabricate-cycles --t 2000000 --canister BootstrapperIndirectCaller
	-dfx canister call RepositoryIndex init "()"
	npx ts-node scripts/prepare.ts
