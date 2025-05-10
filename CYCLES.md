This bug is mentioned in [TODO](TODO.md):

TODO@P3: The below is a rough draft. If unsure, consult the source code.

> After putting about 13.1T cycles to the bootstrapper (using the blue cycles widget)
> and starting bootstrap, there was "IC0504: Error from Canister cxtct-7iaaa-aaaad-aammq-cai: Canister cxtct-7iaaa-aaaad-aammq-cai is out of cycles" error, also about 0.6T cycles were spent.
> `cxtct-7iaaa-aaaad-aammq-cai` is the bootstrapper canister.

To help fix that bug and possible similar bugs, I will explain how cycle transfers work in my app:

* On the mainnet, cycles are initially put into the user's subaccount of `bootstrapper` canister.
  When starting bootstrapping by `bootstrapFrontend()`, they are transferred to the null subaccount,
  to be used by calls.

* On local, I store cycles in the null subaccount of the `bootstrapper`.

Futher cycles are copied to modules of the `icpack` package, especially the `battery` module of this
package is funded by all remaining cycles.