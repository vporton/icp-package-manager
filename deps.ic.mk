NETWORK ?= local

DEPLOY_FLAGS ?= 

ROOT_DIR := $(dir $(realpath $(lastword $(MAKEFILE_LIST))))

.PHONY: canister@Bootstrapper canister@BootstrapperData canister@RepositoryIndex canister@bookmark canister@bootstrapper_frontend canister@cycles_ledger canister@example_frontend canister@indirect_caller canister@internet_identity canister@package_manager canister@package_manager_frontend canister@simple_indirect

.PHONY: deploy@Bootstrapper deploy@BootstrapperData deploy@RepositoryIndex deploy@bookmark deploy@bootstrapper_frontend deploy@cycles_ledger deploy@example_frontend deploy@indirect_caller deploy@internet_identity deploy@package_manager deploy@package_manager_frontend deploy@simple_indirect

.PHONY: generate@Bootstrapper generate@BootstrapperData generate@RepositoryIndex generate@bookmark generate@bootstrapper_frontend generate@cycles_ledger generate@example_frontend generate@indirect_caller generate@internet_identity generate@package_manager generate@package_manager_frontend generate@simple_indirect

canister@Bootstrapper: \
  .dfx/$(NETWORK)/canisters/Bootstrapper/Bootstrapper.wasm .dfx/$(NETWORK)/canisters/Bootstrapper/Bootstrapper.did

.dfx/$(NETWORK)/canisters/Bootstrapper/Bootstrapper.wasm .dfx/$(NETWORK)/canisters/Bootstrapper/Bootstrapper.did: src/bootstrapper_backend/bootstrapper.mo

canister@BootstrapperData: \
  .dfx/$(NETWORK)/canisters/BootstrapperData/BootstrapperData.wasm .dfx/$(NETWORK)/canisters/BootstrapperData/BootstrapperData.did

.dfx/$(NETWORK)/canisters/BootstrapperData/BootstrapperData.wasm .dfx/$(NETWORK)/canisters/BootstrapperData/BootstrapperData.did: src/bootstrapper_backend/BootstrapperData.mo

canister@RepositoryIndex: \
  .dfx/$(NETWORK)/canisters/RepositoryIndex/RepositoryIndex.wasm .dfx/$(NETWORK)/canisters/RepositoryIndex/RepositoryIndex.did

.dfx/$(NETWORK)/canisters/RepositoryIndex/RepositoryIndex.wasm .dfx/$(NETWORK)/canisters/RepositoryIndex/RepositoryIndex.did: src/repository_backend/RepositoryIndex.mo

canister@bookmark: \
  .dfx/$(NETWORK)/canisters/bookmark/bookmark.wasm .dfx/$(NETWORK)/canisters/bookmark/bookmark.did

.dfx/$(NETWORK)/canisters/bookmark/bookmark.wasm .dfx/$(NETWORK)/canisters/bookmark/bookmark.did: src/bootstrapper_backend/bookmarks.mo

canister@bootstrapper_frontend: \
  .dfx/$(NETWORK)/canisters/bootstrapper_frontend/assetstorage.wasm.gz

canister@cycles_ledger: \
  .dfx/$(NETWORK)/canisters/cycles_ledger/cycles_ledger.wasm .dfx/$(NETWORK)/canisters/cycles_ledger/cycles_ledger.did

.dfx/$(NETWORK)/canisters/cycles_ledger/cycles_ledger.wasm .dfx/$(NETWORK)/canisters/cycles_ledger/cycles_ledger.did: src/MockCreateCanister.mo

canister@example_frontend: \
  .dfx/$(NETWORK)/canisters/example_frontend/assetstorage.wasm.gz

canister@indirect_caller: \
  .dfx/$(NETWORK)/canisters/indirect_caller/indirect_caller.wasm .dfx/$(NETWORK)/canisters/indirect_caller/indirect_caller.did

.dfx/$(NETWORK)/canisters/indirect_caller/indirect_caller.wasm .dfx/$(NETWORK)/canisters/indirect_caller/indirect_caller.did: src/package_manager_backend/indirect_caller.mo

canister@internet_identity: \
  .dfx/$(NETWORK)/canisters/internet_identity/internet_identity.wasm.gz .dfx/$(NETWORK)/canisters/internet_identity/internet_identity.did

canister@package_manager: \
  .dfx/$(NETWORK)/canisters/package_manager/package_manager.wasm .dfx/$(NETWORK)/canisters/package_manager/package_manager.did

.dfx/$(NETWORK)/canisters/package_manager/package_manager.wasm .dfx/$(NETWORK)/canisters/package_manager/package_manager.did: src/package_manager_backend/package_manager.mo

canister@package_manager_frontend: \
  .dfx/$(NETWORK)/canisters/package_manager_frontend/assetstorage.wasm.gz

canister@simple_indirect: \
  .dfx/$(NETWORK)/canisters/simple_indirect/simple_indirect.wasm .dfx/$(NETWORK)/canisters/simple_indirect/simple_indirect.did

.dfx/$(NETWORK)/canisters/simple_indirect/simple_indirect.wasm .dfx/$(NETWORK)/canisters/simple_indirect/simple_indirect.did: src/package_manager_backend/simple_indirect.mo

generate@Bootstrapper: \
  src/declarations/Bootstrapper/Bootstrapper.did.js src/declarations/Bootstrapper/index.js src/declarations/Bootstrapper/Bootstrapper.did.d.ts src/declarations/Bootstrapper/index.d.ts src/declarations/Bootstrapper/Bootstrapper.did

src/declarations/Bootstrapper/Bootstrapper.did.js src/declarations/Bootstrapper/index.js src/declarations/Bootstrapper/Bootstrapper.did.d.ts src/declarations/Bootstrapper/index.d.ts src/declarations/Bootstrapper/Bootstrapper.did: .dfx/$(NETWORK)/canisters/Bootstrapper/Bootstrapper.did
	dfx generate --no-compile --network $(NETWORK) Bootstrapper

generate@BootstrapperData: \
  src/declarations/BootstrapperData/BootstrapperData.did.js src/declarations/BootstrapperData/index.js src/declarations/BootstrapperData/BootstrapperData.did.d.ts src/declarations/BootstrapperData/index.d.ts src/declarations/BootstrapperData/BootstrapperData.did

src/declarations/BootstrapperData/BootstrapperData.did.js src/declarations/BootstrapperData/index.js src/declarations/BootstrapperData/BootstrapperData.did.d.ts src/declarations/BootstrapperData/index.d.ts src/declarations/BootstrapperData/BootstrapperData.did: .dfx/$(NETWORK)/canisters/BootstrapperData/BootstrapperData.did
	dfx generate --no-compile --network $(NETWORK) BootstrapperData

generate@RepositoryIndex: \
  src/declarations/RepositoryIndex/RepositoryIndex.did.js src/declarations/RepositoryIndex/index.js src/declarations/RepositoryIndex/RepositoryIndex.did.d.ts src/declarations/RepositoryIndex/index.d.ts src/declarations/RepositoryIndex/RepositoryIndex.did

src/declarations/RepositoryIndex/RepositoryIndex.did.js src/declarations/RepositoryIndex/index.js src/declarations/RepositoryIndex/RepositoryIndex.did.d.ts src/declarations/RepositoryIndex/index.d.ts src/declarations/RepositoryIndex/RepositoryIndex.did: .dfx/$(NETWORK)/canisters/RepositoryIndex/RepositoryIndex.did
	dfx generate --no-compile --network $(NETWORK) RepositoryIndex

generate@bookmark: \
  src/declarations/bookmark/bookmark.did.js src/declarations/bookmark/index.js src/declarations/bookmark/bookmark.did.d.ts src/declarations/bookmark/index.d.ts src/declarations/bookmark/bookmark.did

src/declarations/bookmark/bookmark.did.js src/declarations/bookmark/index.js src/declarations/bookmark/bookmark.did.d.ts src/declarations/bookmark/index.d.ts src/declarations/bookmark/bookmark.did: .dfx/$(NETWORK)/canisters/bookmark/bookmark.did
	dfx generate --no-compile --network $(NETWORK) bookmark

generate@bootstrapper_frontend: \
  src/declarations/bootstrapper_frontend/bootstrapper_frontend.did.js src/declarations/bootstrapper_frontend/index.js src/declarations/bootstrapper_frontend/bootstrapper_frontend.did.d.ts src/declarations/bootstrapper_frontend/index.d.ts src/declarations/bootstrapper_frontend/bootstrapper_frontend.did

src/declarations/bootstrapper_frontend/bootstrapper_frontend.did.js src/declarations/bootstrapper_frontend/index.js src/declarations/bootstrapper_frontend/bootstrapper_frontend.did.d.ts src/declarations/bootstrapper_frontend/index.d.ts src/declarations/bootstrapper_frontend/bootstrapper_frontend.did: .dfx/$(NETWORK)/canisters/bootstrapper_frontend/service.did
	dfx generate --no-compile --network $(NETWORK) bootstrapper_frontend

generate@cycles_ledger: \
  src/declarations/cycles_ledger/cycles_ledger.did.js src/declarations/cycles_ledger/index.js src/declarations/cycles_ledger/cycles_ledger.did.d.ts src/declarations/cycles_ledger/index.d.ts src/declarations/cycles_ledger/cycles_ledger.did

src/declarations/cycles_ledger/cycles_ledger.did.js src/declarations/cycles_ledger/index.js src/declarations/cycles_ledger/cycles_ledger.did.d.ts src/declarations/cycles_ledger/index.d.ts src/declarations/cycles_ledger/cycles_ledger.did: .dfx/$(NETWORK)/canisters/cycles_ledger/cycles_ledger.did
	dfx generate --no-compile --network $(NETWORK) cycles_ledger

generate@example_frontend: \
  src/declarations/example_frontend/example_frontend.did.js src/declarations/example_frontend/index.js src/declarations/example_frontend/example_frontend.did.d.ts src/declarations/example_frontend/index.d.ts src/declarations/example_frontend/example_frontend.did

src/declarations/example_frontend/example_frontend.did.js src/declarations/example_frontend/index.js src/declarations/example_frontend/example_frontend.did.d.ts src/declarations/example_frontend/index.d.ts src/declarations/example_frontend/example_frontend.did: .dfx/$(NETWORK)/canisters/example_frontend/service.did
	dfx generate --no-compile --network $(NETWORK) example_frontend

generate@indirect_caller: \
  src/declarations/indirect_caller/indirect_caller.did.js src/declarations/indirect_caller/index.js src/declarations/indirect_caller/indirect_caller.did.d.ts src/declarations/indirect_caller/index.d.ts src/declarations/indirect_caller/indirect_caller.did

src/declarations/indirect_caller/indirect_caller.did.js src/declarations/indirect_caller/index.js src/declarations/indirect_caller/indirect_caller.did.d.ts src/declarations/indirect_caller/index.d.ts src/declarations/indirect_caller/indirect_caller.did: .dfx/$(NETWORK)/canisters/indirect_caller/indirect_caller.did
	dfx generate --no-compile --network $(NETWORK) indirect_caller

generate@package_manager: \
  src/declarations/package_manager/package_manager.did.js src/declarations/package_manager/index.js src/declarations/package_manager/package_manager.did.d.ts src/declarations/package_manager/index.d.ts src/declarations/package_manager/package_manager.did

src/declarations/package_manager/package_manager.did.js src/declarations/package_manager/index.js src/declarations/package_manager/package_manager.did.d.ts src/declarations/package_manager/index.d.ts src/declarations/package_manager/package_manager.did: .dfx/$(NETWORK)/canisters/package_manager/package_manager.did
	dfx generate --no-compile --network $(NETWORK) package_manager

generate@package_manager_frontend: \
  src/declarations/package_manager_frontend/package_manager_frontend.did.js src/declarations/package_manager_frontend/index.js src/declarations/package_manager_frontend/package_manager_frontend.did.d.ts src/declarations/package_manager_frontend/index.d.ts src/declarations/package_manager_frontend/package_manager_frontend.did

src/declarations/package_manager_frontend/package_manager_frontend.did.js src/declarations/package_manager_frontend/index.js src/declarations/package_manager_frontend/package_manager_frontend.did.d.ts src/declarations/package_manager_frontend/index.d.ts src/declarations/package_manager_frontend/package_manager_frontend.did: .dfx/$(NETWORK)/canisters/package_manager_frontend/service.did
	dfx generate --no-compile --network $(NETWORK) package_manager_frontend

generate@simple_indirect: \
  src/declarations/simple_indirect/simple_indirect.did.js src/declarations/simple_indirect/index.js src/declarations/simple_indirect/simple_indirect.did.d.ts src/declarations/simple_indirect/index.d.ts src/declarations/simple_indirect/simple_indirect.did

src/declarations/simple_indirect/simple_indirect.did.js src/declarations/simple_indirect/index.js src/declarations/simple_indirect/simple_indirect.did.d.ts src/declarations/simple_indirect/index.d.ts src/declarations/simple_indirect/simple_indirect.did: .dfx/$(NETWORK)/canisters/simple_indirect/simple_indirect.did
	dfx generate --no-compile --network $(NETWORK) simple_indirect

.dfx/$(NETWORK)/canisters/Bootstrapper/Bootstrapper.wasm .dfx/$(NETWORK)/canisters/Bootstrapper/Bootstrapper.did: src/common.mo
src/install.mo: .dfx/$(NETWORK)/canisters/cycles_ledger/cycles_ledger.wasm .dfx/$(NETWORK)/canisters/cycles_ledger/cycles_ledger.did
src/install.mo: src/Settings.mo
src/install.mo: src/common.mo
src/install.mo: src/copy_assets.mo
.dfx/$(NETWORK)/canisters/Bootstrapper/Bootstrapper.wasm .dfx/$(NETWORK)/canisters/Bootstrapper/Bootstrapper.did: src/install.mo
.dfx/$(NETWORK)/canisters/Bootstrapper/Bootstrapper.wasm .dfx/$(NETWORK)/canisters/Bootstrapper/Bootstrapper.did: .dfx/$(NETWORK)/canisters/BootstrapperData/BootstrapperData.wasm .dfx/$(NETWORK)/canisters/BootstrapperData/BootstrapperData.did
.dfx/$(NETWORK)/canisters/RepositoryIndex/RepositoryIndex.wasm .dfx/$(NETWORK)/canisters/RepositoryIndex/RepositoryIndex.did: src/common.mo
.dfx/$(NETWORK)/canisters/bootstrapper_frontend/assetstorage.wasm.gz: .dfx/$(NETWORK)/canisters/Bootstrapper/Bootstrapper.wasm .dfx/$(NETWORK)/canisters/Bootstrapper/Bootstrapper.did
.dfx/$(NETWORK)/canisters/bootstrapper_frontend/assetstorage.wasm.gz: .dfx/$(NETWORK)/canisters/bookmark/bookmark.wasm .dfx/$(NETWORK)/canisters/bookmark/bookmark.did
.dfx/$(NETWORK)/canisters/bootstrapper_frontend/assetstorage.wasm.gz: .dfx/$(NETWORK)/canisters/internet_identity/internet_identity.wasm.gz .dfx/$(NETWORK)/canisters/internet_identity/internet_identity.did
.dfx/$(NETWORK)/canisters/bootstrapper_frontend/assetstorage.wasm.gz: .dfx/$(NETWORK)/canisters/RepositoryIndex/RepositoryIndex.wasm .dfx/$(NETWORK)/canisters/RepositoryIndex/RepositoryIndex.did
.dfx/$(NETWORK)/canisters/indirect_caller/indirect_caller.wasm .dfx/$(NETWORK)/canisters/indirect_caller/indirect_caller.did: src/common.mo
.dfx/$(NETWORK)/canisters/indirect_caller/indirect_caller.wasm .dfx/$(NETWORK)/canisters/indirect_caller/indirect_caller.did: src/install.mo
.dfx/$(NETWORK)/canisters/package_manager/package_manager.wasm .dfx/$(NETWORK)/canisters/package_manager/package_manager.did: src/common.mo
src/package_manager_backend/indirect_caller.mo: src/common.mo
src/package_manager_backend/indirect_caller.mo: src/install.mo
.dfx/$(NETWORK)/canisters/package_manager/package_manager.wasm .dfx/$(NETWORK)/canisters/package_manager/package_manager.did: src/package_manager_backend/indirect_caller.mo
.dfx/$(NETWORK)/canisters/package_manager/package_manager.wasm .dfx/$(NETWORK)/canisters/package_manager/package_manager.did: src/package_manager_backend/simple_indirect.mo
.dfx/$(NETWORK)/canisters/package_manager_frontend/assetstorage.wasm.gz: .dfx/$(NETWORK)/canisters/package_manager/package_manager.wasm .dfx/$(NETWORK)/canisters/package_manager/package_manager.did
.dfx/$(NETWORK)/canisters/package_manager_frontend/assetstorage.wasm.gz: .dfx/$(NETWORK)/canisters/internet_identity/internet_identity.wasm.gz .dfx/$(NETWORK)/canisters/internet_identity/internet_identity.did
.PHONY: .dfx/$(NETWORK)/canisters/bootstrapper_frontend/assetstorage.wasm.gz
.dfx/$(NETWORK)/canisters/bootstrapper_frontend/assetstorage.wasm.gz:
	dfx canister create --network $(NETWORK) bootstrapper_frontend
	dfx build --no-deps --network $(NETWORK) bootstrapper_frontend


deploy-self@bootstrapper_frontend: canister@bootstrapper_frontend
	dfx deploy --no-compile --network $(NETWORK) $(DEPLOY_FLAGS) $(DEPLOY_FLAGS.bootstrapper_frontend) bootstrapper_frontend


canister@bootstrapper_frontend: \
  generate@Bootstrapper generate@bookmark generate@internet_identity generate@RepositoryIndex
deploy@bootstrapper_frontend: deploy@Bootstrapper deploy@bookmark deploy@internet_identity deploy@RepositoryIndex \
  deploy-self@bootstrapper_frontend

.dfx/$(NETWORK)/canisters/package_manager/package_manager.wasm .dfx/$(NETWORK)/canisters/package_manager/package_manager.did:
	dfx canister create --network $(NETWORK) package_manager
	dfx build --no-deps --network $(NETWORK) package_manager


deploy-self@package_manager: canister@package_manager
	dfx deploy --no-compile --network $(NETWORK) $(DEPLOY_FLAGS) $(DEPLOY_FLAGS.package_manager) package_manager

deploy@package_manager: deploy@Bootstrapper deploy@cycles_ledger deploy@RepositoryIndex \
  deploy-self@package_manager

.PHONY: .dfx/$(NETWORK)/canisters/package_manager_frontend/assetstorage.wasm.gz
.dfx/$(NETWORK)/canisters/package_manager_frontend/assetstorage.wasm.gz:
	dfx canister create --network $(NETWORK) package_manager_frontend
	dfx build --no-deps --network $(NETWORK) package_manager_frontend


deploy-self@package_manager_frontend: canister@package_manager_frontend
	dfx deploy --no-compile --network $(NETWORK) $(DEPLOY_FLAGS) $(DEPLOY_FLAGS.package_manager_frontend) package_manager_frontend


canister@package_manager_frontend: \
  generate@package_manager generate@internet_identity
deploy@package_manager_frontend: deploy@package_manager deploy@internet_identity \
  deploy-self@package_manager_frontend

.dfx/$(NETWORK)/canisters/cycles_ledger/cycles_ledger.wasm .dfx/$(NETWORK)/canisters/cycles_ledger/cycles_ledger.did:
	dfx canister create --network $(NETWORK) cycles_ledger
	dfx build --no-deps --network $(NETWORK) cycles_ledger


deploy-self@cycles_ledger: canister@cycles_ledger
	dfx deploy --no-compile --network $(NETWORK) $(DEPLOY_FLAGS) $(DEPLOY_FLAGS.cycles_ledger) cycles_ledger

deploy@cycles_ledger: deploy-self@cycles_ledger

.dfx/$(NETWORK)/canisters/indirect_caller/indirect_caller.wasm .dfx/$(NETWORK)/canisters/indirect_caller/indirect_caller.did:
	dfx canister create --network $(NETWORK) indirect_caller
	dfx build --no-deps --network $(NETWORK) indirect_caller


deploy-self@indirect_caller: canister@indirect_caller
	dfx deploy --no-compile --network $(NETWORK) $(DEPLOY_FLAGS) $(DEPLOY_FLAGS.indirect_caller) indirect_caller

deploy@indirect_caller: deploy@Bootstrapper deploy@cycles_ledger \
  deploy-self@indirect_caller

.dfx/$(NETWORK)/canisters/RepositoryIndex/RepositoryIndex.wasm .dfx/$(NETWORK)/canisters/RepositoryIndex/RepositoryIndex.did:
	dfx canister create --network $(NETWORK) RepositoryIndex
	dfx build --no-deps --network $(NETWORK) RepositoryIndex


deploy-self@RepositoryIndex: canister@RepositoryIndex
	dfx deploy --no-compile --network $(NETWORK) $(DEPLOY_FLAGS) $(DEPLOY_FLAGS.RepositoryIndex) RepositoryIndex

deploy@RepositoryIndex: deploy-self@RepositoryIndex

.dfx/$(NETWORK)/canisters/BootstrapperData/BootstrapperData.wasm .dfx/$(NETWORK)/canisters/BootstrapperData/BootstrapperData.did:
	dfx canister create --network $(NETWORK) BootstrapperData
	dfx build --no-deps --network $(NETWORK) BootstrapperData


deploy-self@BootstrapperData: canister@BootstrapperData
	dfx deploy --no-compile --network $(NETWORK) $(DEPLOY_FLAGS) $(DEPLOY_FLAGS.BootstrapperData) BootstrapperData

deploy@BootstrapperData: deploy-self@BootstrapperData

.dfx/$(NETWORK)/canisters/internet_identity/internet_identity.wasm.gz .dfx/$(NETWORK)/canisters/internet_identity/internet_identity.did:
	dfx canister create --network $(NETWORK) internet_identity
	dfx build --no-deps --network $(NETWORK) internet_identity


deploy-self@internet_identity: canister@internet_identity
	dfx deploy --no-compile --network $(NETWORK) $(DEPLOY_FLAGS) $(DEPLOY_FLAGS.internet_identity) internet_identity

deploy@internet_identity: deploy-self@internet_identity

.PHONY: .dfx/$(NETWORK)/canisters/example_frontend/assetstorage.wasm.gz
.dfx/$(NETWORK)/canisters/example_frontend/assetstorage.wasm.gz:
	dfx canister create --network $(NETWORK) example_frontend
	dfx build --no-deps --network $(NETWORK) example_frontend


deploy-self@example_frontend: canister@example_frontend
	dfx deploy --no-compile --network $(NETWORK) $(DEPLOY_FLAGS) $(DEPLOY_FLAGS.example_frontend) example_frontend

deploy@example_frontend: deploy-self@example_frontend

.dfx/$(NETWORK)/canisters/simple_indirect/simple_indirect.wasm .dfx/$(NETWORK)/canisters/simple_indirect/simple_indirect.did:
	dfx canister create --network $(NETWORK) simple_indirect
	dfx build --no-deps --network $(NETWORK) simple_indirect


deploy-self@simple_indirect: canister@simple_indirect
	dfx deploy --no-compile --network $(NETWORK) $(DEPLOY_FLAGS) $(DEPLOY_FLAGS.simple_indirect) simple_indirect

deploy@simple_indirect: deploy@cycles_ledger \
  deploy-self@simple_indirect

.dfx/$(NETWORK)/canisters/Bootstrapper/Bootstrapper.wasm .dfx/$(NETWORK)/canisters/Bootstrapper/Bootstrapper.did:
	dfx canister create --network $(NETWORK) Bootstrapper
	dfx build --no-deps --network $(NETWORK) Bootstrapper


deploy-self@Bootstrapper: canister@Bootstrapper
	dfx deploy --no-compile --network $(NETWORK) $(DEPLOY_FLAGS) $(DEPLOY_FLAGS.Bootstrapper) Bootstrapper

deploy@Bootstrapper: deploy@cycles_ledger deploy@BootstrapperData deploy@RepositoryIndex \
  deploy-self@Bootstrapper

.dfx/$(NETWORK)/canisters/bookmark/bookmark.wasm .dfx/$(NETWORK)/canisters/bookmark/bookmark.did:
	dfx canister create --network $(NETWORK) bookmark
	dfx build --no-deps --network $(NETWORK) bookmark


deploy-self@bookmark: canister@bookmark
	dfx deploy --no-compile --network $(NETWORK) $(DEPLOY_FLAGS) $(DEPLOY_FLAGS.bookmark) bookmark

deploy@bookmark: deploy-self@bookmark

