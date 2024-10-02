Remaining things to do:

- FIXME: It shows `icpack` as partially installed after bootstrapping.

- Use remaining dev's cycles to store URLs of PMs.

- FIXME: It doesn't show `icpack` in Installed Packages after bootstrapping.

- FIXME: ic0.app vs icp0.io

- FIXME: How to decide which modules to install/remove, if the module list in package description changes?

- FIXME: future compaitibility in package format.

- FIXME: Deploy not only WASM but also metadata.

- FIXME: Check that `getPackage` and similar methods don't hang us.

- Prevent browser window to close during bootstrap.

- `Cycles.add<system>(...)` & `ignore Cycles.accept<system>(...)` - consider each case individually. Also spread cycles.

- Show the hash of installed package and refuse installation/upgrade, when doesn't match.

- Keep a log of **finished** operations. Especially useful to check whether upgrade completed.

- use the CMC’s `notify_create_canister`.

- https://www.npmjs.com/package/@dfinity/assets to upload assets.

- Gzip modules.

- Error handling in frontend.

- Bootstrapping package manager partly done (depends on installing frontend canisters).

- Use https://github.com/dfinity/cycles-ledger (or directly CMC?) instead of `IC.create_canister`.

- Installation of frontend canisters with assets.
  - Specify if package has a frontend canister (or several ones?) to show them
    in the package manager.

- Managing package repositories.

- FIXME: The current implementation of uninstallation will bug, if the package description
  moves to a different CanDB partition.

- Upgrading.
  - It's unclear how to do upgrading: The number of modules in a package may change.

- UI:
    - Scanning package dependencies in the UI.

- A special DAO.

- Every package should have owner(s) to specify who is able to change it.

- Package's and/or user's option to stop all canisters of a package before upgrading.

- "Add distro" at distro's site.

- Autocomplete package name for installation.

- Events (similar to permissions?)

- Should we automatically uninstall "orphaned" packages (installed only to support another package)?

- Store in installed package info also its `RepositoryIndex`?

- Package manager (and probably some other packages) should be non-removable.

- `!` in TypeScript.

- Option to re-use a canister for another package (should require non-safe confirmation from both
  user and package).

- Statistics of use.

- `FIXME`/`TODO` in the sources.