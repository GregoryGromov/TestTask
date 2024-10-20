// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/UniswapV3.sol";
import "hardhat/console.sol";

contract TestTask2 {
    INonfungiblePositionManager immutable nfpManager;

    constructor(address nfpManagerAddress) {
        nfpManager = INonfungiblePositionManager(nfpManagerAddress);
    }

    function provideLiquidity(
        address poolAdress,
        uint64 width,
        uint64 amount0,
        uint64 amount1
    ) external payable {
        require(
            width > 0,
            "Invalid width: the value must be greater than zero."
        );
        require(width != 10000, "Invalid width: the value must not be 10,000.");
        require(
            amount0 >= 0,
            "Invalid amount0: the value must be greater than or equal to zero."
        );
        require(
            amount1 >= 0,
            "Invalid amount1: the value must be greater than or equal to zero."
        );
        require(
            (amount0 != 0) || (amount1 != 0),
            "Invalid amounts: both amount1 and amount2 must not be zeros."
        );

        IUniswapV3Pool pool = IUniswapV3Pool(poolAdress);

        IERC20 token0 = IERC20(pool.token0());
        IERC20 token1 = IERC20(pool.token1());

        uint160 sqrtPAX96;
        uint160 sqrtPBX96;

        (uint160 sqrtPriceX96, , , , , , ) = pool.slot0();

        if (amount0 == 0) {
            sqrtPBX96 = sqrtPriceX96;
            sqrtPAX96 = SafeCast.toUint160(
                FullMath.mulDiv(sqrtPBX96, 10000 - width, 10000 + width)
            );
        } else if (amount1 == 0) {
            sqrtPAX96 = sqrtPriceX96;
            sqrtPBX96 = SafeCast.toUint160(
                FullMath.mulDiv(sqrtPBX96, 10000 + width, 10000 - width)
            );
        } else {
            uint256 sqrtPAX96Numerator = computeSqrtPAX96Numerator(width, amount0, amount1, sqrtPriceX96);

            uint256 sqrtPAX96Denominator = FullMath.mulDiv(
                2 * amount0 * sqrtPriceX96,
                sqrt(10000 + width),
                sqrt(10000 - width)
            );

            sqrtPAX96 = SafeCast.toUint160(
                FullMath.mulDiv(sqrtPAX96Numerator, 1, sqrtPAX96Denominator)
            );

            sqrtPBX96 =
                sqrtPAX96 *
                SafeCast.toUint160(
                    FullMath.mulDiv(sqrtPAX96, 10000 + width, 10000 - width)
                );
        }

        int24 pATick;
        int24 pBTick;

        {
            int24 tickSpacing = pool.tickSpacing();

            int24 pATickExact = TickMath.getTickAtSqrtRatio(sqrtPAX96);
            int24 pBTickExact = TickMath.getTickAtSqrtRatio(sqrtPBX96);

            pATick = (pATickExact / tickSpacing) * tickSpacing;
            if (pATick % tickSpacing >= tickSpacing / 2) {
                pATick += tickSpacing;
            }

            pBTick = (pBTickExact / tickSpacing) * tickSpacing;
            if (pBTick % tickSpacing >= tickSpacing / 2) {
                pBTick += tickSpacing;
            }
        }

        token0.transferFrom(msg.sender, address(this), amount0);
        token1.transferFrom(msg.sender, address(this), amount1);

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

    function computeSqrtPAX96Numerator(
        uint64 width,
        uint64 amount0,
        uint64 amount1,
        uint160 sqrtPriceX96
    ) private pure returns (uint256 numerator) {
        uint256 discriminant = FullMath.mulDiv(
            (amount1 - amount0 * sqrtPriceX96) ** 2,
            10000 + width,
            10000 - width
        );

        numerator =
            FullMath.mulDiv(
                amount0 * sqrtPriceX96 - amount1,
                sqrt(10000 + width),
                sqrt(10000 - width)
            )
            + sqrt(discriminant);

        if (numerator < 0) {
            numerator =
                FullMath.mulDiv(
                    amount0 * sqrtPriceX96 - amount1,
                    sqrt(10000 + width),
                    sqrt(10000 - width)
                ) 
                - sqrt(discriminant);
            require(numerator >= 0, "No solutions");
        }
    }

    function sqrt(uint x) public pure returns (uint y) {
        uint z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }
}
