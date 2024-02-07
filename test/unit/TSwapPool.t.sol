// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Test, console } from "forge-std/Test.sol";
import { TSwapPool } from "../../src/PoolFactory.sol";
import { ERC20Mock } from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract TSwapPoolTest is Test {
    TSwapPool pool;
    ERC20Mock poolToken;
    ERC20Mock weth;

    address liquidityProvider = makeAddr("liquidityProvider");
    address user = makeAddr("user");

    function setUp() public {
        poolToken = new ERC20Mock();
        weth = new ERC20Mock();
        pool = new TSwapPool(address(poolToken), address(weth), "LTokenA", "LA");

        weth.mint(liquidityProvider, 200e18);
        poolToken.mint(liquidityProvider, 200e18);

        weth.mint(user, 10e18);
        poolToken.mint(user, 10e18);
    }

    function testDeposit() public {
        vm.startPrank(liquidityProvider);
        weth.approve(address(pool), 100e18);
        poolToken.approve(address(pool), 100e18);
        pool.deposit(100e18, 100e18, 100e18, uint64(block.timestamp));

        assertEq(pool.balanceOf(liquidityProvider), 100e18);
        assertEq(weth.balanceOf(liquidityProvider), 100e18);
        assertEq(poolToken.balanceOf(liquidityProvider), 100e18);

        assertEq(weth.balanceOf(address(pool)), 100e18);
        assertEq(poolToken.balanceOf(address(pool)), 100e18);
    }

    function testDepositSwap() public {
        vm.startPrank(liquidityProvider);
        weth.approve(address(pool), 100e18);
        poolToken.approve(address(pool), 100e18);
        pool.deposit(100e18, 100e18, 100e18, uint64(block.timestamp));
        vm.stopPrank();

        vm.startPrank(user);
        poolToken.approve(address(pool), 10e18);
        // After we swap, there will be ~110 tokenA, and ~91 WETH
        // 100 * 100 = 10,000
        // 110 * ~91 = 10,000
        uint256 expected = 9e18;

        pool.swapExactInput(poolToken, 10e18, weth, expected, uint64(block.timestamp));
        assert(weth.balanceOf(user) >= expected);
    }

    function testWithdraw() public {
        vm.startPrank(liquidityProvider);
        weth.approve(address(pool), 100e18);
        poolToken.approve(address(pool), 100e18);
        pool.deposit(100e18, 100e18, 100e18, uint64(block.timestamp));

        pool.approve(address(pool), 100e18);
        pool.withdraw(100e18, 100e18, 100e18, uint64(block.timestamp));

        assertEq(pool.totalSupply(), 0);
        assertEq(weth.balanceOf(liquidityProvider), 200e18);
        assertEq(poolToken.balanceOf(liquidityProvider), 200e18);
    }

    function testCollectFees() public {
        vm.startPrank(liquidityProvider);
        weth.approve(address(pool), 100e18);
        poolToken.approve(address(pool), 100e18);
        pool.deposit(100e18, 100e18, 100e18, uint64(block.timestamp));
        vm.stopPrank();

        vm.startPrank(user);
        uint256 expected = 9e18;
        poolToken.approve(address(pool), 10e18);
        pool.swapExactInput(poolToken, 10e18, weth, expected, uint64(block.timestamp));
        vm.stopPrank();

        vm.startPrank(liquidityProvider);
        pool.approve(address(pool), 100e18);
        pool.withdraw(100e18, 90e18, 100e18, uint64(block.timestamp));
        assertEq(pool.totalSupply(), 0);
        assert(weth.balanceOf(liquidityProvider) + poolToken.balanceOf(liquidityProvider) > 400e18);
    }

    ///////////////////
    ///Finding Tests///
    ///////////////////

    function test_expectedFeesAreEqualToActualFees() external {
        uint256 intialLiquidity = 100e18;
        vm.startPrank(liquidityProvider);
        weth.approve(address(pool), intialLiquidity);
        poolToken.approve(address(pool), intialLiquidity);

        pool.deposit({
            wethToDeposit: intialLiquidity,
            minimumLiquidityTokensToMint: 0,
            maximumPoolTokensToDeposit: intialLiquidity,
            deadline: uint64(block.timestamp)
        });
        vm.stopPrank();

        //User has 11 tokens
        address someUser = makeAddr("someUser");
        uint256 userInitialPoolTokenBalance = 11e18;
        poolToken.mint(someUser, userInitialPoolTokenBalance);
        vm.startPrank(someUser);

        //User buys 1 WETH from the pool, paying with pool tokens
        poolToken.approve(address(pool), type(uint256).max);
        pool.swapExactOutput(
            poolToken,
            weth,
            1 ether,
            uint64(block.timestamp)
        );

        //Initial liquidity was 1:1 so user should have paid ~1 pool tokne
        //However it sends much more than that. User started with 11 tokens and now only has less than 1
        assertLt(poolToken.balanceOf(someUser), 1 ether);
        vm.stopPrank();

        //The liquidity proivder can run all funds from the pool now
        //including those deposited by the user
        vm.startPrank(liquidityProvider);

        pool.withdraw(
            pool.balanceOf(liquidityProvider),
            1,
            1,
            uint64(block.timestamp)
        );

        vm.stopPrank();

        assertEq(weth.balanceOf(address(pool)), 0);
        assertEq(poolToken.balanceOf(address(pool)), 0);

    }

    function test_returnValuesForswapExactInput() external {
        vm.startPrank(liquidityProvider);
        weth.approve(address(pool), 200e18);
        poolToken.approve(address(pool), 200e18);
        pool.deposit(200e18, 200e18, 200e18, uint64(block.timestamp));
        vm.stopPrank();

        //first user
        address firstUser = makeAddr("firstUser");
        uint256 userInitialPoolTokenBalance = 1e18;
        poolToken.mint(firstUser, userInitialPoolTokenBalance);
        vm.startPrank(firstUser);
        poolToken.approve(address(pool), type(uint256).max);
        uint256 firstSwapAmount = pool.swapExactInput(
            poolToken,
            1e18,
            weth,
            1,
            uint64(block.timestamp)
        );

        vm.stopPrank();

        //seconduser
        address secondUser = makeAddr("firstUser");
        uint256 secondUserInitialPoolTokenBalance = 100e18;
        poolToken.mint(secondUser, secondUserInitialPoolTokenBalance);
        vm.startPrank(secondUser);
        poolToken.approve(address(pool), type(uint256).max);
        uint256 secondSwapAmount = pool.swapExactInput(
            poolToken,
            100e18,
            weth,
            1,
            uint64(block.timestamp)
        );

        console.log(secondSwapAmount);

        //Since the first user is swapping much less tokens than the second user we should expect to see different outputs. 
        //However this is not the case. Both are defaulted to zero.

        assertEq(firstSwapAmount, secondSwapAmount);


    }
}
