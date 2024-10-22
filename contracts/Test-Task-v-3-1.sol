// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/UniswapV3.sol";
import "./interfaces/ILP.sol";
import "hardhat/console.sol";

contract LP is ILP {
    INonfungiblePositionManager immutable nfpManager;

    constructor(address nfpManagerAddress) {
        nfpManager = INonfungiblePositionManager(nfpManagerAddress);
    }

    function test() external pure returns (uint256 num) {
        num = 228;
    }

    function provideLiquidity(
        address poolAdress,
        uint64 width,
        uint64 amount0,
        uint64 amount1
    ) external payable {
        console.log("Na start!");

        checkInputData(width, amount0, amount1);

        IUniswapV3Pool pool = IUniswapV3Pool(poolAdress);

        IERC20 token0 = IERC20(pool.token0());
        IERC20 token1 = IERC20(pool.token1());

        uint160 sqrtPA;
        uint160 sqrtPB;

        {
            (uint160 sqrtPriceX96, , , , , , ) = pool.slot0();
            console.log("sqrtPriceX96 = %s", sqrtPriceX96);

            uint160 sqrtPrice = (sqrtPriceX96 * 10 ** 6) / 2 ** 96;
            console.log("sqrtPrice = ", sqrtPrice);

            uint256 price = TickMath.getPriceBySqrtRatio(sqrtPriceX96, 12);
            console.log("curPrice = ", price);

            // TODO: Переделать для случаев сложение одного актива
            if (amount0 == 0) {
                (sqrtPA, sqrtPB) = computeBordersForFullToken1Asset(
                    width,
                    sqrtPrice
                );
            } else if (amount1 == 0) {
                (sqrtPA, sqrtPB) = computeBordersForFullToken0Asset(
                    width,
                    sqrtPrice
                );
            } else {
                console.log("invest both assets");
                (sqrtPA, sqrtPB) = computeBordersForGeneralCase(
                    width,
                    amount0,
                    amount1,
                    sqrtPrice,
                    price
                );
                console.log("sqrtPA = %s", sqrtPA);
                console.log("sqrtPB = %s", sqrtPB);
            }
        }

        uint160 sqrtPAX96 = sqrtPA * 2 ** 96 / 10 ** 6;
        uint160 sqrtPBX96 = sqrtPB * 2 ** 96 / 10 ** 6;

        console.log("sqrtPAX96 = %s", sqrtPAX96);
        console.log("sqrtPBX96 = %s", sqrtPBX96);

        (int24 pATick, int24 pBTick) = computeTicks(
            pool.tickSpacing(),
            sqrtPAX96,
            sqrtPBX96
        );

        {
            int256 pATickAbs = pATick < 0 ? -int256(pATick) : int256(pATick);
            uint256 pATickSquared = uint256(pATickAbs) * uint256(pATickAbs);
            console.log("   pATick = -%s", sqrt(pATickSquared));
        }
        
        {
            int256 pBTickAbs = pBTick < 0 ? -int256(pBTick) : int256(pBTick);
            uint256 pBTickSquared = uint256(pBTickAbs) * uint256(pBTickAbs);
            console.log("   pBTick = -%s", sqrt(pBTickSquared));
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

    function computeTicks(
        int24 tickSpacing,
        uint160 sqrtPAX96,
        uint160 sqrtPBX96
    ) private pure returns (int24 pATick, int24 pBTick) {
        int24 pATickExact = TickMath.getTickAtSqrtRatio(sqrtPAX96);
        int24 pBTickExact = TickMath.getTickAtSqrtRatio(sqrtPBX96);

        // console.log("exact ticks: ");
        // console.log(uint256(int256(pATickExact)));
        // console.log(uint256(int256(pBTickExact)));

        // pATick = (pATickExact / tickSpacing) * tickSpacing;
        // if (pATick % tickSpacing >= tickSpacing / 2) {
        //     pATick -= tickSpacing;
        // }

        pATick = (pATickExact / tickSpacing) * tickSpacing;
        pATick -= tickSpacing;
        
        pBTick = (pBTickExact / tickSpacing) * tickSpacing;
        pBTick += tickSpacing;

        console.log("Price borders: ");
        console.log(TickMath.getPriceBySqrtRatio(sqrtPAX96, 12));
        console.log(TickMath.getPriceBySqrtRatio(sqrtPBX96, 12));
       
    }

    function computeBordersForFullToken1Asset(
        uint64 width,
        uint160 sqrtPrice
    ) private pure returns (uint160 sqrtPAX96, uint160 sqrtPBX96) {
        sqrtPBX96 = sqrtPrice;
        sqrtPAX96 = SafeCast.toUint160(
            FullMath.mulDiv(sqrtPBX96, 10000 - width, 10000 + width)
        );
    }

    function computeBordersForFullToken0Asset(
        uint64 width,
        uint160 sqrtPrice
    ) private pure returns (uint160 sqrtPAX96, uint160 sqrtPBX96) {
        sqrtPAX96 = sqrtPrice;
        sqrtPBX96 = SafeCast.toUint160(
            FullMath.mulDiv(sqrtPBX96, 10000 + width, 10000 - width)
        );
    }

    function computeBordersForGeneralCase(
        uint64 width,
        uint64 amount0,
        uint64 amount1,
        uint160 sqrtPrice,
        uint256 price
    ) private pure returns (uint160 sqrtPA, uint160 sqrtPB) {
        // console.log("We are in computeBordersForGeneralCase");
        uint256 sqrtPANumerator = computeSqrtPANumerator(
            width,
            amount0,
            amount1,
            sqrtPrice,
            price
        );
        // console.log("sqrtPANumerator = %s", sqrtPANumerator);

        uint256 sqrtPADenominator = FullMath.mulDiv(
            2 * amount0 * sqrtPrice,
            sqrt(10000 + width),
            sqrt(10000 - width)
        );

        sqrtPA = SafeCast.toUint160(
            FullMath.mulDiv(sqrtPANumerator, 1, sqrtPADenominator)
        );

        console.log("Sqrt from left border sqrtPA = ", sqrtPA);

        sqrtPB = //!!!
            SafeCast.toUint160(
                FullMath.mulDiv(sqrtPA, sqrt(10000 + width), sqrt(10000 - width))
            );
        console.log("Sqrt from right border sqrtPB = ", sqrtPB);
    }

    function checkInputData(
        uint64 width,
        uint64 amount0,
        uint64 amount1
    ) private pure {
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
    }

    function computeSqrtPANumerator(
        uint256 width,
        uint256 amount0,
        uint256 amount1,
        uint160 sqrtPrice,
        uint256 price
    ) private pure returns (uint256 numerator) {
        console.log("We are in func computeSqrtPAX96Numerator");

        console.log("sqrtPrice = ", sqrtPrice);
        console.log("curPrice = ", price);

        uint256 x = amount1 ** 2 +
            (amount0 ** 2) *
            (price ** 2) -
            2 *
            amount0 *
            amount1 *
            price;

        console.log("x = ", x);
        uint256 discriminant = FullMath.mulDiv(
            x,
            10000 + width,
            10000 - width
        ) +
            FullMath.mulDiv(
                4 * amount0 * price * amount1,
                sqrt(10000 + width),
                sqrt(10000 - width)
            );

        console.log("discriminant = %s", discriminant);

        numerator =
            FullMath.mulDiv(
                amount0 * price - amount1,
                sqrt(10000 + width),
                sqrt(10000 - width)
            ) +
            sqrt(discriminant);

        // console.log("!!!");
        // console.log("numerator = %s", numerator);

        if (numerator < 0) { //!!!
            numerator =
                FullMath.mulDiv(
                    amount0 * sqrtPrice - amount1,
                    sqrt(10000 + width),
                    sqrt(10000 - width)
                ) -
                sqrt(discriminant);
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
