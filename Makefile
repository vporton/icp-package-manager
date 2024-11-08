#!/usr/bin/make -f

.PHONY: deploy

.PHONY: deploy
deploy:
	dfx canister create package_manager
	# dfx canister create bootstrapper
	dfx canister create package_manager_frontend
	dfx canister create bootstrapper_frontend
	dfx canister create RepositoryIndex
	dfx canister create bookmark
	dfx canister create BootstrapperIndirectCaller
	dfx canister create internet_identity
	# TODO: What does it do with cycles_ledger on mainnet?
	dfx canister create cycles_ledger
	dfx build BootstrapperIndirectCaller
	dfx generate BootstrapperIndirectCaller
	dfx canister install -m auto BootstrapperIndirectCaller
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
	dfx deploy internet_identity
	dfx ledger fabricate-cycles --t 2000000 --canister RepositoryIndex
	dfx ledger fabricate-cycles --t 2000000 --canister cycles_ledger
	dfx ledger fabricate-cycles --t 2000000 --canister BootstrapperIndirectCaller
	-dfx canister call RepositoryIndex init "()"
	# npx ts-node scripts/prepare.ts
