// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {MockUSDT} from "../src/MockUSDT.sol";

contract DeployMock is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        MockUSDT usdt = new MockUSDT();
        
        console.log("Mock USDT Deployed to:", address(usdt));
        
        vm.stopBroadcast();
    }
}