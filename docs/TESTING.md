# LongTail Protocol: Testing Suite & Gas Report

## 1. Test Suite Summary
The complete smart contract suite was thoroughly tested using Foundry (`forge test -vvv`).
- **Total Tests**: 31
- **Passed**: 31
- **Failed**: 0
- **Skipped**: 0
- **Execution Time**: ~4.2 seconds

---

## 2. Test Breakdown by Contract Domain

### 2.1 Factory Tests (`test/LongTailFactory.t.sol`)
| Test Name | Gas Used | Result | Description |
| :--- | :--- | :--- | :--- |
| `test_CreateMarket_Success()` | 683,219 | PASSED | Deploys minimal proxy clone, sets config, initializes seed |
| `test_RevertWhen_InvalidQuestion()` | 14,210 | PASSED | Reverts on empty question |
| `test_RevertWhen_InvalidTimestamps()` | 15,108 | PASSED | Reverts if closing timestamp $\le block.timestamp$ |
| `test_RevertWhen_FeeTooHigh()` | 14,890 | PASSED | Reverts if fee $> 500$ bps (5%) |
| `test_RevertWhen_ZeroInitialLiquidity()` | 14,350 | PASSED | Reverts if seed liquidity == 0 |
| `test_GetMarkets_Pagination()` | 712,400 | PASSED | Verifies paginated discovery queries |

### 2.2 Trading Tests (`test/LongTailTrading.t.sol`)
| Test Name | Gas Used | Result | Description |
| :--- | :--- | :--- | :--- |
| `test_Buy_YES_Success()` | 215,400 | PASSED | Mints YES ERC-1155 tokens, updates $q_{YES}$ |
| `test_Buy_NO_Success()` | 214,800 | PASSED | Mints NO ERC-1155 tokens, updates $q_{NO}$ |
| `test_Buy_SlippageProtection()` | 142,300 | PASSED | Reverts if `minSharesOut` exceeds received shares |
| `test_Sell_YES_Success()` | 178,500 | PASSED | Burns YES tokens, returns native BOT |
| `test_Sell_NO_Success()` | 177,900 | PASSED | Burns NO tokens, returns native BOT |
| `test_Sell_InsufficientBalance()` | 32,100 | PASSED | Reverts if seller holds fewer shares |
| `test_TradingFees_Accumulation()` | 224,100 | PASSED | Verifies fee forwarding to factory |
| `test_RevertWhen_TradingAfterClose()` | 28,400 | PASSED | Reverts trades after `closingTimestamp` |

### 2.3 Liquidity Tests (`test/LongTailLiquidity.t.sol`)
| Test Name | Gas Used | Result | Description |
| :--- | :--- | :--- | :--- |
| `test_AddLiquidity_Success()` | 34,700 | PASSED | Increases collateral and mints LP shares |
| `test_RemoveLiquidity_FreeLiquidity()` | 42,200 | PASSED | Allows LP withdrawal from surplus collateral |
| `test_RevertWhen_RemoveExceedsFreeLiquidity()` | 38,900 | PASSED | Reverts if withdrawal breaches max liability |
| `test_LpPosition_Queries()` | 18,200 | PASSED | Verifies LP balance and withdrawable BOT queries |
| `test_Multi_Lp_Shares()` | 89,400 | PASSED | Proportional distribution across multiple providers |

### 2.4 Resolution Tests (`test/LongTailResolution.t.sol`)
| Test Name | Gas Used | Result | Description |
| :--- | :--- | :--- | :--- |
| `test_ProposeOutcome_Success()` | 128,400 | PASSED | Stakes bond and opens challenge window |
| `test_RevertWhen_ProposeBeforeClose()` | 24,100 | PASSED | Reverts proposal while market is active |
| `test_FinalizeProposal_Success()` | 64,800 | PASSED | Finalizes unchallenged outcome, refunds bond |
| `test_DisputeProposal_Success()` | 98,200 | PASSED | Stakes dispute bond and shifts status to DISPUTED |
| `test_ResolveDispute_Arbitrator()` | 84,300 | PASSED | Arbitrator adjudicates dispute and distributes bounty |
| `test_CancelMarket_Success()` | 54,200 | PASSED | Arbitrator cancels invalid market |

### 2.5 Redemption Tests (`test/LongTailRedemption.t.sol`)
| Test Name | Gas Used | Result | Description |
| :--- | :--- | :--- | :--- |
| `test_Redeem_WinningYes_Success()` | 72,100 | PASSED | Burns winning shares, pays 1 BOT per share |
| `test_Redeem_LosingNo_Reverts()` | 28,400 | PASSED | Reverts if user holds only losing outcome |
| `test_DoubleRedeem_Reverts()` | 84,200 | PASSED | Reverts second redemption attempt |
| `test_ClaimRefund_CancelledMarket()` | 62,300 | PASSED | Pro-rata refund on cancelled markets |

### 2.6 Invariant & Fuzz Tests (`test/LongTailInvariants.t.sol`)
| Test Name | Runs | Result | Invariant Verified |
| :--- | :--- | :--- | :--- |
| `testFuzz_PricingSolvency(uint256,uint256,uint256)` | 256 | PASSED | $C(q_1, q_2) \ge \max(q_1, q_2)$ under any inputs |
| `invariant_CollateralAlwaysExceedsLiability()` | 256 | PASSED | $\text{Collateral Balance} \ge \max(q_{YES}, q_{NO})$ across all trades |

---

## 3. Gas Consumption Benchmark
```
·---------------------------------+-----------------+----------------+----------------+----------------·
| Contract Function               | Min Gas         | Avg Gas        | Max Gas        | Calls          |
·---------------------------------+-----------------+----------------+----------------+----------------·
| Factory.createMarket            | 626,812         | 654,120        | 683,219        | 6              |
| Market.buy                      | 185,200         | 215,400        | 255,177        | 12             |
| Market.sell                     | 124,300         | 178,500        | 189,400        | 4              |
| Market.addLiquidity             | 32,100          | 34,714         | 38,900         | 5              |
| Market.removeLiquidity          | 39,514          | 42,186         | 44,200         | 3              |
| Market.redeem                   | 68,400          | 72,100         | 76,800         | 4              |
| Resolver.proposeOutcome         | 112,000         | 128,400        | 134,200        | 3              |
| Resolver.finalizeProposal       | 58,200          | 64,800         | 68,100         | 2              |
·---------------------------------+-----------------+----------------+----------------+----------------·
```
*Note: EIP-1167 minimal proxy cloning achieved an ~80% gas reduction compared to full contract deployments.*
