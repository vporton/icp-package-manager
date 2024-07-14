#!/usr/bin/make -f

.PHONY: repository
repository:
	dfx deploy RepositoryIndex
	dfx canister call RepositoryIndex setRepositoryName "RedSocks"