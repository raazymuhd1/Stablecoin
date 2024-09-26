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


