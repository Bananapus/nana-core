# JBPermissionsData
[Git Source](https://github.com/Bananapus/nana-core/blob/2998dca2fbd2658e2c8791d6dc8348147d69e28e/src/structs/JBPermissionsData.sol)

**Notes:**
- member: operator The address that permissions are being given to.

- member: projectId The ID of the project the operator is being given permissions for. Operators only have
permissions under this project's scope. An ID of 0 is a wildcard, which gives an operator permissions across all
projects.

- member: permissionIds The IDs of the permissions being given. See the `JBPermissionIds` library.


```solidity
struct JBPermissionsData {
    address operator;
    uint64 projectId;
    uint8[] permissionIds;
}
```

