// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import {PoolManager} from "@uniswap/v4-core/src/PoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";

contract CreatePool is Script {
    address constant POOL_MANAGER = 0xE03A1074c86CFeDd5C142C4F04F1a1536e203543;
    address constant HOOK = 0xd82eF7E7CF1B96daDD0703b47274835a996f4880;
    address constant USDT = 0x598C00BA505De7c9f5059e163570c9059CFcD19F;

    function run() public {
        vm.startBroadcast();

        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(address(0)),  // Native ETH (Sepolia)
            currency1: Currency.wrap(USDT),        // USDT
            fee: 4000,                             // 0.3%
            tickSpacing: 60,
            hooks: IHooks(HOOK)
        });

        // Target price: 1 ETH = 2500 USDT
        // If USDT has 6 decimals: price = (2500 * 1e6) / 1e18 = 2.5e-9 -> Tick: -198079
        // If USDT has 18 decimals: price = (2500 * 1e18) / 1e18 = 2500 -> Tick: 78244
        int24 initialTick = -198079; // <-- CHANGE TO 78244 IF YOUR USDT IS 18 DECIMALS
        
        uint160 sqrtPriceX96 = TickMath.getSqrtPriceAtTick(initialTick);

        console.log("Initializing pool at tick:", initialTick);
        console.log("sqrtPriceX96:", sqrtPriceX96);

        PoolManager(POOL_MANAGER).initialize(key, sqrtPriceX96);

        PoolId id = PoolIdLibrary.toId(key);

        console.log("Pool initialized successfully!");
        console.log("Pool ID:", uint256(PoolId.unwrap(id)));
        console.log("Hook:", HOOK);

        vm.stopBroadcast();
    }
}