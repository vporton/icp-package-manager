NETWORK ?= local

DEPLOY_FLAGS ?= 

ROOT_DIR := $(dir $(realpath $(lastword $(MAKEFILE_LIST))))

.PHONY: build@Bootstrapper build@BootstrapperData build@Repository build@bookmark build@bootstrapper_frontend build@cycles_ledger build@example_backend build@example_frontend build@internet_identity build@main_indirect build@package_manager build@package_manager_frontend build@simple_indirect build@upgrade_example_backend1_v1 build@upgrade_example_backend2_v1 build@upgrade_example_backend2_v2 build@upgrade_example_backend3_v2

.PHONY: deploy@Bootstrapper deploy@BootstrapperData deploy@Repository deploy@bookmark deploy@bootstrapper_frontend deploy@cycles_ledger deploy@example_backend deploy@example_frontend deploy@internet_identity deploy@main_indirect deploy@package_manager deploy@package_manager_frontend deploy@simple_indirect deploy@upgrade_example_backend1_v1 deploy@upgrade_example_backend2_v1 deploy@upgrade_example_backend2_v2 deploy@upgrade_example_backend3_v2

.PHONY: generate@Bootstrapper generate@BootstrapperData generate@Repository generate@bookmark generate@bootstrapper_frontend generate@cycles_ledger generate@example_backend generate@example_frontend generate@internet_identity generate@main_indirect generate@package_manager generate@package_manager_frontend generate@simple_indirect generate@upgrade_example_backend1_v1 generate@upgrade_example_backend2_v1 generate@upgrade_example_backend2_v2 generate@upgrade_example_backend3_v2

build@Bootstrapper: \
  .dfx/$(NETWORK)/canisters/Bootstrapper/Bootstrapper.wasm .dfx/$(NETWORK)/canisters/Bootstrapper/Bootstrapper.did

.dfx/$(NETWORK)/canisters/Bootstrapper/Bootstrapper.wasm .dfx/$(NETWORK)/canisters/Bootstrapper/Bootstrapper.did: src/bootstrapper_backend/bootstrapper.mo

build@BootstrapperData: \
  .dfx/$(NETWORK)/canisters/BootstrapperData/BootstrapperData.wasm .dfx/$(NETWORK)/canisters/BootstrapperData/BootstrapperData.did

.dfx/$(NETWORK)/canisters/BootstrapperData/BootstrapperData.wasm .dfx/$(NETWORK)/canisters/BootstrapperData/BootstrapperData.did: src/bootstrapper_backend/BootstrapperData.mo

build@Repository: \
  .dfx/$(NETWORK)/canisters/Repository/Repository.wasm .dfx/$(NETWORK)/canisters/Repository/Repository.did

.dfx/$(NETWORK)/canisters/Repository/Repository.wasm .dfx/$(NETWORK)/canisters/Repository/Repository.did: src/repository_backend/Repository.mo

build@bookmark: \
  .dfx/$(NETWORK)/canisters/bookmark/bookmark.wasm .dfx/$(NETWORK)/canisters/bookmark/bookmark.did

.dfx/$(NETWORK)/canisters/bookmark/bookmark.wasm .dfx/$(NETWORK)/canisters/bookmark/bookmark.did: src/bootstrapper_backend/bookmarks.mo

build@bootstrapper_frontend: \
  .dfx/$(NETWORK)/canisters/bootstrapper_frontend/assetstorage.wasm.gz

build@cycles_ledger: \
  .dfx/$(NETWORK)/canisters/cycles_ledger/cycles_ledger.wasm .dfx/$(NETWORK)/canisters/cycles_ledger/cycles_ledger.did

.dfx/$(NETWORK)/canisters/cycles_ledger/cycles_ledger.wasm .dfx/$(NETWORK)/canisters/cycles_ledger/cycles_ledger.did: src/MockCreateCanister.mo

build@example_backend: \
  .dfx/$(NETWORK)/canisters/example_backend/example_backend.wasm .dfx/$(NETWORK)/canisters/example_backend/example_backend.did

.dfx/$(NETWORK)/canisters/example_backend/example_backend.wasm .dfx/$(NETWORK)/canisters/example_backend/example_backend.did: src/example_backend/main.mo

build@example_frontend: \
  .dfx/$(NETWORK)/canisters/example_frontend/assetstorage.wasm.gz

build@internet_identity: \
  .dfx/$(NETWORK)/canisters/internet_identity/internet_identity.wasm.gz .dfx/$(NETWORK)/canisters/internet_identity/internet_identity.did

build@main_indirect: \
  .dfx/$(NETWORK)/canisters/main_indirect/main_indirect.wasm .dfx/$(NETWORK)/canisters/main_indirect/main_indirect.did

.dfx/$(NETWORK)/canisters/main_indirect/main_indirect.wasm .dfx/$(NETWORK)/canisters/main_indirect/main_indirect.did: src/package_manager_backend/main_indirect.mo

build@package_manager: \
  .dfx/$(NETWORK)/canisters/package_manager/package_manager.wasm .dfx/$(NETWORK)/canisters/package_manager/package_manager.did

.dfx/$(NETWORK)/canisters/package_manager/package_manager.wasm .dfx/$(NETWORK)/canisters/package_manager/package_manager.did: src/package_manager_backend/package_manager.mo

build@package_manager_frontend: \
  .dfx/$(NETWORK)/canisters/package_manager_frontend/assetstorage.wasm.gz

build@simple_indirect: \
  .dfx/$(NETWORK)/canisters/simple_indirect/simple_indirect.wasm .dfx/$(NETWORK)/canisters/simple_indirect/simple_indirect.did

.dfx/$(NETWORK)/canisters/simple_indirect/simple_indirect.wasm .dfx/$(NETWORK)/canisters/simple_indirect/simple_indirect.did: src/package_manager_backend/simple_indirect.mo

build@upgrade_example_backend1_v1: \
  .dfx/$(NETWORK)/canisters/upgrade_example_backend1_v1/upgrade_example_backend1_v1.wasm .dfx/$(NETWORK)/canisters/upgrade_example_backend1_v1/upgrade_example_backend1_v1.did

.dfx/$(NETWORK)/canisters/upgrade_example_backend1_v1/upgrade_example_backend1_v1.wasm .dfx/$(NETWORK)/canisters/upgrade_example_backend1_v1/upgrade_example_backend1_v1.did: src/upgrade_example_backend/0.0.1/main1.mo

build@upgrade_example_backend2_v1: \
  .dfx/$(NETWORK)/canisters/upgrade_example_backend2_v1/upgrade_example_backend2_v1.wasm .dfx/$(NETWORK)/canisters/upgrade_example_backend2_v1/upgrade_example_backend2_v1.did

.dfx/$(NETWORK)/canisters/upgrade_example_backend2_v1/upgrade_example_backend2_v1.wasm .dfx/$(NETWORK)/canisters/upgrade_example_backend2_v1/upgrade_example_backend2_v1.did: src/upgrade_example_backend/0.0.1/main2.mo

build@upgrade_example_backend2_v2: \
  .dfx/$(NETWORK)/canisters/upgrade_example_backend2_v2/upgrade_example_backend2_v2.wasm .dfx/$(NETWORK)/canisters/upgrade_example_backend2_v2/upgrade_example_backend2_v2.did

.dfx/$(NETWORK)/canisters/upgrade_example_backend2_v2/upgrade_example_backend2_v2.wasm .dfx/$(NETWORK)/canisters/upgrade_example_backend2_v2/upgrade_example_backend2_v2.did: src/upgrade_example_backend/0.0.2/main2.mo

build@upgrade_example_backend3_v2: \
  .dfx/$(NETWORK)/canisters/upgrade_example_backend3_v2/upgrade_example_backend3_v2.wasm .dfx/$(NETWORK)/canisters/upgrade_example_backend3_v2/upgrade_example_backend3_v2.did

.dfx/$(NETWORK)/canisters/upgrade_example_backend3_v2/upgrade_example_backend3_v2.wasm .dfx/$(NETWORK)/canisters/upgrade_example_backend3_v2/upgrade_example_backend3_v2.did: src/upgrade_example_backend/0.0.2/main3.mo

generate@Bootstrapper: build@Bootstrapper \
  src/declarations/Bootstrapper/Bootstrapper.did.js src/declarations/Bootstrapper/index.js src/declarations/Bootstrapper/Bootstrapper.did.d.ts src/declarations/Bootstrapper/index.d.ts src/declarations/Bootstrapper/Bootstrapper.did

src/declarations/Bootstrapper/Bootstrapper.did.js src/declarations/Bootstrapper/index.js src/declarations/Bootstrapper/Bootstrapper.did.d.ts src/declarations/Bootstrapper/index.d.ts src/declarations/Bootstrapper/Bootstrapper.did: .dfx/$(NETWORK)/canisters/Bootstrapper/Bootstrapper.did
	dfx generate --no-compile --network $(NETWORK) Bootstrapper

generate@BootstrapperData: build@BootstrapperData \
  src/declarations/BootstrapperData/BootstrapperData.did.js src/declarations/BootstrapperData/index.js src/declarations/BootstrapperData/BootstrapperData.did.d.ts src/declarations/BootstrapperData/index.d.ts src/declarations/BootstrapperData/BootstrapperData.did

src/declarations/BootstrapperData/BootstrapperData.did.js src/declarations/BootstrapperData/index.js src/declarations/BootstrapperData/BootstrapperData.did.d.ts src/declarations/BootstrapperData/index.d.ts src/declarations/BootstrapperData/BootstrapperData.did: .dfx/$(NETWORK)/canisters/BootstrapperData/BootstrapperData.did
	dfx generate --no-compile --network $(NETWORK) BootstrapperData

generate@Repository: build@Repository \
  src/declarations/Repository/Repository.did.js src/declarations/Repository/index.js src/declarations/Repository/Repository.did.d.ts src/declarations/Repository/index.d.ts src/declarations/Repository/Repository.did

src/declarations/Repository/Repository.did.js src/declarations/Repository/index.js src/declarations/Repository/Repository.did.d.ts src/declarations/Repository/index.d.ts src/declarations/Repository/Repository.did: .dfx/$(NETWORK)/canisters/Repository/Repository.did
	dfx generate --no-compile --network $(NETWORK) Repository

generate@bookmark: build@bookmark \
  src/declarations/bookmark/bookmark.did.js src/declarations/bookmark/index.js src/declarations/bookmark/bookmark.did.d.ts src/declarations/bookmark/index.d.ts src/declarations/bookmark/bookmark.did

src/declarations/bookmark/bookmark.did.js src/declarations/bookmark/index.js src/declarations/bookmark/bookmark.did.d.ts src/declarations/bookmark/index.d.ts src/declarations/bookmark/bookmark.did: .dfx/$(NETWORK)/canisters/bookmark/bookmark.did
	dfx generate --no-compile --network $(NETWORK) bookmark

generate@bootstrapper_frontend: build@bootstrapper_frontend \
  src/declarations/bootstrapper_frontend/bootstrapper_frontend.did.js src/declarations/bootstrapper_frontend/index.js src/declarations/bootstrapper_frontend/bootstrapper_frontend.did.d.ts src/declarations/bootstrapper_frontend/index.d.ts src/declarations/bootstrapper_frontend/bootstrapper_frontend.did

src/declarations/bootstrapper_frontend/bootstrapper_frontend.did.js src/declarations/bootstrapper_frontend/index.js src/declarations/bootstrapper_frontend/bootstrapper_frontend.did.d.ts src/declarations/bootstrapper_frontend/index.d.ts src/declarations/bootstrapper_frontend/bootstrapper_frontend.did: .dfx/$(NETWORK)/canisters/bootstrapper_frontend/service.did
	dfx generate --no-compile --network $(NETWORK) bootstrapper_frontend

generate@cycles_ledger: build@cycles_ledger \
  src/declarations/cycles_ledger/cycles_ledger.did.js src/declarations/cycles_ledger/index.js src/declarations/cycles_ledger/cycles_ledger.did.d.ts src/declarations/cycles_ledger/index.d.ts src/declarations/cycles_ledger/cycles_ledger.did

src/declarations/cycles_ledger/cycles_ledger.did.js src/declarations/cycles_ledger/index.js src/declarations/cycles_ledger/cycles_ledger.did.d.ts src/declarations/cycles_ledger/index.d.ts src/declarations/cycles_ledger/cycles_ledger.did: .dfx/$(NETWORK)/canisters/cycles_ledger/cycles_ledger.did
	dfx generate --no-compile --network $(NETWORK) cycles_ledger

generate@example_backend: build@example_backend \
  src/declarations/example_backend/example_backend.did.js src/declarations/example_backend/index.js src/declarations/example_backend/example_backend.did.d.ts src/declarations/example_backend/index.d.ts src/declarations/example_backend/example_backend.did

src/declarations/example_backend/example_backend.did.js src/declarations/example_backend/index.js src/declarations/example_backend/example_backend.did.d.ts src/declarations/example_backend/index.d.ts src/declarations/example_backend/example_backend.did: .dfx/$(NETWORK)/canisters/example_backend/example_backend.did
	dfx generate --no-compile --network $(NETWORK) example_backend

generate@example_frontend: build@example_frontend \
  src/declarations/example_frontend/example_frontend.did.js src/declarations/example_frontend/index.js src/declarations/example_frontend/example_frontend.did.d.ts src/declarations/example_frontend/index.d.ts src/declarations/example_frontend/example_frontend.did

src/declarations/example_frontend/example_frontend.did.js src/declarations/example_frontend/index.js src/declarations/example_frontend/example_frontend.did.d.ts src/declarations/example_frontend/index.d.ts src/declarations/example_frontend/example_frontend.did: .dfx/$(NETWORK)/canisters/example_frontend/service.did
	dfx generate --no-compile --network $(NETWORK) example_frontend

generate@main_indirect: build@main_indirect \
  src/declarations/main_indirect/main_indirect.did.js src/declarations/main_indirect/index.js src/declarations/main_indirect/main_indirect.did.d.ts src/declarations/main_indirect/index.d.ts src/declarations/main_indirect/main_indirect.did

src/declarations/main_indirect/main_indirect.did.js src/declarations/main_indirect/index.js src/declarations/main_indirect/main_indirect.did.d.ts src/declarations/main_indirect/index.d.ts src/declarations/main_indirect/main_indirect.did: .dfx/$(NETWORK)/canisters/main_indirect/main_indirect.did
	dfx generate --no-compile --network $(NETWORK) main_indirect

generate@package_manager: build@package_manager \
  src/declarations/package_manager/package_manager.did.js src/declarations/package_manager/index.js src/declarations/package_manager/package_manager.did.d.ts src/declarations/package_manager/index.d.ts src/declarations/package_manager/package_manager.did

src/declarations/package_manager/package_manager.did.js src/declarations/package_manager/index.js src/declarations/package_manager/package_manager.did.d.ts src/declarations/package_manager/index.d.ts src/declarations/package_manager/package_manager.did: .dfx/$(NETWORK)/canisters/package_manager/package_manager.did
	dfx generate --no-compile --network $(NETWORK) package_manager

generate@package_manager_frontend: build@package_manager_frontend \
  src/declarations/package_manager_frontend/package_manager_frontend.did.js src/declarations/package_manager_frontend/index.js src/declarations/package_manager_frontend/package_manager_frontend.did.d.ts src/declarations/package_manager_frontend/index.d.ts src/declarations/package_manager_frontend/package_manager_frontend.did

src/declarations/package_manager_frontend/package_manager_frontend.did.js src/declarations/package_manager_frontend/index.js src/declarations/package_manager_frontend/package_manager_frontend.did.d.ts src/declarations/package_manager_frontend/index.d.ts src/declarations/package_manager_frontend/package_manager_frontend.did: .dfx/$(NETWORK)/canisters/package_manager_frontend/service.did
	dfx generate --no-compile --network $(NETWORK) package_manager_frontend

generate@simple_indirect: build@simple_indirect \
  src/declarations/simple_indirect/simple_indirect.did.js src/declarations/simple_indirect/index.js src/declarations/simple_indirect/simple_indirect.did.d.ts src/declarations/simple_indirect/index.d.ts src/declarations/simple_indirect/simple_indirect.did

src/declarations/simple_indirect/simple_indirect.did.js src/declarations/simple_indirect/index.js src/declarations/simple_indirect/simple_indirect.did.d.ts src/declarations/simple_indirect/index.d.ts src/declarations/simple_indirect/simple_indirect.did: .dfx/$(NETWORK)/canisters/simple_indirect/simple_indirect.did
	dfx generate --no-compile --network $(NETWORK) simple_indirect

generate@upgrade_example_backend1_v1: build@upgrade_example_backend1_v1 \
  src/declarations/upgrade_example_backend1_v1/upgrade_example_backend1_v1.did.js src/declarations/upgrade_example_backend1_v1/index.js src/declarations/upgrade_example_backend1_v1/upgrade_example_backend1_v1.did.d.ts src/declarations/upgrade_example_backend1_v1/index.d.ts src/declarations/upgrade_example_backend1_v1/upgrade_example_backend1_v1.did

src/declarations/upgrade_example_backend1_v1/upgrade_example_backend1_v1.did.js src/declarations/upgrade_example_backend1_v1/index.js src/declarations/upgrade_example_backend1_v1/upgrade_example_backend1_v1.did.d.ts src/declarations/upgrade_example_backend1_v1/index.d.ts src/declarations/upgrade_example_backend1_v1/upgrade_example_backend1_v1.did: .dfx/$(NETWORK)/canisters/upgrade_example_backend1_v1/upgrade_example_backend1_v1.did
	dfx generate --no-compile --network $(NETWORK) upgrade_example_backend1_v1

generate@upgrade_example_backend2_v1: build@upgrade_example_backend2_v1 \
  src/declarations/upgrade_example_backend2_v1/upgrade_example_backend2_v1.did.js src/declarations/upgrade_example_backend2_v1/index.js src/declarations/upgrade_example_backend2_v1/upgrade_example_backend2_v1.did.d.ts src/declarations/upgrade_example_backend2_v1/index.d.ts src/declarations/upgrade_example_backend2_v1/upgrade_example_backend2_v1.did

src/declarations/upgrade_example_backend2_v1/upgrade_example_backend2_v1.did.js src/declarations/upgrade_example_backend2_v1/index.js src/declarations/upgrade_example_backend2_v1/upgrade_example_backend2_v1.did.d.ts src/declarations/upgrade_example_backend2_v1/index.d.ts src/declarations/upgrade_example_backend2_v1/upgrade_example_backend2_v1.did: .dfx/$(NETWORK)/canisters/upgrade_example_backend2_v1/upgrade_example_backend2_v1.did
	dfx generate --no-compile --network $(NETWORK) upgrade_example_backend2_v1

generate@upgrade_example_backend2_v2: build@upgrade_example_backend2_v2 \
  src/declarations/upgrade_example_backend2_v2/upgrade_example_backend2_v2.did.js src/declarations/upgrade_example_backend2_v2/index.js src/declarations/upgrade_example_backend2_v2/upgrade_example_backend2_v2.did.d.ts src/declarations/upgrade_example_backend2_v2/index.d.ts src/declarations/upgrade_example_backend2_v2/upgrade_example_backend2_v2.did

src/declarations/upgrade_example_backend2_v2/upgrade_example_backend2_v2.did.js src/declarations/upgrade_example_backend2_v2/index.js src/declarations/upgrade_example_backend2_v2/upgrade_example_backend2_v2.did.d.ts src/declarations/upgrade_example_backend2_v2/index.d.ts src/declarations/upgrade_example_backend2_v2/upgrade_example_backend2_v2.did: .dfx/$(NETWORK)/canisters/upgrade_example_backend2_v2/upgrade_example_backend2_v2.did
	dfx generate --no-compile --network $(NETWORK) upgrade_example_backend2_v2

generate@upgrade_example_backend3_v2: build@upgrade_example_backend3_v2 \
  src/declarations/upgrade_example_backend3_v2/upgrade_example_backend3_v2.did.js src/declarations/upgrade_example_backend3_v2/index.js src/declarations/upgrade_example_backend3_v2/upgrade_example_backend3_v2.did.d.ts src/declarations/upgrade_example_backend3_v2/index.d.ts src/declarations/upgrade_example_backend3_v2/upgrade_example_backend3_v2.did

src/declarations/upgrade_example_backend3_v2/upgrade_example_backend3_v2.did.js src/declarations/upgrade_example_backend3_v2/index.js src/declarations/upgrade_example_backend3_v2/upgrade_example_backend3_v2.did.d.ts src/declarations/upgrade_example_backend3_v2/index.d.ts src/declarations/upgrade_example_backend3_v2/upgrade_example_backend3_v2.did: .dfx/$(NETWORK)/canisters/upgrade_example_backend3_v2/upgrade_example_backend3_v2.did
	dfx generate --no-compile --network $(NETWORK) upgrade_example_backend3_v2

.dfx/$(NETWORK)/canisters/Bootstrapper/Bootstrapper.wasm .dfx/$(NETWORK)/canisters/Bootstrapper/Bootstrapper.did: src/common.mo
src/install.mo: .dfx/$(NETWORK)/canisters/cycles_ledger/cycles_ledger.wasm .dfx/$(NETWORK)/canisters/cycles_ledger/cycles_ledger.did
src/install.mo: src/Settings.mo
src/install.mo: src/common.mo
src/install.mo: src/copy_assets.mo
.dfx/$(NETWORK)/canisters/Bootstrapper/Bootstrapper.wasm .dfx/$(NETWORK)/canisters/Bootstrapper/Bootstrapper.did: src/install.mo
.dfx/$(NETWORK)/canisters/Bootstrapper/Bootstrapper.wasm .dfx/$(NETWORK)/canisters/Bootstrapper/Bootstrapper.did: .dfx/$(NETWORK)/canisters/BootstrapperData/BootstrapperData.wasm .dfx/$(NETWORK)/canisters/BootstrapperData/BootstrapperData.did
.dfx/$(NETWORK)/canisters/Repository/Repository.wasm .dfx/$(NETWORK)/canisters/Repository/Repository.did: src/common.mo
.dfx/$(NETWORK)/canisters/bootstrapper_frontend/assetstorage.wasm.gz: .dfx/$(NETWORK)/canisters/Bootstrapper/Bootstrapper.wasm .dfx/$(NETWORK)/canisters/Bootstrapper/Bootstrapper.did
.dfx/$(NETWORK)/canisters/bootstrapper_frontend/assetstorage.wasm.gz: .dfx/$(NETWORK)/canisters/bookmark/bookmark.wasm .dfx/$(NETWORK)/canisters/bookmark/bookmark.did
.dfx/$(NETWORK)/canisters/bootstrapper_frontend/assetstorage.wasm.gz: .dfx/$(NETWORK)/canisters/internet_identity/internet_identity.wasm.gz .dfx/$(NETWORK)/canisters/internet_identity/internet_identity.did
.dfx/$(NETWORK)/canisters/bootstrapper_frontend/assetstorage.wasm.gz: .dfx/$(NETWORK)/canisters/Repository/Repository.wasm .dfx/$(NETWORK)/canisters/Repository/Repository.did
.dfx/$(NETWORK)/canisters/example_frontend/assetstorage.wasm.gz: .dfx/$(NETWORK)/canisters/example_backend/example_backend.wasm .dfx/$(NETWORK)/canisters/example_backend/example_backend.did
.dfx/$(NETWORK)/canisters/main_indirect/main_indirect.wasm .dfx/$(NETWORK)/canisters/main_indirect/main_indirect.did: src/common.mo
.dfx/$(NETWORK)/canisters/main_indirect/main_indirect.wasm .dfx/$(NETWORK)/canisters/main_indirect/main_indirect.did: src/install.mo
.dfx/$(NETWORK)/canisters/main_indirect/main_indirect.wasm .dfx/$(NETWORK)/canisters/main_indirect/main_indirect.did: .dfx/$(NETWORK)/canisters/simple_indirect/simple_indirect.wasm .dfx/$(NETWORK)/canisters/simple_indirect/simple_indirect.did
.dfx/$(NETWORK)/canisters/package_manager/package_manager.wasm .dfx/$(NETWORK)/canisters/package_manager/package_manager.did: src/common.mo
src/package_manager_backend/main_indirect.mo: src/common.mo
src/package_manager_backend/main_indirect.mo: src/install.mo
src/package_manager_backend/main_indirect.mo: .dfx/$(NETWORK)/canisters/simple_indirect/simple_indirect.wasm .dfx/$(NETWORK)/canisters/simple_indirect/simple_indirect.did
.dfx/$(NETWORK)/canisters/package_manager/package_manager.wasm .dfx/$(NETWORK)/canisters/package_manager/package_manager.did: src/package_manager_backend/main_indirect.mo
.dfx/$(NETWORK)/canisters/package_manager/package_manager.wasm .dfx/$(NETWORK)/canisters/package_manager/package_manager.did: src/package_manager_backend/simple_indirect.mo
.dfx/$(NETWORK)/canisters/package_manager_frontend/assetstorage.wasm.gz: .dfx/$(NETWORK)/canisters/package_manager/package_manager.wasm .dfx/$(NETWORK)/canisters/package_manager/package_manager.did
.dfx/$(NETWORK)/canisters/package_manager_frontend/assetstorage.wasm.gz: .dfx/$(NETWORK)/canisters/internet_identity/internet_identity.wasm.gz .dfx/$(NETWORK)/canisters/internet_identity/internet_identity.did
.dfx/$(NETWORK)/canisters/bookmark/bookmark.wasm .dfx/$(NETWORK)/canisters/bookmark/bookmark.did:
	dfx canister create --network $(NETWORK) bookmark
	dfx build --no-deps --network $(NETWORK) bookmark


deploy-self@bookmark: build@bookmark
	dfx deploy --no-compile --network $(NETWORK) $(DEPLOY_FLAGS) $(DEPLOY_FLAGS.bookmark) bookmark

deploy@bookmark: deploy-self@bookmark

.PHONY: .dfx/$(NETWORK)/canisters/bootstrapper_frontend/assetstorage.wasm.gz
.dfx/$(NETWORK)/canisters/bootstrapper_frontend/assetstorage.wasm.gz:
	dfx canister create --network $(NETWORK) bootstrapper_frontend
	dfx build --no-deps --network $(NETWORK) bootstrapper_frontend


deploy-self@bootstrapper_frontend: build@bootstrapper_frontend
	dfx deploy --no-compile --network $(NETWORK) $(DEPLOY_FLAGS) $(DEPLOY_FLAGS.bootstrapper_frontend) bootstrapper_frontend


canister@bootstrapper_frontend: \
  generate@Bootstrapper generate@bookmark generate@internet_identity generate@Repository
deploy@bootstrapper_frontend: deploy@Bootstrapper deploy@bookmark deploy@internet_identity deploy@Repository \
  deploy-self@bootstrapper_frontend

.dfx/$(NETWORK)/canisters/simple_indirect/simple_indirect.wasm .dfx/$(NETWORK)/canisters/simple_indirect/simple_indirect.did:
	dfx canister create --network $(NETWORK) simple_indirect
	dfx build --no-deps --network $(NETWORK) simple_indirect


deploy-self@simple_indirect: build@simple_indirect
	dfx deploy --no-compile --network $(NETWORK) $(DEPLOY_FLAGS) $(DEPLOY_FLAGS.simple_indirect) simple_indirect

deploy@simple_indirect: deploy@cycles_ledger \
  deploy-self@simple_indirect

.dfx/$(NETWORK)/canisters/cycles_ledger/cycles_ledger.wasm .dfx/$(NETWORK)/canisters/cycles_ledger/cycles_ledger.did:
	dfx canister create --network $(NETWORK) cycles_ledger
	dfx build --no-deps --network $(NETWORK) cycles_ledger


deploy-self@cycles_ledger: build@cycles_ledger
	dfx deploy --no-compile --network $(NETWORK) $(DEPLOY_FLAGS) $(DEPLOY_FLAGS.cycles_ledger) cycles_ledger

deploy@cycles_ledger: deploy-self@cycles_ledger

.PHONY: .dfx/$(NETWORK)/canisters/example_frontend/assetstorage.wasm.gz
.dfx/$(NETWORK)/canisters/example_frontend/assetstorage.wasm.gz:
	dfx canister create --network $(NETWORK) example_frontend
	dfx build --no-deps --network $(NETWORK) example_frontend


deploy-self@example_frontend: build@example_frontend
	dfx deploy --no-compile --network $(NETWORK) $(DEPLOY_FLAGS) $(DEPLOY_FLAGS.example_frontend) example_frontend


canister@example_frontend: \
  generate@example_backend
deploy@example_frontend: deploy@example_backend \
  deploy-self@example_frontend

.dfx/$(NETWORK)/canisters/upgrade_example_backend2_v1/upgrade_example_backend2_v1.wasm .dfx/$(NETWORK)/canisters/upgrade_example_backend2_v1/upgrade_example_backend2_v1.did:
	dfx canister create --network $(NETWORK) upgrade_example_backend2_v1
	dfx build --no-deps --network $(NETWORK) upgrade_example_backend2_v1


deploy-self@upgrade_example_backend2_v1: build@upgrade_example_backend2_v1
	dfx deploy --no-compile --network $(NETWORK) $(DEPLOY_FLAGS) $(DEPLOY_FLAGS.upgrade_example_backend2_v1) upgrade_example_backend2_v1

deploy@upgrade_example_backend2_v1: deploy-self@upgrade_example_backend2_v1

.PHONY: .dfx/$(NETWORK)/canisters/package_manager_frontend/assetstorage.wasm.gz
.dfx/$(NETWORK)/canisters/package_manager_frontend/assetstorage.wasm.gz:
	dfx canister create --network $(NETWORK) package_manager_frontend
	dfx build --no-deps --network $(NETWORK) package_manager_frontend


deploy-self@package_manager_frontend: build@package_manager_frontend
	dfx deploy --no-compile --network $(NETWORK) $(DEPLOY_FLAGS) $(DEPLOY_FLAGS.package_manager_frontend) package_manager_frontend


canister@package_manager_frontend: \
  generate@package_manager generate@internet_identity
deploy@package_manager_frontend: deploy@package_manager deploy@internet_identity \
  deploy-self@package_manager_frontend

.dfx/$(NETWORK)/canisters/BootstrapperData/BootstrapperData.wasm .dfx/$(NETWORK)/canisters/BootstrapperData/BootstrapperData.did:
	dfx canister create --network $(NETWORK) BootstrapperData
	dfx build --no-deps --network $(NETWORK) BootstrapperData


deploy-self@BootstrapperData: build@BootstrapperData
	dfx deploy --no-compile --network $(NETWORK) $(DEPLOY_FLAGS) $(DEPLOY_FLAGS.BootstrapperData) BootstrapperData

deploy@BootstrapperData: deploy-self@BootstrapperData

.dfx/$(NETWORK)/canisters/internet_identity/internet_identity.wasm.gz .dfx/$(NETWORK)/canisters/internet_identity/internet_identity.did:
	dfx canister create --network $(NETWORK) internet_identity
	dfx build --no-deps --network $(NETWORK) internet_identity


deploy-self@internet_identity: build@internet_identity
	dfx deploy --no-compile --network $(NETWORK) $(DEPLOY_FLAGS) $(DEPLOY_FLAGS.internet_identity) internet_identity

deploy@internet_identity: deploy-self@internet_identity

.dfx/$(NETWORK)/canisters/Bootstrapper/Bootstrapper.wasm .dfx/$(NETWORK)/canisters/Bootstrapper/Bootstrapper.did:
	dfx canister create --network $(NETWORK) Bootstrapper
	dfx build --no-deps --network $(NETWORK) Bootstrapper


deploy-self@Bootstrapper: build@Bootstrapper
	dfx deploy --no-compile --network $(NETWORK) $(DEPLOY_FLAGS) $(DEPLOY_FLAGS.Bootstrapper) Bootstrapper

deploy@Bootstrapper: deploy@cycles_ledger deploy@BootstrapperData deploy@Repository \
  deploy-self@Bootstrapper

.dfx/$(NETWORK)/canisters/example_backend/example_backend.wasm .dfx/$(NETWORK)/canisters/example_backend/example_backend.did:
	dfx canister create --network $(NETWORK) example_backend
	dfx build --no-deps --network $(NETWORK) example_backend


deploy-self@example_backend: build@example_backend
	dfx deploy --no-compile --network $(NETWORK) $(DEPLOY_FLAGS) $(DEPLOY_FLAGS.example_backend) example_backend

deploy@example_backend: deploy-self@example_backend

.dfx/$(NETWORK)/canisters/package_manager/package_manager.wasm .dfx/$(NETWORK)/canisters/package_manager/package_manager.did:
	dfx canister create --network $(NETWORK) package_manager
	dfx build --no-deps --network $(NETWORK) package_manager


deploy-self@package_manager: build@package_manager
	dfx deploy --no-compile --network $(NETWORK) $(DEPLOY_FLAGS) $(DEPLOY_FLAGS.package_manager) package_manager

deploy@package_manager: deploy@Bootstrapper deploy@cycles_ledger deploy@Repository \
  deploy-self@package_manager

.dfx/$(NETWORK)/canisters/Repository/Repository.wasm .dfx/$(NETWORK)/canisters/Repository/Repository.did:
	dfx canister create --network $(NETWORK) Repository
	dfx build --no-deps --network $(NETWORK) Repository


deploy-self@Repository: build@Repository
	dfx deploy --no-compile --network $(NETWORK) $(DEPLOY_FLAGS) $(DEPLOY_FLAGS.Repository) Repository

deploy@Repository: deploy-self@Repository

.dfx/$(NETWORK)/canisters/main_indirect/main_indirect.wasm .dfx/$(NETWORK)/canisters/main_indirect/main_indirect.did:
	dfx canister create --network $(NETWORK) main_indirect
	dfx build --no-deps --network $(NETWORK) main_indirect


deploy-self@main_indirect: build@main_indirect
	dfx deploy --no-compile --network $(NETWORK) $(DEPLOY_FLAGS) $(DEPLOY_FLAGS.main_indirect) main_indirect

deploy@main_indirect: deploy@Bootstrapper deploy@cycles_ledger \
  deploy-self@main_indirect

.dfx/$(NETWORK)/canisters/upgrade_example_backend1_v1/upgrade_example_backend1_v1.wasm .dfx/$(NETWORK)/canisters/upgrade_example_backend1_v1/upgrade_example_backend1_v1.did:
	dfx canister create --network $(NETWORK) upgrade_example_backend1_v1
	dfx build --no-deps --network $(NETWORK) upgrade_example_backend1_v1


deploy-self@upgrade_example_backend1_v1: build@upgrade_example_backend1_v1
	dfx deploy --no-compile --network $(NETWORK) $(DEPLOY_FLAGS) $(DEPLOY_FLAGS.upgrade_example_backend1_v1) upgrade_example_backend1_v1

deploy@upgrade_example_backend1_v1: deploy-self@upgrade_example_backend1_v1

.dfx/$(NETWORK)/canisters/upgrade_example_backend2_v2/upgrade_example_backend2_v2.wasm .dfx/$(NETWORK)/canisters/upgrade_example_backend2_v2/upgrade_example_backend2_v2.did:
	dfx canister create --network $(NETWORK) upgrade_example_backend2_v2
	dfx build --no-deps --network $(NETWORK) upgrade_example_backend2_v2


deploy-self@upgrade_example_backend2_v2: build@upgrade_example_backend2_v2
	dfx deploy --no-compile --network $(NETWORK) $(DEPLOY_FLAGS) $(DEPLOY_FLAGS.upgrade_example_backend2_v2) upgrade_example_backend2_v2

deploy@upgrade_example_backend2_v2: deploy-self@upgrade_example_backend2_v2

.dfx/$(NETWORK)/canisters/upgrade_example_backend3_v2/upgrade_example_backend3_v2.wasm .dfx/$(NETWORK)/canisters/upgrade_example_backend3_v2/upgrade_example_backend3_v2.did:
	dfx canister create --network $(NETWORK) upgrade_example_backend3_v2
	dfx build --no-deps --network $(NETWORK) upgrade_example_backend3_v2


deploy-self@upgrade_example_backend3_v2: build@upgrade_example_backend3_v2
	dfx deploy --no-compile --network $(NETWORK) $(DEPLOY_FLAGS) $(DEPLOY_FLAGS.upgrade_example_backend3_v2) upgrade_example_backend3_v2

deploy@upgrade_example_backend3_v2: deploy-self@upgrade_example_backend3_v2

