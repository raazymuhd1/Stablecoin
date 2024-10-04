// SPDX-Licenses-Identifier: MIT;
pragma solidity ^0.8.18;

import { Test, console } from "forge-std/Test.sol";
import { DSCEngine } from "../../src/DSCEngine.sol";
import { RUSD } from "../../src/RUSD.sol";
import { DeployRUSD } from "../../script/DeployRUSD.s.sol";
import { HelperConfig } from "../../script/HelperConfig.s.sol";
import { MockERC20 } from "../mocks/MockERC20.t.sol";
import { MockV3Aggregator } from "../mocks/MockV3Aggregator.t.sol";

contract DSCEngineIntegrations is Test {
    RUSD dsc;
    DSCEngine dscEngine;
    DeployRUSD deployer;
    HelperConfig config;
    MockV3Aggregator mockV3Aggregator;

    address private constant USER = address(1);
    address private constant INITIAL_OWNER = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    uint256 private constant AMOUNT_COLLATERAL = 1 ether;
    uint256 private constant RUSD_AMOUNT = 1000 ether;
    address private constant UNALLOWED_TOKEN = address(0);
    address private ethUsdPriceFeed;
    address private btcUsdPriceFeed;
    address private weth;

    function setUp() public {
        deployer = new DeployRUSD();
        (RUSD dsc_, DSCEngine dscEngine_, HelperConfig config_ ) = deployer.run();
         config = config_;
        (ethUsdPriceFeed, btcUsdPriceFeed, weth , ,) = config.activeNetwork(); 

        dsc = dsc_;
        dscEngine = dscEngine_;

        vm.prank(INITIAL_OWNER);
        // transerring ownership to the DSCEngine from the initial owner
        dsc.transferOwnership(address(dscEngine));
        MockERC20(weth).mint(USER, 100 ether);
    }

    function test_depositCollateralAndRedeem() public {
        vm.startPrank(USER);
        uint256 userInitialBalance = MockERC20(weth).balanceOf(USER);
        MockERC20(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);

        dscEngine.depositCollateral(weth, AMOUNT_COLLATERAL);
        dscEngine.redeemCollateral(weth, AMOUNT_COLLATERAL);
        uint256 userAfterBalance = MockERC20(weth).balanceOf(USER);

        console.log("user balance after a collateral redemption");
        vm.stopPrank();

        assert(userAfterBalance == userInitialBalance);
    }
}