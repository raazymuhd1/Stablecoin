// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

// this handler is to narrow down our invariant test to randomly call only on the function we need ( which is what specicify in this handler ) 

import { Test } from "forge-std/Test.sol";
import { DSCEngine } from "../../src/DSCEngine.sol";
import { DecentralizedStableCoin } from "../../src/DecentralizedStablecoin.sol";
import { MockERC20 } from "../mocks/MockERC20.t.sol";


contract Handler is Test {
    DSCEngine dscEngine;
    DecentralizedStableCoin dsc;

    MockERC20 weth;
    MockERC20 wbtc;

    constructor(DSCEngine dscEngine_, DecentralizedStableCoin dsc_) {
        dscEngine = dscEngine_;
        dsc = dsc_;

        address[] memory collateralTokens = dscEngine.getCollateralTokens();
        weth = MockERC20(collateralTokens[0]);
        wbtc = MockERC20(collateralTokens[1]);
    }

    function depositCollateral(uint collateralSeed, uint256 amount) public {
        MockERC20 collateralToken = _getCollateralFromSeed(collateralSeed);

        dscEngine.depositCollateral(address(collateralToken), amount);

    }

    function _getCollateralFromSeed(uint256 collateralSeed) public returns(MockERC20) {
        if(collateralSeed % 2 == 0) {
            return weth;
        }

        return wbtc;
    }
}