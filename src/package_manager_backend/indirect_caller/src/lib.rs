extern crate ic_cdk;
extern crate ic_cdk_macros;
use std::{future::{ready, Future}, sync::OnceLock};
use futures::future::FutureExt;
use ic_cdk_macros::{init, update};
use ic_cdk::{api::call::call_raw, export::candid::{CandidType, Deserialize, Principal}, spawn};
use serde::Serialize;

#[derive(CandidType, Deserialize)]
struct State {
    owner: Principal,
}

static STATE: OnceLock<State> = OnceLock::new();

#[init]
fn init(owner: Principal) {
    STATE.set(State {owner});
}

/// We check owner, for only owner to be able to control Asset canisters
fn onlyOwner() -> bool {
    if let Some(state) = STATE.get() {
        ic_cdk::api::caller() == state.owner
    } else {
        false
    }
}

#[derive(CandidType, Deserialize)]
struct Call {
    canister: Principal,
    name: String,
    data: Vec<u8>, // TODO: Optimize.
}

/// Call methods in the given order and don't return.
///
/// If a method is missing, stop.
// #[update(guard = onlyOwner)] // FIXME
#[update]
fn callAll(methods: Vec<Call>) {
    spawn(async {
        for method in methods {
            call_raw(method.canister, &method.name, &method.data, 0).await;
        }
    });
}

/// Call methods in the given order and don't return.
///
/// If a method is missing, keep calling other methods.
#[update(guard = onlyOwner)]
fn callIgnoringMissing(methods: [Call]): () {
    for (method in methods.vals()) {
        try {
            ignore IC::call(method.canister, method.name, method.data).await;
        }
        catch (e) {
            if (Error.code(e) != #call_error {err_code = 302}) { // CanisterMethodNotFound
                throw e; // Other error cause interruption.
            }
        }
    };
};
