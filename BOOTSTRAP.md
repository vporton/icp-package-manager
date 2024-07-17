# Installation of the package manager itself (bootstrapping)

This file describes installation of the package manager itself, aka bootstrapping.

- From the frontend using Cycles Ledger canister install backend and UI (to the same subnet).

- Call `init()` with frontend principal as an argument.

- `init` will execute fake package installation of `package-manager` package.

- `init` will set owner to user's principal.

- If caller is different from owner, redirect from PM to distro page, where the user
  can confirm installation by automatic (not requiring more user's actions) changing of the
  principal.