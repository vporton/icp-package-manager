#!/usr/bin/make -f

SHELL=/bin/bash

NETWORK = local
export MOPS_ENV = $(NETWORK)
USER = $(shell dfx identity get-principal)
# DEPLOY_FLAGS.bookmark = --argument "rec { bootstrapper = \"$$()\""; }"
DEPLOY_FLAGS.bootstrapper_data = --argument "principal \"$(USER)\""

.PHONY: deploy
deploy:

# Don't use dfx.json dependency, because package_manager is not to be installed.
# example_frontend is used here to deploy an asset canister.
build@bootstrapper_frontend: generate@example_frontend generate@package_manager generate@main_indirect generate@simple_indirect generate@bookmark generate@battery generate@bootstrapper

include deps.$(NETWORK).mk

.PHONY: deps
deps:
	dfx rules --network $(NETWORK) -o deps.$(NETWORK).mk

# INIT_BLOB = $(shell echo 'encode(record {})' | ic-repl-linux64)
INIT_BLOB = blob "\44\49\44\4c\01\6c\00\01\00"

.PHONY: deploy
deploy: deploy@bootstrapper_frontend deploy-self@package_manager_frontend deploy@example_frontend \
	generate@example_frontend generate@package_manager_frontend deploy-backend

.PHONY: deploy-backend
deploy-backend: deploy@repository deploy@bookmark generate@battery \
  deploy@internet_identity init

.PHONY: init
init:
	-dfx ledger fabricate-cycles --t 2000000 --canister repository
	-dfx canister call repository init "()"
	-dfx canister call bootstrapper_data setOwner "(principal \"`dfx canister id bootstrapper`\")"

.PHONY: deploy-test
deploy-test: deploy \
  deploy@upgrade_example_backend1_v1 deploy@upgrade_example_backend2_v1 \
  deploy@upgrade_example_backend2_v2 deploy@upgrade_example_backend3_v2
	npx tsx scripts/prepare-test.ts

deploy-self@cycles_ledger:
	dfx deploy --no-compile --network $(NETWORK) $(DEPLOY_FLAGS) $(DEPLOY_FLAGS.cycles_ledger) \
	  --argument "( record { \
		name = \"Internet Computer\"; \
		symbol = \"ICP\"; \
		decimals = 6; \
		fee = 100_000_000; \
		max_supply = 1_000_000_000_000_000_000; \
		initial_balances = vec { \
			record { \
				record { \
					owner = principal \"$(USER)\"; \
					subaccount = null; \
				}; \
				1_000_000_000 \
			} \
		}; \
		min_burn_amount = 10_000; \
		minting_account = opt record { owner = principal \"$(USER)\"; subaccount = null }; \
		advanced_settings = null; \
	  })" \
	  cycles_ledger

deploy-self@bookmark: build@bookmark deploy@bootstrapper
	dfx deploy --no-compile --network $(NETWORK) $(DEPLOY_FLAGS) $(DEPLOY_FLAGS.bookmark) \
	  --argument "principal \"$(USER)\"" \
	  bookmark
	-dfx canister call bookmark init "record { bootstrapper = principal \"`dfx canister id bootstrapper`\" }"

.PHONY: docs
docs: docs/out/md/icpack docs/out/html/icpack docs/out/index.html docs/out/internet-computer-icp-logo.svg \
	docs/out/sources/prepare-test.ts.html

.PHONY: deploy-docs
deploy-docs: docs
	cleanup() { \
	  test "$$TMPDIR" != '' && rm -rf "$$TMPDIR"; \
	} && \
	trap "cleanup" EXIT && \
	TMPDIR=`mktemp -d` && \
	(cd $$TMPDIR && git clone git@github.com:vporton/icpack-docs.git) && \
	cp -a docs/out/* $$TMPDIR/icpack-docs/ && \
	cd $$TMPDIR/icpack-docs/ && git add -A && git commit -m "Update docs" && git push

docs/out/%: docs/src/%
	cp -f $< $@

.PHONY: docs/out/md/icpack
docs/out/md/icpack:
	rm -rf $@
	`dfx cache show`/mo-doc --source src --output $@ --format plain

.PHONY: docs/out/html/icpack
docs/out/html/icpack:
	rm -rf $@
	`dfx cache show`/mo-doc --source src --output $@ --format html

docs/out/sources/prepare-test.ts.html: scripts/prepare-test.ts
	mkdir -p docs/out/sources
	pygmentize -O full -o $@ $<

build@example_frontend: generate@example_backend