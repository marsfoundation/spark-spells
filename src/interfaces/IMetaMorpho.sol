// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.10;

struct MarketParams {
    address loanToken;
    address collateralToken;
    address oracle;
    address irm;
    uint256 lltv;
}

struct MarketConfig {
    uint184 cap;
    bool    enabled;
    uint64  removableAt;
}

struct PendingUint192 {
    uint192 value;
    uint64  validAt;
}

interface IMetaMorpho {
    function config(bytes32) external view returns (MarketConfig memory);
    function submitCap(MarketParams memory marketParams, uint256 newSupplyCap) external;
    function acceptCap(MarketParams memory marketParams) external;
    function pendingCap(bytes32) external view returns (PendingUint192 memory);
    function timelock() external view returns (uint256);
}
