NETWORK ?= local

DEPLOY_FLAGS ?= 

ROOT_DIR := $(dir $(realpath $(lastword $(MAKEFILE_LIST))))

.PHONY: build@battery build@bookmark build@bootstrapper build@bootstrapper_data build@bootstrapper_frontend build@cycles_ledger build@example_backend build@example_frontend build@internet_identity build@main_indirect build@nns-cycles-minting build@nns-genesis-token build@nns-governance build@nns-ledger build@nns-lifeline build@nns-registry build@nns-root build@nns-sns-wasm build@package_manager build@package_manager_frontend build@repository build@simple_indirect build@upgrade_example_backend1_v1 build@upgrade_example_backend2_v1 build@upgrade_example_backend2_v2 build@upgrade_example_backend3_v2

.PHONY: deploy@battery deploy@bookmark deploy@bootstrapper deploy@bootstrapper_data deploy@bootstrapper_frontend deploy@cycles_ledger deploy@example_backend deploy@example_frontend deploy@internet_identity deploy@main_indirect deploy@nns-cycles-minting deploy@nns-genesis-token deploy@nns-governance deploy@nns-ledger deploy@nns-lifeline deploy@nns-registry deploy@nns-root deploy@nns-sns-wasm deploy@package_manager deploy@package_manager_frontend deploy@repository deploy@simple_indirect deploy@upgrade_example_backend1_v1 deploy@upgrade_example_backend2_v1 deploy@upgrade_example_backend2_v2 deploy@upgrade_example_backend3_v2

.PHONY: generate@battery generate@bookmark generate@bootstrapper generate@bootstrapper_data generate@bootstrapper_frontend generate@cycles_ledger generate@example_backend generate@example_frontend generate@internet_identity generate@main_indirect generate@nns-cycles-minting generate@nns-genesis-token generate@nns-governance generate@nns-ledger generate@nns-lifeline generate@nns-registry generate@nns-root generate@nns-sns-wasm generate@package_manager generate@package_manager_frontend generate@repository generate@simple_indirect generate@upgrade_example_backend1_v1 generate@upgrade_example_backend2_v1 generate@upgrade_example_backend2_v2 generate@upgrade_example_backend3_v2

build@battery: \
  .dfx/$(NETWORK)/canisters/battery/battery.wasm .dfx/$(NETWORK)/canisters/battery/battery.did

.dfx/$(NETWORK)/canisters/battery/battery.wasm .dfx/$(NETWORK)/canisters/battery/battery.did: src/package_manager_backend/battery.mo

build@bookmark: \
  .dfx/$(NETWORK)/canisters/bookmark/bookmark.wasm .dfx/$(NETWORK)/canisters/bookmark/bookmark.did

.dfx/$(NETWORK)/canisters/bookmark/bookmark.wasm .dfx/$(NETWORK)/canisters/bookmark/bookmark.did: src/bootstrapper_backend/bookmarks.mo

build@bootstrapper: \
  .dfx/$(NETWORK)/canisters/bootstrapper/bootstrapper.wasm .dfx/$(NETWORK)/canisters/bootstrapper/bootstrapper.did

.dfx/$(NETWORK)/canisters/bootstrapper/bootstrapper.wasm .dfx/$(NETWORK)/canisters/bootstrapper/bootstrapper.did: src/bootstrapper_backend/bootstrapper.mo

build@bootstrapper_data: \
  .dfx/$(NETWORK)/canisters/bootstrapper_data/bootstrapper_data.wasm .dfx/$(NETWORK)/canisters/bootstrapper_data/bootstrapper_data.did

.dfx/$(NETWORK)/canisters/bootstrapper_data/bootstrapper_data.wasm .dfx/$(NETWORK)/canisters/bootstrapper_data/bootstrapper_data.did: src/bootstrapper_backend/BootstrapperData.mo

build@bootstrapper_frontend: \
  .dfx/$(NETWORK)/canisters/bootstrapper_frontend/assetstorage.wasm.gz

build@cycles_ledger: \
  .dfx/$(NETWORK)/canisters/cycles_ledger/cycles_ledger.wasm.gz .dfx/$(NETWORK)/canisters/cycles_ledger/cycles_ledger.did

build@example_backend: \
  .dfx/$(NETWORK)/canisters/example_backend/example_backend.wasm .dfx/$(NETWORK)/canisters/example_backend/example_backend.did

.dfx/$(NETWORK)/canisters/example_backend/example_backend.wasm .dfx/$(NETWORK)/canisters/example_backend/example_backend.did: examples/example_backend/main.mo

build@example_frontend: \
  .dfx/$(NETWORK)/canisters/example_frontend/assetstorage.wasm.gz

build@internet_identity: \
  .dfx/$(NETWORK)/canisters/internet_identity/internet_identity.wasm.gz .dfx/$(NETWORK)/canisters/internet_identity/internet_identity.did

build@main_indirect: \
  .dfx/$(NETWORK)/canisters/main_indirect/main_indirect.wasm .dfx/$(NETWORK)/canisters/main_indirect/main_indirect.did

.dfx/$(NETWORK)/canisters/main_indirect/main_indirect.wasm .dfx/$(NETWORK)/canisters/main_indirect/main_indirect.did: src/package_manager_backend/main_indirect.mo

build@nns-cycles-minting: \
  .dfx/$(NETWORK)/canisters/nns-cycles-minting/nns-cycles-minting.wasm .dfx/$(NETWORK)/canisters/nns-cycles-minting/nns-cycles-minting.did

build@nns-genesis-token: \
  .dfx/$(NETWORK)/canisters/nns-genesis-token/nns-genesis-token.wasm .dfx/$(NETWORK)/canisters/nns-genesis-token/nns-genesis-token.did

build@nns-governance: \
  .dfx/$(NETWORK)/canisters/nns-governance/nns-governance.wasm .dfx/$(NETWORK)/canisters/nns-governance/nns-governance.did

build@nns-ledger: \
  .dfx/$(NETWORK)/canisters/nns-ledger/nns-ledger.wasm .dfx/$(NETWORK)/canisters/nns-ledger/nns-ledger.did

build@nns-lifeline: \
  .dfx/$(NETWORK)/canisters/nns-lifeline/nns-lifeline.wasm .dfx/$(NETWORK)/canisters/nns-lifeline/nns-lifeline.did

build@nns-registry: \
  .dfx/$(NETWORK)/canisters/nns-registry/nns-registry.wasm .dfx/$(NETWORK)/canisters/nns-registry/nns-registry.did

build@nns-root: \
  .dfx/$(NETWORK)/canisters/nns-root/nns-root.wasm .dfx/$(NETWORK)/canisters/nns-root/nns-root.did

build@nns-sns-wasm: \
  .dfx/$(NETWORK)/canisters/nns-sns-wasm/nns-sns-wasm.wasm .dfx/$(NETWORK)/canisters/nns-sns-wasm/nns-sns-wasm.did

build@package_manager: \
  .dfx/$(NETWORK)/canisters/package_manager/package_manager.wasm .dfx/$(NETWORK)/canisters/package_manager/package_manager.did

.dfx/$(NETWORK)/canisters/package_manager/package_manager.wasm .dfx/$(NETWORK)/canisters/package_manager/package_manager.did: src/package_manager_backend/package_manager.mo

build@package_manager_frontend: \
  .dfx/$(NETWORK)/canisters/package_manager_frontend/assetstorage.wasm.gz

build@repository: \
  .dfx/$(NETWORK)/canisters/repository/repository.wasm .dfx/$(NETWORK)/canisters/repository/repository.did

.dfx/$(NETWORK)/canisters/repository/repository.wasm .dfx/$(NETWORK)/canisters/repository/repository.did: src/repository_backend/Repository.mo

build@simple_indirect: \
  .dfx/$(NETWORK)/canisters/simple_indirect/simple_indirect.wasm .dfx/$(NETWORK)/canisters/simple_indirect/simple_indirect.did

.dfx/$(NETWORK)/canisters/simple_indirect/simple_indirect.wasm .dfx/$(NETWORK)/canisters/simple_indirect/simple_indirect.did: src/package_manager_backend/simple_indirect.mo

build@upgrade_example_backend1_v1: \
  .dfx/$(NETWORK)/canisters/upgrade_example_backend1_v1/upgrade_example_backend1_v1.wasm .dfx/$(NETWORK)/canisters/upgrade_example_backend1_v1/upgrade_example_backend1_v1.did

.dfx/$(NETWORK)/canisters/upgrade_example_backend1_v1/upgrade_example_backend1_v1.wasm .dfx/$(NETWORK)/canisters/upgrade_example_backend1_v1/upgrade_example_backend1_v1.did: examples/upgrade_example_backend/0.0.1/main1.mo

build@upgrade_example_backend2_v1: \
  .dfx/$(NETWORK)/canisters/upgrade_example_backend2_v1/upgrade_example_backend2_v1.wasm .dfx/$(NETWORK)/canisters/upgrade_example_backend2_v1/upgrade_example_backend2_v1.did

.dfx/$(NETWORK)/canisters/upgrade_example_backend2_v1/upgrade_example_backend2_v1.wasm .dfx/$(NETWORK)/canisters/upgrade_example_backend2_v1/upgrade_example_backend2_v1.did: examples/upgrade_example_backend/0.0.1/main2.mo

build@upgrade_example_backend2_v2: \
  .dfx/$(NETWORK)/canisters/upgrade_example_backend2_v2/upgrade_example_backend2_v2.wasm .dfx/$(NETWORK)/canisters/upgrade_example_backend2_v2/upgrade_example_backend2_v2.did

.dfx/$(NETWORK)/canisters/upgrade_example_backend2_v2/upgrade_example_backend2_v2.wasm .dfx/$(NETWORK)/canisters/upgrade_example_backend2_v2/upgrade_example_backend2_v2.did: examples/upgrade_example_backend/0.0.2/main2.mo

build@upgrade_example_backend3_v2: \
  .dfx/$(NETWORK)/canisters/upgrade_example_backend3_v2/upgrade_example_backend3_v2.wasm .dfx/$(NETWORK)/canisters/upgrade_example_backend3_v2/upgrade_example_backend3_v2.did

.dfx/$(NETWORK)/canisters/upgrade_example_backend3_v2/upgrade_example_backend3_v2.wasm .dfx/$(NETWORK)/canisters/upgrade_example_backend3_v2/upgrade_example_backend3_v2.did: examples/upgrade_example_backend/0.0.2/main3.mo

generate@battery: build@battery \
  src/declarations/battery/battery.did.js src/declarations/battery/index.js src/declarations/battery/battery.did.d.ts src/declarations/battery/index.d.ts src/declarations/battery/battery.did

src/declarations/battery/battery.did.js src/declarations/battery/index.js src/declarations/battery/battery.did.d.ts src/declarations/battery/index.d.ts src/declarations/battery/battery.did: .dfx/$(NETWORK)/canisters/battery/battery.did
	dfx generate --no-compile --network $(NETWORK) battery

generate@bookmark: build@bookmark \
  src/declarations/bookmark/bookmark.did.js src/declarations/bookmark/index.js src/declarations/bookmark/bookmark.did.d.ts src/declarations/bookmark/index.d.ts src/declarations/bookmark/bookmark.did

src/declarations/bookmark/bookmark.did.js src/declarations/bookmark/index.js src/declarations/bookmark/bookmark.did.d.ts src/declarations/bookmark/index.d.ts src/declarations/bookmark/bookmark.did: .dfx/$(NETWORK)/canisters/bookmark/bookmark.did
	dfx generate --no-compile --network $(NETWORK) bookmark

generate@bootstrapper: build@bootstrapper \
  src/declarations/bootstrapper/bootstrapper.did.js src/declarations/bootstrapper/index.js src/declarations/bootstrapper/bootstrapper.did.d.ts src/declarations/bootstrapper/index.d.ts src/declarations/bootstrapper/bootstrapper.did

src/declarations/bootstrapper/bootstrapper.did.js src/declarations/bootstrapper/index.js src/declarations/bootstrapper/bootstrapper.did.d.ts src/declarations/bootstrapper/index.d.ts src/declarations/bootstrapper/bootstrapper.did: .dfx/$(NETWORK)/canisters/bootstrapper/bootstrapper.did
	dfx generate --no-compile --network $(NETWORK) bootstrapper

generate@bootstrapper_data: build@bootstrapper_data \
  src/declarations/bootstrapper_data/bootstrapper_data.did.js src/declarations/bootstrapper_data/index.js src/declarations/bootstrapper_data/bootstrapper_data.did.d.ts src/declarations/bootstrapper_data/index.d.ts src/declarations/bootstrapper_data/bootstrapper_data.did

src/declarations/bootstrapper_data/bootstrapper_data.did.js src/declarations/bootstrapper_data/index.js src/declarations/bootstrapper_data/bootstrapper_data.did.d.ts src/declarations/bootstrapper_data/index.d.ts src/declarations/bootstrapper_data/bootstrapper_data.did: .dfx/$(NETWORK)/canisters/bootstrapper_data/bootstrapper_data.did
	dfx generate --no-compile --network $(NETWORK) bootstrapper_data

generate@bootstrapper_frontend: build@bootstrapper_frontend \
  src/declarations/bootstrapper_frontend/bootstrapper_frontend.did.js src/declarations/bootstrapper_frontend/index.js src/declarations/bootstrapper_frontend/bootstrapper_frontend.did.d.ts src/declarations/bootstrapper_frontend/index.d.ts src/declarations/bootstrapper_frontend/bootstrapper_frontend.did

src/declarations/bootstrapper_frontend/bootstrapper_frontend.did.js src/declarations/bootstrapper_frontend/index.js src/declarations/bootstrapper_frontend/bootstrapper_frontend.did.d.ts src/declarations/bootstrapper_frontend/index.d.ts src/declarations/bootstrapper_frontend/bootstrapper_frontend.did: .dfx/$(NETWORK)/canisters/bootstrapper_frontend/service.did
	dfx generate --no-compile --network $(NETWORK) bootstrapper_frontend

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

generate@repository: build@repository \
  src/declarations/repository/repository.did.js src/declarations/repository/index.js src/declarations/repository/repository.did.d.ts src/declarations/repository/index.d.ts src/declarations/repository/repository.did

src/declarations/repository/repository.did.js src/declarations/repository/index.js src/declarations/repository/repository.did.d.ts src/declarations/repository/index.d.ts src/declarations/repository/repository.did: .dfx/$(NETWORK)/canisters/repository/repository.did
	dfx generate --no-compile --network $(NETWORK) repository

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

.dfx/$(NETWORK)/canisters/battery/battery.wasm .dfx/$(NETWORK)/canisters/battery/battery.did: src/common.mo
.dfx/$(NETWORK)/canisters/battery/battery.wasm .dfx/$(NETWORK)/canisters/battery/battery.did: .dfx/$(NETWORK)/canisters/nns-ledger/nns-ledger.wasm .dfx/$(NETWORK)/canisters/nns-ledger/nns-ledger.did
.dfx/$(NETWORK)/canisters/bootstrapper/bootstrapper.wasm .dfx/$(NETWORK)/canisters/bootstrapper/bootstrapper.did: src/common.mo
src/install.mo: src/common.mo
src/install.mo: src/copy_assets.mo
src/install.mo: .dfx/$(NETWORK)/canisters/nns-cycles-minting/nns-cycles-minting.wasm .dfx/$(NETWORK)/canisters/nns-cycles-minting/nns-cycles-minting.did
.dfx/$(NETWORK)/canisters/bootstrapper/bootstrapper.wasm .dfx/$(NETWORK)/canisters/bootstrapper/bootstrapper.did: src/install.mo
src/package_manager_backend/battery.mo: src/common.mo
src/package_manager_backend/battery.mo: .dfx/$(NETWORK)/canisters/nns-ledger/nns-ledger.wasm .dfx/$(NETWORK)/canisters/nns-ledger/nns-ledger.did
.dfx/$(NETWORK)/canisters/bootstrapper/bootstrapper.wasm .dfx/$(NETWORK)/canisters/bootstrapper/bootstrapper.did: src/package_manager_backend/battery.mo
.dfx/$(NETWORK)/canisters/bootstrapper/bootstrapper.wasm .dfx/$(NETWORK)/canisters/bootstrapper/bootstrapper.did: src/lib/Account.mo
.dfx/$(NETWORK)/canisters/bootstrapper/bootstrapper.wasm .dfx/$(NETWORK)/canisters/bootstrapper/bootstrapper.did: .dfx/$(NETWORK)/canisters/nns-ledger/nns-ledger.wasm .dfx/$(NETWORK)/canisters/nns-ledger/nns-ledger.did
.dfx/$(NETWORK)/canisters/bootstrapper/bootstrapper.wasm .dfx/$(NETWORK)/canisters/bootstrapper/bootstrapper.did: .dfx/$(NETWORK)/canisters/cycles_ledger/cycles_ledger.wasm.gz .dfx/$(NETWORK)/canisters/cycles_ledger/cycles_ledger.did
.dfx/$(NETWORK)/canisters/bootstrapper/bootstrapper.wasm .dfx/$(NETWORK)/canisters/bootstrapper/bootstrapper.did: .dfx/$(NETWORK)/canisters/nns-cycles-minting/nns-cycles-minting.wasm .dfx/$(NETWORK)/canisters/nns-cycles-minting/nns-cycles-minting.did
.dfx/$(NETWORK)/canisters/bootstrapper/bootstrapper.wasm .dfx/$(NETWORK)/canisters/bootstrapper/bootstrapper.did: .dfx/$(NETWORK)/canisters/bootstrapper_data/bootstrapper_data.wasm .dfx/$(NETWORK)/canisters/bootstrapper_data/bootstrapper_data.did
.dfx/$(NETWORK)/canisters/repository/repository.wasm .dfx/$(NETWORK)/canisters/repository/repository.did: src/common.mo
.dfx/$(NETWORK)/canisters/bootstrapper/bootstrapper.wasm .dfx/$(NETWORK)/canisters/bootstrapper/bootstrapper.did: .dfx/$(NETWORK)/canisters/repository/repository.wasm .dfx/$(NETWORK)/canisters/repository/repository.did
.dfx/$(NETWORK)/canisters/bootstrapper/bootstrapper.wasm .dfx/$(NETWORK)/canisters/bootstrapper/bootstrapper.did: .dfx/$(NETWORK)/canisters/bookmark/bookmark.wasm .dfx/$(NETWORK)/canisters/bookmark/bookmark.did
.dfx/$(NETWORK)/canisters/bootstrapper_frontend/assetstorage.wasm.gz: .dfx/$(NETWORK)/canisters/bootstrapper/bootstrapper.wasm .dfx/$(NETWORK)/canisters/bootstrapper/bootstrapper.did
.dfx/$(NETWORK)/canisters/bootstrapper_frontend/assetstorage.wasm.gz: .dfx/$(NETWORK)/canisters/bookmark/bookmark.wasm .dfx/$(NETWORK)/canisters/bookmark/bookmark.did
.dfx/$(NETWORK)/canisters/bootstrapper_frontend/assetstorage.wasm.gz: .dfx/$(NETWORK)/canisters/internet_identity/internet_identity.wasm.gz .dfx/$(NETWORK)/canisters/internet_identity/internet_identity.did
.dfx/$(NETWORK)/canisters/bootstrapper_frontend/assetstorage.wasm.gz: .dfx/$(NETWORK)/canisters/repository/repository.wasm .dfx/$(NETWORK)/canisters/repository/repository.did
.dfx/$(NETWORK)/canisters/example_backend/example_backend.wasm .dfx/$(NETWORK)/canisters/example_backend/example_backend.did: .dfx/$(NETWORK)/canisters/nns-ledger/nns-ledger.wasm .dfx/$(NETWORK)/canisters/nns-ledger/nns-ledger.did
.dfx/$(NETWORK)/canisters/example_frontend/assetstorage.wasm.gz: .dfx/$(NETWORK)/canisters/example_backend/example_backend.wasm .dfx/$(NETWORK)/canisters/example_backend/example_backend.did
.dfx/$(NETWORK)/canisters/main_indirect/main_indirect.wasm .dfx/$(NETWORK)/canisters/main_indirect/main_indirect.did: src/common.mo
.dfx/$(NETWORK)/canisters/main_indirect/main_indirect.wasm .dfx/$(NETWORK)/canisters/main_indirect/main_indirect.did: src/install.mo
src/package_manager_backend/simple_indirect.mo: src/common.mo
src/package_manager_backend/simple_indirect.mo: .dfx/$(NETWORK)/canisters/nns-ledger/nns-ledger.wasm .dfx/$(NETWORK)/canisters/nns-ledger/nns-ledger.did
.dfx/$(NETWORK)/canisters/main_indirect/main_indirect.wasm .dfx/$(NETWORK)/canisters/main_indirect/main_indirect.did: src/package_manager_backend/simple_indirect.mo
.dfx/$(NETWORK)/canisters/main_indirect/main_indirect.wasm .dfx/$(NETWORK)/canisters/main_indirect/main_indirect.did: .dfx/$(NETWORK)/canisters/nns-ledger/nns-ledger.wasm .dfx/$(NETWORK)/canisters/nns-ledger/nns-ledger.did
.dfx/$(NETWORK)/canisters/main_indirect/main_indirect.wasm .dfx/$(NETWORK)/canisters/main_indirect/main_indirect.did: src/package_manager_backend/battery.mo
.dfx/$(NETWORK)/canisters/package_manager/package_manager.wasm .dfx/$(NETWORK)/canisters/package_manager/package_manager.did: src/common.mo
src/package_manager_backend/main_indirect.mo: src/common.mo
src/package_manager_backend/main_indirect.mo: src/install.mo
src/package_manager_backend/main_indirect.mo: src/package_manager_backend/simple_indirect.mo
src/package_manager_backend/main_indirect.mo: .dfx/$(NETWORK)/canisters/nns-ledger/nns-ledger.wasm .dfx/$(NETWORK)/canisters/nns-ledger/nns-ledger.did
src/package_manager_backend/main_indirect.mo: src/package_manager_backend/battery.mo
.dfx/$(NETWORK)/canisters/package_manager/package_manager.wasm .dfx/$(NETWORK)/canisters/package_manager/package_manager.did: src/package_manager_backend/main_indirect.mo
.dfx/$(NETWORK)/canisters/package_manager/package_manager.wasm .dfx/$(NETWORK)/canisters/package_manager/package_manager.did: src/package_manager_backend/simple_indirect.mo
.dfx/$(NETWORK)/canisters/package_manager/package_manager.wasm .dfx/$(NETWORK)/canisters/package_manager/package_manager.did: .dfx/$(NETWORK)/canisters/nns-ledger/nns-ledger.wasm .dfx/$(NETWORK)/canisters/nns-ledger/nns-ledger.did
.dfx/$(NETWORK)/canisters/package_manager/package_manager.wasm .dfx/$(NETWORK)/canisters/package_manager/package_manager.did: src/lib/Account.mo
.dfx/$(NETWORK)/canisters/package_manager/package_manager.wasm .dfx/$(NETWORK)/canisters/package_manager/package_manager.did: src/package_manager_backend/battery.mo
.dfx/$(NETWORK)/canisters/package_manager_frontend/assetstorage.wasm.gz: .dfx/$(NETWORK)/canisters/package_manager/package_manager.wasm .dfx/$(NETWORK)/canisters/package_manager/package_manager.did
.dfx/$(NETWORK)/canisters/package_manager_frontend/assetstorage.wasm.gz: .dfx/$(NETWORK)/canisters/internet_identity/internet_identity.wasm.gz .dfx/$(NETWORK)/canisters/internet_identity/internet_identity.did
.dfx/$(NETWORK)/canisters/package_manager_frontend/assetstorage.wasm.gz: .dfx/$(NETWORK)/canisters/bootstrapper/bootstrapper.wasm .dfx/$(NETWORK)/canisters/bootstrapper/bootstrapper.did
.dfx/$(NETWORK)/canisters/simple_indirect/simple_indirect.wasm .dfx/$(NETWORK)/canisters/simple_indirect/simple_indirect.did: src/common.mo
.dfx/$(NETWORK)/canisters/simple_indirect/simple_indirect.wasm .dfx/$(NETWORK)/canisters/simple_indirect/simple_indirect.did: .dfx/$(NETWORK)/canisters/nns-ledger/nns-ledger.wasm .dfx/$(NETWORK)/canisters/nns-ledger/nns-ledger.did
.dfx/$(NETWORK)/canisters/upgrade_example_backend1_v1/upgrade_example_backend1_v1.wasm .dfx/$(NETWORK)/canisters/upgrade_example_backend1_v1/upgrade_example_backend1_v1.did: .dfx/$(NETWORK)/canisters/nns-ledger/nns-ledger.wasm .dfx/$(NETWORK)/canisters/nns-ledger/nns-ledger.did
.dfx/$(NETWORK)/canisters/upgrade_example_backend2_v1/upgrade_example_backend2_v1.wasm .dfx/$(NETWORK)/canisters/upgrade_example_backend2_v1/upgrade_example_backend2_v1.did: .dfx/$(NETWORK)/canisters/nns-ledger/nns-ledger.wasm .dfx/$(NETWORK)/canisters/nns-ledger/nns-ledger.did
.dfx/$(NETWORK)/canisters/upgrade_example_backend2_v2/upgrade_example_backend2_v2.wasm .dfx/$(NETWORK)/canisters/upgrade_example_backend2_v2/upgrade_example_backend2_v2.did: .dfx/$(NETWORK)/canisters/nns-ledger/nns-ledger.wasm .dfx/$(NETWORK)/canisters/nns-ledger/nns-ledger.did
.dfx/$(NETWORK)/canisters/upgrade_example_backend3_v2/upgrade_example_backend3_v2.wasm .dfx/$(NETWORK)/canisters/upgrade_example_backend3_v2/upgrade_example_backend3_v2.did: .dfx/$(NETWORK)/canisters/nns-ledger/nns-ledger.wasm .dfx/$(NETWORK)/canisters/nns-ledger/nns-ledger.did
.PHONY: .dfx/$(NETWORK)/canisters/example_frontend/assetstorage.wasm.gz
.dfx/$(NETWORK)/canisters/example_frontend/assetstorage.wasm.gz:
	dfx canister create --network $(NETWORK) example_frontend
	dfx build --no-deps --network $(NETWORK) example_frontend


deploy-self@example_frontend: build@example_frontend
	dfx deploy --no-compile --network $(NETWORK) $(DEPLOY_FLAGS) $(DEPLOY_FLAGS.example_frontend) example_frontend


build@example_frontend: \
  generate@example_backend
deploy@example_frontend: deploy@example_backend \
  deploy-self@example_frontend

.dfx/$(NETWORK)/canisters/bootstrapper_data/bootstrapper_data.wasm .dfx/$(NETWORK)/canisters/bootstrapper_data/bootstrapper_data.did:
	dfx canister create --network $(NETWORK) bootstrapper_data
	dfx build --no-deps --network $(NETWORK) bootstrapper_data


deploy-self@bootstrapper_data: build@bootstrapper_data
	dfx deploy --no-compile --network $(NETWORK) $(DEPLOY_FLAGS) $(DEPLOY_FLAGS.bootstrapper_data) bootstrapper_data

deploy@bootstrapper_data: deploy-self@bootstrapper_data

.dfx/$(NETWORK)/canisters/nns-governance/nns-governance.wasm .dfx/$(NETWORK)/canisters/nns-governance/nns-governance.did:
	dfx build --no-deps --network $(NETWORK) nns-governance


deploy-self@nns-governance: build@nns-governance
deploy@nns-governance: deploy-self@nns-governance

.dfx/$(NETWORK)/canisters/upgrade_example_backend3_v2/upgrade_example_backend3_v2.wasm .dfx/$(NETWORK)/canisters/upgrade_example_backend3_v2/upgrade_example_backend3_v2.did:
	dfx canister create --network $(NETWORK) upgrade_example_backend3_v2
	dfx build --no-deps --network $(NETWORK) upgrade_example_backend3_v2


deploy-self@upgrade_example_backend3_v2: build@upgrade_example_backend3_v2
	dfx deploy --no-compile --network $(NETWORK) $(DEPLOY_FLAGS) $(DEPLOY_FLAGS.upgrade_example_backend3_v2) upgrade_example_backend3_v2

deploy@upgrade_example_backend3_v2: deploy-self@upgrade_example_backend3_v2

.dfx/$(NETWORK)/canisters/nns-ledger/nns-ledger.wasm .dfx/$(NETWORK)/canisters/nns-ledger/nns-ledger.did:
	dfx build --no-deps --network $(NETWORK) nns-ledger


deploy-self@nns-ledger: build@nns-ledger
deploy@nns-ledger: deploy-self@nns-ledger

.dfx/$(NETWORK)/canisters/nns-root/nns-root.wasm .dfx/$(NETWORK)/canisters/nns-root/nns-root.did:
	dfx build --no-deps --network $(NETWORK) nns-root


deploy-self@nns-root: build@nns-root
deploy@nns-root: deploy-self@nns-root

.dfx/$(NETWORK)/canisters/upgrade_example_backend2_v1/upgrade_example_backend2_v1.wasm .dfx/$(NETWORK)/canisters/upgrade_example_backend2_v1/upgrade_example_backend2_v1.did:
	dfx canister create --network $(NETWORK) upgrade_example_backend2_v1
	dfx build --no-deps --network $(NETWORK) upgrade_example_backend2_v1


deploy-self@upgrade_example_backend2_v1: build@upgrade_example_backend2_v1
	dfx deploy --no-compile --network $(NETWORK) $(DEPLOY_FLAGS) $(DEPLOY_FLAGS.upgrade_example_backend2_v1) upgrade_example_backend2_v1

deploy@upgrade_example_backend2_v1: deploy-self@upgrade_example_backend2_v1

.dfx/$(NETWORK)/canisters/bootstrapper/bootstrapper.wasm .dfx/$(NETWORK)/canisters/bootstrapper/bootstrapper.did:
	dfx canister create --network $(NETWORK) bootstrapper
	dfx build --no-deps --network $(NETWORK) bootstrapper


deploy-self@bootstrapper: build@bootstrapper
	dfx deploy --no-compile --network $(NETWORK) $(DEPLOY_FLAGS) $(DEPLOY_FLAGS.bootstrapper) bootstrapper

deploy@bootstrapper: deploy@nns-ledger deploy@cycles_ledger deploy@nns-cycles-minting deploy@bootstrapper_data deploy@repository \
  deploy-self@bootstrapper

.dfx/$(NETWORK)/canisters/nns-cycles-minting/nns-cycles-minting.wasm .dfx/$(NETWORK)/canisters/nns-cycles-minting/nns-cycles-minting.did:
	dfx build --no-deps --network $(NETWORK) nns-cycles-minting


deploy-self@nns-cycles-minting: build@nns-cycles-minting
deploy@nns-cycles-minting: deploy-self@nns-cycles-minting

.dfx/$(NETWORK)/canisters/nns-lifeline/nns-lifeline.wasm .dfx/$(NETWORK)/canisters/nns-lifeline/nns-lifeline.did:
	dfx build --no-deps --network $(NETWORK) nns-lifeline


deploy-self@nns-lifeline: build@nns-lifeline
deploy@nns-lifeline: deploy-self@nns-lifeline

.dfx/$(NETWORK)/canisters/repository/repository.wasm .dfx/$(NETWORK)/canisters/repository/repository.did:
	dfx canister create --network $(NETWORK) repository
	dfx build --no-deps --network $(NETWORK) repository


deploy-self@repository: build@repository
	dfx deploy --no-compile --network $(NETWORK) $(DEPLOY_FLAGS) $(DEPLOY_FLAGS.repository) repository

deploy@repository: deploy-self@repository

.dfx/$(NETWORK)/canisters/nns-genesis-token/nns-genesis-token.wasm .dfx/$(NETWORK)/canisters/nns-genesis-token/nns-genesis-token.did:
	dfx build --no-deps --network $(NETWORK) nns-genesis-token


deploy-self@nns-genesis-token: build@nns-genesis-token
deploy@nns-genesis-token: deploy-self@nns-genesis-token

.dfx/$(NETWORK)/canisters/upgrade_example_backend1_v1/upgrade_example_backend1_v1.wasm .dfx/$(NETWORK)/canisters/upgrade_example_backend1_v1/upgrade_example_backend1_v1.did:
	dfx canister create --network $(NETWORK) upgrade_example_backend1_v1
	dfx build --no-deps --network $(NETWORK) upgrade_example_backend1_v1


deploy-self@upgrade_example_backend1_v1: build@upgrade_example_backend1_v1
	dfx deploy --no-compile --network $(NETWORK) $(DEPLOY_FLAGS) $(DEPLOY_FLAGS.upgrade_example_backend1_v1) upgrade_example_backend1_v1

deploy@upgrade_example_backend1_v1: deploy-self@upgrade_example_backend1_v1

.dfx/$(NETWORK)/canisters/package_manager/package_manager.wasm .dfx/$(NETWORK)/canisters/package_manager/package_manager.did:
	dfx canister create --network $(NETWORK) package_manager
	dfx build --no-deps --network $(NETWORK) package_manager


deploy-self@package_manager: build@package_manager
	dfx deploy --no-compile --network $(NETWORK) $(DEPLOY_FLAGS) $(DEPLOY_FLAGS.package_manager) package_manager

deploy@package_manager: deploy@bootstrapper deploy@nns-ledger deploy@repository \
  deploy-self@package_manager

.dfx/$(NETWORK)/canisters/internet_identity/internet_identity.wasm.gz .dfx/$(NETWORK)/canisters/internet_identity/internet_identity.did:
	dfx canister create --network $(NETWORK) internet_identity
	dfx build --no-deps --network $(NETWORK) internet_identity


deploy-self@internet_identity: build@internet_identity
	dfx deploy --no-compile --network $(NETWORK) $(DEPLOY_FLAGS) $(DEPLOY_FLAGS.internet_identity) internet_identity

deploy@internet_identity: deploy-self@internet_identity

.dfx/$(NETWORK)/canisters/example_backend/example_backend.wasm .dfx/$(NETWORK)/canisters/example_backend/example_backend.did:
	dfx canister create --network $(NETWORK) example_backend
	dfx build --no-deps --network $(NETWORK) example_backend


deploy-self@example_backend: build@example_backend
	dfx deploy --no-compile --network $(NETWORK) $(DEPLOY_FLAGS) $(DEPLOY_FLAGS.example_backend) example_backend

deploy@example_backend: deploy-self@example_backend

.dfx/$(NETWORK)/canisters/battery/battery.wasm .dfx/$(NETWORK)/canisters/battery/battery.did:
	dfx canister create --network $(NETWORK) battery
	dfx build --no-deps --network $(NETWORK) battery


deploy-self@battery: build@battery
	dfx deploy --no-compile --network $(NETWORK) $(DEPLOY_FLAGS) $(DEPLOY_FLAGS.battery) battery

deploy@battery: deploy-self@battery

.PHONY: .dfx/$(NETWORK)/canisters/package_manager_frontend/assetstorage.wasm.gz
.dfx/$(NETWORK)/canisters/package_manager_frontend/assetstorage.wasm.gz:
	dfx canister create --network $(NETWORK) package_manager_frontend
	dfx build --no-deps --network $(NETWORK) package_manager_frontend


deploy-self@package_manager_frontend: build@package_manager_frontend
	dfx deploy --no-compile --network $(NETWORK) $(DEPLOY_FLAGS) $(DEPLOY_FLAGS.package_manager_frontend) package_manager_frontend


build@package_manager_frontend: \
  generate@package_manager generate@internet_identity generate@bootstrapper
deploy@package_manager_frontend: deploy@package_manager deploy@internet_identity deploy@bootstrapper \
  deploy-self@package_manager_frontend

.dfx/$(NETWORK)/canisters/bookmark/bookmark.wasm .dfx/$(NETWORK)/canisters/bookmark/bookmark.did:
	dfx canister create --network $(NETWORK) bookmark
	dfx build --no-deps --network $(NETWORK) bookmark


deploy-self@bookmark: build@bookmark
	dfx deploy --no-compile --network $(NETWORK) $(DEPLOY_FLAGS) $(DEPLOY_FLAGS.bookmark) bookmark

deploy@bookmark: deploy@bootstrapper \
  deploy-self@bookmark

.dfx/$(NETWORK)/canisters/nns-sns-wasm/nns-sns-wasm.wasm .dfx/$(NETWORK)/canisters/nns-sns-wasm/nns-sns-wasm.did:
	dfx build --no-deps --network $(NETWORK) nns-sns-wasm


deploy-self@nns-sns-wasm: build@nns-sns-wasm
deploy@nns-sns-wasm: deploy-self@nns-sns-wasm

.dfx/$(NETWORK)/canisters/upgrade_example_backend2_v2/upgrade_example_backend2_v2.wasm .dfx/$(NETWORK)/canisters/upgrade_example_backend2_v2/upgrade_example_backend2_v2.did:
	dfx canister create --network $(NETWORK) upgrade_example_backend2_v2
	dfx build --no-deps --network $(NETWORK) upgrade_example_backend2_v2


deploy-self@upgrade_example_backend2_v2: build@upgrade_example_backend2_v2
	dfx deploy --no-compile --network $(NETWORK) $(DEPLOY_FLAGS) $(DEPLOY_FLAGS.upgrade_example_backend2_v2) upgrade_example_backend2_v2

deploy@upgrade_example_backend2_v2: deploy-self@upgrade_example_backend2_v2

.dfx/$(NETWORK)/canisters/nns-registry/nns-registry.wasm .dfx/$(NETWORK)/canisters/nns-registry/nns-registry.did:
	dfx build --no-deps --network $(NETWORK) nns-registry


deploy-self@nns-registry: build@nns-registry
deploy@nns-registry: deploy-self@nns-registry

.dfx/$(NETWORK)/canisters/main_indirect/main_indirect.wasm .dfx/$(NETWORK)/canisters/main_indirect/main_indirect.did:
	dfx canister create --network $(NETWORK) main_indirect
	dfx build --no-deps --network $(NETWORK) main_indirect


deploy-self@main_indirect: build@main_indirect
	dfx deploy --no-compile --network $(NETWORK) $(DEPLOY_FLAGS) $(DEPLOY_FLAGS.main_indirect) main_indirect

deploy@main_indirect: deploy@bootstrapper deploy@nns-ledger deploy@nns-cycles-minting \
  deploy-self@main_indirect

.PHONY: .dfx/$(NETWORK)/canisters/bootstrapper_frontend/assetstorage.wasm.gz
.dfx/$(NETWORK)/canisters/bootstrapper_frontend/assetstorage.wasm.gz:
	dfx canister create --network $(NETWORK) bootstrapper_frontend
	dfx build --no-deps --network $(NETWORK) bootstrapper_frontend


deploy-self@bootstrapper_frontend: build@bootstrapper_frontend
	dfx deploy --no-compile --network $(NETWORK) $(DEPLOY_FLAGS) $(DEPLOY_FLAGS.bootstrapper_frontend) bootstrapper_frontend


build@bootstrapper_frontend: \
  generate@bootstrapper generate@bookmark generate@internet_identity generate@repository
deploy@bootstrapper_frontend: deploy@bootstrapper deploy@bookmark deploy@internet_identity deploy@repository \
  deploy-self@bootstrapper_frontend

.dfx/$(NETWORK)/canisters/simple_indirect/simple_indirect.wasm .dfx/$(NETWORK)/canisters/simple_indirect/simple_indirect.did:
	dfx canister create --network $(NETWORK) simple_indirect
	dfx build --no-deps --network $(NETWORK) simple_indirect


deploy-self@simple_indirect: build@simple_indirect
	dfx deploy --no-compile --network $(NETWORK) $(DEPLOY_FLAGS) $(DEPLOY_FLAGS.simple_indirect) simple_indirect

deploy@simple_indirect: deploy-self@simple_indirect

.dfx/$(NETWORK)/canisters/cycles_ledger/cycles_ledger.wasm.gz .dfx/$(NETWORK)/canisters/cycles_ledger/cycles_ledger.did:
	dfx canister create --network $(NETWORK) cycles_ledger
	dfx build --no-deps --network $(NETWORK) cycles_ledger


deploy-self@cycles_ledger: build@cycles_ledger
	dfx deploy --no-compile --network $(NETWORK) $(DEPLOY_FLAGS) $(DEPLOY_FLAGS.cycles_ledger) cycles_ledger

deploy@cycles_ledger: deploy-self@cycles_ledger

