# ICP Package Manager

ICP Package Manager is an analogue of Linux package managers, but for ICP. It allows to install the code of provided packages (in the future they will be provided by DAOs akin Linux distros) into a user's "own" subnet, giving the user sovereignity over his software and greater execution speed thanks to interoperating software installed in the same subnet.

[**IC Pack**](https://docs.package-manager.com) is an apps package manager (like Google Play), but for remote apps. It redefines SaaS.

Internet users (and future AI agents) lost control over their apps in cloud era due to SaaS. An app may be up-priced, hacked, blocked, undesirably updated, gone bankrupt. Apps installed with my package manager cannot be removed or updated without user's consent - While the user pays for hardware, the app works.

Another reason, why this is good to developers, is that it frees the developer from the need to do any DevOps: The developer just creates a repository and an installation link.

IC Pack will also provide a standard for "events" and "permissions" between apps.

I have also shipped the first useful app for IC Pack - Payments Wallet. Payments Wallet is distinguished by configurable threshold of payments requiring extra user's confirmation, to protect the user from erroneous accidental payments. Payments Wallet will also provide in-app payments for IC Pack. The wallet has Invest tab, allowing users to invest into IC Pack. This wallet is superior over other ICP wallets by installing it into a user's canister, hindering the wallet provider (e.g. a dev or a DAO) from cheating (e.g. stealing user's funds) by substituting wallet's canisters content. For the wallet the following features are not yet finished: Bitcoin, Ethereum, and Solana payments, displaying a QR code. In-app payments are not standardized, yet.

In a future version, I will give the user option for an app to do in-app payments up to a certain amount without asking user.

Here is feature comparison of IC Pack with other ways to install apps:

[Feature comparison with other ways to install apps.](https://docs.package-manager.com/features-comparison/)

Unlike Google Play we support installing apps from multiple repositories. (It is anticipated that every developer creates their own repository.) There is provided a bootstrapper of the package manager that helps to install the package manager and partially installed package manager to finish its own installation. There is a simple API for installing package manager together with a third-party app, so app authors will advertise our package manager together with their apps.

By a sophisticated way of programming, the canisters of the package manager are well-protected against non-returning-function DoS attack. By a sophisticated way of programming, during bootstrapping partly installed package manager installs itself.

We are going to make money charging 10% of paid apps prices (paid apps and paid app updates have been implemented), 5% of hardware costs and 3% of in-app payments.

Economic breakdown: An average SaaS company (our potential customer) has revenue $15M/year (we expect to take like 5% of such a customer's revenue) and there are 17K SaaS companies in the US only.
For more information on this project [see here](https://dev.package-manager.com) and [here](https://docs.package-manager.com).

See [`TODO.md`](TODO.md) about yet unimplemented features.

[Read here](https://chatgpt.com/s/cd_684b24efcc20819190b4b7ddf9df132d) about this codebase.

## Howto guides to running it

I strongly recommend to use [patched](https://github.com/dfinity/sdk/pull/4083) DFX for compiling this faster.

If you didn't run it yet, run `dfx extension install nns`.

`make deploy-work` for deploying the UI.

`make deploy-test && npm test` for automatic tests.

To build a particular canister and its dependencies, issue `make build@CANISTER`; to deploy a canister and its dependencies, `make deploy@CANISTER`; to deploy without dependencies, `make deploy-self@CANISTER`. To generate interface, `make generate@CANISTER`.

You can run the included crypto wallet (a draft project, for now use it just for testing) with commands:
```sh
make deploy@wallet_backend generate@wallet_backend
(cd src/wallet_frontend/ && npx vite build)
```

Installing the wallet as a package is not yet supported, because I have certain troubles with cryptography,
that will be used to confirm that nobody can steal your user wallet.

### General instructions

To get started, you might want to explore the project directory structure and the default configuration file. Working with this project in your development environment will not affect any production deployment or identity tokens.

To learn more before you start working with ICP Package Manager, see the following documentation available online:

- [Quick Start](https://internetcomputer.org/docs/current/developer-docs/setup/deploy-locally)
- [SDK Developer Tools](https://internetcomputer.org/docs/current/developer-docs/setup/install)
- [Motoko Programming Language Guide](https://internetcomputer.org/docs/current/motoko/main/motoko)
- [Motoko Language Quick Reference](https://internetcomputer.org/docs/current/motoko/main/language-manual)

If you want to start working on your project right away, you might want to try the following commands:

```bash
cd icp-package-manager/
dfx help
dfx canister --help
```

### Note on frontend environment variables

If you are hosting frontend code somewhere without using DFX, you may need to make one of the following adjustments to ensure your project does not fetch the root key in production:

- set`DFX_NETWORK` to `ic` if you are using Webpack
- use your own preferred method to replace `process.env.DFX_NETWORK` in the autogenerated declarations
  - Setting `canisters -> {asset_canister_id} -> declarations -> env_override to a string` in `dfx.json` will replace `process.env.DFX_NETWORK` with the string in the autogenerated declarations
- Write your own `createActor` constructor
