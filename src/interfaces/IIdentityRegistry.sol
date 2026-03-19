// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IIdentityRegistry {
    function isVerified(address _userAddress) external view returns (bool);
}