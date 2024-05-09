// SPDX-License-Identifier: MIT

pragma solidity 0.6.11;

interface ICommunityIssuance { 
    
    // --- Events ---
    
    event LQTYTokenAddressSet(address _rewardsTokenAddress);  
    event StabilityPoolAddressSet(address _stabilityPoolAddress);
    event TotalLQTYIssuedUpdated(uint _totalRewardsIssued); 

    // --- Functions ---

    function setAddresses(address _rewardsTokenAddress, address _stabilityPoolAddress) external;

    function issueLQTY() external returns (uint);

    function sendLQTY(address _account, uint _amount) external;
}

