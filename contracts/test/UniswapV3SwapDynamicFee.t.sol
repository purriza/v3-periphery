// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.7.6;
pragma abicoder v2;

import "./utils/UniswapV3SwapDynamicFeeFixture.sol";

contract UniswapV3SwapDynamicFeeTest is UniswapV3SwapDynamicFeeFixture {
    function setUp() public override {
        super.setUp();
    }

    function testDynamicFeeTWAP() public {
        // Perform a series of swaps to generate fee history
        vm.startPrank(alice);

        // Approve tokens for swapping
        token0.approve(address(swapRouter), type(uint256).max);
        token1.approve(address(swapRouter), type(uint256).max);

        // Get the current slot0 to determine the current sqrt price
        (uint160 sqrtPriceX96, , , , , , ) = uniswapV3Pool.slot0();

        // Determine swap direction and price limit
        bool zeroForOne = true; // Swapping token0 for token1
        uint160 sqrtPriceLimitX96;

        if (zeroForOne) {
            // When swapping token0 for token1, we want the price to go down
            // So the limit must be less than current price but above MIN_SQRT_RATIO
            sqrtPriceLimitX96 = (sqrtPriceX96 * 9) / 10; // 10% lower
        } else {
            // When swapping token1 for token0, we want the price to go up
            // So the limit must be higher than current price but below MAX_SQRT_RATIO
            sqrtPriceLimitX96 = (sqrtPriceX96 * 11) / 10; // 10% higher
        }

        ISwapRouter.ExactInputSingleParams memory params = 
            ISwapRouter.ExactInputSingleParams({
                tokenIn: address(token0),
                tokenOut: address(token1),
                fee: uniswapV3Pool.fee(), 
                recipient: alice,
                deadline: block.timestamp + 300,
                amountIn: 5_000 * 1e18,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: sqrtPriceLimitX96
            });

        console.log("Pool token0 balance:", token0.balanceOf(address(uniswapV3Pool)));
        console.log("Pool token1 balance:", token1.balanceOf(address(uniswapV3Pool)));

        uint256 amountOut;
        uint24 currentDynamicFee;
        uint256 price;
        // Simulate multiple swaps over time
        for (uint i = 0; i < 5; i++) {
            amountOut = swapRouter.exactInputSingle(params);

            console.log("Swap number:", i);

            assertGt(amountOut, 0, "Output tokens amount check");
            console.log("Output tokens amount:", amountOut);

            console.log("Pool token0 balance:", token0.balanceOf(address(uniswapV3Pool)));
            console.log("Pool token1 balance:", token1.balanceOf(address(uniswapV3Pool)));

            console.log("Alice token0 balance:", token0.balanceOf(alice));
            console.log("Alice token1 balance:", token1.balanceOf(alice));

            currentDynamicFee = uniswapV3Pool.currentDynamicFee();
            console.log("Current dynamic fee: ", uint256(currentDynamicFee));

            // Simulate time passing
            vm.warp(block.timestamp + 120); // 2 minutes between swaps
            params.deadline = block.timestamp + 5;

            // Show current price (Amount of token0 to get token1)
            (sqrtPriceX96, , , , , , ) = uniswapV3Pool.slot0();
            price = (uint256(sqrtPriceX96) * uint256(sqrtPriceX96) * 10**18) / (2**192);
            console.log("Current price: ", price);

            // Update sqrtPriceLimitX96 for the next swap
            if (zeroForOne) {
                sqrtPriceLimitX96 = (sqrtPriceX96 * 9) / 10;
            } else {
                sqrtPriceLimitX96 = (sqrtPriceX96 * 11) / 10;
            }
            params.sqrtPriceLimitX96 = sqrtPriceLimitX96;

            if (i == 3) {
                params.amountIn = 300_000 * 1e18;
            }
        }

        vm.stopPrank();

        vm.startPrank(bob);

        // Approve tokens for swapping
        token0.approve(address(swapRouter), type(uint256).max);
        token1.approve(address(swapRouter), type(uint256).max);

        vm.warp(block.timestamp + 6000); // Wait 10 minutes

        // Increase the amount to swap
        params.amountIn = 300_000 * 1e18;
        params.deadline = block.timestamp + 5;

        console.log("Swap number 6");

        amountOut = swapRouter.exactInputSingle(params);

        assertGt(amountOut, 0, "Output tokens amount check");
        console.log("Output tokens amount:", amountOut);

        console.log("Pool token0 balance:", token0.balanceOf(address(uniswapV3Pool)));
        console.log("Pool token1 balance:", token1.balanceOf(address(uniswapV3Pool)));

        console.log("Bob token0 balance:", token0.balanceOf(bob));
        console.log("Bob token1 balance:", token1.balanceOf(bob));

        currentDynamicFee = uniswapV3Pool.currentDynamicFee();
        console.log("Current dynamic fee: ", uint256(currentDynamicFee));

        // Show current price (Amount of token0 to get token1)
        (sqrtPriceX96, , , , , , ) = uniswapV3Pool.slot0();
        price = (uint256(sqrtPriceX96) * uint256(sqrtPriceX96) * 10**18) / (2**192);
        console.log("Current price: ", price);

        vm.stopPrank();
    }
}
