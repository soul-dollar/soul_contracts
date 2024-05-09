// SPDX-License-Identifier: MIT

pragma solidity 0.6.11;

import './Interfaces/IActivePool.sol';
import './Interfaces/ICollSurplusPool.sol';
import './Interfaces/ILQTYStaking.sol';
import './Interfaces/IDefaultPool.sol';
import './Interfaces/IStabilityPool.sol';
import "./Dependencies/SafeMath.sol";
import "./Dependencies/Ownable.sol";
import "./Dependencies/CheckContract.sol";
import "./Dependencies/console.sol";
import "./Dependencies/IERC20.sol";

/*
 * The Active Pool holds the ETH collateral and LUSD debt (but not LUSD tokens) for all active troves.
 *
 * When a trove is liquidated, it's ETH and LUSD debt are transferred from the Active Pool, to either the
 * Stability Pool, the Default Pool, or both, depending on the liquidation conditions.
 *
 */
contract ActivePool is Ownable, CheckContract, IActivePool {
    using SafeMath for uint256;

    string constant public NAME = "ActivePool";

    IERC20 public WETH;

    address public collSurplusPoolAddress;
    address public lqtyStakingAddress;
    address public borrowerOperationsAddress;
    address public troveManagerAddress;
    address public stabilityPoolAddress;
    address public defaultPoolAddress;
    uint256 internal ETH;  // deposited ether tracker
    uint256 internal LUSDDebt;
    bool public isInitialized;

    // --- Events ---

    event BorrowerOperationsAddressChanged(address _newBorrowerOperationsAddress);
    event TroveManagerAddressChanged(address _newTroveManagerAddress);
    event ActivePoolLUSDDebtUpdated(uint _LUSDDebt);
    event ActivePoolETHBalanceUpdated(uint _ETH);

    // --- Contract setters ---

    function initialize(address _weth) external onlyOwner {
        require(!isInitialized, "Already Initialized");
        checkContract(_weth);
        isInitialized = true;
        WETH = IERC20(_weth);
    }

    function setAddresses(
        address _collSurplusPoolAddress,
        address _lqtyStakingAddress,
        address _borrowerOperationsAddress,
        address _troveManagerAddress,
        address _stabilityPoolAddress,
        address _defaultPoolAddress
    )
        external
        onlyOwner
    {
        checkContract(_collSurplusPoolAddress);
        checkContract(_lqtyStakingAddress);
        checkContract(_borrowerOperationsAddress);
        checkContract(_troveManagerAddress);
        checkContract(_stabilityPoolAddress);
        checkContract(_defaultPoolAddress);

        collSurplusPoolAddress = _collSurplusPoolAddress;
        lqtyStakingAddress = _lqtyStakingAddress;
        borrowerOperationsAddress = _borrowerOperationsAddress;
        troveManagerAddress = _troveManagerAddress;
        stabilityPoolAddress = _stabilityPoolAddress;
        defaultPoolAddress = _defaultPoolAddress;

        emit BorrowerOperationsAddressChanged(_borrowerOperationsAddress);
        emit TroveManagerAddressChanged(_troveManagerAddress);
        emit StabilityPoolAddressChanged(_stabilityPoolAddress);
        emit DefaultPoolAddressChanged(_defaultPoolAddress);

        _renounceOwnership();
    }

    // --- Getters for public variables. Required by IPool interface ---

    /*
    * Returns the ETH state variable.
    *
    *Not necessarily equal to the the contract's raw ETH balance - ether can be forcibly sent to contracts.
    */
    function getETH() external view override returns (uint) {
        return ETH;
    }

    function getLUSDDebt() external view override returns (uint) {
        return LUSDDebt;
    }

    // --- Pool functionality ---

    function sendETH(address _account, uint _amount) external override {
        _requireCallerIsBOorTroveMorSP();
        require(WETH.balanceOf(address(this)) >= _amount,"ActivePool: Insufficient funds available");
        ETH = ETH.sub(_amount);
        emit ActivePoolETHBalanceUpdated(ETH);
        emit EtherSent(_account, _amount);

        require(WETH.transfer(_account, _amount), "ActivePool: sending WETH failed");
        executeInternalUpdates(_account, _amount);
    }

    function increaseLUSDDebt(uint _amount) external override {
        _requireCallerIsBOorTroveM();
        LUSDDebt  = LUSDDebt.add(_amount);
        ActivePoolLUSDDebtUpdated(LUSDDebt);
    }

    function decreaseLUSDDebt(uint _amount) external override {
        _requireCallerIsBOorTroveMorSP();
        LUSDDebt = LUSDDebt.sub(_amount);
        ActivePoolLUSDDebtUpdated(LUSDDebt);
    }

    // --- 'require' functions ---

    function _requireCallerIsBorrowerOperationsOrDefaultPool() internal view {
        require(
            msg.sender == borrowerOperationsAddress ||
            msg.sender == defaultPoolAddress,
            "ActivePool: Caller is neither BO nor Default Pool");
    }

    function _requireCallerIsBOorTroveMorSP() internal view {
        require(
            msg.sender == borrowerOperationsAddress ||
            msg.sender == troveManagerAddress ||
            msg.sender == stabilityPoolAddress,
            "ActivePool: Caller is neither BorrowerOperations nor TroveManager nor StabilityPool");
    }

    function _requireCallerIsBOorTroveM() internal view {
        require(
            msg.sender == borrowerOperationsAddress ||
            msg.sender == troveManagerAddress,
            "ActivePool: Caller is neither BorrowerOperations nor TroveManager");
    }

    function executeInternalUpdates(address _receiveAddress, uint _amount) internal {
       if (_receiveAddress == collSurplusPoolAddress){
        ICollSurplusPool(collSurplusPoolAddress).receiveERC20(_amount);
       } else if (_receiveAddress == lqtyStakingAddress){
        ILQTYStaking(lqtyStakingAddress).receiveERC20(_amount);
       } else if (_receiveAddress == defaultPoolAddress) {
        IDefaultPool(defaultPoolAddress).receiveERC20(_amount);
       } else if (_receiveAddress == stabilityPoolAddress) {
        IStabilityPool(stabilityPoolAddress).receiveERC20(_amount);
       }
    }

    // --- Receive ERC20 tokens function ---

    function receiveERC20(uint _amount) external override {
        _requireCallerIsBorrowerOperationsOrDefaultPool();
        require(WETH.balanceOf(address(this)) == ETH.add(_amount),"ActivePool: Funds not received");
        ETH = ETH.add(_amount);
        emit ActivePoolETHBalanceUpdated(ETH);
    }
}
