Remaining things TODO:

- Battery canister should not supply cycles to itself.

- The payment popup may not fit browser window. The menu is broken on mobile.

- Withdraw cycles. When withdrawing cycles, update `battery.activatedCycles`.

- Replace `stableheapbtreemap` by OrderedMap or OrderedSet from `base` library.

- Replace unstable HashMap (and Trie?) by stable OrderedMap.

- FIXME: Apparently, I will use `simple_indirect` to delete a canister.
  Then `simple_indirect` receives its cycles and cycles need to be transferred to `battery`.

- When deleting a module, withdraw its cycles.

- Add/delete a package one-by-one in addition to `setFullPackageInfo`.

- Meta descriptions for packages.

- On clicking Upgrade button, ask the user whether really wants to upgrade.

- Store WASM blobs together with packages, for them to be effectively deleted, when a package version is deleted.
  Use SHA-256 to identify blobs.  

- Update some packages automatically (every day).

- casing of identifiers: https://forum.dfinity.org/t/what-is-the-advised-naming-scheme-for-canisters/41023/2

- Can we install additional packages not waiting till full bootstrapping of the PM?

- It should say "Install additonal copy" of the package when installing an already installed package.

- `HashMap<..., ()>` -> `Set<...>`.

- Test real module with zero modules.

- If the user has several PMs installed, order their order.

- https://forum.dfinity.org/t/env-variables-for-motoko-builds/11640/8

- Use remaining dev's cycles to store URLs of PMs.

- FIXME: If I login after changing the page between `/` and `/installed` and then reload, then login status is wrong.  

- FIXME: rejecting (i.e. throw) does 'not' rollback state changes done before, while trapping (e.g. Debug.trap, assert…, out of cycle conditions) does.

- Events WG: https://forum.dfinity.org/t/technical-working-group-inter-canister-event-utility-working-group/29048/41

- TODO: future compaitibility in package format.

- Ability to bootstrap backend without frontend (for AI agents and other API users).

- Prevent using Tab key to circumvent “busy” overlay.

- A button to copy repository's principal.

- FIXME: Ensure that clicking finishing install of a half-installing package doesn't interfere with its ongoing installation.
  (It to be done by checking in writing a result that it has not been not yet written.)

- Remove `indirectCaller` (remain only `simpleIndirect`) as controller.

- Should we use 32-bytes hash as the ID of WASM value instead of number?

- `inspect` incoming calls. To avoid DoS attacks, limit max package description to 30KB.

- Resist to drain cycles attack.

- Should user be a controller?

- Disallow packages of zero modules.

- Backing/restoring state of packages.

- Paid soft.

- Reconcile different naming schemes: `main_indirect` but `Repository`.

- Bootstrappers of packages (devs) could forbid more than one bootstrap to limit their gas loss and store principals.

- Wait curtains.

- For initializing a package, add `packageInit` function (not sure in backend or main_indirect).
  that could be used to init dependencies from dependent packages (because they may be not yet initialized).

- When user adds a new repository canister, check that it is an index canister.

- Prevent browser window to close during bootstrap.

- `Cycles.add<system>(...)` & `ignore Cycles.accept<system>(...)` - consider each case individually. Also spread cycles.

- Show the hash of installed package and refuse installation/upgrade, when doesn't match.

- Keep a log of **finished** operations. Especially useful to check whether upgrade completed.

- use the CMC’s `notify_create_canister`.

- When logged out while showing installing packages, should message that cannot show.
  Likewise for mainpage,

- Error handling in frontend.

- Optionally, create user's repository and copy there installed packages.

- Use https://github.com/dfinity/cycles-ledger (or directly CMC?) instead of `IC.create_canister`.

- Managing package repositories.

- "no such frontend or key expired" - show this message to the user.

- Upgrading.

- UI:
    - Scanning package dependencies in the UI.

- A special DAO.

  - Every package should have owner(s) to specify who is able to change it.

- https://dashboard.internetcomputer.org/sns/l7ra6-uqaaa-aaaaq-aadea-cai

- Package's and/or user's option to stop all canisters of a package before upgrading.

- "Add distro" at distro's site.

- Autocomplete package name for installation.

- Events (similar to permissions?)

- Should we automatically uninstall "orphaned" packages (installed only to support another package)?

- Store in installed package info also its `Repository`?

- Package manager (and probably some other packages) should be non-removable.

- `!` in TypeScript.

- Option to re-use a canister for another package (should require non-safe confirmation from both
  user and package).

- Statistics of use.

- `FIXME`/`TODO` in the sources.

- Security policy

- Should `getOwners` method be available only to owners?

- Enhanced orthogonal persistence.

- With new 64-bit memory model no need for CanDB.

- Partner with https://launchdarkly.com (app feature management platform).

- https://thoropass.com/guide/compliance-guide-soc-2-for-your-startup/
  SOC 2 defines criteria for managing customer data based on five “trust service principles”—security, availability, processing integrity, confidentiality and privacy.