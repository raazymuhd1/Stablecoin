// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

import { Script } from "forge-std/Script.sol";
import { DSCEngine } from "../src/DSCEngine.sol";
import { RUSD } from "../src/RUSD.sol";
import { HelperConfig } from "./HelperConfig.s.sol";

contract DeployRUSD is Script {
    HelperConfig config;
    address[] tokenAddresses;
    address[] priceFeedAddresses;
    address private constant DSC_CONTRACT_OWNER = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    function run() public returns(RUSD, DSCEngine, HelperConfig) {
        config = new HelperConfig();
        (address wethPriceFee, address wbtcPriceFeed, address weth, address wbtc, uint256 deployerKey) = config.activeNetwork();

        priceFeedAddresses = [wethPriceFee, wbtcPriceFeed];
        tokenAddresses = [weth, wbtc];

        vm.startBroadcast(deployerKey);
        RUSD dsc = new RUSD(DSC_CONTRACT_OWNER);
        DSCEngine dscEngine = new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));

        // dsc.transferOwnership(address(dscEngine)); // only dsc engine can govern DecentralizeStablecoin token;
        vm.stopBroadcast();

        return (dsc, dscEngine, config);

    }

}