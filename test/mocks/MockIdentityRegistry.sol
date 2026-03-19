// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IIdentityRegistry} from "../../src/interfaces/IIdentityRegistry.sol";

contract MockIdentityRegistry is IIdentityRegistry {
    mapping(address => bool) public verifiedUsers;

    function setVerified(address user, bool status) external {
        verifiedUsers[user] = status;
    }

    function isVerified(address _userAddress) external view returns (bool) {
        return verifiedUsers[_userAddress];
    }
}