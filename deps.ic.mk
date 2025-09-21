NETWORK ?= local

DEPLOY_FLAGS ?= 

.PHONY: build@battery
.PRECIOUS: .dfx/$(NETWORK)/canisters/battery/battery.wasm .dfx/$(NETWORK)/canisters/battery/battery.did
build@battery: .dfx/$(NETWORK)/canisters/battery/battery.wasm .dfx/$(NETWORK)/canisters/battery/battery.did

.dfx/$(NETWORK)/canisters/battery/battery.wasm .dfx/$(NETWORK)/canisters/battery/battery.did: src/package_manager_backend/battery.mo
	dfx canister create --network $(NETWORK) battery
	dfx build --no-deps --network $(NETWORK) battery

.PHONY: build@bookmark
.PRECIOUS: .dfx/$(NETWORK)/canisters/bookmark/bookmark.wasm .dfx/$(NETWORK)/canisters/bookmark/bookmark.did
build@bookmark: .dfx/$(NETWORK)/canisters/bookmark/bookmark.wasm .dfx/$(NETWORK)/canisters/bookmark/bookmark.did

.dfx/$(NETWORK)/canisters/bookmark/bookmark.wasm .dfx/$(NETWORK)/canisters/bookmark/bookmark.did: src/bootstrapper_backend/bookmarks.mo
	dfx canister create --network $(NETWORK) bookmark
	dfx build --no-deps --network $(NETWORK) bookmark

.PHONY: build@bootstrapper
.PRECIOUS: .dfx/$(NETWORK)/canisters/bootstrapper/bootstrapper.wasm .dfx/$(NETWORK)/canisters/bootstrapper/bootstrapper.did
build@bootstrapper: .dfx/$(NETWORK)/canisters/bootstrapper/bootstrapper.wasm .dfx/$(NETWORK)/canisters/bootstrapper/bootstrapper.did

.dfx/$(NETWORK)/canisters/bootstrapper/bootstrapper.wasm .dfx/$(NETWORK)/canisters/bootstrapper/bootstrapper.did: src/bootstrapper_backend/bootstrapper.mo
	dfx canister create --network $(NETWORK) bootstrapper
	dfx build --no-deps --network $(NETWORK) bootstrapper

.PHONY: build@bootstrapper_data
.PRECIOUS: .dfx/$(NETWORK)/canisters/bootstrapper_data/bootstrapper_data.wasm .dfx/$(NETWORK)/canisters/bootstrapper_data/bootstrapper_data.did
build@bootstrapper_data: .dfx/$(NETWORK)/canisters/bootstrapper_data/bootstrapper_data.wasm .dfx/$(NETWORK)/canisters/bootstrapper_data/bootstrapper_data.did

.dfx/$(NETWORK)/canisters/bootstrapper_data/bootstrapper_data.wasm .dfx/$(NETWORK)/canisters/bootstrapper_data/bootstrapper_data.did: src/bootstrapper_backend/BootstrapperData.mo
	dfx canister create --network $(NETWORK) bootstrapper_data
	dfx build --no-deps --network $(NETWORK) bootstrapper_data

.PHONY: build@bootstrapper_frontend
.PRECIOUS: .dfx/$(NETWORK)/canisters/bootstrapper_frontend/assetstorage.wasm.gz
build@bootstrapper_frontend: .dfx/$(NETWORK)/canisters/bootstrapper_frontend/assetstorage.wasm.gz

.dfx/$(NETWORK)/canisters/bootstrapper_frontend/assetstorage.wasm.gz: 
	dfx canister create --network $(NETWORK) bootstrapper_frontend
	dfx build --no-deps --network $(NETWORK) bootstrapper_frontend

.PHONY: build@cycles_ledger
.PRECIOUS: .dfx/$(NETWORK)/canisters/cycles_ledger/cycles_ledger.wasm.gz .dfx/$(NETWORK)/canisters/cycles_ledger/cycles_ledger.did
build@cycles_ledger: .dfx/$(NETWORK)/canisters/cycles_ledger/cycles_ledger.wasm.gz .dfx/$(NETWORK)/canisters/cycles_ledger/cycles_ledger.did

.dfx/$(NETWORK)/canisters/cycles_ledger/cycles_ledger.wasm.gz .dfx/$(NETWORK)/canisters/cycles_ledger/cycles_ledger.did: 

.PHONY: build@example_backend
.PRECIOUS: .dfx/$(NETWORK)/canisters/example_backend/example_backend.wasm .dfx/$(NETWORK)/canisters/example_backend/example_backend.did
build@example_backend: .dfx/$(NETWORK)/canisters/example_backend/example_backend.wasm .dfx/$(NETWORK)/canisters/example_backend/example_backend.did

.dfx/$(NETWORK)/canisters/example_backend/example_backend.wasm .dfx/$(NETWORK)/canisters/example_backend/example_backend.did: examples/example_backend/main.mo
	dfx canister create --network $(NETWORK) example_backend
	dfx build --no-deps --network $(NETWORK) example_backend

.PHONY: build@example_frontend
.PRECIOUS: .dfx/$(NETWORK)/canisters/example_frontend/assetstorage.wasm.gz
build@example_frontend: .dfx/$(NETWORK)/canisters/example_frontend/assetstorage.wasm.gz

.dfx/$(NETWORK)/canisters/example_frontend/assetstorage.wasm.gz: 
	dfx canister create --network $(NETWORK) example_frontend
	dfx build --no-deps --network $(NETWORK) example_frontend

.PHONY: build@exchange-rate
.PRECIOUS: .dfx/$(NETWORK)/canisters/exchange-rate/exchange-rate.wasm.gz .dfx/$(NETWORK)/canisters/exchange-rate/exchange-rate.did
build@exchange-rate: .dfx/$(NETWORK)/canisters/exchange-rate/exchange-rate.wasm.gz .dfx/$(NETWORK)/canisters/exchange-rate/exchange-rate.did

.dfx/$(NETWORK)/canisters/exchange-rate/exchange-rate.wasm.gz .dfx/$(NETWORK)/canisters/exchange-rate/exchange-rate.did: 

.PHONY: build@internet_identity
.PRECIOUS: .dfx/$(NETWORK)/canisters/internet_identity/internet_identity.wasm.gz .dfx/$(NETWORK)/canisters/internet_identity/internet_identity.did
build@internet_identity: .dfx/$(NETWORK)/canisters/internet_identity/internet_identity.wasm.gz .dfx/$(NETWORK)/canisters/internet_identity/internet_identity.did

.dfx/$(NETWORK)/canisters/internet_identity/internet_identity.wasm.gz .dfx/$(NETWORK)/canisters/internet_identity/internet_identity.did: 

.PHONY: build@main_indirect
.PRECIOUS: .dfx/$(NETWORK)/canisters/main_indirect/main_indirect.wasm .dfx/$(NETWORK)/canisters/main_indirect/main_indirect.did
build@main_indirect: .dfx/$(NETWORK)/canisters/main_indirect/main_indirect.wasm .dfx/$(NETWORK)/canisters/main_indirect/main_indirect.did

.dfx/$(NETWORK)/canisters/main_indirect/main_indirect.wasm .dfx/$(NETWORK)/canisters/main_indirect/main_indirect.did: src/package_manager_backend/main_indirect.mo
	dfx canister create --network $(NETWORK) main_indirect
	dfx build --no-deps --network $(NETWORK) main_indirect

.PHONY: build@multiassets
.PRECIOUS: .dfx/$(NETWORK)/canisters/multiassets/multiassets.wasm .dfx/$(NETWORK)/canisters/multiassets/multiassets.did
build@multiassets: .dfx/$(NETWORK)/canisters/multiassets/multiassets.wasm .dfx/$(NETWORK)/canisters/multiassets/multiassets.did

.dfx/$(NETWORK)/canisters/multiassets/multiassets.wasm .dfx/$(NETWORK)/canisters/multiassets/multiassets.did: src/multiassets/src/main.mo
	dfx canister create --network $(NETWORK) multiassets
	dfx build --no-deps --network $(NETWORK) multiassets

.PHONY: build@nns-cycles-minting
.PRECIOUS: .dfx/$(NETWORK)/canisters/nns-cycles-minting/nns-cycles-minting.wasm .dfx/$(NETWORK)/canisters/nns-cycles-minting/nns-cycles-minting.did
build@nns-cycles-minting: .dfx/$(NETWORK)/canisters/nns-cycles-minting/nns-cycles-minting.wasm .dfx/$(NETWORK)/canisters/nns-cycles-minting/nns-cycles-minting.did

.dfx/$(NETWORK)/canisters/nns-cycles-minting/nns-cycles-minting.wasm .dfx/$(NETWORK)/canisters/nns-cycles-minting/nns-cycles-minting.did: 

.PHONY: build@nns-genesis-token
.PRECIOUS: .dfx/$(NETWORK)/canisters/nns-genesis-token/nns-genesis-token.wasm .dfx/$(NETWORK)/canisters/nns-genesis-token/nns-genesis-token.did
build@nns-genesis-token: .dfx/$(NETWORK)/canisters/nns-genesis-token/nns-genesis-token.wasm .dfx/$(NETWORK)/canisters/nns-genesis-token/nns-genesis-token.did

.dfx/$(NETWORK)/canisters/nns-genesis-token/nns-genesis-token.wasm .dfx/$(NETWORK)/canisters/nns-genesis-token/nns-genesis-token.did: 

.PHONY: build@nns-governance
.PRECIOUS: .dfx/$(NETWORK)/canisters/nns-governance/nns-governance.wasm .dfx/$(NETWORK)/canisters/nns-governance/nns-governance.did
build@nns-governance: .dfx/$(NETWORK)/canisters/nns-governance/nns-governance.wasm .dfx/$(NETWORK)/canisters/nns-governance/nns-governance.did

.dfx/$(NETWORK)/canisters/nns-governance/nns-governance.wasm .dfx/$(NETWORK)/canisters/nns-governance/nns-governance.did: 

.PHONY: build@nns-ledger
.PRECIOUS: .dfx/$(NETWORK)/canisters/nns-ledger/nns-ledger.wasm .dfx/$(NETWORK)/canisters/nns-ledger/nns-ledger.did
build@nns-ledger: .dfx/$(NETWORK)/canisters/nns-ledger/nns-ledger.wasm .dfx/$(NETWORK)/canisters/nns-ledger/nns-ledger.did

.dfx/$(NETWORK)/canisters/nns-ledger/nns-ledger.wasm .dfx/$(NETWORK)/canisters/nns-ledger/nns-ledger.did: 

.PHONY: build@nns-lifeline
.PRECIOUS: .dfx/$(NETWORK)/canisters/nns-lifeline/nns-lifeline.wasm .dfx/$(NETWORK)/canisters/nns-lifeline/nns-lifeline.did
build@nns-lifeline: .dfx/$(NETWORK)/canisters/nns-lifeline/nns-lifeline.wasm .dfx/$(NETWORK)/canisters/nns-lifeline/nns-lifeline.did

.dfx/$(NETWORK)/canisters/nns-lifeline/nns-lifeline.wasm .dfx/$(NETWORK)/canisters/nns-lifeline/nns-lifeline.did: 

.PHONY: build@nns-registry
.PRECIOUS: .dfx/$(NETWORK)/canisters/nns-registry/nns-registry.wasm .dfx/$(NETWORK)/canisters/nns-registry/nns-registry.did
build@nns-registry: .dfx/$(NETWORK)/canisters/nns-registry/nns-registry.wasm .dfx/$(NETWORK)/canisters/nns-registry/nns-registry.did

.dfx/$(NETWORK)/canisters/nns-registry/nns-registry.wasm .dfx/$(NETWORK)/canisters/nns-registry/nns-registry.did: 

.PHONY: build@nns-root
.PRECIOUS: .dfx/$(NETWORK)/canisters/nns-root/nns-root.wasm .dfx/$(NETWORK)/canisters/nns-root/nns-root.did
build@nns-root: .dfx/$(NETWORK)/canisters/nns-root/nns-root.wasm .dfx/$(NETWORK)/canisters/nns-root/nns-root.did

.dfx/$(NETWORK)/canisters/nns-root/nns-root.wasm .dfx/$(NETWORK)/canisters/nns-root/nns-root.did: 

.PHONY: build@nns-sns-wasm
.PRECIOUS: .dfx/$(NETWORK)/canisters/nns-sns-wasm/nns-sns-wasm.wasm .dfx/$(NETWORK)/canisters/nns-sns-wasm/nns-sns-wasm.did
build@nns-sns-wasm: .dfx/$(NETWORK)/canisters/nns-sns-wasm/nns-sns-wasm.wasm .dfx/$(NETWORK)/canisters/nns-sns-wasm/nns-sns-wasm.did

.dfx/$(NETWORK)/canisters/nns-sns-wasm/nns-sns-wasm.wasm .dfx/$(NETWORK)/canisters/nns-sns-wasm/nns-sns-wasm.did: 

.PHONY: build@package_manager
.PRECIOUS: .dfx/$(NETWORK)/canisters/package_manager/package_manager.wasm .dfx/$(NETWORK)/canisters/package_manager/package_manager.did
build@package_manager: .dfx/$(NETWORK)/canisters/package_manager/package_manager.wasm .dfx/$(NETWORK)/canisters/package_manager/package_manager.did

.dfx/$(NETWORK)/canisters/package_manager/package_manager.wasm .dfx/$(NETWORK)/canisters/package_manager/package_manager.did: src/package_manager_backend/package_manager.mo
	dfx canister create --network $(NETWORK) package_manager
	dfx build --no-deps --network $(NETWORK) package_manager

.PHONY: build@package_manager_frontend
.PRECIOUS: .dfx/$(NETWORK)/canisters/package_manager_frontend/assetstorage.wasm.gz
build@package_manager_frontend: .dfx/$(NETWORK)/canisters/package_manager_frontend/assetstorage.wasm.gz

.dfx/$(NETWORK)/canisters/package_manager_frontend/assetstorage.wasm.gz: 
	dfx canister create --network $(NETWORK) package_manager_frontend
	dfx build --no-deps --network $(NETWORK) package_manager_frontend

.PHONY: build@repository
.PRECIOUS: .dfx/$(NETWORK)/canisters/repository/repository.wasm .dfx/$(NETWORK)/canisters/repository/repository.did
build@repository: .dfx/$(NETWORK)/canisters/repository/repository.wasm .dfx/$(NETWORK)/canisters/repository/repository.did

.dfx/$(NETWORK)/canisters/repository/repository.wasm .dfx/$(NETWORK)/canisters/repository/repository.did: src/repository_backend/Repository.mo
	dfx canister create --network $(NETWORK) repository
	dfx build --no-deps --network $(NETWORK) repository

.PHONY: build@simple_indirect
.PRECIOUS: .dfx/$(NETWORK)/canisters/simple_indirect/simple_indirect.wasm .dfx/$(NETWORK)/canisters/simple_indirect/simple_indirect.did
build@simple_indirect: .dfx/$(NETWORK)/canisters/simple_indirect/simple_indirect.wasm .dfx/$(NETWORK)/canisters/simple_indirect/simple_indirect.did

.dfx/$(NETWORK)/canisters/simple_indirect/simple_indirect.wasm .dfx/$(NETWORK)/canisters/simple_indirect/simple_indirect.did: src/package_manager_backend/simple_indirect.mo
	dfx canister create --network $(NETWORK) simple_indirect
	dfx build --no-deps --network $(NETWORK) simple_indirect

.PHONY: build@swap-factory
.PRECIOUS: .dfx/$(NETWORK)/canisters/swap-factory/swap-factory.wasm .dfx/$(NETWORK)/canisters/swap-factory/swap-factory.did
build@swap-factory: .dfx/$(NETWORK)/canisters/swap-factory/swap-factory.wasm .dfx/$(NETWORK)/canisters/swap-factory/swap-factory.did

.dfx/$(NETWORK)/canisters/swap-factory/swap-factory.wasm .dfx/$(NETWORK)/canisters/swap-factory/swap-factory.did: 

.PHONY: build@swap-pool
.PRECIOUS: .dfx/$(NETWORK)/canisters/swap-pool/swap-pool.wasm .dfx/$(NETWORK)/canisters/swap-pool/swap-pool.did
build@swap-pool: .dfx/$(NETWORK)/canisters/swap-pool/swap-pool.wasm .dfx/$(NETWORK)/canisters/swap-pool/swap-pool.did

.dfx/$(NETWORK)/canisters/swap-pool/swap-pool.wasm .dfx/$(NETWORK)/canisters/swap-pool/swap-pool.did: 

.PHONY: build@upgrade_example_backend1_v1
.PRECIOUS: .dfx/$(NETWORK)/canisters/upgrade_example_backend1_v1/upgrade_example_backend1_v1.wasm .dfx/$(NETWORK)/canisters/upgrade_example_backend1_v1/upgrade_example_backend1_v1.did
build@upgrade_example_backend1_v1: .dfx/$(NETWORK)/canisters/upgrade_example_backend1_v1/upgrade_example_backend1_v1.wasm .dfx/$(NETWORK)/canisters/upgrade_example_backend1_v1/upgrade_example_backend1_v1.did

.dfx/$(NETWORK)/canisters/upgrade_example_backend1_v1/upgrade_example_backend1_v1.wasm .dfx/$(NETWORK)/canisters/upgrade_example_backend1_v1/upgrade_example_backend1_v1.did: examples/upgrade_example_backend/0.0.1/main1.mo
	dfx canister create --network $(NETWORK) upgrade_example_backend1_v1
	dfx build --no-deps --network $(NETWORK) upgrade_example_backend1_v1

.PHONY: build@upgrade_example_backend2_v1
.PRECIOUS: .dfx/$(NETWORK)/canisters/upgrade_example_backend2_v1/upgrade_example_backend2_v1.wasm .dfx/$(NETWORK)/canisters/upgrade_example_backend2_v1/upgrade_example_backend2_v1.did
build@upgrade_example_backend2_v1: .dfx/$(NETWORK)/canisters/upgrade_example_backend2_v1/upgrade_example_backend2_v1.wasm .dfx/$(NETWORK)/canisters/upgrade_example_backend2_v1/upgrade_example_backend2_v1.did

.dfx/$(NETWORK)/canisters/upgrade_example_backend2_v1/upgrade_example_backend2_v1.wasm .dfx/$(NETWORK)/canisters/upgrade_example_backend2_v1/upgrade_example_backend2_v1.did: examples/upgrade_example_backend/0.0.1/main2.mo
	dfx canister create --network $(NETWORK) upgrade_example_backend2_v1
	dfx build --no-deps --network $(NETWORK) upgrade_example_backend2_v1

.PHONY: build@upgrade_example_backend2_v2
.PRECIOUS: .dfx/$(NETWORK)/canisters/upgrade_example_backend2_v2/upgrade_example_backend2_v2.wasm .dfx/$(NETWORK)/canisters/upgrade_example_backend2_v2/upgrade_example_backend2_v2.did
build@upgrade_example_backend2_v2: .dfx/$(NETWORK)/canisters/upgrade_example_backend2_v2/upgrade_example_backend2_v2.wasm .dfx/$(NETWORK)/canisters/upgrade_example_backend2_v2/upgrade_example_backend2_v2.did

.dfx/$(NETWORK)/canisters/upgrade_example_backend2_v2/upgrade_example_backend2_v2.wasm .dfx/$(NETWORK)/canisters/upgrade_example_backend2_v2/upgrade_example_backend2_v2.did: examples/upgrade_example_backend/0.0.2/main2.mo
	dfx canister create --network $(NETWORK) upgrade_example_backend2_v2
	dfx build --no-deps --network $(NETWORK) upgrade_example_backend2_v2

.PHONY: build@upgrade_example_backend3_v2
.PRECIOUS: .dfx/$(NETWORK)/canisters/upgrade_example_backend3_v2/upgrade_example_backend3_v2.wasm .dfx/$(NETWORK)/canisters/upgrade_example_backend3_v2/upgrade_example_backend3_v2.did
build@upgrade_example_backend3_v2: .dfx/$(NETWORK)/canisters/upgrade_example_backend3_v2/upgrade_example_backend3_v2.wasm .dfx/$(NETWORK)/canisters/upgrade_example_backend3_v2/upgrade_example_backend3_v2.did

.dfx/$(NETWORK)/canisters/upgrade_example_backend3_v2/upgrade_example_backend3_v2.wasm .dfx/$(NETWORK)/canisters/upgrade_example_backend3_v2/upgrade_example_backend3_v2.did: examples/upgrade_example_backend/0.0.2/main3.mo
	dfx canister create --network $(NETWORK) upgrade_example_backend3_v2
	dfx build --no-deps --network $(NETWORK) upgrade_example_backend3_v2

.PHONY: build@wallet_backend
.PRECIOUS: .dfx/$(NETWORK)/canisters/wallet_backend/wallet_backend.wasm .dfx/$(NETWORK)/canisters/wallet_backend/wallet_backend.did
build@wallet_backend: .dfx/$(NETWORK)/canisters/wallet_backend/wallet_backend.wasm .dfx/$(NETWORK)/canisters/wallet_backend/wallet_backend.did

.dfx/$(NETWORK)/canisters/wallet_backend/wallet_backend.wasm .dfx/$(NETWORK)/canisters/wallet_backend/wallet_backend.did: src/wallet_backend/wallet.mo
	dfx canister create --network $(NETWORK) wallet_backend
	dfx build --no-deps --network $(NETWORK) wallet_backend

.PHONY: build@wallet_frontend
.PRECIOUS: .dfx/$(NETWORK)/canisters/wallet_frontend/assetstorage.wasm.gz
build@wallet_frontend: .dfx/$(NETWORK)/canisters/wallet_frontend/assetstorage.wasm.gz

.dfx/$(NETWORK)/canisters/wallet_frontend/assetstorage.wasm.gz: 
	dfx canister create --network $(NETWORK) wallet_frontend
	dfx build --no-deps --network $(NETWORK) wallet_frontend

.PHONY: generate@battery
.PRECIOUS: src/declarations/battery/battery.did.js src/declarations/battery/index.js src/declarations/battery/battery.did.d.ts src/declarations/battery/index.d.ts src/declarations/battery/battery.did
generate@battery: src/declarations/battery/battery.did.js src/declarations/battery/index.js src/declarations/battery/battery.did.d.ts src/declarations/battery/index.d.ts src/declarations/battery/battery.did

src/declarations/battery/battery.did.js src/declarations/battery/index.js src/declarations/battery/battery.did.d.ts src/declarations/battery/index.d.ts src/declarations/battery/battery.did: .dfx/$(NETWORK)/canisters/battery/battery.wasm .dfx/$(NETWORK)/canisters/battery/battery.did
	dfx generate --no-compile --network $(NETWORK) battery

.PHONY: generate@bookmark
.PRECIOUS: src/declarations/bookmark/bookmark.did.js src/declarations/bookmark/index.js src/declarations/bookmark/bookmark.did.d.ts src/declarations/bookmark/index.d.ts src/declarations/bookmark/bookmark.did
generate@bookmark: src/declarations/bookmark/bookmark.did.js src/declarations/bookmark/index.js src/declarations/bookmark/bookmark.did.d.ts src/declarations/bookmark/index.d.ts src/declarations/bookmark/bookmark.did

src/declarations/bookmark/bookmark.did.js src/declarations/bookmark/index.js src/declarations/bookmark/bookmark.did.d.ts src/declarations/bookmark/index.d.ts src/declarations/bookmark/bookmark.did: .dfx/$(NETWORK)/canisters/bookmark/bookmark.wasm .dfx/$(NETWORK)/canisters/bookmark/bookmark.did
	dfx generate --no-compile --network $(NETWORK) bookmark

.PHONY: generate@bootstrapper
.PRECIOUS: src/declarations/bootstrapper/bootstrapper.did.js src/declarations/bootstrapper/index.js src/declarations/bootstrapper/bootstrapper.did.d.ts src/declarations/bootstrapper/index.d.ts src/declarations/bootstrapper/bootstrapper.did
generate@bootstrapper: src/declarations/bootstrapper/bootstrapper.did.js src/declarations/bootstrapper/index.js src/declarations/bootstrapper/bootstrapper.did.d.ts src/declarations/bootstrapper/index.d.ts src/declarations/bootstrapper/bootstrapper.did

src/declarations/bootstrapper/bootstrapper.did.js src/declarations/bootstrapper/index.js src/declarations/bootstrapper/bootstrapper.did.d.ts src/declarations/bootstrapper/index.d.ts src/declarations/bootstrapper/bootstrapper.did: .dfx/$(NETWORK)/canisters/bootstrapper/bootstrapper.wasm .dfx/$(NETWORK)/canisters/bootstrapper/bootstrapper.did
	dfx generate --no-compile --network $(NETWORK) bootstrapper

.PHONY: generate@bootstrapper_data
.PRECIOUS: src/declarations/bootstrapper_data/bootstrapper_data.did.js src/declarations/bootstrapper_data/index.js src/declarations/bootstrapper_data/bootstrapper_data.did.d.ts src/declarations/bootstrapper_data/index.d.ts src/declarations/bootstrapper_data/bootstrapper_data.did
generate@bootstrapper_data: src/declarations/bootstrapper_data/bootstrapper_data.did.js src/declarations/bootstrapper_data/index.js src/declarations/bootstrapper_data/bootstrapper_data.did.d.ts src/declarations/bootstrapper_data/index.d.ts src/declarations/bootstrapper_data/bootstrapper_data.did

src/declarations/bootstrapper_data/bootstrapper_data.did.js src/declarations/bootstrapper_data/index.js src/declarations/bootstrapper_data/bootstrapper_data.did.d.ts src/declarations/bootstrapper_data/index.d.ts src/declarations/bootstrapper_data/bootstrapper_data.did: .dfx/$(NETWORK)/canisters/bootstrapper_data/bootstrapper_data.wasm .dfx/$(NETWORK)/canisters/bootstrapper_data/bootstrapper_data.did
	dfx generate --no-compile --network $(NETWORK) bootstrapper_data

.PHONY: generate@bootstrapper_frontend
.PRECIOUS: src/declarations/bootstrapper_frontend/bootstrapper_frontend.did.js src/declarations/bootstrapper_frontend/index.js src/declarations/bootstrapper_frontend/bootstrapper_frontend.did.d.ts src/declarations/bootstrapper_frontend/index.d.ts src/declarations/bootstrapper_frontend/bootstrapper_frontend.did
generate@bootstrapper_frontend: src/declarations/bootstrapper_frontend/bootstrapper_frontend.did.js src/declarations/bootstrapper_frontend/index.js src/declarations/bootstrapper_frontend/bootstrapper_frontend.did.d.ts src/declarations/bootstrapper_frontend/index.d.ts src/declarations/bootstrapper_frontend/bootstrapper_frontend.did

src/declarations/bootstrapper_frontend/bootstrapper_frontend.did.js src/declarations/bootstrapper_frontend/index.js src/declarations/bootstrapper_frontend/bootstrapper_frontend.did.d.ts src/declarations/bootstrapper_frontend/index.d.ts src/declarations/bootstrapper_frontend/bootstrapper_frontend.did: .dfx/$(NETWORK)/canisters/bootstrapper_frontend/assetstorage.wasm.gz
	dfx generate --no-compile --network $(NETWORK) bootstrapper_frontend

.PHONY: generate@cycles_ledger
.PRECIOUS: src/declarations/cycles_ledger/cycles_ledger.did.js src/declarations/cycles_ledger/index.js src/declarations/cycles_ledger/cycles_ledger.did.d.ts src/declarations/cycles_ledger/index.d.ts src/declarations/cycles_ledger/cycles_ledger.did
generate@cycles_ledger: src/declarations/cycles_ledger/cycles_ledger.did.js src/declarations/cycles_ledger/index.js src/declarations/cycles_ledger/cycles_ledger.did.d.ts src/declarations/cycles_ledger/index.d.ts src/declarations/cycles_ledger/cycles_ledger.did

src/declarations/cycles_ledger/cycles_ledger.did.js src/declarations/cycles_ledger/index.js src/declarations/cycles_ledger/cycles_ledger.did.d.ts src/declarations/cycles_ledger/index.d.ts src/declarations/cycles_ledger/cycles_ledger.did: .dfx/$(NETWORK)/canisters/cycles_ledger/cycles_ledger.wasm.gz .dfx/$(NETWORK)/canisters/cycles_ledger/cycles_ledger.did
	dfx generate --no-compile --network $(NETWORK) cycles_ledger

.PHONY: generate@example_backend
.PRECIOUS: src/declarations/example_backend/example_backend.did.js src/declarations/example_backend/index.js src/declarations/example_backend/example_backend.did.d.ts src/declarations/example_backend/index.d.ts src/declarations/example_backend/example_backend.did
generate@example_backend: src/declarations/example_backend/example_backend.did.js src/declarations/example_backend/index.js src/declarations/example_backend/example_backend.did.d.ts src/declarations/example_backend/index.d.ts src/declarations/example_backend/example_backend.did

src/declarations/example_backend/example_backend.did.js src/declarations/example_backend/index.js src/declarations/example_backend/example_backend.did.d.ts src/declarations/example_backend/index.d.ts src/declarations/example_backend/example_backend.did: .dfx/$(NETWORK)/canisters/example_backend/example_backend.wasm .dfx/$(NETWORK)/canisters/example_backend/example_backend.did
	dfx generate --no-compile --network $(NETWORK) example_backend

.PHONY: generate@example_frontend
.PRECIOUS: src/declarations/example_frontend/example_frontend.did.js src/declarations/example_frontend/index.js src/declarations/example_frontend/example_frontend.did.d.ts src/declarations/example_frontend/index.d.ts src/declarations/example_frontend/example_frontend.did
generate@example_frontend: src/declarations/example_frontend/example_frontend.did.js src/declarations/example_frontend/index.js src/declarations/example_frontend/example_frontend.did.d.ts src/declarations/example_frontend/index.d.ts src/declarations/example_frontend/example_frontend.did

src/declarations/example_frontend/example_frontend.did.js src/declarations/example_frontend/index.js src/declarations/example_frontend/example_frontend.did.d.ts src/declarations/example_frontend/index.d.ts src/declarations/example_frontend/example_frontend.did: .dfx/$(NETWORK)/canisters/example_frontend/assetstorage.wasm.gz
	dfx generate --no-compile --network $(NETWORK) example_frontend

.PHONY: generate@exchange-rate
.PRECIOUS: src/declarations/exchange-rate/exchange-rate.did.js src/declarations/exchange-rate/index.js src/declarations/exchange-rate/exchange-rate.did.d.ts src/declarations/exchange-rate/index.d.ts src/declarations/exchange-rate/exchange-rate.did
generate@exchange-rate: src/declarations/exchange-rate/exchange-rate.did.js src/declarations/exchange-rate/index.js src/declarations/exchange-rate/exchange-rate.did.d.ts src/declarations/exchange-rate/index.d.ts src/declarations/exchange-rate/exchange-rate.did

src/declarations/exchange-rate/exchange-rate.did.js src/declarations/exchange-rate/index.js src/declarations/exchange-rate/exchange-rate.did.d.ts src/declarations/exchange-rate/index.d.ts src/declarations/exchange-rate/exchange-rate.did: .dfx/$(NETWORK)/canisters/exchange-rate/exchange-rate.wasm.gz .dfx/$(NETWORK)/canisters/exchange-rate/exchange-rate.did
	dfx generate --no-compile --network $(NETWORK) exchange-rate

.PHONY: generate@internet_identity
.PRECIOUS: src/declarations/internet_identity/internet_identity.did.js src/declarations/internet_identity/index.js src/declarations/internet_identity/internet_identity.did.d.ts src/declarations/internet_identity/index.d.ts src/declarations/internet_identity/internet_identity.did
generate@internet_identity: src/declarations/internet_identity/internet_identity.did.js src/declarations/internet_identity/index.js src/declarations/internet_identity/internet_identity.did.d.ts src/declarations/internet_identity/index.d.ts src/declarations/internet_identity/internet_identity.did

src/declarations/internet_identity/internet_identity.did.js src/declarations/internet_identity/index.js src/declarations/internet_identity/internet_identity.did.d.ts src/declarations/internet_identity/index.d.ts src/declarations/internet_identity/internet_identity.did: .dfx/$(NETWORK)/canisters/internet_identity/internet_identity.wasm.gz .dfx/$(NETWORK)/canisters/internet_identity/internet_identity.did
	dfx generate --no-compile --network $(NETWORK) internet_identity

.PHONY: generate@main_indirect
.PRECIOUS: src/declarations/main_indirect/main_indirect.did.js src/declarations/main_indirect/index.js src/declarations/main_indirect/main_indirect.did.d.ts src/declarations/main_indirect/index.d.ts src/declarations/main_indirect/main_indirect.did
generate@main_indirect: src/declarations/main_indirect/main_indirect.did.js src/declarations/main_indirect/index.js src/declarations/main_indirect/main_indirect.did.d.ts src/declarations/main_indirect/index.d.ts src/declarations/main_indirect/main_indirect.did

src/declarations/main_indirect/main_indirect.did.js src/declarations/main_indirect/index.js src/declarations/main_indirect/main_indirect.did.d.ts src/declarations/main_indirect/index.d.ts src/declarations/main_indirect/main_indirect.did: .dfx/$(NETWORK)/canisters/main_indirect/main_indirect.wasm .dfx/$(NETWORK)/canisters/main_indirect/main_indirect.did
	dfx generate --no-compile --network $(NETWORK) main_indirect

.PHONY: generate@multiassets
.PRECIOUS: src/declarations/multiassets/multiassets.did.js src/declarations/multiassets/index.js src/declarations/multiassets/multiassets.did.d.ts src/declarations/multiassets/index.d.ts src/declarations/multiassets/multiassets.did
generate@multiassets: src/declarations/multiassets/multiassets.did.js src/declarations/multiassets/index.js src/declarations/multiassets/multiassets.did.d.ts src/declarations/multiassets/index.d.ts src/declarations/multiassets/multiassets.did

src/declarations/multiassets/multiassets.did.js src/declarations/multiassets/index.js src/declarations/multiassets/multiassets.did.d.ts src/declarations/multiassets/index.d.ts src/declarations/multiassets/multiassets.did: .dfx/$(NETWORK)/canisters/multiassets/multiassets.wasm .dfx/$(NETWORK)/canisters/multiassets/multiassets.did
	dfx generate --no-compile --network $(NETWORK) multiassets

.PHONY: generate@nns-cycles-minting
.PRECIOUS: src/declarations/nns-cycles-minting/nns-cycles-minting.did.js src/declarations/nns-cycles-minting/index.js src/declarations/nns-cycles-minting/nns-cycles-minting.did.d.ts src/declarations/nns-cycles-minting/index.d.ts src/declarations/nns-cycles-minting/nns-cycles-minting.did
generate@nns-cycles-minting: src/declarations/nns-cycles-minting/nns-cycles-minting.did.js src/declarations/nns-cycles-minting/index.js src/declarations/nns-cycles-minting/nns-cycles-minting.did.d.ts src/declarations/nns-cycles-minting/index.d.ts src/declarations/nns-cycles-minting/nns-cycles-minting.did

src/declarations/nns-cycles-minting/nns-cycles-minting.did.js src/declarations/nns-cycles-minting/index.js src/declarations/nns-cycles-minting/nns-cycles-minting.did.d.ts src/declarations/nns-cycles-minting/index.d.ts src/declarations/nns-cycles-minting/nns-cycles-minting.did: .dfx/$(NETWORK)/canisters/nns-cycles-minting/nns-cycles-minting.wasm .dfx/$(NETWORK)/canisters/nns-cycles-minting/nns-cycles-minting.did
	dfx generate --no-compile --network $(NETWORK) nns-cycles-minting

.PHONY: generate@nns-genesis-token
.PRECIOUS: src/declarations/nns-genesis-token/nns-genesis-token.did.js src/declarations/nns-genesis-token/index.js src/declarations/nns-genesis-token/nns-genesis-token.did.d.ts src/declarations/nns-genesis-token/index.d.ts src/declarations/nns-genesis-token/nns-genesis-token.did
generate@nns-genesis-token: src/declarations/nns-genesis-token/nns-genesis-token.did.js src/declarations/nns-genesis-token/index.js src/declarations/nns-genesis-token/nns-genesis-token.did.d.ts src/declarations/nns-genesis-token/index.d.ts src/declarations/nns-genesis-token/nns-genesis-token.did

src/declarations/nns-genesis-token/nns-genesis-token.did.js src/declarations/nns-genesis-token/index.js src/declarations/nns-genesis-token/nns-genesis-token.did.d.ts src/declarations/nns-genesis-token/index.d.ts src/declarations/nns-genesis-token/nns-genesis-token.did: .dfx/$(NETWORK)/canisters/nns-genesis-token/nns-genesis-token.wasm .dfx/$(NETWORK)/canisters/nns-genesis-token/nns-genesis-token.did
	dfx generate --no-compile --network $(NETWORK) nns-genesis-token

.PHONY: generate@nns-governance
.PRECIOUS: src/declarations/nns-governance/nns-governance.did.js src/declarations/nns-governance/index.js src/declarations/nns-governance/nns-governance.did.d.ts src/declarations/nns-governance/index.d.ts src/declarations/nns-governance/nns-governance.did
generate@nns-governance: src/declarations/nns-governance/nns-governance.did.js src/declarations/nns-governance/index.js src/declarations/nns-governance/nns-governance.did.d.ts src/declarations/nns-governance/index.d.ts src/declarations/nns-governance/nns-governance.did

src/declarations/nns-governance/nns-governance.did.js src/declarations/nns-governance/index.js src/declarations/nns-governance/nns-governance.did.d.ts src/declarations/nns-governance/index.d.ts src/declarations/nns-governance/nns-governance.did: .dfx/$(NETWORK)/canisters/nns-governance/nns-governance.wasm .dfx/$(NETWORK)/canisters/nns-governance/nns-governance.did
	dfx generate --no-compile --network $(NETWORK) nns-governance

.PHONY: generate@nns-ledger
.PRECIOUS: src/declarations/nns-ledger/nns-ledger.did.js src/declarations/nns-ledger/index.js src/declarations/nns-ledger/nns-ledger.did.d.ts src/declarations/nns-ledger/index.d.ts src/declarations/nns-ledger/nns-ledger.did
generate@nns-ledger: src/declarations/nns-ledger/nns-ledger.did.js src/declarations/nns-ledger/index.js src/declarations/nns-ledger/nns-ledger.did.d.ts src/declarations/nns-ledger/index.d.ts src/declarations/nns-ledger/nns-ledger.did

src/declarations/nns-ledger/nns-ledger.did.js src/declarations/nns-ledger/index.js src/declarations/nns-ledger/nns-ledger.did.d.ts src/declarations/nns-ledger/index.d.ts src/declarations/nns-ledger/nns-ledger.did: .dfx/$(NETWORK)/canisters/nns-ledger/nns-ledger.wasm .dfx/$(NETWORK)/canisters/nns-ledger/nns-ledger.did
	dfx generate --no-compile --network $(NETWORK) nns-ledger

.PHONY: generate@nns-lifeline
.PRECIOUS: src/declarations/nns-lifeline/nns-lifeline.did.js src/declarations/nns-lifeline/index.js src/declarations/nns-lifeline/nns-lifeline.did.d.ts src/declarations/nns-lifeline/index.d.ts src/declarations/nns-lifeline/nns-lifeline.did
generate@nns-lifeline: src/declarations/nns-lifeline/nns-lifeline.did.js src/declarations/nns-lifeline/index.js src/declarations/nns-lifeline/nns-lifeline.did.d.ts src/declarations/nns-lifeline/index.d.ts src/declarations/nns-lifeline/nns-lifeline.did

src/declarations/nns-lifeline/nns-lifeline.did.js src/declarations/nns-lifeline/index.js src/declarations/nns-lifeline/nns-lifeline.did.d.ts src/declarations/nns-lifeline/index.d.ts src/declarations/nns-lifeline/nns-lifeline.did: .dfx/$(NETWORK)/canisters/nns-lifeline/nns-lifeline.wasm .dfx/$(NETWORK)/canisters/nns-lifeline/nns-lifeline.did
	dfx generate --no-compile --network $(NETWORK) nns-lifeline

.PHONY: generate@nns-registry
.PRECIOUS: src/declarations/nns-registry/nns-registry.did.js src/declarations/nns-registry/index.js src/declarations/nns-registry/nns-registry.did.d.ts src/declarations/nns-registry/index.d.ts src/declarations/nns-registry/nns-registry.did
generate@nns-registry: src/declarations/nns-registry/nns-registry.did.js src/declarations/nns-registry/index.js src/declarations/nns-registry/nns-registry.did.d.ts src/declarations/nns-registry/index.d.ts src/declarations/nns-registry/nns-registry.did

src/declarations/nns-registry/nns-registry.did.js src/declarations/nns-registry/index.js src/declarations/nns-registry/nns-registry.did.d.ts src/declarations/nns-registry/index.d.ts src/declarations/nns-registry/nns-registry.did: .dfx/$(NETWORK)/canisters/nns-registry/nns-registry.wasm .dfx/$(NETWORK)/canisters/nns-registry/nns-registry.did
	dfx generate --no-compile --network $(NETWORK) nns-registry

.PHONY: generate@nns-root
.PRECIOUS: src/declarations/nns-root/nns-root.did.js src/declarations/nns-root/index.js src/declarations/nns-root/nns-root.did.d.ts src/declarations/nns-root/index.d.ts src/declarations/nns-root/nns-root.did
generate@nns-root: src/declarations/nns-root/nns-root.did.js src/declarations/nns-root/index.js src/declarations/nns-root/nns-root.did.d.ts src/declarations/nns-root/index.d.ts src/declarations/nns-root/nns-root.did

src/declarations/nns-root/nns-root.did.js src/declarations/nns-root/index.js src/declarations/nns-root/nns-root.did.d.ts src/declarations/nns-root/index.d.ts src/declarations/nns-root/nns-root.did: .dfx/$(NETWORK)/canisters/nns-root/nns-root.wasm .dfx/$(NETWORK)/canisters/nns-root/nns-root.did
	dfx generate --no-compile --network $(NETWORK) nns-root

.PHONY: generate@nns-sns-wasm
.PRECIOUS: src/declarations/nns-sns-wasm/nns-sns-wasm.did.js src/declarations/nns-sns-wasm/index.js src/declarations/nns-sns-wasm/nns-sns-wasm.did.d.ts src/declarations/nns-sns-wasm/index.d.ts src/declarations/nns-sns-wasm/nns-sns-wasm.did
generate@nns-sns-wasm: src/declarations/nns-sns-wasm/nns-sns-wasm.did.js src/declarations/nns-sns-wasm/index.js src/declarations/nns-sns-wasm/nns-sns-wasm.did.d.ts src/declarations/nns-sns-wasm/index.d.ts src/declarations/nns-sns-wasm/nns-sns-wasm.did

src/declarations/nns-sns-wasm/nns-sns-wasm.did.js src/declarations/nns-sns-wasm/index.js src/declarations/nns-sns-wasm/nns-sns-wasm.did.d.ts src/declarations/nns-sns-wasm/index.d.ts src/declarations/nns-sns-wasm/nns-sns-wasm.did: .dfx/$(NETWORK)/canisters/nns-sns-wasm/nns-sns-wasm.wasm .dfx/$(NETWORK)/canisters/nns-sns-wasm/nns-sns-wasm.did
	dfx generate --no-compile --network $(NETWORK) nns-sns-wasm

.PHONY: generate@package_manager
.PRECIOUS: src/declarations/package_manager/package_manager.did.js src/declarations/package_manager/index.js src/declarations/package_manager/package_manager.did.d.ts src/declarations/package_manager/index.d.ts src/declarations/package_manager/package_manager.did
generate@package_manager: src/declarations/package_manager/package_manager.did.js src/declarations/package_manager/index.js src/declarations/package_manager/package_manager.did.d.ts src/declarations/package_manager/index.d.ts src/declarations/package_manager/package_manager.did

src/declarations/package_manager/package_manager.did.js src/declarations/package_manager/index.js src/declarations/package_manager/package_manager.did.d.ts src/declarations/package_manager/index.d.ts src/declarations/package_manager/package_manager.did: .dfx/$(NETWORK)/canisters/package_manager/package_manager.wasm .dfx/$(NETWORK)/canisters/package_manager/package_manager.did
	dfx generate --no-compile --network $(NETWORK) package_manager

.PHONY: generate@package_manager_frontend
.PRECIOUS: src/declarations/package_manager_frontend/package_manager_frontend.did.js src/declarations/package_manager_frontend/index.js src/declarations/package_manager_frontend/package_manager_frontend.did.d.ts src/declarations/package_manager_frontend/index.d.ts src/declarations/package_manager_frontend/package_manager_frontend.did
generate@package_manager_frontend: src/declarations/package_manager_frontend/package_manager_frontend.did.js src/declarations/package_manager_frontend/index.js src/declarations/package_manager_frontend/package_manager_frontend.did.d.ts src/declarations/package_manager_frontend/index.d.ts src/declarations/package_manager_frontend/package_manager_frontend.did

src/declarations/package_manager_frontend/package_manager_frontend.did.js src/declarations/package_manager_frontend/index.js src/declarations/package_manager_frontend/package_manager_frontend.did.d.ts src/declarations/package_manager_frontend/index.d.ts src/declarations/package_manager_frontend/package_manager_frontend.did: .dfx/$(NETWORK)/canisters/package_manager_frontend/assetstorage.wasm.gz
	dfx generate --no-compile --network $(NETWORK) package_manager_frontend

.PHONY: generate@repository
.PRECIOUS: src/declarations/repository/repository.did.js src/declarations/repository/index.js src/declarations/repository/repository.did.d.ts src/declarations/repository/index.d.ts src/declarations/repository/repository.did
generate@repository: src/declarations/repository/repository.did.js src/declarations/repository/index.js src/declarations/repository/repository.did.d.ts src/declarations/repository/index.d.ts src/declarations/repository/repository.did

src/declarations/repository/repository.did.js src/declarations/repository/index.js src/declarations/repository/repository.did.d.ts src/declarations/repository/index.d.ts src/declarations/repository/repository.did: .dfx/$(NETWORK)/canisters/repository/repository.wasm .dfx/$(NETWORK)/canisters/repository/repository.did
	dfx generate --no-compile --network $(NETWORK) repository

.PHONY: generate@simple_indirect
.PRECIOUS: src/declarations/simple_indirect/simple_indirect.did.js src/declarations/simple_indirect/index.js src/declarations/simple_indirect/simple_indirect.did.d.ts src/declarations/simple_indirect/index.d.ts src/declarations/simple_indirect/simple_indirect.did
generate@simple_indirect: src/declarations/simple_indirect/simple_indirect.did.js src/declarations/simple_indirect/index.js src/declarations/simple_indirect/simple_indirect.did.d.ts src/declarations/simple_indirect/index.d.ts src/declarations/simple_indirect/simple_indirect.did

src/declarations/simple_indirect/simple_indirect.did.js src/declarations/simple_indirect/index.js src/declarations/simple_indirect/simple_indirect.did.d.ts src/declarations/simple_indirect/index.d.ts src/declarations/simple_indirect/simple_indirect.did: .dfx/$(NETWORK)/canisters/simple_indirect/simple_indirect.wasm .dfx/$(NETWORK)/canisters/simple_indirect/simple_indirect.did
	dfx generate --no-compile --network $(NETWORK) simple_indirect

.PHONY: generate@swap-factory
.PRECIOUS: src/declarations/swap-factory/swap-factory.did.js src/declarations/swap-factory/index.js src/declarations/swap-factory/swap-factory.did.d.ts src/declarations/swap-factory/index.d.ts src/declarations/swap-factory/swap-factory.did
generate@swap-factory: src/declarations/swap-factory/swap-factory.did.js src/declarations/swap-factory/index.js src/declarations/swap-factory/swap-factory.did.d.ts src/declarations/swap-factory/index.d.ts src/declarations/swap-factory/swap-factory.did

src/declarations/swap-factory/swap-factory.did.js src/declarations/swap-factory/index.js src/declarations/swap-factory/swap-factory.did.d.ts src/declarations/swap-factory/index.d.ts src/declarations/swap-factory/swap-factory.did: .dfx/$(NETWORK)/canisters/swap-factory/swap-factory.wasm .dfx/$(NETWORK)/canisters/swap-factory/swap-factory.did
	dfx generate --no-compile --network $(NETWORK) swap-factory

.PHONY: generate@swap-pool
.PRECIOUS: src/declarations/swap-pool/swap-pool.did.js src/declarations/swap-pool/index.js src/declarations/swap-pool/swap-pool.did.d.ts src/declarations/swap-pool/index.d.ts src/declarations/swap-pool/swap-pool.did
generate@swap-pool: src/declarations/swap-pool/swap-pool.did.js src/declarations/swap-pool/index.js src/declarations/swap-pool/swap-pool.did.d.ts src/declarations/swap-pool/index.d.ts src/declarations/swap-pool/swap-pool.did

src/declarations/swap-pool/swap-pool.did.js src/declarations/swap-pool/index.js src/declarations/swap-pool/swap-pool.did.d.ts src/declarations/swap-pool/index.d.ts src/declarations/swap-pool/swap-pool.did: .dfx/$(NETWORK)/canisters/swap-pool/swap-pool.wasm .dfx/$(NETWORK)/canisters/swap-pool/swap-pool.did
	dfx generate --no-compile --network $(NETWORK) swap-pool

.PHONY: generate@upgrade_example_backend1_v1
.PRECIOUS: src/declarations/upgrade_example_backend1_v1/upgrade_example_backend1_v1.did.js src/declarations/upgrade_example_backend1_v1/index.js src/declarations/upgrade_example_backend1_v1/upgrade_example_backend1_v1.did.d.ts src/declarations/upgrade_example_backend1_v1/index.d.ts src/declarations/upgrade_example_backend1_v1/upgrade_example_backend1_v1.did
generate@upgrade_example_backend1_v1: src/declarations/upgrade_example_backend1_v1/upgrade_example_backend1_v1.did.js src/declarations/upgrade_example_backend1_v1/index.js src/declarations/upgrade_example_backend1_v1/upgrade_example_backend1_v1.did.d.ts src/declarations/upgrade_example_backend1_v1/index.d.ts src/declarations/upgrade_example_backend1_v1/upgrade_example_backend1_v1.did

src/declarations/upgrade_example_backend1_v1/upgrade_example_backend1_v1.did.js src/declarations/upgrade_example_backend1_v1/index.js src/declarations/upgrade_example_backend1_v1/upgrade_example_backend1_v1.did.d.ts src/declarations/upgrade_example_backend1_v1/index.d.ts src/declarations/upgrade_example_backend1_v1/upgrade_example_backend1_v1.did: .dfx/$(NETWORK)/canisters/upgrade_example_backend1_v1/upgrade_example_backend1_v1.wasm .dfx/$(NETWORK)/canisters/upgrade_example_backend1_v1/upgrade_example_backend1_v1.did
	dfx generate --no-compile --network $(NETWORK) upgrade_example_backend1_v1

.PHONY: generate@upgrade_example_backend2_v1
.PRECIOUS: src/declarations/upgrade_example_backend2_v1/upgrade_example_backend2_v1.did.js src/declarations/upgrade_example_backend2_v1/index.js src/declarations/upgrade_example_backend2_v1/upgrade_example_backend2_v1.did.d.ts src/declarations/upgrade_example_backend2_v1/index.d.ts src/declarations/upgrade_example_backend2_v1/upgrade_example_backend2_v1.did
generate@upgrade_example_backend2_v1: src/declarations/upgrade_example_backend2_v1/upgrade_example_backend2_v1.did.js src/declarations/upgrade_example_backend2_v1/index.js src/declarations/upgrade_example_backend2_v1/upgrade_example_backend2_v1.did.d.ts src/declarations/upgrade_example_backend2_v1/index.d.ts src/declarations/upgrade_example_backend2_v1/upgrade_example_backend2_v1.did

src/declarations/upgrade_example_backend2_v1/upgrade_example_backend2_v1.did.js src/declarations/upgrade_example_backend2_v1/index.js src/declarations/upgrade_example_backend2_v1/upgrade_example_backend2_v1.did.d.ts src/declarations/upgrade_example_backend2_v1/index.d.ts src/declarations/upgrade_example_backend2_v1/upgrade_example_backend2_v1.did: .dfx/$(NETWORK)/canisters/upgrade_example_backend2_v1/upgrade_example_backend2_v1.wasm .dfx/$(NETWORK)/canisters/upgrade_example_backend2_v1/upgrade_example_backend2_v1.did
	dfx generate --no-compile --network $(NETWORK) upgrade_example_backend2_v1

.PHONY: generate@upgrade_example_backend2_v2
.PRECIOUS: src/declarations/upgrade_example_backend2_v2/upgrade_example_backend2_v2.did.js src/declarations/upgrade_example_backend2_v2/index.js src/declarations/upgrade_example_backend2_v2/upgrade_example_backend2_v2.did.d.ts src/declarations/upgrade_example_backend2_v2/index.d.ts src/declarations/upgrade_example_backend2_v2/upgrade_example_backend2_v2.did
generate@upgrade_example_backend2_v2: src/declarations/upgrade_example_backend2_v2/upgrade_example_backend2_v2.did.js src/declarations/upgrade_example_backend2_v2/index.js src/declarations/upgrade_example_backend2_v2/upgrade_example_backend2_v2.did.d.ts src/declarations/upgrade_example_backend2_v2/index.d.ts src/declarations/upgrade_example_backend2_v2/upgrade_example_backend2_v2.did

src/declarations/upgrade_example_backend2_v2/upgrade_example_backend2_v2.did.js src/declarations/upgrade_example_backend2_v2/index.js src/declarations/upgrade_example_backend2_v2/upgrade_example_backend2_v2.did.d.ts src/declarations/upgrade_example_backend2_v2/index.d.ts src/declarations/upgrade_example_backend2_v2/upgrade_example_backend2_v2.did: .dfx/$(NETWORK)/canisters/upgrade_example_backend2_v2/upgrade_example_backend2_v2.wasm .dfx/$(NETWORK)/canisters/upgrade_example_backend2_v2/upgrade_example_backend2_v2.did
	dfx generate --no-compile --network $(NETWORK) upgrade_example_backend2_v2

.PHONY: generate@upgrade_example_backend3_v2
.PRECIOUS: src/declarations/upgrade_example_backend3_v2/upgrade_example_backend3_v2.did.js src/declarations/upgrade_example_backend3_v2/index.js src/declarations/upgrade_example_backend3_v2/upgrade_example_backend3_v2.did.d.ts src/declarations/upgrade_example_backend3_v2/index.d.ts src/declarations/upgrade_example_backend3_v2/upgrade_example_backend3_v2.did
generate@upgrade_example_backend3_v2: src/declarations/upgrade_example_backend3_v2/upgrade_example_backend3_v2.did.js src/declarations/upgrade_example_backend3_v2/index.js src/declarations/upgrade_example_backend3_v2/upgrade_example_backend3_v2.did.d.ts src/declarations/upgrade_example_backend3_v2/index.d.ts src/declarations/upgrade_example_backend3_v2/upgrade_example_backend3_v2.did

src/declarations/upgrade_example_backend3_v2/upgrade_example_backend3_v2.did.js src/declarations/upgrade_example_backend3_v2/index.js src/declarations/upgrade_example_backend3_v2/upgrade_example_backend3_v2.did.d.ts src/declarations/upgrade_example_backend3_v2/index.d.ts src/declarations/upgrade_example_backend3_v2/upgrade_example_backend3_v2.did: .dfx/$(NETWORK)/canisters/upgrade_example_backend3_v2/upgrade_example_backend3_v2.wasm .dfx/$(NETWORK)/canisters/upgrade_example_backend3_v2/upgrade_example_backend3_v2.did
	dfx generate --no-compile --network $(NETWORK) upgrade_example_backend3_v2

.PHONY: generate@wallet_backend
.PRECIOUS: src/declarations/wallet_backend/wallet_backend.did.js src/declarations/wallet_backend/index.js src/declarations/wallet_backend/wallet_backend.did.d.ts src/declarations/wallet_backend/index.d.ts src/declarations/wallet_backend/wallet_backend.did
generate@wallet_backend: src/declarations/wallet_backend/wallet_backend.did.js src/declarations/wallet_backend/index.js src/declarations/wallet_backend/wallet_backend.did.d.ts src/declarations/wallet_backend/index.d.ts src/declarations/wallet_backend/wallet_backend.did

src/declarations/wallet_backend/wallet_backend.did.js src/declarations/wallet_backend/index.js src/declarations/wallet_backend/wallet_backend.did.d.ts src/declarations/wallet_backend/index.d.ts src/declarations/wallet_backend/wallet_backend.did: .dfx/$(NETWORK)/canisters/wallet_backend/wallet_backend.wasm .dfx/$(NETWORK)/canisters/wallet_backend/wallet_backend.did
	dfx generate --no-compile --network $(NETWORK) wallet_backend

.PHONY: generate@wallet_frontend
.PRECIOUS: src/declarations/wallet_frontend/wallet_frontend.did.js src/declarations/wallet_frontend/index.js src/declarations/wallet_frontend/wallet_frontend.did.d.ts src/declarations/wallet_frontend/index.d.ts src/declarations/wallet_frontend/wallet_frontend.did
generate@wallet_frontend: src/declarations/wallet_frontend/wallet_frontend.did.js src/declarations/wallet_frontend/index.js src/declarations/wallet_frontend/wallet_frontend.did.d.ts src/declarations/wallet_frontend/index.d.ts src/declarations/wallet_frontend/wallet_frontend.did

src/declarations/wallet_frontend/wallet_frontend.did.js src/declarations/wallet_frontend/index.js src/declarations/wallet_frontend/wallet_frontend.did.d.ts src/declarations/wallet_frontend/index.d.ts src/declarations/wallet_frontend/wallet_frontend.did: .dfx/$(NETWORK)/canisters/wallet_frontend/assetstorage.wasm.gz
	dfx generate --no-compile --network $(NETWORK) wallet_frontend

src/common.mo: 

.dfx/$(NETWORK)/canisters/battery/battery.wasm .dfx/$(NETWORK)/canisters/battery/battery.did: src/common.mo

.dfx/$(NETWORK)/canisters/battery/battery.wasm .dfx/$(NETWORK)/canisters/battery/battery.did: 

.dfx/$(NETWORK)/canisters/battery/battery.wasm .dfx/$(NETWORK)/canisters/battery/battery.did: 

.dfx/$(NETWORK)/canisters/battery/battery.wasm .dfx/$(NETWORK)/canisters/battery/battery.did: 

.dfx/$(NETWORK)/canisters/bootstrapper_data/bootstrapper_data.wasm .dfx/$(NETWORK)/canisters/bootstrapper_data/bootstrapper_data.did: src/lib/Account.mo

.dfx/$(NETWORK)/canisters/battery/battery.wasm .dfx/$(NETWORK)/canisters/battery/battery.did: .dfx/$(NETWORK)/canisters/bootstrapper_data/bootstrapper_data.wasm .dfx/$(NETWORK)/canisters/bootstrapper_data/bootstrapper_data.did

.dfx/$(NETWORK)/canisters/bootstrapper/bootstrapper.wasm .dfx/$(NETWORK)/canisters/bootstrapper/bootstrapper.did: src/common.mo

src/install.mo: src/common.mo

src/install.mo: src/copy_assets.mo

src/install.mo: 

.dfx/$(NETWORK)/canisters/bootstrapper/bootstrapper.wasm .dfx/$(NETWORK)/canisters/bootstrapper/bootstrapper.did: src/install.mo

src/package_manager_backend/battery.mo: src/common.mo

src/package_manager_backend/battery.mo: 

src/package_manager_backend/battery.mo: 

src/package_manager_backend/battery.mo: 

src/package_manager_backend/battery.mo: .dfx/$(NETWORK)/canisters/bootstrapper_data/bootstrapper_data.wasm .dfx/$(NETWORK)/canisters/bootstrapper_data/bootstrapper_data.did

.dfx/$(NETWORK)/canisters/bootstrapper/bootstrapper.wasm .dfx/$(NETWORK)/canisters/bootstrapper/bootstrapper.did: src/package_manager_backend/battery.mo

.dfx/$(NETWORK)/canisters/bootstrapper/bootstrapper.wasm .dfx/$(NETWORK)/canisters/bootstrapper/bootstrapper.did: src/lib/Account.mo

.dfx/$(NETWORK)/canisters/bootstrapper/bootstrapper.wasm .dfx/$(NETWORK)/canisters/bootstrapper/bootstrapper.did: .dfx/$(NETWORK)/canisters/bootstrapper_data/bootstrapper_data.wasm .dfx/$(NETWORK)/canisters/bootstrapper_data/bootstrapper_data.did

.dfx/$(NETWORK)/canisters/bootstrapper/bootstrapper.wasm .dfx/$(NETWORK)/canisters/bootstrapper/bootstrapper.did: 

.dfx/$(NETWORK)/canisters/bootstrapper/bootstrapper.wasm .dfx/$(NETWORK)/canisters/bootstrapper/bootstrapper.did: 

.dfx/$(NETWORK)/canisters/bootstrapper/bootstrapper.wasm .dfx/$(NETWORK)/canisters/bootstrapper/bootstrapper.did: 

.dfx/$(NETWORK)/canisters/repository/repository.wasm .dfx/$(NETWORK)/canisters/repository/repository.did: src/common.mo

.dfx/$(NETWORK)/canisters/bootstrapper/bootstrapper.wasm .dfx/$(NETWORK)/canisters/bootstrapper/bootstrapper.did: .dfx/$(NETWORK)/canisters/repository/repository.wasm .dfx/$(NETWORK)/canisters/repository/repository.did

.dfx/$(NETWORK)/canisters/bootstrapper/bootstrapper.wasm .dfx/$(NETWORK)/canisters/bootstrapper/bootstrapper.did: .dfx/$(NETWORK)/canisters/bookmark/bookmark.wasm .dfx/$(NETWORK)/canisters/bookmark/bookmark.did

.dfx/$(NETWORK)/canisters/bootstrapper_frontend/assetstorage.wasm.gz: .dfx/$(NETWORK)/canisters/bootstrapper/bootstrapper.wasm .dfx/$(NETWORK)/canisters/bootstrapper/bootstrapper.did

.dfx/$(NETWORK)/canisters/bootstrapper_frontend/assetstorage.wasm.gz: .dfx/$(NETWORK)/canisters/bookmark/bookmark.wasm .dfx/$(NETWORK)/canisters/bookmark/bookmark.did

.dfx/$(NETWORK)/canisters/bootstrapper_frontend/assetstorage.wasm.gz: 

.dfx/$(NETWORK)/canisters/bootstrapper_frontend/assetstorage.wasm.gz: .dfx/$(NETWORK)/canisters/repository/repository.wasm .dfx/$(NETWORK)/canisters/repository/repository.did

.dfx/$(NETWORK)/canisters/example_backend/example_backend.wasm .dfx/$(NETWORK)/canisters/example_backend/example_backend.did: 

.dfx/$(NETWORK)/canisters/example_frontend/assetstorage.wasm.gz: .dfx/$(NETWORK)/canisters/example_backend/example_backend.wasm .dfx/$(NETWORK)/canisters/example_backend/example_backend.did

.dfx/$(NETWORK)/canisters/main_indirect/main_indirect.wasm .dfx/$(NETWORK)/canisters/main_indirect/main_indirect.did: src/common.mo

.dfx/$(NETWORK)/canisters/main_indirect/main_indirect.wasm .dfx/$(NETWORK)/canisters/main_indirect/main_indirect.did: src/install.mo

src/package_manager_backend/simple_indirect.mo: src/common.mo

src/package_manager_backend/simple_indirect.mo: 

.dfx/$(NETWORK)/canisters/main_indirect/main_indirect.wasm .dfx/$(NETWORK)/canisters/main_indirect/main_indirect.did: src/package_manager_backend/simple_indirect.mo

.dfx/$(NETWORK)/canisters/main_indirect/main_indirect.wasm .dfx/$(NETWORK)/canisters/main_indirect/main_indirect.did: 

.dfx/$(NETWORK)/canisters/main_indirect/main_indirect.wasm .dfx/$(NETWORK)/canisters/main_indirect/main_indirect.did: src/package_manager_backend/battery.mo

.dfx/$(NETWORK)/canisters/package_manager/package_manager.wasm .dfx/$(NETWORK)/canisters/package_manager/package_manager.did: src/common.mo

src/package_manager_backend/main_indirect.mo: src/common.mo

src/package_manager_backend/main_indirect.mo: src/install.mo

src/package_manager_backend/main_indirect.mo: src/package_manager_backend/simple_indirect.mo

src/package_manager_backend/main_indirect.mo: 

src/package_manager_backend/main_indirect.mo: src/package_manager_backend/battery.mo

.dfx/$(NETWORK)/canisters/package_manager/package_manager.wasm .dfx/$(NETWORK)/canisters/package_manager/package_manager.did: src/package_manager_backend/main_indirect.mo

.dfx/$(NETWORK)/canisters/package_manager/package_manager.wasm .dfx/$(NETWORK)/canisters/package_manager/package_manager.did: src/package_manager_backend/simple_indirect.mo

.dfx/$(NETWORK)/canisters/package_manager/package_manager.wasm .dfx/$(NETWORK)/canisters/package_manager/package_manager.did: 

.dfx/$(NETWORK)/canisters/package_manager/package_manager.wasm .dfx/$(NETWORK)/canisters/package_manager/package_manager.did: src/lib/Account.mo

.dfx/$(NETWORK)/canisters/package_manager/package_manager.wasm .dfx/$(NETWORK)/canisters/package_manager/package_manager.did: src/package_manager_backend/battery.mo

.dfx/$(NETWORK)/canisters/package_manager/package_manager.wasm .dfx/$(NETWORK)/canisters/package_manager/package_manager.did: src/install.mo

.dfx/$(NETWORK)/canisters/package_manager_frontend/assetstorage.wasm.gz: .dfx/$(NETWORK)/canisters/package_manager/package_manager.wasm .dfx/$(NETWORK)/canisters/package_manager/package_manager.did

.dfx/$(NETWORK)/canisters/package_manager_frontend/assetstorage.wasm.gz: 

.dfx/$(NETWORK)/canisters/package_manager_frontend/assetstorage.wasm.gz: .dfx/$(NETWORK)/canisters/bootstrapper/bootstrapper.wasm .dfx/$(NETWORK)/canisters/bootstrapper/bootstrapper.did

.dfx/$(NETWORK)/canisters/package_manager_frontend/assetstorage.wasm.gz: .dfx/$(NETWORK)/canisters/battery/battery.wasm .dfx/$(NETWORK)/canisters/battery/battery.did

.dfx/$(NETWORK)/canisters/simple_indirect/simple_indirect.wasm .dfx/$(NETWORK)/canisters/simple_indirect/simple_indirect.did: src/common.mo

.dfx/$(NETWORK)/canisters/simple_indirect/simple_indirect.wasm .dfx/$(NETWORK)/canisters/simple_indirect/simple_indirect.did: 

.dfx/$(NETWORK)/canisters/upgrade_example_backend1_v1/upgrade_example_backend1_v1.wasm .dfx/$(NETWORK)/canisters/upgrade_example_backend1_v1/upgrade_example_backend1_v1.did: 

.dfx/$(NETWORK)/canisters/upgrade_example_backend2_v1/upgrade_example_backend2_v1.wasm .dfx/$(NETWORK)/canisters/upgrade_example_backend2_v1/upgrade_example_backend2_v1.did: 

.dfx/$(NETWORK)/canisters/upgrade_example_backend2_v2/upgrade_example_backend2_v2.wasm .dfx/$(NETWORK)/canisters/upgrade_example_backend2_v2/upgrade_example_backend2_v2.did: 

.dfx/$(NETWORK)/canisters/upgrade_example_backend3_v2/upgrade_example_backend3_v2.wasm .dfx/$(NETWORK)/canisters/upgrade_example_backend3_v2/upgrade_example_backend3_v2.did: 

.dfx/$(NETWORK)/canisters/wallet_backend/wallet_backend.wasm .dfx/$(NETWORK)/canisters/wallet_backend/wallet_backend.did: src/common.mo

.dfx/$(NETWORK)/canisters/wallet_backend/wallet_backend.wasm .dfx/$(NETWORK)/canisters/wallet_backend/wallet_backend.did: src/lib/Account.mo

.dfx/$(NETWORK)/canisters/wallet_backend/wallet_backend.wasm .dfx/$(NETWORK)/canisters/wallet_backend/wallet_backend.did: 

.dfx/$(NETWORK)/canisters/wallet_backend/wallet_backend.wasm .dfx/$(NETWORK)/canisters/wallet_backend/wallet_backend.did: 

.dfx/$(NETWORK)/canisters/wallet_backend/wallet_backend.wasm .dfx/$(NETWORK)/canisters/wallet_backend/wallet_backend.did: 

src/bootstrapper_backend/BootstrapperData.mo: src/lib/Account.mo

.dfx/$(NETWORK)/canisters/wallet_backend/wallet_backend.wasm .dfx/$(NETWORK)/canisters/wallet_backend/wallet_backend.did: src/bootstrapper_backend/BootstrapperData.mo

.dfx/$(NETWORK)/canisters/wallet_frontend/assetstorage.wasm.gz: .dfx/$(NETWORK)/canisters/wallet_backend/wallet_backend.wasm .dfx/$(NETWORK)/canisters/wallet_backend/wallet_backend.did

.PHONY: deploy-self@battery
deploy-self@battery: .dfx/$(NETWORK)/canisters/battery/battery.wasm .dfx/$(NETWORK)/canisters/battery/battery.did
	dfx deploy --no-compile --network $(NETWORK) $(DEPLOY_FLAGS) $(DEPLOY_FLAGS.battery) battery



.PHONY: deploy@battery
deploy@battery: deploy-self@battery

.PHONY: deploy-self@bookmark
deploy-self@bookmark: .dfx/$(NETWORK)/canisters/bookmark/bookmark.wasm .dfx/$(NETWORK)/canisters/bookmark/bookmark.did
	dfx deploy --no-compile --network $(NETWORK) $(DEPLOY_FLAGS) $(DEPLOY_FLAGS.bookmark) bookmark



.PHONY: deploy@bookmark
deploy@bookmark: deploy@bootstrapper deploy-self@bookmark

.PHONY: deploy-self@bootstrapper
deploy-self@bootstrapper: .dfx/$(NETWORK)/canisters/bootstrapper/bootstrapper.wasm .dfx/$(NETWORK)/canisters/bootstrapper/bootstrapper.did
	dfx deploy --no-compile --network $(NETWORK) $(DEPLOY_FLAGS) $(DEPLOY_FLAGS.bootstrapper) bootstrapper



.PHONY: deploy@bootstrapper
deploy@bootstrapper: deploy@nns-ledger deploy@cycles_ledger deploy@nns-cycles-minting deploy@bootstrapper_data deploy@repository deploy-self@bootstrapper

.PHONY: deploy-self@bootstrapper_data
deploy-self@bootstrapper_data: .dfx/$(NETWORK)/canisters/bootstrapper_data/bootstrapper_data.wasm .dfx/$(NETWORK)/canisters/bootstrapper_data/bootstrapper_data.did
	dfx deploy --no-compile --network $(NETWORK) $(DEPLOY_FLAGS) $(DEPLOY_FLAGS.bootstrapper_data) bootstrapper_data



.PHONY: deploy@bootstrapper_data
deploy@bootstrapper_data: deploy-self@bootstrapper_data

.PHONY: deploy-self@bootstrapper_frontend
deploy-self@bootstrapper_frontend: .dfx/$(NETWORK)/canisters/bootstrapper_frontend/assetstorage.wasm.gz
	dfx deploy --no-compile --network $(NETWORK) $(DEPLOY_FLAGS) $(DEPLOY_FLAGS.bootstrapper_frontend) bootstrapper_frontend



.dfx/$(NETWORK)/canisters/bootstrapper_frontend/assetstorage.wasm.gz: generate@bootstrapper generate@bookmark generate@internet_identity generate@repository

.PHONY: deploy@bootstrapper_frontend
deploy@bootstrapper_frontend: deploy@bootstrapper deploy@bookmark deploy@internet_identity deploy@repository deploy-self@bootstrapper_frontend

.PHONY: deploy-self@cycles_ledger
deploy-self@cycles_ledger: .dfx/$(NETWORK)/canisters/cycles_ledger/cycles_ledger.wasm.gz .dfx/$(NETWORK)/canisters/cycles_ledger/cycles_ledger.did

.PHONY: deploy@cycles_ledger
deploy@cycles_ledger: deploy-self@cycles_ledger

.PHONY: deploy-self@example_backend
deploy-self@example_backend: .dfx/$(NETWORK)/canisters/example_backend/example_backend.wasm .dfx/$(NETWORK)/canisters/example_backend/example_backend.did
	dfx deploy --no-compile --network $(NETWORK) $(DEPLOY_FLAGS) $(DEPLOY_FLAGS.example_backend) example_backend



.PHONY: deploy@example_backend
deploy@example_backend: deploy-self@example_backend

.PHONY: deploy-self@example_frontend
deploy-self@example_frontend: .dfx/$(NETWORK)/canisters/example_frontend/assetstorage.wasm.gz
	dfx deploy --no-compile --network $(NETWORK) $(DEPLOY_FLAGS) $(DEPLOY_FLAGS.example_frontend) example_frontend



.dfx/$(NETWORK)/canisters/example_frontend/assetstorage.wasm.gz: generate@example_backend

.PHONY: deploy@example_frontend
deploy@example_frontend: deploy@example_backend deploy-self@example_frontend

.PHONY: deploy-self@exchange-rate
deploy-self@exchange-rate: .dfx/$(NETWORK)/canisters/exchange-rate/exchange-rate.wasm.gz .dfx/$(NETWORK)/canisters/exchange-rate/exchange-rate.did

.PHONY: deploy@exchange-rate
deploy@exchange-rate: deploy-self@exchange-rate

.PHONY: deploy-self@internet_identity
deploy-self@internet_identity: .dfx/$(NETWORK)/canisters/internet_identity/internet_identity.wasm.gz .dfx/$(NETWORK)/canisters/internet_identity/internet_identity.did

.PHONY: deploy@internet_identity
deploy@internet_identity: deploy-self@internet_identity

.PHONY: deploy-self@main_indirect
deploy-self@main_indirect: .dfx/$(NETWORK)/canisters/main_indirect/main_indirect.wasm .dfx/$(NETWORK)/canisters/main_indirect/main_indirect.did
	dfx deploy --no-compile --network $(NETWORK) $(DEPLOY_FLAGS) $(DEPLOY_FLAGS.main_indirect) main_indirect



.PHONY: deploy@main_indirect
deploy@main_indirect: deploy@bootstrapper deploy@nns-ledger deploy@nns-cycles-minting deploy-self@main_indirect

.PHONY: deploy-self@multiassets
deploy-self@multiassets: .dfx/$(NETWORK)/canisters/multiassets/multiassets.wasm .dfx/$(NETWORK)/canisters/multiassets/multiassets.did
	dfx deploy --no-compile --network $(NETWORK) $(DEPLOY_FLAGS) $(DEPLOY_FLAGS.multiassets) multiassets



.PHONY: deploy@multiassets
deploy@multiassets: deploy-self@multiassets

.PHONY: deploy-self@nns-cycles-minting
deploy-self@nns-cycles-minting: .dfx/$(NETWORK)/canisters/nns-cycles-minting/nns-cycles-minting.wasm .dfx/$(NETWORK)/canisters/nns-cycles-minting/nns-cycles-minting.did

.PHONY: deploy@nns-cycles-minting
deploy@nns-cycles-minting: deploy-self@nns-cycles-minting

.PHONY: deploy-self@nns-genesis-token
deploy-self@nns-genesis-token: .dfx/$(NETWORK)/canisters/nns-genesis-token/nns-genesis-token.wasm .dfx/$(NETWORK)/canisters/nns-genesis-token/nns-genesis-token.did

.PHONY: deploy@nns-genesis-token
deploy@nns-genesis-token: deploy-self@nns-genesis-token

.PHONY: deploy-self@nns-governance
deploy-self@nns-governance: .dfx/$(NETWORK)/canisters/nns-governance/nns-governance.wasm .dfx/$(NETWORK)/canisters/nns-governance/nns-governance.did

.PHONY: deploy@nns-governance
deploy@nns-governance: deploy-self@nns-governance

.PHONY: deploy-self@nns-ledger
deploy-self@nns-ledger: .dfx/$(NETWORK)/canisters/nns-ledger/nns-ledger.wasm .dfx/$(NETWORK)/canisters/nns-ledger/nns-ledger.did

.PHONY: deploy@nns-ledger
deploy@nns-ledger: deploy-self@nns-ledger

.PHONY: deploy-self@nns-lifeline
deploy-self@nns-lifeline: .dfx/$(NETWORK)/canisters/nns-lifeline/nns-lifeline.wasm .dfx/$(NETWORK)/canisters/nns-lifeline/nns-lifeline.did

.PHONY: deploy@nns-lifeline
deploy@nns-lifeline: deploy-self@nns-lifeline

.PHONY: deploy-self@nns-registry
deploy-self@nns-registry: .dfx/$(NETWORK)/canisters/nns-registry/nns-registry.wasm .dfx/$(NETWORK)/canisters/nns-registry/nns-registry.did

.PHONY: deploy@nns-registry
deploy@nns-registry: deploy-self@nns-registry

.PHONY: deploy-self@nns-root
deploy-self@nns-root: .dfx/$(NETWORK)/canisters/nns-root/nns-root.wasm .dfx/$(NETWORK)/canisters/nns-root/nns-root.did

.PHONY: deploy@nns-root
deploy@nns-root: deploy-self@nns-root

.PHONY: deploy-self@nns-sns-wasm
deploy-self@nns-sns-wasm: .dfx/$(NETWORK)/canisters/nns-sns-wasm/nns-sns-wasm.wasm .dfx/$(NETWORK)/canisters/nns-sns-wasm/nns-sns-wasm.did

.PHONY: deploy@nns-sns-wasm
deploy@nns-sns-wasm: deploy-self@nns-sns-wasm

.PHONY: deploy-self@package_manager
deploy-self@package_manager: .dfx/$(NETWORK)/canisters/package_manager/package_manager.wasm .dfx/$(NETWORK)/canisters/package_manager/package_manager.did
	dfx deploy --no-compile --network $(NETWORK) $(DEPLOY_FLAGS) $(DEPLOY_FLAGS.package_manager) package_manager



.PHONY: deploy@package_manager
deploy@package_manager: deploy@nns-ledger deploy@cycles_ledger deploy-self@package_manager

.PHONY: deploy-self@package_manager_frontend
deploy-self@package_manager_frontend: .dfx/$(NETWORK)/canisters/package_manager_frontend/assetstorage.wasm.gz
	dfx deploy --no-compile --network $(NETWORK) $(DEPLOY_FLAGS) $(DEPLOY_FLAGS.package_manager_frontend) package_manager_frontend



.dfx/$(NETWORK)/canisters/package_manager_frontend/assetstorage.wasm.gz: generate@package_manager generate@internet_identity generate@bootstrapper generate@battery

.PHONY: deploy@package_manager_frontend
deploy@package_manager_frontend: deploy@package_manager deploy@internet_identity deploy@bootstrapper deploy@battery deploy-self@package_manager_frontend

.PHONY: deploy-self@repository
deploy-self@repository: .dfx/$(NETWORK)/canisters/repository/repository.wasm .dfx/$(NETWORK)/canisters/repository/repository.did
	dfx deploy --no-compile --network $(NETWORK) $(DEPLOY_FLAGS) $(DEPLOY_FLAGS.repository) repository



.PHONY: deploy@repository
deploy@repository: deploy-self@repository

.PHONY: deploy-self@simple_indirect
deploy-self@simple_indirect: .dfx/$(NETWORK)/canisters/simple_indirect/simple_indirect.wasm .dfx/$(NETWORK)/canisters/simple_indirect/simple_indirect.did
	dfx deploy --no-compile --network $(NETWORK) $(DEPLOY_FLAGS) $(DEPLOY_FLAGS.simple_indirect) simple_indirect



.PHONY: deploy@simple_indirect
deploy@simple_indirect: deploy-self@simple_indirect

.PHONY: deploy-self@swap-factory
deploy-self@swap-factory: .dfx/$(NETWORK)/canisters/swap-factory/swap-factory.wasm .dfx/$(NETWORK)/canisters/swap-factory/swap-factory.did

.PHONY: deploy@swap-factory
deploy@swap-factory: deploy-self@swap-factory

.PHONY: deploy-self@swap-pool
deploy-self@swap-pool: .dfx/$(NETWORK)/canisters/swap-pool/swap-pool.wasm .dfx/$(NETWORK)/canisters/swap-pool/swap-pool.did

.PHONY: deploy@swap-pool
deploy@swap-pool: deploy-self@swap-pool

.PHONY: deploy-self@upgrade_example_backend1_v1
deploy-self@upgrade_example_backend1_v1: .dfx/$(NETWORK)/canisters/upgrade_example_backend1_v1/upgrade_example_backend1_v1.wasm .dfx/$(NETWORK)/canisters/upgrade_example_backend1_v1/upgrade_example_backend1_v1.did
	dfx deploy --no-compile --network $(NETWORK) $(DEPLOY_FLAGS) $(DEPLOY_FLAGS.upgrade_example_backend1_v1) upgrade_example_backend1_v1



.PHONY: deploy@upgrade_example_backend1_v1
deploy@upgrade_example_backend1_v1: deploy-self@upgrade_example_backend1_v1

.PHONY: deploy-self@upgrade_example_backend2_v1
deploy-self@upgrade_example_backend2_v1: .dfx/$(NETWORK)/canisters/upgrade_example_backend2_v1/upgrade_example_backend2_v1.wasm .dfx/$(NETWORK)/canisters/upgrade_example_backend2_v1/upgrade_example_backend2_v1.did
	dfx deploy --no-compile --network $(NETWORK) $(DEPLOY_FLAGS) $(DEPLOY_FLAGS.upgrade_example_backend2_v1) upgrade_example_backend2_v1



.PHONY: deploy@upgrade_example_backend2_v1
deploy@upgrade_example_backend2_v1: deploy-self@upgrade_example_backend2_v1

.PHONY: deploy-self@upgrade_example_backend2_v2
deploy-self@upgrade_example_backend2_v2: .dfx/$(NETWORK)/canisters/upgrade_example_backend2_v2/upgrade_example_backend2_v2.wasm .dfx/$(NETWORK)/canisters/upgrade_example_backend2_v2/upgrade_example_backend2_v2.did
	dfx deploy --no-compile --network $(NETWORK) $(DEPLOY_FLAGS) $(DEPLOY_FLAGS.upgrade_example_backend2_v2) upgrade_example_backend2_v2



.PHONY: deploy@upgrade_example_backend2_v2
deploy@upgrade_example_backend2_v2: deploy-self@upgrade_example_backend2_v2

.PHONY: deploy-self@upgrade_example_backend3_v2
deploy-self@upgrade_example_backend3_v2: .dfx/$(NETWORK)/canisters/upgrade_example_backend3_v2/upgrade_example_backend3_v2.wasm .dfx/$(NETWORK)/canisters/upgrade_example_backend3_v2/upgrade_example_backend3_v2.did
	dfx deploy --no-compile --network $(NETWORK) $(DEPLOY_FLAGS) $(DEPLOY_FLAGS.upgrade_example_backend3_v2) upgrade_example_backend3_v2



.PHONY: deploy@upgrade_example_backend3_v2
deploy@upgrade_example_backend3_v2: deploy-self@upgrade_example_backend3_v2

.PHONY: deploy-self@wallet_backend
deploy-self@wallet_backend: .dfx/$(NETWORK)/canisters/wallet_backend/wallet_backend.wasm .dfx/$(NETWORK)/canisters/wallet_backend/wallet_backend.did
	dfx deploy --no-compile --network $(NETWORK) $(DEPLOY_FLAGS) $(DEPLOY_FLAGS.wallet_backend) wallet_backend



.PHONY: deploy@wallet_backend
deploy@wallet_backend: deploy@nns-ledger deploy@exchange-rate deploy-self@wallet_backend

.PHONY: deploy-self@wallet_frontend
deploy-self@wallet_frontend: .dfx/$(NETWORK)/canisters/wallet_frontend/assetstorage.wasm.gz
	dfx deploy --no-compile --network $(NETWORK) $(DEPLOY_FLAGS) $(DEPLOY_FLAGS.wallet_frontend) wallet_frontend



.dfx/$(NETWORK)/canisters/wallet_frontend/assetstorage.wasm.gz: generate@wallet_backend

.PHONY: deploy@wallet_frontend
deploy@wallet_frontend: deploy@wallet_backend deploy-self@wallet_frontend