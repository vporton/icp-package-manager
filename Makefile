#!/usr/bin/make -f

.PHONY: deploy
deploy: repository pm

.PHONY: repository
repository:
	dfx deploy RepositoryIndex
	dfx ledger fabricate-cycles --t 2000000 --canister RepositoryIndex
	-dfx canister call RepositoryIndex init "()"
	dfx deploy counter
	npx ts-node scripts/prepare.ts
	dfx canister call RepositoryIndex setRepositoryName "RedSocks"

.PHONY: pm
pm:
	dfx deploy package_manager
	dfx ledger fabricate-cycles --t 2000000 --canister package_manager
