## What Is Stablecoin??
  stablecoin is a crypto assets whose buying power fluctuate very little relative to the rest of market, where the price fluctuations is not very volatile

## Stablecoin Categories
  1. 2 types of stablecoins
    - pegged/tied stable coins have their value tied to another assets ( like usd )
    - floating stablecoins use math and other mechanism to maintain a constant buying power 
 2. stability methods
    - algorithmic ( the minting, burning, and collateralization determined by the code )
    - governed method ( minting, burning, and collateralization determined by governance/DAO )
 3. collateral types
    - endogenous => a collateral that originates from inside the protocol ( like TUSD ( terra usd ) uses a luna as a collateral which in the same protocol ), if TUSD fails the LUNA also will fail

    - exogenous => a collateral that originates from outside of a protocol ( like USDT uses usd as a collateral, which is from outside of the protocol ), if USDT fails then USD will not fail. bcoz its from outside of USDT protocol. But if the USD is failed then the dollar pegged stablecoin will fails.

 ## Example
   - USDT, USDC price pegged to USD ( harga USDT, USDC ter patok ke harga USD dollar ), the way it works is anytime we minted a new USDT token on-chain, there must be a collateral being deposited into a bank with the same amount of the minted USDT token on-chain.

### Advanced Testing
 - Fuzz/stateless is a property based testing, a testing that intend to break/exploit our system/app, basically this is a test on how a hacker can break into our system, foundry will try to pass a random data ( integers, strings or other types ) into arguments
   1. stateless fuzzing = where the state of previous run is discarded for every new run
   2. statefull fuzzing = where the final state of previous run is the starting state of the next run;
 - Invariant/stateful test is passing a random data and calling random functions
 - invariant is property that our system/app should always hold


## What determined the liquidation actions
  let's say the protocol set the `Liquidation Threshold` 80%, therefore user can only mint 80% RUSD token of their collateral value, by setting `MIN_HEALTH_FACTOR` the protocol could determined whether the `user A` collateral is `undercollateralized` or not, if it is then another user can come and liquidate the `user A` positions and earn yield. For this `Stablecoin` procotol we set `MIN_HEALTH_FACTOR`  to 1, if the user A or another user `health factor` is goes below 1, then another user can liquidate the user A positions and earn yield.

## How the liquidation works
 - supposed user A deposits $`1000` of collateral and minted `$800 RUSD` token (80% of collateral value), And later on the user A collateral value is went to `$950` or even low than that, Therefore user B or user C can liquidate a user A positions and earn profit by supplying the collateral value worth of the amount of RUSD token minted by user A and the collateral value left in the protocol will be send to the user B after liquidating it. That way we could make the protocol survive, encouraging users to keep monitoring their collateral value and making sure its always over collateralized, therefore keeping the protocol more safe and stable also providing more incentives for another users by liquidating undercollateralized user positions and earn yield.

 