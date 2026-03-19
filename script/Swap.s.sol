// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency, CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {PoolSwapTest} from "@uniswap/v4-core/src/test/PoolSwapTest.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";

contract SwapScript is Script {
    using CurrencyLibrary for Currency;
    address constant POOL_MANAGER = 0xE03A1074c86CFeDd5C142C4F04F1a1536e203543;
    address constant HOOK = 0xd82eF7E7CF1B96daDD0703b47274835a996f4880;
    address constant USDT = 0x598C00BA505De7c9f5059e163570c9059CFcD19F;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy own Swap Router for testing
        PoolSwapTest swapRouter = new PoolSwapTest(IPoolManager(POOL_MANAGER));
        console.log("Deployed PoolSwapTest to:", address(swapRouter));

        // 2. Define the exact PoolKey of the pool you funded
        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(address(0)),
            currency1: Currency.wrap(USDT),
            fee: 4000,
            tickSpacing: 60,
            hooks: IHooks(HOOK)
        });

        // 3. Configure the Swap Parameters (ETH -> USDT)
        IPoolManager.SwapParams memory params = IPoolManager.SwapParams({
            zeroForOne: true, // true = Swap Currency0 (ETH) for Currency1 (USDT)
            amountSpecified: -int256(uint256(1e15)), // Swap exactly 0.001 ETH
            sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1 // Allow maximum slippage for testnet
        });

        // 4. Configure Test Settings
        PoolSwapTest.TestSettings memory testSettings = PoolSwapTest.TestSettings({
            takeClaims: false, // Return actual ERC-20/ETH tokens to the wallet
            settleUsingBurn: false
        });

        // 5. Execute the Swap
        console.log("Executing Swap of 0.001 ETH for USDT...");
        
        //  0.001 ETH as msg.value since it is Native ETH
        swapRouter.swap{value: 1e15}(
            key,
            params,
            testSettings,
            new bytes(0)
        );

        console.log("Swap Successful!");

        vm.stopBroadcast();
    }
}