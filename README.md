# Bananapus Core

This repository contains the core protocol contracts for Bananapus' Juicebox v4. Juicebox is a flexible toolkit for launching and managing a treasury-backed token on Ethereum and L2s.

To learn more about the protocol, visit the [Juicebox Docs](https://docs.juicebox.money/). If you have questions, reach out on [Discord](https://discord.com/invite/ErQYmth4dS).

## Install

For `npm` projects (recommended):

```bash
npm install @bananapus/core
```

For `forge` projects (not recommended):

```bash
forge install Bananapus/nana-core
```

Add `@bananapus/core/=lib/nana-core/` to `remappings.txt`. You'll also need to install `nana-core`'s dependencies and add similar remappings for them.

## Develop

`nana-core` uses [npm](https://www.npmjs.com/) for package management and the [Foundry](https://github.com/foundry-rs/foundry) development toolchain for builds, tests, and deployments. To get set up, [install Node.js](https://nodejs.org/en/download) and install [Foundry](https://github.com/foundry-rs/foundry):

```bash
curl -L https://foundry.paradigm.xyz | sh
```

You can download and install dependencies with:

```bash
npm install && forge install
```

If you run into trouble with `forge install`, try using `git submodule update --init --recursive` to ensure that nested submodules have been properly initialized.

Some useful commands:

| Command               | Description                                         |
| --------------------- | --------------------------------------------------- |
| `forge build`         | Compile the contracts and write artifacts to `out`. |
| `forge fmt`           | Lint.                                               |
| `forge test`          | Run the tests.                                      |
| `forge build --sizes` | Get contract sizes.                                 |
| `forge coverage`      | Generate a test coverage report.                    |
| `foundryup`           | Update foundry. Run this periodically.              |
| `forge clean`         | Remove the build artifacts and cache directories.   |

To learn more, visit the [Foundry Book](https://book.getfoundry.sh/) docs.

## Scripts

For convenience, several utility commands are available in `package.json`.

| Command                           | Description                            |
| --------------------------------- | -------------------------------------- |
| `npm test`                        | Run local tests.                       |
| `npm run test:fork`               | Run fork tests (for use in CI).        |
| `npm run coverage:lcov`           | Generate an LCOV test coverage report. |
| `npm run deploy:ethereum-mainnet` | Deploy to Ethereum mainnet             |
| `npm run deploy:ethereum-sepolia` | Deploy to Ethereum Sepolia testnet     |
| `npm run deploy:optimism-mainnet` | Deploy to Optimism mainnet             |
| `npm run deploy:optimism-testnet` | Deploy to Optimism testnet             |
| `npm run deploy:polygon-mainnet`  | Deploy to Polygon mainnet              |
| `npm run deploy:polygon-mumbai`   | Deploy to Polygon Mumbai testnet       |
