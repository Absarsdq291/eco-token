// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test, console } from "forge-std/Test.sol";

import { IUniswapV2Factory } from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import { IUniswapV2Pair } from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import { IUniswapV2Router02 } from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

import { IWETH } from "./external/IWETH.sol";

import { Eco } from "../contracts/Eco.sol";

contract EcoTest is Test {
    /* ========================== STATE VARIABLES ========================== */

    Eco eco;
    IUniswapV2Factory factory;
    IUniswapV2Router02 router;
    IUniswapV2Pair pair;
    IWETH weth;

    address lpProvider = address(0xCAFE);
    address user = address(this);
    address owner = address(0xBEEF);

    address liquidityPoolWallet = address(0x1111);
    address presaleWallet = address(0x2222);
    address marketingWallet = address(0x3333);
    address devWallet = address(0x4444);
    address communityWallet = address(0x5555);
    address vestedWallet = address(0x6666);

    /* ========================== HELPERS ========================== */

    function _addLiquidity(address provider, uint256 ecoAmount, uint256 wethAmount) private {
        vm.startPrank(provider);

        deal(address(eco), provider, ecoAmount);
        vm.deal(provider, wethAmount);
        weth.deposit{value: wethAmount}();

        eco.approve(address(router), ecoAmount);
        weth.approve(address(router), wethAmount);

        router.addLiquidity(
            address(eco),
            address(weth),
            ecoAmount,
            wethAmount,
            0,
            0,
            provider,
            block.timestamp
        );

        vm.stopPrank();
    }

    function _removeLiquidity(address provider, uint256 liquidity) private returns (uint256 ecoAmount, uint256 wethAmount) {
        vm.startPrank(provider);

        // Approve router to spend LP tokens
        pair.approve(address(router), liquidity);

        // Remove liquidity
        (ecoAmount, wethAmount) = router.removeLiquidity(
            address(eco),
            address(weth),
            liquidity,
            0, // amountAMin
            0, // amountBMin
            provider,
            block.timestamp
        );

        vm.stopPrank();
    }

    /* ========================== SET UP ========================== */

    function setUp() external {

        factory = IUniswapV2Factory(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);
        router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        weth = IWETH(router.WETH());

        // Deploy Eco token
        eco = new Eco(
            owner,
            liquidityPoolWallet,
            presaleWallet,
            marketingWallet,
            devWallet,
            communityWallet,
            vestedWallet
        );

        // Create UniswapV2 pair
        address pairAddr = factory.createPair(address(eco), address(weth));
        pair = IUniswapV2Pair(pairAddr);

        // Register pair in Eco
        vm.prank(owner);
        eco.setAutomatedMarketMakerPair(pairAddr, true);

        // Provide initial liquidity
        _addLiquidity(lpProvider, 1_000_000 ether, 1_000_000 ether);

        // Fund this test user
        deal(address(eco), address(this), 1_000_000 ether);
        vm.deal(address(this), 1_000_000 ether);
        weth.deposit{value: 1_000_000 ether}();
    }

    /* ========================== TEST FUNCTIONS ========================== */

    function testAddLiquidity() public view {
        // LP provider should have provided liquidity as done in setUp()
        assertGt(eco.balanceOf(address(pair)), 0 ether, "Liquidity should be added");
    }

    function testSwapExactTokensForTokens() public {
        // approve router
        weth.approve(address(router), type(uint256).max);
        eco.approve(address(router), type(uint256).max);

        // swap WETH → ECO (buy)
        console.log("before buying lp wallet eco balance", eco.balanceOf(liquidityPoolWallet));
        uint256 ecoBefore = eco.balanceOf(user);
        console.log(ecoBefore);

        address [] memory path = new address[](2);
        path[0] = address(weth);
        path[1] = address(eco);

        router.swapExactTokensForTokens(
            1 ether,
            0,
            path,
            user,
            block.timestamp
        );

        uint256 ecoAfter = eco.balanceOf(user);
        console.log(ecoAfter);
        assertGt(ecoAfter, ecoBefore, "Should receive ECO from buy");

        // swap ECO → WETH (sell)
        path[0] = address(eco);
        path[1] = address(weth);

        vm.expectRevert();
        router.swapExactTokensForTokens(
            ecoAfter / 2,
            0,
            path,
            user,
            block.timestamp
        );

        console.log("Buy/Sell tax logic executed successfully");
    }

    function testRemoveLiquidity() public {
        _addLiquidity(lpProvider, 1_000_000 ether, 1_000_000 ether);

        // Get LP token balance
        uint256 lpBalance = pair.balanceOf(lpProvider);

        // Record balances before removing liquidity
        uint256 ecoBefore = eco.balanceOf(lpProvider);
        uint256 wethBefore = weth.balanceOf(lpProvider);

        // Record tax wallet balances before
        console.log("eco balance before remove liquidity", eco.balanceOf(lpProvider));

        // Remove all liquidity
        _removeLiquidity(lpProvider, lpBalance);

        console.log("eco balance after remove liquidity", eco.balanceOf(lpProvider));
        // Verify tokens were received
        assertGt(eco.balanceOf(lpProvider), ecoBefore, "Should receive ECO tokens");
        assertGt(weth.balanceOf(lpProvider), wethBefore, "Should receive WETH tokens");
        
        // Verify LP tokens were burned
        assertEq(pair.balanceOf(lpProvider), 0, "LP tokens should be burned");
        
        console.log("Remove liquidity executed");
    }

    function testRemoveLiquidityETHSupportingFeeOnTransferTokens() public {
        _addLiquidity(lpProvider, 10_000 ether, 10_000 ether);

        uint256 lpBalance = pair.balanceOf(lpProvider);
        assertGt(lpBalance, 0, "Should have LP tokens");

        vm.startPrank(lpProvider);
        pair.approve(address(router), lpBalance);

        uint256 ecoBefore = eco.balanceOf(lpProvider);
        uint256 ethBefore = lpProvider.balance;

        router.removeLiquidityETHSupportingFeeOnTransferTokens(
            address(eco),
            lpBalance,
            0,
            0,
            lpProvider,
            block.timestamp
        );

        uint256 ecoAfter = eco.balanceOf(lpProvider);
        uint256 ethAfter = lpProvider.balance;

        vm.stopPrank();

        assertGt(ecoAfter, ecoBefore, "Should receive ECO tokens");
        assertGt(ethAfter, ethBefore, "Should receive ETH back");
        assertEq(pair.balanceOf(lpProvider), 0, "LP tokens should be burned");

        console.log("removeLiquidityETHSupportingFeeOnTransferTokens executed");
    }

    function testSwapExactTokensForTokensSupportingFeeOnTransferTokens() public {
        eco.approve(address(router), type(uint256).max);
        weth.approve(address(router), type(uint256).max);

        address [] memory path = new address[](2);
        path[0] = address(weth);
        path[1] = address(eco);

        uint256 ecoBefore = eco.balanceOf(user);

        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            2 ether,
            0,
            path,
            user,
            block.timestamp
        );

        uint256 ecoAfter = eco.balanceOf(user);
        assertGt(ecoAfter, ecoBefore, "Should receive ECO tokens");

        console.log("swapExactTokensForTokensSupportingFeeOnTransferTokens executed");

        // sell
        uint256 ecoBalance = eco.balanceOf(user);
        require(ecoBalance > 0, "No ECO to sell");

        path[0] = address(eco);
        path[1] = address(weth);

        uint256 wethBefore = weth.balanceOf(user);
        console.log("Before selling: LP wallet ECO =", eco.balanceOf(liquidityPoolWallet));

        vm.prank(user);
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            ecoBalance / 2, // sell half
            0,
            path,
            user,
            block.timestamp
        );

        uint256 wethAfter = weth.balanceOf(user);
        console.log("After selling: LP wallet ECO =", eco.balanceOf(liquidityPoolWallet));
        assertGt(wethAfter, wethBefore, "User should gain WETH from selling ECO");
    }

    function testSwapTokensForExactTokens() public {
        eco.approve(address(router), type(uint256).max);
        weth.approve(address(router), type(uint256).max);

        address [] memory path = new address[](2);
        path[0] = address(weth);
        path[1] = address(eco);

        uint256 ecoToReceive = 5 ether;

        router.swapTokensForExactTokens(
            ecoToReceive,
            10 ether, // max WETH to spend
            path,
            user,
            block.timestamp
        );

        // sell
        uint256 ecoBalance = eco.balanceOf(user);
        require(ecoBalance > 0, "User has no ECO to sell");

        // build reverse path
        path[0] = address(eco);
        path[1] = address(weth);

        console.log("Before selling LP wallet ECO balance:", eco.balanceOf(liquidityPoolWallet));

        // sell half of user's ECO
        uint256 ecoToSell = ecoBalance / 2;
        eco.approve(address(router), ecoToSell);

        vm.expectRevert();
        router.swapExactTokensForTokens(
            ecoToSell,
            0, // accept any WETH out
            path,
            user,
            block.timestamp
        );

        console.log("Sell phase executed successfully");
    }

    function testSwapTokensForExactTokensSupportingFeeOnTransferTokens() public {
        eco.approve(address(router), type(uint256).max);
        weth.approve(address(router), type(uint256).max);

        address [] memory path = new address[](2);
        path[0] = address(weth);
        path[1] = address(eco);

        uint256 ecoDesired = 5 ether;
        uint256[] memory amountsOut = router.getAmountsIn(ecoDesired, path);
        uint256 wethToSpend = amountsOut[0];

        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            wethToSpend,
            0,
            path,
            user,
            block.timestamp
        );

        assertGt(eco.balanceOf(user), 0, "Should receive some ECO even with fees");
        console.log("swapTokensForExactTokensSupportingFeeOnTransferTokens executed successfully");

        // sell
        uint256 wethBefore = weth.balanceOf(user);
        console.log("Before selling LP wallet ECO balance:", eco.balanceOf(liquidityPoolWallet));

        // reverse path for selling
        path[0] = address(eco);
        path[1] = address(weth);

        uint256 ecoToSell = eco.balanceOf(user) / 2;
        eco.approve(address(router), ecoToSell);

        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            ecoToSell,
            0, // accept any WETH output
            path,
            user,
            block.timestamp
        );

        uint256 wethAfter = weth.balanceOf(user);
        assertGt(wethAfter, wethBefore, "User should gain WETH from selling ECO");
        console.log("After selling LP wallet ECO balance:", eco.balanceOf(liquidityPoolWallet));
        console.log("Sell (swapTokensForExactTokensSupportingFeeOnTransferTokens) executed successfully");
    }
}
