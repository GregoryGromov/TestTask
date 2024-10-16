// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {FixedPoint96} from "@uniswap/v3-core/contracts/libraries/FixedPoint96.sol";
import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract TestTask {

    INonfungiblePositionManager immutable nfpManager;

    constructor(INonfungiblePositionManager nfpManager_) {
        nfpManager = nfpManager_;
    }

    function provideLiquidityWithWidth(
        address poolAdress,
        uint64 width,
        uint64 amount0,
        uint64 amount1
    ) external payable  
    {  
        IUniswapV3Pool pool = IUniswapV3Pool(poolAdress);

        IERC20 token0 = IERC20(pool.token0);
        IERC20 token1 = IERC20(pool.token1);

        (uint160 sqrtPriceX96, , , , , , ) = pool.slot0();

        uint256 price = (sqrtPriceX96 / 2 ** 96) ** 2;

        uint64 decimals0 = 10 ** 18; //ETH
        uint64 decimals1 = 10 ** 6; //USDC

        uint256 roundedPrice = price * (decimals0 / decimals1);


        uint256 k = (10 ** 4 - width) / (10 ** 4 + width);
        uint256 D = k * (amount1 - P * amount0) ** 2 - 4 * amount0 * amount1 * P * sqrt(k);

        uint256 pA = (sqrt(D) - sqrt(k) * (amount1 - roundedPrice * amount0)) ** 2 / (4 * (x ** 2) * roundedPrice * k);
        uint256 pB = pA * k;

        uint160 sqrtPAX96 = sqrt(pA * decimals0) * 2 ** 96;
        uint160 sqrtPBX96 = sqrt(pB * decimals1) * 2 ** 96;

        int24 pATick = TickMath.getTickAtSqrtRatio(sqrtPAX96);
        int24 pBTick = TickMath.getTickAtSqrtRatio(sqrtPBX96);


        token0.safeTransferFrom(msg.sender, address(this), amount0);
        token1.safeTransferFrom(msg.sender, address(this), amount1);

        token0.approve(address(nfpManager), amount0);
        token1.approve(address(nfpManager), amount1); 

        nfpManager.mint(
            INonfungiblePositionManager.MintParams(
                address(token0),
                address(token1),
                pool.fee(),
                pATick, 
                pBTick, 
                amount0,
                amount1,
                0, 
                0, 
                msg.sender, 
                block.timestamp 
            )
        );
    }

    function sqrt(uint x) returns (uint y) {
        uint z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }
}
