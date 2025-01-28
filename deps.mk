NETWORK ?= local

DEPLOY_FLAGS ?= 

ROOT_DIR := $(dir $(realpath $(lastword $(MAKEFILE_LIST))))

.PHONY: canister@Bootstrapper canister@BootstrapperData canister@RepositoryIndex canister@RepositoryPartition canister@bookmark canister@bootstrapper_frontend canister@cycles_ledger canister@example_frontend canister@indirect_caller canister@internet_identity canister@package_manager canister@package_manager_frontend canister@simple_indirect

.PHONY: deploy@Bootstrapper deploy@BootstrapperData deploy@RepositoryIndex deploy@RepositoryPartition deploy@bookmark deploy@bootstrapper_frontend deploy@cycles_ledger deploy@example_frontend deploy@indirect_caller deploy@internet_identity deploy@package_manager deploy@package_manager_frontend deploy@simple_indirect

.PHONY: generate@Bootstrapper generate@BootstrapperData generate@RepositoryIndex generate@RepositoryPartition generate@bookmark generate@bootstrapper_frontend generate@cycles_ledger generate@example_frontend generate@indirect_caller generate@internet_identity generate@package_manager generate@package_manager_frontend generate@simple_indirect

canister@Bootstrapper: \
  $(ROOT_DIR)/.dfx/local/canisters/Bootstrapper/Bootstrapper.wasm $(ROOT_DIR)/.dfx/local/canisters/Bootstrapper/Bootstrapper.did

$(ROOT_DIR)/.dfx/local/canisters/Bootstrapper/Bootstrapper.wasm $(ROOT_DIR)/.dfx/local/canisters/Bootstrapper/Bootstrapper.did: $(ROOT_DIR)/src/bootstrapper_backend/bootstrapper.mo

canister@BootstrapperData: \
  $(ROOT_DIR)/.dfx/local/canisters/BootstrapperData/BootstrapperData.wasm $(ROOT_DIR)/.dfx/local/canisters/BootstrapperData/BootstrapperData.did

$(ROOT_DIR)/.dfx/local/canisters/BootstrapperData/BootstrapperData.wasm $(ROOT_DIR)/.dfx/local/canisters/BootstrapperData/BootstrapperData.did: $(ROOT_DIR)/src/bootstrapper_backend/BootstrapperData.mo

canister@RepositoryIndex: \
  $(ROOT_DIR)/.dfx/local/canisters/RepositoryIndex/RepositoryIndex.wasm $(ROOT_DIR)/.dfx/local/canisters/RepositoryIndex/RepositoryIndex.did

$(ROOT_DIR)/.dfx/local/canisters/RepositoryIndex/RepositoryIndex.wasm $(ROOT_DIR)/.dfx/local/canisters/RepositoryIndex/RepositoryIndex.did: $(ROOT_DIR)/src/repository_backend/RepositoryIndex.mo

canister@RepositoryPartition: \
  $(ROOT_DIR)/.dfx/local/canisters/RepositoryPartition/RepositoryPartition.wasm $(ROOT_DIR)/.dfx/local/canisters/RepositoryPartition/RepositoryPartition.did

$(ROOT_DIR)/.dfx/local/canisters/RepositoryPartition/RepositoryPartition.wasm $(ROOT_DIR)/.dfx/local/canisters/RepositoryPartition/RepositoryPartition.did: $(ROOT_DIR)/src/repository_backend/RepositoryPartition.mo

canister@bookmark: \
  $(ROOT_DIR)/.dfx/local/canisters/bookmark/bookmark.wasm $(ROOT_DIR)/.dfx/local/canisters/bookmark/bookmark.did

$(ROOT_DIR)/.dfx/local/canisters/bookmark/bookmark.wasm $(ROOT_DIR)/.dfx/local/canisters/bookmark/bookmark.did: $(ROOT_DIR)/src/bootstrapper_backend/bookmarks.mo

canister@bootstrapper_frontend: \
  $(ROOT_DIR)/.dfx/local/canisters/bootstrapper_frontend/bootstrapper_frontend.wasm.gz $(ROOT_DIR)/.dfx/local/canisters/bootstrapper_frontend/assetstorage.wasm.gz

canister@cycles_ledger: \
  $(ROOT_DIR)/.dfx/local/canisters/cycles_ledger/cycles_ledger.wasm $(ROOT_DIR)/.dfx/local/canisters/cycles_ledger/cycles_ledger.did

$(ROOT_DIR)/.dfx/local/canisters/cycles_ledger/cycles_ledger.wasm $(ROOT_DIR)/.dfx/local/canisters/cycles_ledger/cycles_ledger.did: $(ROOT_DIR)/src/MockCreateCanister.mo

canister@example_frontend: \
  $(ROOT_DIR)/.dfx/local/canisters/example_frontend/example_frontend.wasm.gz $(ROOT_DIR)/.dfx/local/canisters/example_frontend/assetstorage.wasm.gz

canister@indirect_caller: \
  $(ROOT_DIR)/.dfx/local/canisters/indirect_caller/indirect_caller.wasm $(ROOT_DIR)/.dfx/local/canisters/indirect_caller/indirect_caller.did

$(ROOT_DIR)/.dfx/local/canisters/indirect_caller/indirect_caller.wasm $(ROOT_DIR)/.dfx/local/canisters/indirect_caller/indirect_caller.did: $(ROOT_DIR)/src/package_manager_backend/indirect_caller.mo

canister@internet_identity: \
  $(ROOT_DIR)/.dfx/local/canisters/internet_identity/internet_identity.wasm $(ROOT_DIR)/.dfx/local/canisters/internet_identity/internet_identity.did

canister@package_manager: \
  $(ROOT_DIR)/.dfx/local/canisters/package_manager/package_manager.wasm $(ROOT_DIR)/.dfx/local/canisters/package_manager/package_manager.did

$(ROOT_DIR)/.dfx/local/canisters/package_manager/package_manager.wasm $(ROOT_DIR)/.dfx/local/canisters/package_manager/package_manager.did: $(ROOT_DIR)/src/package_manager_backend/package_manager.mo

canister@package_manager_frontend: \
  $(ROOT_DIR)/.dfx/local/canisters/package_manager_frontend/package_manager_frontend.wasm.gz $(ROOT_DIR)/.dfx/local/canisters/package_manager_frontend/assetstorage.wasm.gz

canister@simple_indirect: \
  $(ROOT_DIR)/.dfx/local/canisters/simple_indirect/simple_indirect.wasm $(ROOT_DIR)/.dfx/local/canisters/simple_indirect/simple_indirect.did

$(ROOT_DIR)/.dfx/local/canisters/simple_indirect/simple_indirect.wasm $(ROOT_DIR)/.dfx/local/canisters/simple_indirect/simple_indirect.did: $(ROOT_DIR)/src/package_manager_backend/simple_indirect.mo

generate@Bootstrapper: \
  $(ROOT_DIR)/src/declarations/Bootstrapper/Bootstrapper.did.js $(ROOT_DIR)/src/declarations/Bootstrapper/index.js $(ROOT_DIR)/src/declarations/Bootstrapper/Bootstrapper.did.d.ts $(ROOT_DIR)/src/declarations/Bootstrapper/index.d.ts $(ROOT_DIR)/src/declarations/Bootstrapper/Bootstrapper.did

$(ROOT_DIR)/src/declarations/Bootstrapper/Bootstrapper.did.js $(ROOT_DIR)/src/declarations/Bootstrapper/index.js $(ROOT_DIR)/src/declarations/Bootstrapper/Bootstrapper.did.d.ts $(ROOT_DIR)/src/declarations/Bootstrapper/index.d.ts $(ROOT_DIR)/src/declarations/Bootstrapper/Bootstrapper.did: $(ROOT_DIR)/.dfx/local/canisters/Bootstrapper/Bootstrapper.did
	dfx generate --no-compile --network $(NETWORK) Bootstrapper

generate@BootstrapperData: \
  $(ROOT_DIR)/src/declarations/BootstrapperData/BootstrapperData.did.js $(ROOT_DIR)/src/declarations/BootstrapperData/index.js $(ROOT_DIR)/src/declarations/BootstrapperData/BootstrapperData.did.d.ts $(ROOT_DIR)/src/declarations/BootstrapperData/index.d.ts $(ROOT_DIR)/src/declarations/BootstrapperData/BootstrapperData.did

$(ROOT_DIR)/src/declarations/BootstrapperData/BootstrapperData.did.js $(ROOT_DIR)/src/declarations/BootstrapperData/index.js $(ROOT_DIR)/src/declarations/BootstrapperData/BootstrapperData.did.d.ts $(ROOT_DIR)/src/declarations/BootstrapperData/index.d.ts $(ROOT_DIR)/src/declarations/BootstrapperData/BootstrapperData.did: $(ROOT_DIR)/.dfx/local/canisters/BootstrapperData/BootstrapperData.did
	dfx generate --no-compile --network $(NETWORK) BootstrapperData

generate@RepositoryIndex: \
  $(ROOT_DIR)/src/declarations/RepositoryIndex/RepositoryIndex.did.js $(ROOT_DIR)/src/declarations/RepositoryIndex/index.js $(ROOT_DIR)/src/declarations/RepositoryIndex/RepositoryIndex.did.d.ts $(ROOT_DIR)/src/declarations/RepositoryIndex/index.d.ts $(ROOT_DIR)/src/declarations/RepositoryIndex/RepositoryIndex.did

$(ROOT_DIR)/src/declarations/RepositoryIndex/RepositoryIndex.did.js $(ROOT_DIR)/src/declarations/RepositoryIndex/index.js $(ROOT_DIR)/src/declarations/RepositoryIndex/RepositoryIndex.did.d.ts $(ROOT_DIR)/src/declarations/RepositoryIndex/index.d.ts $(ROOT_DIR)/src/declarations/RepositoryIndex/RepositoryIndex.did: $(ROOT_DIR)/.dfx/local/canisters/RepositoryIndex/RepositoryIndex.did
	dfx generate --no-compile --network $(NETWORK) RepositoryIndex

generate@RepositoryPartition: \
  $(ROOT_DIR)/src/declarations/RepositoryPartition/RepositoryPartition.did.js $(ROOT_DIR)/src/declarations/RepositoryPartition/index.js $(ROOT_DIR)/src/declarations/RepositoryPartition/RepositoryPartition.did.d.ts $(ROOT_DIR)/src/declarations/RepositoryPartition/index.d.ts $(ROOT_DIR)/src/declarations/RepositoryPartition/RepositoryPartition.did

$(ROOT_DIR)/src/declarations/RepositoryPartition/RepositoryPartition.did.js $(ROOT_DIR)/src/declarations/RepositoryPartition/index.js $(ROOT_DIR)/src/declarations/RepositoryPartition/RepositoryPartition.did.d.ts $(ROOT_DIR)/src/declarations/RepositoryPartition/index.d.ts $(ROOT_DIR)/src/declarations/RepositoryPartition/RepositoryPartition.did: $(ROOT_DIR)/.dfx/local/canisters/RepositoryPartition/RepositoryPartition.did
	dfx generate --no-compile --network $(NETWORK) RepositoryPartition

generate@bookmark: \
  $(ROOT_DIR)/src/declarations/bookmark/bookmark.did.js $(ROOT_DIR)/src/declarations/bookmark/index.js $(ROOT_DIR)/src/declarations/bookmark/bookmark.did.d.ts $(ROOT_DIR)/src/declarations/bookmark/index.d.ts $(ROOT_DIR)/src/declarations/bookmark/bookmark.did

$(ROOT_DIR)/src/declarations/bookmark/bookmark.did.js $(ROOT_DIR)/src/declarations/bookmark/index.js $(ROOT_DIR)/src/declarations/bookmark/bookmark.did.d.ts $(ROOT_DIR)/src/declarations/bookmark/index.d.ts $(ROOT_DIR)/src/declarations/bookmark/bookmark.did: $(ROOT_DIR)/.dfx/local/canisters/bookmark/bookmark.did
	dfx generate --no-compile --network $(NETWORK) bookmark

generate@bootstrapper_frontend: \
  $(ROOT_DIR)/src/declarations/bootstrapper_frontend/bootstrapper_frontend.did.js $(ROOT_DIR)/src/declarations/bootstrapper_frontend/index.js $(ROOT_DIR)/src/declarations/bootstrapper_frontend/bootstrapper_frontend.did.d.ts $(ROOT_DIR)/src/declarations/bootstrapper_frontend/index.d.ts $(ROOT_DIR)/src/declarations/bootstrapper_frontend/bootstrapper_frontend.did

$(ROOT_DIR)/src/declarations/bootstrapper_frontend/bootstrapper_frontend.did.js $(ROOT_DIR)/src/declarations/bootstrapper_frontend/index.js $(ROOT_DIR)/src/declarations/bootstrapper_frontend/bootstrapper_frontend.did.d.ts $(ROOT_DIR)/src/declarations/bootstrapper_frontend/index.d.ts $(ROOT_DIR)/src/declarations/bootstrapper_frontend/bootstrapper_frontend.did: $(ROOT_DIR)/.dfx/local/canisters/bootstrapper_frontend/bootstrapper_frontend.did
	dfx generate --no-compile --network $(NETWORK) bootstrapper_frontend

generate@cycles_ledger: \
  $(ROOT_DIR)/src/declarations/cycles_ledger/cycles_ledger.did.js $(ROOT_DIR)/src/declarations/cycles_ledger/index.js $(ROOT_DIR)/src/declarations/cycles_ledger/cycles_ledger.did.d.ts $(ROOT_DIR)/src/declarations/cycles_ledger/index.d.ts $(ROOT_DIR)/src/declarations/cycles_ledger/cycles_ledger.did

$(ROOT_DIR)/src/declarations/cycles_ledger/cycles_ledger.did.js $(ROOT_DIR)/src/declarations/cycles_ledger/index.js $(ROOT_DIR)/src/declarations/cycles_ledger/cycles_ledger.did.d.ts $(ROOT_DIR)/src/declarations/cycles_ledger/index.d.ts $(ROOT_DIR)/src/declarations/cycles_ledger/cycles_ledger.did: $(ROOT_DIR)/.dfx/local/canisters/cycles_ledger/cycles_ledger.did
	dfx generate --no-compile --network $(NETWORK) cycles_ledger

generate@example_frontend: \
  $(ROOT_DIR)/src/declarations/example_frontend/example_frontend.did.js $(ROOT_DIR)/src/declarations/example_frontend/index.js $(ROOT_DIR)/src/declarations/example_frontend/example_frontend.did.d.ts $(ROOT_DIR)/src/declarations/example_frontend/index.d.ts $(ROOT_DIR)/src/declarations/example_frontend/example_frontend.did

$(ROOT_DIR)/src/declarations/example_frontend/example_frontend.did.js $(ROOT_DIR)/src/declarations/example_frontend/index.js $(ROOT_DIR)/src/declarations/example_frontend/example_frontend.did.d.ts $(ROOT_DIR)/src/declarations/example_frontend/index.d.ts $(ROOT_DIR)/src/declarations/example_frontend/example_frontend.did: $(ROOT_DIR)/.dfx/local/canisters/example_frontend/example_frontend.did
	dfx generate --no-compile --network $(NETWORK) example_frontend

generate@indirect_caller: \
  $(ROOT_DIR)/src/declarations/indirect_caller/indirect_caller.did.js $(ROOT_DIR)/src/declarations/indirect_caller/index.js $(ROOT_DIR)/src/declarations/indirect_caller/indirect_caller.did.d.ts $(ROOT_DIR)/src/declarations/indirect_caller/index.d.ts $(ROOT_DIR)/src/declarations/indirect_caller/indirect_caller.did

$(ROOT_DIR)/src/declarations/indirect_caller/indirect_caller.did.js $(ROOT_DIR)/src/declarations/indirect_caller/index.js $(ROOT_DIR)/src/declarations/indirect_caller/indirect_caller.did.d.ts $(ROOT_DIR)/src/declarations/indirect_caller/index.d.ts $(ROOT_DIR)/src/declarations/indirect_caller/indirect_caller.did: $(ROOT_DIR)/.dfx/local/canisters/indirect_caller/indirect_caller.did
	dfx generate --no-compile --network $(NETWORK) indirect_caller

generate@internet_identity: \
  $(ROOT_DIR)/src/declarations/internet_identity/internet_identity.did.js $(ROOT_DIR)/src/declarations/internet_identity/index.js $(ROOT_DIR)/src/declarations/internet_identity/internet_identity.did.d.ts $(ROOT_DIR)/src/declarations/internet_identity/index.d.ts $(ROOT_DIR)/src/declarations/internet_identity/internet_identity.did

$(ROOT_DIR)/src/declarations/internet_identity/internet_identity.did.js $(ROOT_DIR)/src/declarations/internet_identity/index.js $(ROOT_DIR)/src/declarations/internet_identity/internet_identity.did.d.ts $(ROOT_DIR)/src/declarations/internet_identity/index.d.ts $(ROOT_DIR)/src/declarations/internet_identity/internet_identity.did: $(ROOT_DIR)/.dfx/local/canisters/internet_identity/internet_identity.did
	dfx generate --no-compile --network $(NETWORK) internet_identity

generate@package_manager: \
  $(ROOT_DIR)/src/declarations/package_manager/package_manager.did.js $(ROOT_DIR)/src/declarations/package_manager/index.js $(ROOT_DIR)/src/declarations/package_manager/package_manager.did.d.ts $(ROOT_DIR)/src/declarations/package_manager/index.d.ts $(ROOT_DIR)/src/declarations/package_manager/package_manager.did

$(ROOT_DIR)/src/declarations/package_manager/package_manager.did.js $(ROOT_DIR)/src/declarations/package_manager/index.js $(ROOT_DIR)/src/declarations/package_manager/package_manager.did.d.ts $(ROOT_DIR)/src/declarations/package_manager/index.d.ts $(ROOT_DIR)/src/declarations/package_manager/package_manager.did: $(ROOT_DIR)/.dfx/local/canisters/package_manager/package_manager.did
	dfx generate --no-compile --network $(NETWORK) package_manager

generate@package_manager_frontend: \
  $(ROOT_DIR)/src/declarations/package_manager_frontend/package_manager_frontend.did.js $(ROOT_DIR)/src/declarations/package_manager_frontend/index.js $(ROOT_DIR)/src/declarations/package_manager_frontend/package_manager_frontend.did.d.ts $(ROOT_DIR)/src/declarations/package_manager_frontend/index.d.ts $(ROOT_DIR)/src/declarations/package_manager_frontend/package_manager_frontend.did

$(ROOT_DIR)/src/declarations/package_manager_frontend/package_manager_frontend.did.js $(ROOT_DIR)/src/declarations/package_manager_frontend/index.js $(ROOT_DIR)/src/declarations/package_manager_frontend/package_manager_frontend.did.d.ts $(ROOT_DIR)/src/declarations/package_manager_frontend/index.d.ts $(ROOT_DIR)/src/declarations/package_manager_frontend/package_manager_frontend.did: $(ROOT_DIR)/.dfx/local/canisters/package_manager_frontend/package_manager_frontend.did
	dfx generate --no-compile --network $(NETWORK) package_manager_frontend

generate@simple_indirect: \
  $(ROOT_DIR)/src/declarations/simple_indirect/simple_indirect.did.js $(ROOT_DIR)/src/declarations/simple_indirect/index.js $(ROOT_DIR)/src/declarations/simple_indirect/simple_indirect.did.d.ts $(ROOT_DIR)/src/declarations/simple_indirect/index.d.ts $(ROOT_DIR)/src/declarations/simple_indirect/simple_indirect.did

$(ROOT_DIR)/src/declarations/simple_indirect/simple_indirect.did.js $(ROOT_DIR)/src/declarations/simple_indirect/index.js $(ROOT_DIR)/src/declarations/simple_indirect/simple_indirect.did.d.ts $(ROOT_DIR)/src/declarations/simple_indirect/index.d.ts $(ROOT_DIR)/src/declarations/simple_indirect/simple_indirect.did: $(ROOT_DIR)/.dfx/local/canisters/simple_indirect/simple_indirect.did
	dfx generate --no-compile --network $(NETWORK) simple_indirect

$(ROOT_DIR)/.dfx/local/canisters/Bootstrapper/Bootstrapper.wasm $(ROOT_DIR)/.dfx/local/canisters/Bootstrapper/Bootstrapper.did: $(ROOT_DIR)/src/common.mo
$(ROOT_DIR)/src/install.mo: $(ROOT_DIR)/.dfx/local/canisters/cycles_ledger/cycles_ledger.wasm $(ROOT_DIR)/.dfx/local/canisters/cycles_ledger/cycles_ledger.did
$(ROOT_DIR)/src/install.mo: $(ROOT_DIR)/src/Settings.mo
$(ROOT_DIR)/src/install.mo: $(ROOT_DIR)/src/common.mo
$(ROOT_DIR)/src/install.mo: $(ROOT_DIR)/src/copy_assets.mo
$(ROOT_DIR)/.dfx/local/canisters/Bootstrapper/Bootstrapper.wasm $(ROOT_DIR)/.dfx/local/canisters/Bootstrapper/Bootstrapper.did: $(ROOT_DIR)/src/install.mo
$(ROOT_DIR)/.dfx/local/canisters/Bootstrapper/Bootstrapper.wasm $(ROOT_DIR)/.dfx/local/canisters/Bootstrapper/Bootstrapper.did: $(ROOT_DIR)/.dfx/local/canisters/BootstrapperData/BootstrapperData.wasm $(ROOT_DIR)/.dfx/local/canisters/BootstrapperData/BootstrapperData.did
$(ROOT_DIR)/src/repository_backend/RepositoryPartition.mo: $(ROOT_DIR)/src/common.mo
$(ROOT_DIR)/.dfx/local/canisters/RepositoryIndex/RepositoryIndex.wasm $(ROOT_DIR)/.dfx/local/canisters/RepositoryIndex/RepositoryIndex.did: $(ROOT_DIR)/src/repository_backend/RepositoryPartition.mo
$(ROOT_DIR)/.dfx/local/canisters/RepositoryIndex/RepositoryIndex.wasm $(ROOT_DIR)/.dfx/local/canisters/RepositoryIndex/RepositoryIndex.did: $(ROOT_DIR)/src/common.mo
$(ROOT_DIR)/.dfx/local/canisters/RepositoryPartition/RepositoryPartition.wasm $(ROOT_DIR)/.dfx/local/canisters/RepositoryPartition/RepositoryPartition.did: $(ROOT_DIR)/src/common.mo
$(ROOT_DIR)/.dfx/local/canisters/bootstrapper_frontend/bootstrapper_frontend.wasm $(ROOT_DIR)/.dfx/local/canisters/bootstrapper_frontend/bootstrapper_frontend.did: $(ROOT_DIR)/.dfx/local/canisters/Bootstrapper/Bootstrapper.wasm $(ROOT_DIR)/.dfx/local/canisters/Bootstrapper/Bootstrapper.did
$(ROOT_DIR)/.dfx/local/canisters/bootstrapper_frontend/bootstrapper_frontend.wasm $(ROOT_DIR)/.dfx/local/canisters/bootstrapper_frontend/bootstrapper_frontend.did: $(ROOT_DIR)/.dfx/local/canisters/bookmark/bookmark.wasm $(ROOT_DIR)/.dfx/local/canisters/bookmark/bookmark.did
$(ROOT_DIR)/.dfx/local/canisters/bootstrapper_frontend/bootstrapper_frontend.wasm $(ROOT_DIR)/.dfx/local/canisters/bootstrapper_frontend/bootstrapper_frontend.did: $(ROOT_DIR)/.dfx/local/canisters/internet_identity/internet_identity.wasm $(ROOT_DIR)/.dfx/local/canisters/internet_identity/internet_identity.did
$(ROOT_DIR)/.dfx/local/canisters/indirect_caller/indirect_caller.wasm $(ROOT_DIR)/.dfx/local/canisters/indirect_caller/indirect_caller.did: $(ROOT_DIR)/src/common.mo
$(ROOT_DIR)/.dfx/local/canisters/indirect_caller/indirect_caller.wasm $(ROOT_DIR)/.dfx/local/canisters/indirect_caller/indirect_caller.did: $(ROOT_DIR)/src/install.mo
$(ROOT_DIR)/.dfx/local/canisters/package_manager/package_manager.wasm $(ROOT_DIR)/.dfx/local/canisters/package_manager/package_manager.did: $(ROOT_DIR)/src/common.mo
$(ROOT_DIR)/src/package_manager_backend/indirect_caller.mo: $(ROOT_DIR)/src/common.mo
$(ROOT_DIR)/src/package_manager_backend/indirect_caller.mo: $(ROOT_DIR)/src/install.mo
$(ROOT_DIR)/.dfx/local/canisters/package_manager/package_manager.wasm $(ROOT_DIR)/.dfx/local/canisters/package_manager/package_manager.did: $(ROOT_DIR)/src/package_manager_backend/indirect_caller.mo
$(ROOT_DIR)/.dfx/local/canisters/package_manager/package_manager.wasm $(ROOT_DIR)/.dfx/local/canisters/package_manager/package_manager.did: $(ROOT_DIR)/src/package_manager_backend/simple_indirect.mo
$(ROOT_DIR)/.dfx/local/canisters/package_manager_frontend/package_manager_frontend.wasm $(ROOT_DIR)/.dfx/local/canisters/package_manager_frontend/package_manager_frontend.did: $(ROOT_DIR)/.dfx/local/canisters/package_manager/package_manager.wasm $(ROOT_DIR)/.dfx/local/canisters/package_manager/package_manager.did
$(ROOT_DIR)/.dfx/local/canisters/package_manager_frontend/package_manager_frontend.wasm $(ROOT_DIR)/.dfx/local/canisters/package_manager_frontend/package_manager_frontend.did: $(ROOT_DIR)/.dfx/local/canisters/internet_identity/internet_identity.wasm $(ROOT_DIR)/.dfx/local/canisters/internet_identity/internet_identity.did
$(ROOT_DIR)/.dfx/local/canisters/cycles_ledger/cycles_ledger.wasm $(ROOT_DIR)/.dfx/local/canisters/cycles_ledger/cycles_ledger.did:
	dfx canister create cycles_ledger
	dfx build --no-deps cycles_ledger


deploy@cycles_ledger: canister@cycles_ledger
	dfx deploy --no-compile --network $(NETWORK) $(DEPLOY_FLAGS.cycles_ledger) cycles_ledger

$(ROOT_DIR)/.dfx/local/canisters/BootstrapperData/BootstrapperData.wasm $(ROOT_DIR)/.dfx/local/canisters/BootstrapperData/BootstrapperData.did:
	dfx canister create BootstrapperData
	dfx build --no-deps BootstrapperData


deploy@BootstrapperData: canister@BootstrapperData
	dfx deploy --no-compile --network $(NETWORK) $(DEPLOY_FLAGS.BootstrapperData) BootstrapperData

$(ROOT_DIR)/.dfx/local/canisters/RepositoryIndex/RepositoryIndex.wasm $(ROOT_DIR)/.dfx/local/canisters/RepositoryIndex/RepositoryIndex.did:
	dfx canister create RepositoryIndex
	dfx build --no-deps RepositoryIndex


deploy@RepositoryIndex: canister@RepositoryIndex
	dfx deploy --no-compile --network $(NETWORK) $(DEPLOY_FLAGS.RepositoryIndex) RepositoryIndex

$(ROOT_DIR)/.dfx/local/canisters/example_frontend/example_frontend.wasm $(ROOT_DIR)/.dfx/local/canisters/example_frontend/example_frontend.did:
	dfx canister create example_frontend
	dfx build --no-deps example_frontend


deploy@example_frontend: canister@example_frontend
	dfx deploy --no-compile --network $(NETWORK) $(DEPLOY_FLAGS.example_frontend) example_frontend

$(ROOT_DIR)/.dfx/local/canisters/package_manager/package_manager.wasm $(ROOT_DIR)/.dfx/local/canisters/package_manager/package_manager.did:
	dfx canister create package_manager
	dfx build --no-deps package_manager


deploy@package_manager: canister@package_manager
	dfx deploy --no-compile --network $(NETWORK) $(DEPLOY_FLAGS.package_manager) package_manager

$(ROOT_DIR)/.dfx/local/canisters/bootstrapper_frontend/bootstrapper_frontend.wasm $(ROOT_DIR)/.dfx/local/canisters/bootstrapper_frontend/bootstrapper_frontend.did:
	dfx canister create bootstrapper_frontend
	dfx build --no-deps bootstrapper_frontend


deploy@bootstrapper_frontend: canister@bootstrapper_frontend
	dfx deploy --no-compile --network $(NETWORK) $(DEPLOY_FLAGS.bootstrapper_frontend) bootstrapper_frontend


canister@bootstrapper_frontend: generate@Bootstrapper generate@bookmark generate@internet_identity
$(ROOT_DIR)/.dfx/local/canisters/bookmark/bookmark.wasm $(ROOT_DIR)/.dfx/local/canisters/bookmark/bookmark.did:
	dfx canister create bookmark
	dfx build --no-deps bookmark


deploy@bookmark: canister@bookmark
	dfx deploy --no-compile --network $(NETWORK) $(DEPLOY_FLAGS.bookmark) bookmark

$(ROOT_DIR)/.dfx/local/canisters/Bootstrapper/Bootstrapper.wasm $(ROOT_DIR)/.dfx/local/canisters/Bootstrapper/Bootstrapper.did:
	dfx canister create Bootstrapper
	dfx build --no-deps Bootstrapper


deploy@Bootstrapper: canister@Bootstrapper
	dfx deploy --no-compile --network $(NETWORK) $(DEPLOY_FLAGS.Bootstrapper) Bootstrapper

$(ROOT_DIR)/.dfx/local/canisters/simple_indirect/simple_indirect.wasm $(ROOT_DIR)/.dfx/local/canisters/simple_indirect/simple_indirect.did:
	dfx canister create simple_indirect
	dfx build --no-deps simple_indirect


deploy@simple_indirect: canister@simple_indirect
	dfx deploy --no-compile --network $(NETWORK) $(DEPLOY_FLAGS.simple_indirect) simple_indirect

$(ROOT_DIR)/.dfx/local/canisters/RepositoryPartition/RepositoryPartition.wasm $(ROOT_DIR)/.dfx/local/canisters/RepositoryPartition/RepositoryPartition.did:
	dfx canister create RepositoryPartition
	dfx build --no-deps RepositoryPartition


deploy@RepositoryPartition: canister@RepositoryPartition
	dfx deploy --no-compile --network $(NETWORK) $(DEPLOY_FLAGS.RepositoryPartition) RepositoryPartition

$(ROOT_DIR)/.dfx/local/canisters/internet_identity/internet_identity.wasm $(ROOT_DIR)/.dfx/local/canisters/internet_identity/internet_identity.did:
	dfx canister create internet_identity
	dfx build --no-deps internet_identity


deploy@internet_identity: canister@internet_identity
	dfx deploy --no-compile --network $(NETWORK) $(DEPLOY_FLAGS.internet_identity) internet_identity

$(ROOT_DIR)/.dfx/local/canisters/package_manager_frontend/package_manager_frontend.wasm $(ROOT_DIR)/.dfx/local/canisters/package_manager_frontend/package_manager_frontend.did:
	dfx canister create package_manager_frontend
	dfx build --no-deps package_manager_frontend


deploy@package_manager_frontend: canister@package_manager_frontend
	dfx deploy --no-compile --network $(NETWORK) $(DEPLOY_FLAGS.package_manager_frontend) package_manager_frontend


canister@package_manager_frontend: generate@package_manager generate@internet_identity
$(ROOT_DIR)/.dfx/local/canisters/indirect_caller/indirect_caller.wasm $(ROOT_DIR)/.dfx/local/canisters/indirect_caller/indirect_caller.did:
	dfx canister create indirect_caller
	dfx build --no-deps indirect_caller


deploy@indirect_caller: canister@indirect_caller
	dfx deploy --no-compile --network $(NETWORK) $(DEPLOY_FLAGS.indirect_caller) indirect_caller

