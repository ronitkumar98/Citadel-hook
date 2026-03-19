// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IIdentityRegistry} from "./interfaces/IIdentityRegistry.sol";

contract MockIdentityRegistry is IIdentityRegistry {
    mapping(address => bool) public isWhitelisted;

    event UserRegistered(address indexed user);

    function registerUser(address user) external {
        isWhitelisted[user] = true;
        emit UserRegistered(user);
    }

    function isVerified(address _userAddress) external view override returns (bool) {
        return isWhitelisted[_userAddress];
    }
}