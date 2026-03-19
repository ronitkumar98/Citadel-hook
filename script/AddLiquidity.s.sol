// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IPermit2 {
    function approve(address token, address spender, uint160 amount, uint48 expiration) external;
}

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {IPositionManager} from "v4-periphery/src/interfaces/IPositionManager.sol";
import {Actions} from "v4-periphery/src/libraries/Actions.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency, CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {LiquidityAmounts} from "v4-periphery/src/libraries/LiquidityAmounts.sol"; 
import {ActionConstants} from "v4-periphery/src/libraries/ActionConstants.sol";

contract AddLiquidity is Script {
    address constant POSITION_MANAGER = 0x429ba70129df741B2Ca2a85BC3A2a3328e5c09b4;
    address constant USDT = 0x598C00BA505De7c9f5059e163570c9059CFcD19F; // Your Mock USDT
    address constant HOOK = 0xd82eF7E7CF1B96daDD0703b47274835a996f4880; // Your Citadel Hook
    address constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3; // <-- Moved to contract level

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address recipient = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Approve Permit2 to touch your USDT
        IERC20(USDT).approve(PERMIT2, type(uint256).max);

        // 2. Tell Permit2 to allow the PositionManager to spend your USDT
        IPermit2(PERMIT2).approve(USDT, POSITION_MANAGER, type(uint160).max, type(uint48).max);

        // 3. MATCH THE FEE TO YOUR CREATED POOL
        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(address(0)),
            currency1: Currency.wrap(USDT),
            fee: 4000,                            
            tickSpacing: 60,
            hooks: IHooks(HOOK)
        });

        int24 currentTickApprox = -198079; 
        int24 spacing = key.tickSpacing; 

        int24 alignedTick = currentTickApprox;
        if (alignedTick < 0 && alignedTick % spacing != 0) {
            alignedTick = (alignedTick / spacing) * spacing - spacing;
        } else {
            alignedTick = (alignedTick / spacing) * spacing;
        }

        int24 rangeWidth = 120;
        int24 tickLower = alignedTick - rangeWidth;
        int24 tickUpper = alignedTick + rangeWidth;

        // 4. SCALE DOWN TO LEAVE GAS BUFFER
        uint256 amount0Desired = 0.018 ether; // Leaves ~0.002 SEP in wallet for gas
        uint256 amount1Desired = 45 * 10**6; 

        uint160 sqrtPriceX96 = TickMath.getSqrtPriceAtTick(alignedTick);
        uint160 sqrtPriceAX96 = TickMath.getSqrtPriceAtTick(tickLower);
        uint160 sqrtPriceBX96 = TickMath.getSqrtPriceAtTick(tickUpper);

        uint128 liquidityDelta = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceX96,
            sqrtPriceAX96,
            sqrtPriceBX96,
            amount0Desired,
            amount1Desired
        );

        bytes memory actions = abi.encodePacked(
            uint8(Actions.MINT_POSITION),
            uint8(Actions.SETTLE),
            uint8(Actions.SETTLE),
            uint8(Actions.TAKE),
            uint8(Actions.TAKE)
        );

        bytes memory mintParam = abi.encode(
            key,
            tickLower,
            tickUpper,
            uint256(liquidityDelta),
            type(uint128).max, 
            type(uint128).max,  
            recipient,         
            bytes("")          
        );

        bytes[] memory params = new bytes[](5);
        params[0] = mintParam;
        
        // currency0 is Native ETH. We sent it as msg.value, so PositionManager already holds it. payerIsUser = false.
        params[1] = abi.encode(key.currency0, ActionConstants.OPEN_DELTA, false);
        
        // currency1 is USDT. PositionManager doesn't hold it, so it must pull from your wallet. payerIsUser = true.
        params[2] = abi.encode(key.currency1, ActionConstants.OPEN_DELTA, true);
        
        // TAKE actions refund any leftovers to the recipient
        params[3] = abi.encode(key.currency0, recipient, ActionConstants.OPEN_DELTA);
        params[4] = abi.encode(key.currency1, recipient, ActionConstants.OPEN_DELTA);

        bytes memory unlockData = abi.encode(actions, params);

        IPositionManager(POSITION_MANAGER).modifyLiquidities{value: amount0Desired}(
            unlockData,
            block.timestamp + 600
        );

        console.log("Liquidity added successfully!");
        console.log("Recipient:", recipient);
        console.log("tickLower:", int(tickLower));
        console.log("tickUpper:", int(tickUpper));
        console.log("liquidityDelta:", liquidityDelta);

        vm.stopBroadcast();
    }
}