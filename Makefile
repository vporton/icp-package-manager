#!/usr/bin/make -f

.PHONY: deploy

.PHONY: deploy
deploy:
	dfx canister create package_manager
	dfx canister create bootstrapper
	dfx canister create package_manager_frontend
	dfx canister create bootstrapper_frontend
	dfx canister create RepositoryIndex
	dfx canister create bookmark
	dfx canister create indirect_caller
	dfx canister create internet_identity
	dfx build package_manager
	dfx build bootstrapper
	dfx build RepositoryIndex
	dfx build indirect_caller
	dfx generate RepositoryIndex
	dfx generate RepositoryPartition
	dfx generate package_manager
	dfx generate bootstrapper
	dfx generate bookmark
	dfx build package_manager_frontend
	dfx build bootstrapper_frontend
	dfx build bookmark
	dfx canister install -m auto package_manager
	dfx canister install -m auto bootstrapper
	dfx canister install -m auto package_manager_frontend
	dfx canister install -m auto bootstrapper_frontend
	dfx canister install -m auto RepositoryIndex
	dfx canister install -m auto bookmark
	dfx canister install -m auto indirect_caller
	dfx deploy internet_identity
	dfx ledger fabricate-cycles --t 2000000 --canister RepositoryIndex
	-dfx canister call RepositoryIndex init "()"
	npx ts-node scripts/prepare.ts
