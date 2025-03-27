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

        ISwapRouter.ExactInputSingleParams memory params = 
            ISwapRouter.ExactInputSingleParams({
                tokenIn: address(token0),
                tokenOut: address(token1),
                fee: 3000, // 0.3% fee tier
                recipient: alice,
                deadline: block.timestamp + 300, // 5 minutos
                amountIn: 10_000 * 10**18,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });

        // Simulate multiple swaps over time
        for (uint i = 0; i < 5; i++) {
            uint256 amountOut = swapRouter.exactInputSingle(params);

            assertGt(amountOut, 0, "Output tokens amount check");
            console.log("Output tokens amount:", amountOut);

            // Simulate time passing
            vm.warp(block.timestamp + 120); // 2 minutes between swaps
        }

        vm.stopPrank();

        // Check the dynamic fee calculation
        uint24 currentDynamicFee = uniswapV3Pool.currentDynamicFee();
        
        // Dynamic fee should be calculated
        assertGt(uint256(currentDynamicFee), 0, "Dynamic fee should be calculated");
        
        // Checking if the fee is within an expected range
        assertLt(uint256(currentDynamicFee), 100000, "Dynamic fee should be within reasonable bounds");

        // Log the calculated dynamic fee for inspection
        emit log_named_uint("Calculated Dynamic Fee:", uint256(currentDynamicFee));
    }
}
