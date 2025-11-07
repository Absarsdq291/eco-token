// SPDX-License-Identifier: MIT

pragma solidity 0.8.30;

import { Test, console } from "forge-std/Test.sol";

import { IUniswapV3Factory } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import { IUniswapV3Pool } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

import { INonfungiblePositionManager } from "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import { ISwapRouter } from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

import { WETH9 } from "./external/WETH.sol";

import { Eco } from "../contracts/Eco.sol";

contract EcoTest is Test {
    Eco eco;

    WETH9 weth;
    INonfungiblePositionManager positionManager;
    IUniswapV3Factory factory;
    ISwapRouter swapRouter;

    IUniswapV3Pool pool;

    address lpProvider = address(0xCAFE);

    address user = address(this);
    address owner = address(0xBEEF);

    address liquidityPoolWallet = address(0x1111);
    address presaleWallet = address(0x2222);
    address marketingWallet = address(0x3333);
    address devWallet = address(0x4444);
    address communityWallet = address(0x5555);
    address vestedWallet = address(0x6666);

    function setUp() external {
        weth = new WETH9();
        positionManager = INonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);
        factory = IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984);
        swapRouter = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);

        // deploy Eco
        eco = new Eco(
            owner,
            liquidityPoolWallet,
            presaleWallet,
            marketingWallet,
            devWallet,
            communityWallet,
            vestedWallet
        );

        // register Uniswap V3 pool
        uint24 fee = 3000; // 0.3%
        address poolAddr = factory.createPool(address(eco), address(weth), fee);
        pool = IUniswapV3Pool(poolAddr);
        pool.initialize(79228162514264337593543950336); // price = 1:1 ratio

        // mark this pair in Eco
        vm.prank(owner);
        eco.setAutomatedMarketMakerPair(poolAddr, true);

        // provide initial liquidity
        _positionMintHelper(lpProvider, 1_000_000 ether, 1_000_000 ether);

        deal(address(eco), address(this), 1_000_000 ether);
        vm.deal(address(this), 1_000_000 ether);
        weth.deposit{ value: 1_000_000 ether }();
    }

    function testAddLiquidityExemptFromTax() public view {
        // The positionManager should be excluded inside Eco by default constant
        assertEq(eco.balanceOf(address(pool)), 1_000_000 ether, "Should bypass tax");
        assertEq(eco.balanceOf(liquidityPoolWallet), 500_000_000_000 ether, "No tax should be sent to LP wallet");
        assertEq(eco.balanceOf(presaleWallet), 250_000_000_000 ether, "No tax should be sent to presale wallet");
        assertEq(eco.balanceOf(devWallet), 0, "No tax should be sent to dev wallet");
    }

    function testSwapTriggersBuySellTax() public {
        weth.approve(address(swapRouter), type(uint256).max);

        uint256 ecoBefore = eco.balanceOf(user);

        // Swap WETH -> ECO (simulate buy)
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: address(weth),
            tokenOut: address(eco),
            fee: 3000,
            recipient: user,
            deadline: block.timestamp,
            amountIn: 1 ether,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });

        swapRouter.exactInputSingle(params);
        uint256 ecoAfter = eco.balanceOf(user);
        assertGt(ecoAfter - ecoBefore, 0, "Should receive ECO");

        // Now sell ECO back to WETH
        eco.approve(address(swapRouter), type(uint256).max);
        uint256 wethBefore = weth.balanceOf(user);

        ISwapRouter.ExactInputSingleParams memory sellParams = ISwapRouter.ExactInputSingleParams({
            tokenIn: address(eco),
            tokenOut: address(weth),
            fee: 3000,
            recipient: user,
            deadline: block.timestamp,
            amountIn: (ecoAfter - ecoBefore) / 2,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });

        swapRouter.exactInputSingle(sellParams);
        uint256 wethAfter = weth.balanceOf(user);

        assertGt(wethAfter, wethBefore, "Should receive WETH");
        vm.stopPrank();
    }

    function _positionMintHelper(address provider, uint256 ecoAmount, uint256 wethAmount) private {
        // fund provider
        vm.startPrank(provider);

        // eco.transfer(provider, ecoAmount);
        deal(address(eco), provider, ecoAmount);
        vm.deal(provider, wethAmount);
        weth.deposit{ value: wethAmount }();

        eco.approve(address(positionManager), ecoAmount);
        weth.approve(address(positionManager), wethAmount);

        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams({
            token0: address(eco) < address(weth) ? address(eco) : address(weth),
            token1: address(eco) < address(weth) ? address(weth) : address(eco),
            fee: 3000,
            tickLower: -887220,
            tickUpper: 887220,
            amount0Desired: ecoAmount,
            amount1Desired: wethAmount,
            amount0Min: 0,
            amount1Min: 0,
            recipient: provider,
            deadline: block.timestamp
        });

        positionManager.mint(params);

        vm.stopPrank();
    }
}
