// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockUSDT is ERC20 {
    constructor() ERC20("Mock Tether USD", "USDT") {
        // Mint 1,000,000 tokens to the deployer's wallet immediately
        // We multiply by 10**6 because the token has 6 decimals
        _mint(msg.sender, 1000000 * 10**6);
    }

    // Override the default 18 decimals to match real USDT
    function decimals() public view virtual override returns (uint8) {
        return 6;
    }
}