// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { DataTypes } from 'aave-v3-core/contracts/protocol/libraries/types/DataTypes.sol';

interface IDaiJugInterestRateStrategy {
    function vat() external view returns (address);
    function jug() external view returns (address);
    function ilk() external view returns (bytes32);
    function baseRateConversion() external view returns (uint256);
    function borrowSpread() external view returns (uint256);
    function supplySpread() external view returns (uint256);
    function maxRate() external view returns (uint256);
    function performanceBonus() external view returns (uint256);
    function recompute() external;
    function getBaseRate() external view returns (uint256);
    function calculateInterestRates(DataTypes.CalculateInterestRatesParams memory params)
        external
        view
        returns (
            uint256 supplyRate,
            uint256 stableBorrowRate,
            uint256 variableBorrowRate
        );
}
