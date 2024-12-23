Remaining things TODO:

- Call `installModule` from Motoko not frontend (gas of one-way function is not counted towards the caller,
  so it won't overflow 30B limit).

- https://forum.dfinity.org/t/env-variables-for-motoko-builds/11640/8

- Use remaining dev's cycles to store URLs of PMs.

- TODO: Should `backend` be a controller or an owner? Shouldn't we lay aside it for `simpleIndirectCaller`?

- TODO: future compaitibility in package format.

- FIXME: Ensure that clicking finishing install of a half-installing package doesn't interfere with its ongoing installation.
  (It to be done by checking in writing a result that it has not been not yet written.)

- Remove `initialIndirect` (remain only `simpleIndirect`) as controller.

- `inspect` incoming calls.

- Resist to drain cycles attack.

- Should user be a controller?

- Disallow packages of zero modules.

- Backing/restoring state of packages.

- Bootstrapping from several repos.

- Paid soft.

- Instead of showing zero versions for an non-existent package, show a dialog "No such package."

- Reconcile different naming schemes: `indirect_caller` but `RepositoryIndex`.

- Bootstrappers of packages (devs) could forbid more than one bootstrap to limit their gas loss and store principals.

- Wait curtains.

- Extract bootstrapping code from IndirectCaller to a separate canister.

- When user adds a new repository canister, check that it is an index canister.

- Bootstrapping the PM together with any other package(s).

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

- Security policy:

```
WARN: This project does not define a security policy for some assets.
WARN: You should define a security policy in .ic-assets.json5. For example:
WARN: [
WARN:   {
WARN:     "match": "**/*",
WARN:     "security_policy": "standard"
WARN:   }
WARN: ]
WARN: Assets without any security policy: all
WARN: To disable the policy warning, define "disable_security_policy_warning": true in .ic-assets.json5.
```