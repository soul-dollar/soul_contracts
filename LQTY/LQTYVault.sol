// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import "../Interfaces/ILQTYToken.sol";

contract LQTYVault  {

    ILQTYToken public token;
    address public stakingContract;
    bool public isTokenSet;
    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    event TokenAddressSet (address _token);

    constructor(address _stakingContract)  {
        require(_stakingContract != address(0),"Invalid contract address");
        stakingContract = _stakingContract;
        owner = msg.sender;
    }

    function setToken(address _token) external onlyOwner {
        require(!isTokenSet, "Token is already set");
        require (_token != address(0),"Invalid token address");
        token = ILQTYToken(_token);
        isTokenSet = true;
        // Approve the staking contract to spend an unlimited amount of tokens
        token.approve(stakingContract, type(uint256).max);     
        emit TokenAddressSet(_token);
    }

    function renounceOwnership() external onlyOwner {
        require(isTokenSet,"Token address not yet set");
        owner = address(0);
    }
}