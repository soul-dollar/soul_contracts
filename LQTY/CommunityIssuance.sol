// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import "../Interfaces/ICommunityIssuance.sol";
import "../Dependencies/BaseMath.sol";
import "../Dependencies/LiquityMath.sol";
import "../Dependencies/Ownable.sol";
import "../Dependencies/CheckContract.sol";
import "../Dependencies/SafeMath.sol";
import "../Dependencies/IERC20.sol"; //JJ 


contract CommunityIssuance is ICommunityIssuance, Ownable, CheckContract, BaseMath {
    using SafeMath for uint;

    // Provides functions to set up reward cycles for stability pool staking
    // Stability pool address and rewardsToken address must be initialized before initiating a rewards cycle
    // Sufficient reward tokens must be deposited to the contract before initiating a rewards cycle
    // Only one rewards cycle at any given time and new cycles will override existing
    // If tokens are deposited to the contract but are not used in the current reward cycle they are available for future rewards cycles

    // --- Data ---

    string constant public NAME = "CommunityIssuance";

    // for frontend legacy only
    uint constant public SECONDS_IN_ONE_MINUTE = 60;
    uint constant public ISSUANCE_FACTOR = 1;
    uint constant public LQTYSupplyCap = 0; // 32 million
    // ***

    IERC20 public rewardToken; 
    IERC20 public lqtyToken; // retained for frontend integration only

    address public stabilityPoolAddress;

    uint public totalLQTYIssued;            // retained for frontend integration only
    uint public immutable deploymentTime;   // retained for frontend integration only
    
    uint public totalRewardsIssued;  
    uint public rewardsStartTime; 
    uint public rewardsEndTime; 
    uint public rewardsPerSecond; 
    bool public rewardsAvailable;  
    bool public isInitialized; 

    // --- Events ---

    constructor() {
        deploymentTime = block.timestamp;
    }

    // --- Functions ---

    function setAddresses (address _rewardsTokenAddress, address _stabilityPoolAddress) external onlyOwner override {
        require(isInitialized == false,"CommunityIssuance: already initialized");
        checkContract(_rewardsTokenAddress);
        checkContract(_stabilityPoolAddress);
        rewardToken = IERC20(_rewardsTokenAddress);
        lqtyToken = rewardToken; // for frontend integration only
        stabilityPoolAddress = _stabilityPoolAddress;
        emit LQTYTokenAddressSet(_rewardsTokenAddress);
        emit StabilityPoolAddressSet(stabilityPoolAddress);        
        isInitialized = true;
    }

    // Sets up a new rewards cycle and will override any existing rewards cycle
    function setRewardsToken(uint _amount, uint _startTime, uint _rewardsPerSecond) external onlyOwner {
        require(isInitialized,"CommunityIssuance: Not yet initialized");
        uint rewardsBalance = rewardToken.balanceOf(address(this));        
        require(rewardsBalance >= _amount,"CommunityIssuance: Insufficient rewards available");
        require(_startTime >= block.timestamp, "CommunityIssuance: Rewards start time cannot be in the past");        
        require(_rewardsPerSecond >= 0 && _rewardsPerSecond < _amount, "CommunityIssuance: Invalid rewards per second");
        rewardsStartTime = _startTime;
        rewardsEndTime = rewardsStartTime.add(_amount.div(_rewardsPerSecond));
        rewardsPerSecond = _rewardsPerSecond;
        totalRewardsIssued = 0;
        rewardsAvailable = true;
    }

    function issueLQTY() external override returns (uint) {
        _requireCallerIsStabilityPool();
        uint timeNow = block.timestamp;
        uint issuance = 0;

        if(rewardsStartTime < timeNow && rewardsAvailable == true) {
            uint latestTotalRewardsIssued;
            if(timeNow >=  rewardsEndTime) {
                rewardsAvailable = false;
                latestTotalRewardsIssued = (rewardsEndTime.sub(rewardsStartTime)).mul(rewardsPerSecond);
            } else {
              latestTotalRewardsIssued = (timeNow.sub(rewardsStartTime)).mul(rewardsPerSecond);  
            }
            issuance = latestTotalRewardsIssued.sub(totalRewardsIssued);

            totalRewardsIssued = latestTotalRewardsIssued;
            totalLQTYIssued = totalRewardsIssued;  // frontend legacy only
            emit TotalLQTYIssuedUpdated(latestTotalRewardsIssued);
        }
        return issuance;
    }

    function sendLQTY(address _account, uint _amount) external override {  
        _requireCallerIsStabilityPool();
        require(isInitialized,"CommunityIssuance: Not yet initialized");
        rewardToken.transfer(_account, _amount);  
    }

    // --- 'require' functions ---

    function _requireCallerIsStabilityPool() internal view {
        require(msg.sender == stabilityPoolAddress, "CommunityIssuance: caller is not SP");
    }
}