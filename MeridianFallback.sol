// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.6.11;
pragma experimental ABIEncoderV2;

import {SafeMath} from './Dependencies/SafeMath.sol';
import "./Dependencies/Ownable.sol";
import {IPriceOracleGetter} from './Interfaces/IPriceOracleGetter.sol';

contract MeridianFallbackOracle1 is Ownable, IPriceOracleGetter {
  using SafeMath for uint256;

  struct Price {
    uint64 blockNumber;
    uint64 blockTimestamp;
    uint128 price;
  }

  event PricesSubmitted(address sybil, address[] assets, uint128[] prices);
  event SybilAuthorized(address indexed sybil);
  event SybilUnauthorized(address indexed sybil);

  uint256 public constant PERCENTAGE_BASE = 1e4;

  mapping(address => Price) private _prices;

  mapping(address => bool) private _sybils;

  modifier onlySybil {
    _requireWhitelistedSybil(msg.sender);
    _;
  }

  function authorizeSybil(address sybil) external onlyOwner {
    _sybils[sybil] = true;

    emit SybilAuthorized(sybil);
  }

  function unauthorizeSybil(address sybil) external onlyOwner {
    _sybils[sybil] = false;

    emit SybilUnauthorized(sybil);
  }

  function submitPrices(address[] calldata assets, uint128[] calldata prices) external onlySybil {
    require(assets.length == prices.length, 'INCONSISTENT_PARAMS_LENGTH');
    for (uint256 i = 0; i < assets.length; i++) {
      _prices[assets[i]] = Price(uint64(block.number), uint64(block.timestamp), prices[i]);
    }

    emit PricesSubmitted(msg.sender, assets, prices);
  }

  function getAssetPrice(address asset) external view override returns (uint256) {
    return uint256(_prices[asset].price);
  }

  function isSybilWhitelisted(address sybil) public view returns (bool) {
    return _sybils[sybil];
  }


  function _requireWhitelistedSybil(address sybil) internal view {
    require(isSybilWhitelisted(sybil), 'INVALID_SYBIL');
  }
}