// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

// Invariants aka properties

// what are our invariants/properties that our system have ?

// 1. total supply of DSC should be less than total value of collateral ( collateral supply should be more than DSC )
// 2. getter view function should never revert

import { Test, console } from "forge-std/Test.sol";
import { StdInvariant } from "forge-std/StdInvariant.sol";
import {  DSCEngine } from "../../src/DSCEngine.sol";
import { DeployDSC } from "../../script/DeployDSC.s.sol";
import { HelperConfig } from "../../script//HelperConfig.s.sol";
import { DecentralizedStableCoin } from "../../src/DecentralizedStablecoin.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Handler } from "./Handler.t.sol";

contract InvariantsTest is StdInvariant, Test {
    DeployDSC deployer;
    DSCEngine dscEngine;
    DecentralizedStableCoin dsc;
    HelperConfig config;
    Handler handler;
    address weth;
    address wbtc;

    function setUp() public {
        deployer = new DeployDSC();
        (dsc, dscEngine, config) = deployer.run();
        // targetContract(address(dscEngine)); // target contract to run an invariant test
        targetContract(address(handler)); // target contract to run an invariant test

        (, , weth, wbtc, ) = config.activeNetwork();
    }

    function invariant_protocolMustHaveMoreValueThanTotalSupply() public view {
        uint256 totalSupply = dsc.totalSupply();
        uint256 totalWethDeposited = IERC20(weth).balanceOf(address(dscEngine));
        uint256 totalWbtcDeposited = IERC20(wbtc).balanceOf(address(dscEngine));

        uint256 wethValue = dscEngine.getUsdValue(weth, totalWethDeposited);
        uint256 wbtcValue = dscEngine.getUsdValue(wbtc, totalWbtcDeposited);

        console.log("supply", totalSupply);
        console.log("totalWethDeposited", totalWethDeposited);

        assert(wethValue + wbtcValue > totalSupply);
    }
}