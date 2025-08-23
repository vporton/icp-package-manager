Remaining things TODO

- FIXME@P1 Use a template parameter to pass Wasm values.

- FIXME@P1 "wallet (3 ICP)" should be "wallet (3 TCycles)"

- TODO@P3 Pay back to all users with a minted token.

- TODO@P3 Change the owner of PM and wallet.

- TODO@P2 [Migrate](https://internetcomputer.org/docs/motoko/base-core-migration) from `base` to `core`.

- TODO@P2 Remove wrong (valid only for the bootstrapper frontend) value of `user` from initialization/upgrade code for modules in the package manager.

- TODO@P2 Withdraw cycles when uninstalling a package.

- TODO@P3 Fiat payments: https://github.com/Expeera/IC-PayPortal/tree/phase-3

- FIXME@P3 After logout/login on `/choose-upgrade/*`, we have "Upgrade package" button disabled. [FIXED: Added `agent` to useEffect dependency array and authentication check to upgrade button]

- TODO@P3 (For saving gas) does it make sense to check module hash before upgrading it?

- TODO@P3 Addresses for sending/receiving Bitcoin and Ethereum in wallet.

- TODO@P3 Make the "reload" button rotating, while reloading.

- TODO@P3 Opt-in Swetrix events in the PM.

- TODO@P3 Affiliate program.

- TODO@P3 Chunked canister installation.

- TODO@P3 Command line utility to upgrade `icpack` after failed upgrade.

- TODO@P3 When upgrading `icpack`, warn user not to close the window!

- TODO@P3 Reload the site after upgrade of `icpack`?

- TODO@P3 When topping up bootstrapper with ICP, 0.0001 remains.

- TODO@P3 Automatically retrieve the name of the added repo.

- TODO@P3: `inspect`.

- TODO@P3 Option to install additional software after bootstrapping.

- TODO@P3 Deployment to mainnet required to copy several `.did` files manually and run `make deploy-work` several times.

- TODO@P3 Display canisters' principals somewhere.

- TODO@P3 Don't call `ic.update_settings` several times per module.

- TODO@P3 "Stop checked processes" should re-load the page or at least the list of processes.

- TODO@P3 I stupidly used `useEffect`, where `useMemo` would suffice.

- TODO@P3 Close button in the title does not close dialogs.

- TODO@P3 Interface for asking the battery for more cycles (if the user accepts). Use for example, for `icpack`.

- TODO@P3 Use choosen "Default version" on the mainpage.

- TODO@P3 When running two upgrade operations of the same package in nearly the same time,
  it tries to `stop_canister` for an already deleted canister. That may be a more serious symptom.

- TODO@P3 Support upgrade from a different repo.

- TODO@P3 Prevent upgrading package to the same version as installed?

- TODO@P3 Battery canister should not supply cycles to itself.

- TODO@P3 The payment popup may not fit browser window. The menu is broken on mobile.

- TODO@P3 Withdraw cycles. When withdrawing cycles, update `battery.activatedCycles`.

- TODO@P3 Apparently, I will use `simple_indirect` to delete a canister.
  Then `simple_indirect` receives its cycles and cycles need to be transferred to `battery`.

- TODO@P3 Add/delete a package one-by-one in addition to `setFullPackageInfo`.

- TODO@P3 On clicking Upgrade button, ask the user whether really wants to upgrade.

- TODO@P3 Update some packages automatically (every day).

- TODO@P3 Can we install additional packages not waiting till full bootstrapping of the PM?

- TODO@P3 It should say "Install additonal copy" of the package when installing an already installed package.

- TODO@P3 Test real package with zero modules.

- TODO@P3 Events WG: https://forum.dfinity.org/t/technical-working-group-inter-canister-event-utility-working-group/29048/41

- TODO@P3 Show dependencies/suggests/recommends in app store.

- TODO@P3 Ability to bootstrap backend without frontend (for AI agents and other API users).

- TODO@P3 Prevent using Tab key to circumvent “busy” overlay.

- TODO@P3 A button to copy repository's principal.

- TODO@P3 `inspect` incoming calls. To avoid DoS attacks, limit max package description to 30KB.

- TODO@P3 Resist to drain cycles attack.

- TODO@P3 Disallow packages of zero modules.

- TODO@P3 Backing/restoring state of packages.

- TODO@P3 tECDSA for unlocking paid soft.

- TODO@P3 When user adds a new repository canister, check that it is an index canister.

- TODO@P3 Prevent browser window to close during bootstrap.

- TODO@P3 Keep a log of **finished** operations. Especially useful to check whether upgrade completed.

- TODO@P3 When logged out while showing installing packages, should message that cannot show.
  Likewise for mainpage,

- TODO@P3 Error handling in frontend.

- TODO@P3 Optionally, create user's repository and copy there installed packages.

- TODO@P3 Managing package repositories.

- TODO@P3 "no such frontend or key expired" - show this message to the user.

- TODO@P3 A special DAO.

- TODO@P3 Package's and/or user's option to stop all canisters of a package before upgrading.

- TODO@P3 "Add distro" at distro's site.

- TODO@P3 Autocomplete package name for installation.

- TODO@P3 Events (similar to permissions?)

- TODO@P3 Package manager (and probably some other packages) should be non-removable.

- TODO@P3 `!` in TypeScript.

- TODO@P3 Option to re-use a canister for another package (should require non-safe confirmation from both
  user and package).

- TODO@P3 Statistics of use.

- TODO@P3 Security policy

- TODO@P3 Should `getOwners` method be available only to owners?

- TODO@P3 Partner with https://launchdarkly.com (app feature management platform).

- TODO@P3 https://thoropass.com/guide/compliance-guide-soc-2-for-your-startup/
  SOC 2 defines criteria for managing customer data based on five “trust service principles”—security, availability, processing integrity, confidentiality and privacy.

- TODO@P2 Replace some `Principal`s by actor types?

- TODO@P3 Handing names of user's repositories.

- TODO@P3 "Buy ICP" (affiliate) link in the UI.

- TODO@P3 Wallet: Use settings.

- TODO@P3 Wallet: View payments history.

- TODO@P3 Wallet & other: QR codes for payments.

- TODO@P3 Wallet: Update Balances button.
