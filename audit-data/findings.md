## High

### [H-1] Incorrect fee calculation in `TSwapPool::getInputAmountBasedOnOutput` causes protocol to take too many too many tokens form user, resulting in lost fees.

**Description:** The `getInputAmountBasedOnOutput` function is intended to calculate the amount of tokens a user should eposit given an amount of output tokens. However the function currently miscalculates the resulting amount. When calculating the fee, it scales the amoutn by 10_000 instead of 1_000.

**Impact:** Protocol takes more fees than expected from users.


**Recommended Mitigation:** 

```diff
 function getInputAmountBasedOnOutput(uint256 outputAmount,uint256 inputReserves,uint256 outputReserves) public pure
        revertIfZero(outputAmount)
        revertIfZero(outputReserves)
        returns (uint256 inputAmount)
    {
        // 91.3% fee???
        //@audit - high 
        return
-            ((inputReserves * outputAmount) * 10000) /
+           ((inputReserves * outputAmount) * 1000) /
            ((outputReserves - outputAmount) * 997);
    }


```




## Medium

### [M-1] `TSwapPool::deposit` is missing deadline check causing transactions to complete even after the deadline.

**Description:**  The `deposit` function accepts a deadline parameter, which according to the documention "@param deadline The deadline for the transaction to be completed by". However, this parameter is never used. As a consequence, operations that add liquidity tothe pool might be executed at times, in market conditions where the deposte rate is unfavorable. 

<!-- MEV attacks -->

**Impact:** Transactions could be sent when market conditions are unfavorable to deposit, even adding when adding a deadline parameter. 

**Proof of Concept:** The `deadline` parameter is unused. 

**Recommended Mitigation:** Consider making the following change to the function. 

```diff
    function deposit(
        uint256 wethToDeposit,
        uint256 minimumLiquidityTokensToMint,
        uint256 maximumPoolTokensToDeposit,
        uint64 deadline
    )
        external
+        revertIfDeadlinePassed(deadline)
        revertIfZero(wethToDeposit)
        returns (uint256 liquidityTokensToMint)
    { 
```

## Low

### [L-1] `TSwapPool::Liqudiity` has parameters outof order causing event to emit incorrect information.

**Description:** When the `Liqudiity` event is emiited in `TSwapPool::_addLiquidityMintAndTransfer` function, it logs values in an incorrect order. The `poolTokensToDeposit` value should go in the third parameter position, whereas the `wethToDeposit` value should go second.

**Impact:** Event emission is incorerct, leading to off-chain functions potentially malfunctioning.

**Recommended Mitigation:**  
```diff
-emit LiquidityAdded(msg.sender, poolTokensToDeposit, wethToDeposit);
+emit LiquidityAdded(msg.sender, wethToDeposit, poolTokensToDeposit);
```

## Gas

## Informationals

### [I-1] Error `PoolFactory::PoolFactory__PoolDoesNotExist` is not used and should be removed. 

```diff
-   error PoolFactory__PoolDoesNotExist(address tokenAddress);
```

### [I-2] Constructor of `PoolFactory` is lacking zero address check.

```diff
    constructor(address wethToken) {
+        if(wethToken == address(0)) {revert();}
        i_wethToken = wethToken;
    }
```

### [I-3] `PoolFactory::createPool` should use `.symboL()` instead of `.name()`

```diff
-   string memory liquidityTokenSymbol = string.concat("ts", IERC20(tokenAddress).name())
+   string memory liquidityTokenSymbol = string.concat("ts", IERC20(tokenAddress).symbol())
```


## [I-4]: Events in `TSwapPool` are missing `indexed` fields

Index event fields make the field more quickly accessible to off-chain tools that parse events. However, note that each index field costs extra gas during emission, so it's not necessarily best to index the maximum allowed per event (three fields). Each event should use three indexed fields if there are three or more fields, and gas usage is not particularly of concern for the events in question. If there are fewer than three fields, all of the fields should be indexed.

<summary> Instances </summary>
<details>

- Found in src/TSwapPool.sol [Line: 52](src/TSwapPool.sol#L52)

	```solidity
	    event LiquidityAdded(
	```

- Found in src/TSwapPool.sol [Line: 57](src/TSwapPool.sol#L57)

	```solidity
	    event LiquidityRemoved(
	```

- Found in src/TSwapPool.sol [Line: 62](src/TSwapPool.sol#L62)

	```solidity
	    event Swap(
	```


</details>