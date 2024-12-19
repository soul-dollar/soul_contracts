// SPDX-License-Identifier: agpl-3.0

pragma solidity 0.8.20;

/**
 * @title IPriceOracleGetter interface
 * @notice Interface for the Meridian price oracle.
 **/

interface IPriceOracleGetter {
  /**
   * @dev returns the asset price USD
   * @param asset the address of the asset
   * @return the price of the asset
   **/
  function getAssetPrice(address asset) external view returns (uint256);
}