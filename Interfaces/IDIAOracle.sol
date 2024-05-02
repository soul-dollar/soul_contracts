// SPDX-License-Identifier: MIT

pragma solidity 0.6.11;


interface IDIAOracle {
    function getValue(string memory key) external view returns (uint128, uint128);
}