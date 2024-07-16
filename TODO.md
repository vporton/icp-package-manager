Remaining things to do:

- Use https://github.com/dfinity/cycles-ledger instead of `IC.create_canister`.

- Managing package repositories.

- Deinstallation, upgrading.

- UI:
    - Showing installed packages.
    - Managing installation and deinstallation.
    - Showing half-installed packages, managing repair/removal of them.
    - Scanning package dependencies in the UI.

- A special DAO.

- Every package should have owner(s) to specify who is able to change it.

- Package's and/or user's option to stop all canisters of a package before upgrading.

- Specify if package has a frontend canister (or several ones?) to show them
  in the package manager.

- "Add distro" at distro's site.

- Autocomplete package name for installation.

- Events (similar to permissions?)

- Should we automatically uninstall "orphaned" packages (installed only to support another package)?

- Store in installed package info also its `RepositoryIndex`?

- Package manager (and probably some other packages) should be non-removable.

- `!` is TypeScript.

- `FIXME`/`TODO` in the sources.