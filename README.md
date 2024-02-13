# Juicebox v4

Juicebox is a flexible toolkit for launching and managing a treasury-backed token on Ethereum and L2s.

To learn more about the protocol, visit the [Juicebox Docs](https://docs.juicebox.money/). If you have questions, reach out on [Discord](https://discord.com/invite/ErQYmth4dS).

## Develop

`juice-contracts-v4` uses [npm](https://www.npmjs.com/) for package management and the [Foundry](https://github.com/foundry-rs/foundry) development toolchain for builds, tests, and deployments. To get set up, [install Node.js](https://nodejs.org/en/download) and install [Foundry](https://github.com/foundry-rs/foundry):

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

## Utilities

For convenience, several utility commands are available in `util.sh`. To see a list, run:

```bash
`bash util.sh --help`.
```

Or make the script executable and run:

```bash
./util.sh --help
```
