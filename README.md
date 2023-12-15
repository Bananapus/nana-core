# juice-contracts-v4

https://github.com/bananapus/juice-contracts-v4

Juicebox is a flexible toolkit for launching and managing a treasury-backed token on Ethereum and L2s.

To learn more about the protocol, visit the [Juicebox Docs](https://docs.juicebox.money/).

## Develop

`juice-contracts-v4` uses the [Foundry](https://github.com/foundry-rs/foundry) development toolchain for builds, tests, and deployments. To get set up, install [Foundry](https://github.com/foundry-rs/foundry):

```bash
curl -L https://foundry.paradigm.xyz | sh
```

You can download and install dependencies with:

```bash
forge install
```

If you run into trouble with `forge install`, try using `git submodule update --init --recursive` to ensure that nested submodules have been properly initialized.

Some useful commands:

| Command               | Description                                         |
| --------------------- | --------------------------------------------------- |
| `forge install`       | Install the dependencies.                           |
| `forge build`         | Compile the contracts and write artifacts to `out`. |
| `forge fmt`           | Lint.                                               |
| `forge test`          | Run the tests.                                      |
| `forge build --sizes` | Get contract sizes.                                 |
| `forge coverage`      | Generate a test coverage report.                    |
| `foundryup`           | Update foundry. Run this periodically.              |
| `forge clean`         | Remove the build artifacts and cache directories.   |

To learn more, visit the [Foundry Book](https://book.getfoundry.sh/) docs.

We recommend using [Juan Blanco's solidity extension](https://marketplace.visualstudio.com/items?itemName=JuanBlanco.solidity) for VSCode.

## Utilities

For convenience, several utility commands are available in `util.sh`. To see a list, run:

```bash
`bash util.sh --help`.
```

Or make the script executable and run:

```bash
./util.sh --help
```
