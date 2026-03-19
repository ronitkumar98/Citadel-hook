// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {BaseHook} from "lib/v4-hooks-public/src/base/BaseHook.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "@uniswap/v4-core/src/types/BeforeSwapDelta.sol";
import {IIdentityRegistry} from "./interfaces/IIdentityRegistry.sol";
import {AssetStatusRegistry} from "./AssetStatusRegistry.sol"; 
import {Currency, CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";

contract CitadelHook is BaseHook {
    using BeforeSwapDeltaLibrary for BeforeSwapDelta;
    using CurrencyLibrary for Currency;
    address public assetRegistry;
    address public identityRegistry;

    constructor(IPoolManager _poolManager, address _assetRegistry, address _identityRegistry) 
        BaseHook(_poolManager) 
    {
        assetRegistry = _assetRegistry;
        identityRegistry = _identityRegistry;
    }

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: true,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: true, 
            afterSwap: false,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    // Combined validation logic to save gas and maintain consistency
    function _validateCompliance(address user, PoolKey calldata key) internal view {
        // 1. Micro Check: Identity
        require(IIdentityRegistry(identityRegistry).isVerified(user), "Citadel: User Not KYC'd");

        // 2. Macro Check: Asset Status (Check both tokens in the pair)
        require(
            AssetStatusRegistry(assetRegistry).getStatus(Currency.unwrap(key.currency0)) == AssetStatusRegistry.Status.ACTIVE &&
            AssetStatusRegistry(assetRegistry).getStatus(Currency.unwrap(key.currency1)) == AssetStatusRegistry.Status.ACTIVE,
            "Citadel: Asset Frozen/Litigation"
        );
    }

    function beforeSwap(address, PoolKey calldata key, IPoolManager.SwapParams calldata, bytes calldata)
        external view override returns (bytes4, BeforeSwapDelta, uint24)
    {
        _validateCompliance(tx.origin, key); 
        // return (BaseHook.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
        return (IHooks.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
    }

    function beforeAddLiquidity(address, PoolKey calldata key, IPoolManager.ModifyLiquidityParams calldata, bytes calldata)
        external view override returns (bytes4)
    {
        _validateCompliance(tx.origin, key);
        // return BaseHook.beforeAddLiquidity.selector;
        return IHooks.beforeAddLiquidity.selector;
    }
}