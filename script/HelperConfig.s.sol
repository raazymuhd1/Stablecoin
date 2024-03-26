// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import { Script } from "forge-std/Script.sol";
import { MockV3Aggregator } from "../test/mocks/MockV3Aggregator.t.sol";
import { MockERC20 } from "../test/mocks/MockERC20.t.sol";

contract HelperConfig is Script {

    NetworkConfig public activeNetwork;
    uint8 private constant DECIMALS = 8;
    int256 private constant ETH_USD_PRICE = 2000e8;
    int256 private constant BTC_USD_PRICE = 1000e8;


    struct NetworkConfig {
        address wethPriceFeed;
        address wbtcPriceFeed;
        address weth;
        address wbtc;
        uint256 deployerKey;
    }

    constructor() {
        if(block.chainid == 11155111) {
            activeNetwork = networkSepoliaConfig();
        } else {
            activeNetwork = networkAnvilConfig();
        }
    }

    function networkSepoliaConfig() public view returns(NetworkConfig memory) {
        return NetworkConfig({
            wethPriceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306,
            wbtcPriceFeed: 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43,
            weth: 0xdd13E55209Fd76AfE204dBda4007C227904f0a81,
            wbtc: 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063,
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }


    function networkAnvilConfig() public returns(NetworkConfig memory) {
         return getOrCreateAnvilConfig();
    }

    function getOrCreateAnvilConfig() public returns(NetworkConfig memory) {
         if(activeNetwork.wethPriceFeed != address(0)) {
              return activeNetwork;
         }

         vm.startBroadcast();
         MockV3Aggregator ethUsdPriceFeed = new MockV3Aggregator(DECIMALS, ETH_USD_PRICE);
         MockV3Aggregator btcUsdPriceFeed = new MockV3Aggregator(DECIMALS, BTC_USD_PRICE);
         MockERC20 wethMock = new MockERC20("WETH", "WETH", msg.sender, 1000e8);
         MockERC20 wbtcMock = new MockERC20("WBTC", "WBTC", msg.sender, 1000e8);

         vm.stopBroadcast();

         return NetworkConfig({
            wethPriceFeed: address(ethUsdPriceFeed),
            wbtcPriceFeed: address(btcUsdPriceFeed),
            weth: address(wethMock),
            wbtc: address(wbtcMock),
            deployerKey: vm.envUint("ANVIL_PRIVATE_KEY")
         });

    }
}