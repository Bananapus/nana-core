# JBTerminalConfig
[Git Source](https://github.com/Bananapus/nana-core/blob/2998dca2fbd2658e2c8791d6dc8348147d69e28e/src/structs/JBTerminalConfig.sol)

**Notes:**
- member: terminal The terminal to configure.

- member: accountingContextsToAccept The accounting contexts to accept from the terminal.


```solidity
struct JBTerminalConfig {
    IJBTerminal terminal;
    JBAccountingContext[] accountingContextsToAccept;
}
```

