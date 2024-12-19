// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import "./Dependencies/Ownable.sol";
import "./Interfaces/IPriceFeed.sol";
import "./DIAOracleV2.sol";
import {IPriceOracleGetter} from './Interfaces/IPriceOracleGetter.sol';

/// @title PriceFeed
/// @author Meridian Finance
/// @notice Proxy smart contract to get the price of an asset from a price source, with DIA oracle
///         smart contracts as primary option
/// - If the returned price by DIA is <= 0, or price is older than maxPriceAgeLimit the call is forwarded to a fallbackOracle
/// - Owned by the OmniDex governance system, allowed to add keys for assets, replace them,
///   change master oracle and change the fallbackOracle
contract PriceFeed is Ownable {
  // using SafeERC20 for IERC20;

  event BaseCurrencySet(address indexed baseCurrency, uint256 baseCurrencyUnit);
  event AssetKeyUpdated(address indexed asset, string indexed key);
  event FallbackOracleUpdated(address indexed fallbackOracle);
  event DIAOracleUpdated(address indexed diaOracleAddress);
  event EthAddressUpdated(address asset);

  mapping(address => string) private assetsKeys;
  address wEthAddress;
  IPriceOracleGetter private _fallbackOracle;
  address public immutable BASE_CURRENCY;
 
  uint256 public immutable BASE_CURRENCY_UNIT;
  uint256 public immutable CONVERSION_FACTOR = 10000000000;

  uint256 maxPriceAgeLimit;  
  DIAOracleV2 DIA;


  /// @notice Constructor
  /// @param DIAOracleAddress The address of the master oracle to use
  /// @param fallbackOracle The address of the fallback oracle to use if the data of an
  /// aggregator is not consistent
  /// @param baseCurrency the base currency used for the price quotes. If USD is used, base currency is 0x0
  /// @param baseCurrencyUnit the unit of the base currency
  /// @param priceAgeLimit the max permitted age of oracle price before call is forwarded to fallback oracle
 
  constructor(
    address DIAOracleAddress,
    address fallbackOracle,
    address baseCurrency,
    uint256 baseCurrencyUnit,
    uint256 priceAgeLimit
  )  {
    _setDIAOracle(DIAOracleAddress);
    _setFallbackOracle(fallbackOracle);
    maxPriceAgeLimit = priceAgeLimit;
    BASE_CURRENCY = baseCurrency;
    BASE_CURRENCY_UNIT = baseCurrencyUnit;
    emit BaseCurrencySet(baseCurrency, baseCurrencyUnit);
  }

// --- configuration functions ---

  /// @notice External function called to set or replace DIA keys for assets. 
  /// @param asset The address of the asset to be set
  /// @param key The DIA keys/symbol of the source of each asset
  function setAssetKey(address asset, string calldata key) external onlyOwner {
    require((asset != address(0) && bytes(key).length != 0), 'Invalid parameters');
      assetsKeys[asset] = key;
      emit AssetKeyUpdated(asset, key);
  }

    function setwEthAddress(address asset) external onlyOwner {
    require((asset != address(0)), 'Invalid parameters');
      wEthAddress = asset;
      emit EthAddressUpdated(asset);
  }

  /// @notice Sets the MasterOracle
  /// @param diaOracleAddress The address of the MasterOracle
  function setDIAOracle(address diaOracleAddress) external onlyOwner {
    _setDIAOracle(diaOracleAddress);
  }

  /// @notice Sets the fallbackOracle
  /// @param fallbackOracle The address of the fallbackOracle
  function setFallbackOracle(address fallbackOracle) external onlyOwner {
    _setFallbackOracle(fallbackOracle);
  }

  /// @notice Sets the max age that an oracle price can be before fallback oracle is called
  /// @param AgeLimit max age in seconds of latest price
  function setMaxPriceAgeLimit(uint256 AgeLimit) external onlyOwner {
    maxPriceAgeLimit = AgeLimit;
  }

// --- Internal Functions --- 

  /// @notice Internal function to set the MasterOracle
  /// @param diaOracleAddress The address of the MasterOracle
  function _setDIAOracle(address diaOracleAddress) internal {    
    DIA = DIAOracleV2(diaOracleAddress);
    emit DIAOracleUpdated(diaOracleAddress);
  }

  /// @notice Internal function to set the fallbackOracle
  /// @param fallbackOracle The address of the fallbackOracle
  function _setFallbackOracle(address fallbackOracle) internal {
    _fallbackOracle = IPriceOracleGetter(fallbackOracle);
    emit FallbackOracleUpdated(fallbackOracle);
  }


// --- Getter Functions ---

  function fetchPrice() external view returns (uint256) {
    address asset = wEthAddress;
    string memory key = assetsKeys[asset];

    if (asset == BASE_CURRENCY) {
      return BASE_CURRENCY_UNIT;
    } else if (bytes(key).length == 0) {    
      return _fallbackOracle.getAssetPrice(asset);
    } else {
      (uint128 price, uint128 timeStamp) = DIA.getValue(key);      
      if (price > 0 && (block.timestamp - timeStamp) < maxPriceAgeLimit) {
        return uint256(price) * CONVERSION_FACTOR;
      } else {
        return _fallbackOracle.getAssetPrice(asset);
      }
    }
  }

  // Gets the DIA key for an asset address.
  // asset The address of the asset
  /// @return The DIA key string
  function getSourceOfAsset(address asset) external view returns (string memory) {
    return string(assetsKeys[asset]);
  }

  /// @notice Gets the address of the master oracle
  /// @return address The addres of the DIA oracle
  function getMasterOracle() external view returns (address) {
    return address(DIA);
  }

  /// @notice Gets the address of the fallback oracle
  /// @return address The addres of the fallback oracle
  function getFallbackOracle() external view returns (address) {
    return address(_fallbackOracle);
  }

  /// @notice Gets the maximum age that the oracle price can be before the call is routed to fallback
  /// @return the max age in seconds
  function getMaxPriceAgeLimit() external view returns (uint256) {
    return maxPriceAgeLimit;
  }
}