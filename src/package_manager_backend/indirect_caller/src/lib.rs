extern crate ic_cdk;
extern crate ic_cdk_macros;
use std::sync::OnceLock;
use ic_cdk_macros::{init, update};
use ic_cdk::{api::call::{call_raw, RejectionCode}, export::candid::{CandidType, Deserialize, Principal}, spawn};

#[derive(CandidType, Deserialize)]
struct State {
    owner: Principal,
}

static STATE: OnceLock<State> = OnceLock::new();

#[init]
fn canister_init(owner: Principal) {
    let _ = STATE.set(State {owner});
}

/// We check owner, for only owner to be able to control Asset canisters
fn only_owner() -> Result<(), String> {
    let state = STATE.get().unwrap();
    if ic_cdk::api::caller() != state.owner {
        return Err("not the owner".to_string());
    }
    Ok(())
}

#[derive(CandidType, Deserialize)]
struct Call {
    canister: Principal,
    name: String,
    data: Vec<u8>,
}

/// Call methods in the given order and don't return.
///
/// If a method is missing, stop.
#[update(guard = only_owner)]
fn callAll(methods: Vec<Call>) {
    spawn(async {
        for method in methods {
            if let Err(_) = call_raw(method.canister, &method.name, &method.data, 0).await {
                return;
            }
        }
    });
}

/// Call methods in the given order and don't return.
///
/// If a method is missing, keep calling other methods.
#[update(guard = only_owner)]
fn callIgnoringMissing(methods: Vec<Call>) {
    spawn(async {
        for method in methods {
            if let Err((code, _string)) = call_raw(method.canister, &method.name, &method.data, 0).await {
                if code != RejectionCode::DestinationInvalid { // CanisterMethodNotFound // FIXME: Is it correct error? https://github.com/dfinity/cdk-rs/issues/506
                    return;
                }
            }
        }
    });
}
