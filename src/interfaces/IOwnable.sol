// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.10;

interface IOwnable {
    function acceptOwnership() external;
    function owner() external view returns (address);
    function pendingOwner() external view returns (address);
    function transferOwnership(address newOwner) external;
}
