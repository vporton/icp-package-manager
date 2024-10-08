#!/usr/bin/make -f

.PHONY: deploy
deploy: repository pm

.PHONY: repository
repository:
	dfx generate RepositoryPartition
	dfx generate RepositoryIndex  # for prepare.ts
	dfx generate package_manager  # TODO: needed?
	dfx deploy RepositoryIndex
	dfx ledger fabricate-cycles --t 2000000 --canister RepositoryIndex
	-dfx canister call RepositoryIndex init "()"
	dfx deploy counter
#	npx ts-node scripts/prepare.ts
#	dfx canister call RepositoryIndex setRepositoryName "RedSocks"

.PHONY: pm
pm:
	dfx deploy package_manager
	dfx ledger fabricate-cycles --t 2000000 --canister package_manager
