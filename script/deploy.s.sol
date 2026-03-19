// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import {CitadelHook} from "../src/CitadelHook.sol";
import {AssetStatusRegistry} from "../src/AssetStatusRegistry.sol";
import {MockIdentityRegistry} from "../src/MRegistry.sol";  // Updated to match renamed file
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {HookMiner} from "v4-hooks-public/src/utils/HookMiner.sol";

contract DeployCitadel is Script {
    // Sepolia addresses (confirmed)
    address constant POOL_MANAGER = 0xE03A1074c86CFeDd5C142C4F04F1a1536e203543;
    address constant USDT = 0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0;

    // CREATE2 Deployer (standard for all chains)
    address constant CREATE2_DEPLOYER = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy Registries (normal new)
        AssetStatusRegistry assetRegistry = new AssetStatusRegistry();
        MockIdentityRegistry identityRegistry = new MockIdentityRegistry();

        // 2. Mine + Deploy Hook with CREATE2 (this fixes HookAddressNotValid)
        bytes memory constructorArgs = abi.encode(
            IPoolManager(POOL_MANAGER),
            address(assetRegistry),
            address(identityRegistry)
        );

        // Flags for your permissions (beforeSwap + beforeAddLiquidity)
        uint160 flags = Hooks.BEFORE_SWAP_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG;

        // Find the "mined" address + salt
        (address hookAddress, bytes32 salt) = HookMiner.find(
            CREATE2_DEPLOYER,
            flags,
            type(CitadelHook).creationCode,
            constructorArgs
        );

        // Deploy to the mined address
        CitadelHook hook = new CitadelHook{salt: salt}(
            IPoolManager(POOL_MANAGER),
            address(assetRegistry),
            address(identityRegistry)
        );

        // Verify it matches (safety check)
        require(address(hook) == hookAddress, "Hook address mismatch");

        // 3. Setup Demo
        assetRegistry.setStatus(USDT, AssetStatusRegistry.Status.ACTIVE);
        assetRegistry.setStatus(address(0), AssetStatusRegistry.Status.ACTIVE); // SEP native
        identityRegistry.registerUser(vm.addr(deployerPrivateKey)); // Deployer verified

        console.log("AssetRegistry:", address(assetRegistry));
        console.log("IdentityRegistry:", address(identityRegistry));
        console.log("CitadelHook (mined):", address(hook));
        console.log("PoolManager:", POOL_MANAGER);

        vm.stopBroadcast();
    }
}