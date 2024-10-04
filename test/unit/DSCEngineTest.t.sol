// SPDX-Licenses-Identifier: MIT;
pragma solidity ^0.8.18;

import { Test, console } from "forge-std/Test.sol";
import { DSCEngine } from "../../src/DSCEngine.sol";
import { RUSD } from "../../src/RUSD.sol";
import { DeployRUSD } from "../../script/DeployRUSD.s.sol";
import { HelperConfig } from "../../script/HelperConfig.s.sol";
import { MockERC20 } from "../mocks/MockERC20.t.sol";
import { MockV3Aggregator } from "../mocks/MockV3Aggregator.t.sol";
 
contract DSCEngineTest is Test {
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
        mockV3Aggregator = new MockV3Aggregator(8, 0);
        //  two ways to get value from return function and assign to var;
        (RUSD dsc_, DSCEngine dscEngine_, HelperConfig config_ ) = deployer.run();
         config = config_;
        (ethUsdPriceFeed, btcUsdPriceFeed, weth , ,) = config.activeNetwork(); 

        dsc = dsc_;
        dscEngine = dscEngine_;

        vm.prank(INITIAL_OWNER);
        dsc.transferOwnership(address(dscEngine));
        MockERC20(weth).mint(USER, 100 ether);
    }

    /////////////////// constructor test /////////////////////////
    address[] tokenAddresses;
    address[] priceFeedAddresses;

    function test_revertIfTokenLengthDoesntMatchPriceFeeds() public {
        tokenAddresses.push(weth);
        priceFeedAddresses.push(ethUsdPriceFeed);
        priceFeedAddresses.push(btcUsdPriceFeed);

        // anything after expectRevert will fail, which is exactly what we wanna test
        vm.expectRevert(DSCEngine.DSCEngine_TokenLengthMustBeSameWithPriceFeedAddresses.selector);
        new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));
    }

    function test_checkOwner() public view {
        // console.log(dsc.getOwner());
        // console.log(dsc.getOwner());
        console.log(dsc.owner());
        assert(dsc.owner() == address(dscEngine));
    }

    function test_ethUsdValue() public view {
        uint256 ethAmount = 10e18;  // 10 ETH
        // 10 ETH = $2000 * 10 ETH = $20,000
        uint256 expectedUsd = 20_000e18;
        uint256 actualUsd = dscEngine.getUsdValue(weth, ethAmount);

        console.log(actualUsd);
        assert(actualUsd == expectedUsd);
    }

    function test_getTokenAmountFromUsd() public {
        uint256 usdAmount = 100 ether;
        // $2000/ETH ( $100 = 0.05 ether );
        uint256 expectedWeth = 0.05 ether;
        uint256 actualWeth = dscEngine.getTokenAmountFromUsd(weth, usdAmount);
        assertEq(expectedWeth, actualWeth);
    }

    function test_revertIfCollateralZero() public {
        vm.prank(USER);
        MockERC20(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);

        vm.expectRevert(DSCEngine.DSCEngine_NeedsMoreThanZero.selector); // anything after this line expected tobe revert it
        dscEngine.depositCollateral(weth, 0);
        vm.stopPrank();
    }

    function test_revertWithWithUnapprovedToken() public {
        MockERC20 randomToken = new MockERC20("Ran", "Rand", USER, AMOUNT_COLLATERAL);
        vm.prank(USER);

        vm.expectRevert(DSCEngine.DSCEngine_NotAllowedToken.selector);
        dscEngine.depositCollateral(address(randomToken), AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    modifier DepositCollateral() {
        vm.prank(USER);
        MockERC20(weth).approve(address(dscEngine), AMOUNT_COLLATERAL / 2);
        dscEngine.depositCollateral(weth, AMOUNT_COLLATERAL / 2);
        vm.stopPrank();
        _;
    }

    function test_canDepositAndGetUserInfo() public DepositCollateral {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dscEngine.getUserInformation(USER);

        uint256 expectedDscMinted = 0;
        uint256 expectedDepositAmount = dscEngine.getTokenAmountFromUsd(weth, collateralValueInUsd);

        assertEq(totalDscMinted, expectedDscMinted);
        assertEq(AMOUNT_COLLATERAL, expectedDepositAmount);
    }

    function test_notEnoughCollateralBalance() public {
        vm.prank(USER);
        MockERC20(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        uint256 senderBalance = MockERC20(weth).balanceOf(USER);
        uint256 allowances = MockERC20(weth).allowance(USER, address(dscEngine));

        vm.expectRevert(DSCEngine.DSCEngine_InsufficientCollateralBalance.selector);
        dscEngine.depositCollateral(weth, 150 ether);

        assertEq(allowances, AMOUNT_COLLATERAL);
    }

    function test_depositCollateralAndMint() public {
        vm.startPrank(USER);
        uint256 userInitBalance = dsc.balanceOf(USER);
        MockERC20(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        dscEngine.depositCollateralAndMintDSC(weth, AMOUNT_COLLATERAL, RUSD_AMOUNT);

        uint256 userAfterBalance = dsc.balanceOf(USER);
        console.log("after balance", userAfterBalance);
        vm.stopPrank();

        assert(userAfterBalance > userInitBalance);
    }

    function test_depositCollateralAndBreaksHealthFactor() public {
        uint256 rusdAmount = 1400 ether;
        vm.startPrank(USER);
        uint256 userInitBalance = dsc.balanceOf(USER);
        MockERC20(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        vm.expectRevert(DSCEngine.DSCEngine_BreaksHealthFactor.selector);
        dscEngine.depositCollateralAndMintDSC(weth, AMOUNT_COLLATERAL, rusdAmount);     

        uint256 userAfterBalance = dsc.balanceOf(USER);
        console.log("after balance", userAfterBalance);
        vm.stopPrank();

        assert(userAfterBalance == userInitBalance);
    }

    function test_redeemZeroCollateral() public {
        vm.startPrank(USER);
        uint256 userBalanceBfore = MockERC20(weth).balanceOf(USER);
        vm.expectRevert(DSCEngine.DSCEngine_ZeroCollateralAvailable.selector);
        dscEngine.redeemCollateral(weth, AMOUNT_COLLATERAL);

        uint256 userBalanceAfter = MockERC20(weth).balanceOf(USER);
        vm.stopPrank();

        console.log("cannot redeem zero collateral");
        assert(userBalanceAfter == userBalanceBfore);
    }

}