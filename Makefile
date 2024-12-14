#!/usr/bin/make -f

USER = $(shell dfx identity get-principal)

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
	dfx canister create example_frontend
	dfx canister create internet_identity
	# TODO: What does it do with cycles_ledger on mainnet?
	dfx canister create cycles_ledger
	dfx build BootstrapperIndirectCaller
	dfx generate BootstrapperIndirectCaller
	dfx canister install -m auto BootstrapperIndirectCaller --argument \
	  'record {packageManagerOrBootstrapper = principal "aaaaa-aa"; initialIndirect = principal "aaaaa-aa"; userArg = blob "\44\49\44\4c\01\6c\03\cb\a4\b6\ed\04\68\b5\fc\e3\e5\09\7d\8f\b2\9a\e4\0f\68\01\00\01\00\00\01\00"}'
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
