# Bananapus Core

This repository contains the core protocol contracts for Bananapus' Juicebox v4. Juicebox is a flexible toolkit for launching and managing a treasury-backed token on Ethereum and L2s.

### Basics

Projects are represented by a 721 NFT (`src/JBProjects.sol`) owned by some address. Each project has a controller (`src/interfaces/IJBController.sol`) that is responsible for interactions with the project’s tokens (`src/JBTokens.sol`), splits (`src/JBSplits.sol`), and rulesets (`src/JBRulesets.sol`), and any number of payment terminals (`src/interfaces/IJBTerminal.sol`) to accept payments and give access to funds through. A project’s controller and terminals can be found through the directory (`src/JBDirectory.sol`).

A well-known and trusted controller, multi terminal, directory, project contract, token contract, split contract, and ruleset contract will be deployed by JuiceboxDAO (`script/Deploy.s.sol`) for projects to use, but project owners can always bring their own. 

Get a project's current terminals using `directory.terminalsOf(…)` (`src/JBDirectory.sol`), it's primary terminal for given inbound token using `directory.primaryTerminalOf(…)` (`src/JBDirectory.sol`), and its controller using `directory.controllerOf(…)` (`src/JBDirectory.sol`).

Learn how everything fits together by launching a new project using `controller.launchProjectFor(…)` (`src/JBController.sol`). 

Next, try paying a project using `terminal.pay(…)` (`src/JBMultiTerminal.sol`) using a payment terminal specified when launching the project. 

Next, distribute scheduled payouts from the project using `terminal.distributePayoutsOf(…)` (`src/JBMultiTerminal.sol`), use the project’s surplus if you’re the owner using `terminal.useSurplusAllowanceOf(…)` (`src/JBMultiTerminal.sol`), or redeem the project’s tokens for access to treasury funds using `terminal.redeemTokensOf(…)` (`src/JBMultiTerminal`). The specifics of how funds can be accessed in both cases depends on the rulesets and fund access constraints specified when launching the project.

If reserved tokens have accumulated as payments have come in, distribute them to the prespecified recipients using `controller.sendReservedTokensToSplitsOf(…)` (`src/JBController.sol`).

If you, the project’s owner, wish to queue a new ruleset to take effect after the current one, use `controller.queueRulesetsOf(…)` (`src/JBController.sol`).

### Multi Terminal

The multi terminal (`src/JBMultiTerminal.sol`) allows projects to receive and store native tokens and any ERC-20 a project wishes to mint its tokens with and keep exposure to.

### Hooks

A project can attach a data hook (`src/interfaces/IJBRulesetDataHook.sol`) address to its rulesets. The data hook can specify custom contract code that runs when the project gets paid (`src/interfaces/IJBPayHook.sol`) or when the project’s tokens are redeemed (`src/interfaces/IJBRedeemHook.sol`).

A project can also schedule payouts to split hooks (`src/interfaces/IJBSplitHook.sol`) alongside splits to addresses and/or other Juicebox projects.

When a project queues new rulesets, its manifestation depends on an optional approval hook (`src/interfaces/IJBRulesetApprovalHook.sol`) of the preceding ruleset. This can be used to prevent scheduled rule changes unless certain conditions are met. 
 
### Rulesets

A project has one active ruleset at a time, and can queue any number of rulesets to become active over time. Each project's rulesets are stored in `JBRulesets` (`src/JBRulesetStore.sol`), which also handles their timing and scheduling.

### Tokens

By default, each project uses a simple internal accounting mechanism to manage token issuance and redemptions. At any time, project's can optionally deploy an ERC-20 (`src/JBERC20.sol`) for it's community of holders to claim in place of the default internal token, which can then be used across ERC20 compatible ecosystems. 

### Permissions

Addresses can give other operator addresses permissions to manage certain ecosystem actions on their behalf.

### Prices

It is possible for a project to accept and store ETH, but issue its $TOKENs relative to USD (i.e. 1,000 $TOKENs issued per 1 USD worth of ETH paid). If a project is managing it's accounting in terms of a certain currency but accepting and storing a token with a different currency, the `src/JBPrices.sol` contract is used to normalize the prices to maintain consistent accounting.

### Splits

A project may manage payouts and reserved token distributions to groups of addresses, other projects, and split hooks. These references are stored in `src/JBSplits.sol` to allow access to various groups of splits across various rulesets over time.

### Fund Access Limits

A project may give itself access to accumulated funds from its treasury either for scheduled payouts or discretionary surplus spending. The limits of its access are stored in `src/JBFundAccessLimits.sol`.


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
npm ci && forge install
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

In order to be able to run deployment scripts you have to install the npm `devDependencies`, to do this run `npm install`.

 For convenience, several utility commands are available in `package.json`.

| Command                           | Description                            |
| --------------------------------- | -------------------------------------- |
| `npm test`                        | Run local tests.                       |
| `npm run test:fork`               | Run fork tests (for use in CI).        |
| `npm run coverage`                | Generate an LCOV test coverage report. |
| `npm run deploy:ethereum-mainnet` | Deploy to Ethereum mainnet             |
| `npm run deploy:ethereum-sepolia` | Deploy to Ethereum Sepolia testnet     |
| `npm run deploy:optimism-mainnet` | Deploy to Optimism mainnet             |
| `npm run deploy:optimism-testnet` | Deploy to Optimism testnet             |
| `npm run deploy:polygon-mainnet`  | Deploy to Polygon mainnet              |
| `npm run deploy:polygon-mumbai`   | Deploy to Polygon Mumbai testnet       |

## Tips

To view test coverage, run `npm run coverage` to generate an LCOV test report. You can use an extension like [Coverage Gutters](https://marketplace.visualstudio.com/items?itemName=ryanluker.vscode-coverage-gutters) to view coverage in your editor.

If you're using Nomic Foundation's [Solidity](https://marketplace.visualstudio.com/items?itemName=NomicFoundation.hardhat-solidity) extension in VSCode, you may run into LSP errors because the extension cannot find dependencies outside of `lib`. You can often fix this by running:

```bash
forge remappings >> remappings.txt
```

This makes the extension aware of default remappings.
