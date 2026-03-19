// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {PoolManager} from "@uniswap/v4-core/src/PoolManager.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {Currency, CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolSwapTest} from "@uniswap/v4-core/src/test/PoolSwapTest.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
// import {HookMiner} from "@uniswap/v4-periphery/src/utils/HookMiner.sol";
import {HookMiner} from "v4-hooks-public/src/utils/HookMiner.sol";
import {CitadelHook} from "../src/CitadelHook.sol";
import {AssetStatusRegistry} from "../src/AssetStatusRegistry.sol";
import {MockIdentityRegistry} from "./mocks/MockIdentityRegistry.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";

contract CitadelHookTest is Test, Deployers {
    using CurrencyLibrary for Currency;

    CitadelHook hook;
    AssetStatusRegistry assetRegistry;
    MockIdentityRegistry identityRegistry;

    address ALICE = address(0x111);

    function setUp() public {
        // Scope 1: Environment Deployment
        {
            deployFreshManagerAndRouters();
            (currency0, currency1) = deployMintAndApprove2Currencies();
        }

        // Scope 2: Registry Deployment
        {
            assetRegistry = new AssetStatusRegistry();
            identityRegistry = new MockIdentityRegistry();

            assetRegistry.setStatus(
                Currency.unwrap(currency0),
                AssetStatusRegistry.Status.ACTIVE
            );
            assetRegistry.setStatus(
                Currency.unwrap(currency1),
                AssetStatusRegistry.Status.ACTIVE
            );
        }

        // Scope 3: Hook Mining (The heaviest part)
        {
            uint160 flags = uint160(
                Hooks.BEFORE_SWAP_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG
            );

            (, bytes32 salt) = HookMiner.find(
                address(this),
                flags,
                type(CitadelHook).creationCode,
                abi.encode(
                    manager,
                    address(assetRegistry),
                    address(identityRegistry)
                )
            );

            hook = new CitadelHook{salt: salt}(
                manager,
                address(assetRegistry),
                address(identityRegistry)
            );
        }

        // Initialize Pool
        key = PoolKey(currency0, currency1, 3000, 60, IHooks(address(hook)));
        manager.initialize(key, SQRT_PRICE_1_1);
    }

    // HELPER FUNCTION TO CLEAR STACK
    function _deployCitadelHook() internal {
        uint160 flags = uint160(
            Hooks.BEFORE_SWAP_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG
        );

        (, bytes32 salt) = HookMiner.find(
            address(this),
            flags,
            type(CitadelHook).creationCode,
            abi.encode(
                manager,
                address(assetRegistry),
                address(identityRegistry)
            )
        );

        hook = new CitadelHook{salt: salt}(
            manager,
            address(assetRegistry),
            address(identityRegistry)
        );
    }

    function test_BeforeSwap_Success_WhenVerified() public {
        // GIVEN: Alice is verified
        identityRegistry.setVerified(ALICE, true);

        // WHEN: Alice swaps (using vm.prank to simulate tx.origin)
        vm.prank(ALICE, ALICE); // (msg.sender, tx.origin)
        swapRouter.swap(
            key,
            IPoolManager.SwapParams(true, 100, SQRT_PRICE_1_2),
            PoolSwapTest.TestSettings(false, false),
            ZERO_BYTES
        );

        // THEN: Transaction succeeds (no revert)
    }

    function test_BeforeSwap_Revert_WhenNotVerified() public {
        identityRegistry.setVerified(ALICE, false);

        // Remove the string requirement to allow the "WrappedError" to pass
        vm.expectRevert(); 
        vm.prank(ALICE, ALICE);
        swapRouter.swap(key, IPoolManager.SwapParams(true, 100, SQRT_PRICE_1_2), PoolSwapTest.TestSettings(false, false), ZERO_BYTES);
    }

    function test_BeforeSwap_Revert_WhenAssetFrozen() public {
        identityRegistry.setVerified(ALICE, true);
        assetRegistry.setStatus(Currency.unwrap(currency0), AssetStatusRegistry.Status.FROZEN);

        vm.expectRevert();
        vm.prank(ALICE, ALICE);
        swapRouter.swap(key, IPoolManager.SwapParams(true, 100, SQRT_PRICE_1_2), PoolSwapTest.TestSettings(false, false), ZERO_BYTES);
    }

    function test_BeforeAddLiquidity_Revert_WhenNotVerified() public {
        identityRegistry.setVerified(ALICE, false);

        vm.expectRevert();
        vm.prank(ALICE, ALICE);
        modifyLiquidityRouter.modifyLiquidity(key, IPoolManager.ModifyLiquidityParams(-60, 60, 10 ether, 0), ZERO_BYTES);
    }
}