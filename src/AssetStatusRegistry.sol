// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract AssetStatusRegistry is Ownable {
    
    enum Status { ACTIVE, FROZEN, LITIGATION, BROKEN }
    
    mapping(address => Status) public assetStatus;

    event StatusChanged(address indexed token, Status status);

    constructor() Ownable(msg.sender) {}

    function setStatus(address token, Status status) external onlyOwner {
        assetStatus[token] = status;
        emit StatusChanged(token, status);
    }

    function getStatus(address token) external view returns (Status) {
        return assetStatus[token];
    }
}