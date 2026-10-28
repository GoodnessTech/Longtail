# LongTail Protocol: Security Architecture & Audit Report

## 1. Security Overview
LongTail was engineered with blockchain security best practices, strict adherence to the Checks-Effects-Interactions (CEI) pattern, OpenZeppelin v5.0.2 audited primitives, and mathematical formal verification via Foundry fuzz and invariant testing.

---

## 2. Access Control Matrix

| Contract | Function | Caller / Role | Access Check |
| :--- | :--- | :--- | :--- |
| `LongTailMarketFactory` | `setImplementation` | Protocol Owner | `onlyOwner` |
| `LongTailMarketFactory` | `setDefaultResolver` | Protocol Owner | `onlyOwner` |
| `LongTailMarketFactory` | `setDefaultPricingModel` | Protocol Owner | `onlyOwner` |
| `LongTailMarketFactory` | `setFeeRecipient` | Protocol Owner | `onlyOwner` |
| `LongTailMarketFactory` | `withdrawFees` | Fee Recipient | `msg.sender == feeRecipient` |
| `LongTailMarketFactory` | `createMarket` | Anyone | Open (Permissionless) |
| `LongTailMarket` | `buy` | Anyone | `onlyActive`, `nonReentrant` |
| `LongTailMarket` | `sell` | Anyone | `onlyActive`, `nonReentrant` |
| `LongTailMarket` | `addLiquidity` | Anyone | `onlyActive`, `nonReentrant` |
| `LongTailMarket` | `removeLiquidity` | LP Holders | `onlyActive`, `nonReentrant` |
| `LongTailMarket` | `setStatus` | Authorized Resolver | `msg.sender == config.resolver` |
| `LongTailMarket` | `setOutcome` | Authorized Resolver | `msg.sender == config.resolver` |
| `LongTailMarket` | `redeem` | Winning Share Holders | `nonReentrant` |
| `LongTailOutcomeToken` | `mintOutcome` | Authorized Market Clone | `msg.sender == factory.getMarketAddress(marketId)` |
| `LongTailOutcomeToken` | `burnOutcome` | Authorized Market Clone | `msg.sender == factory.getMarketAddress(marketId)` |
| `OptimisticResolver` | `resolveDispute` | Arbitrator / Owner | `onlyArbitrator`, `nonReentrant` |
| `OptimisticResolver` | `cancelMarket` | Arbitrator / Owner | `onlyArbitrator`, `nonReentrant` |

---

## 3. Defense Against Known Attack Vectors

### 3.1 Reentrancy Protection
- All state-modifying functions that involve external calls or native BOT transfers implement OpenZeppelin's `ReentrancyGuard` (`nonReentrant`).
- Strict Checks-Effects-Interactions (CEI): User position tokens are burned and internal balances are decremented *before* executing low-level native BOT transfers (`call{value: ...}("")`).

### 3.2 Double-Redemption Prevention
In `LongTailMarket.sol`:
- When a user calls `redeem()`, their ERC-1155 outcome tokens are burned *first*:
  ```solidity
  outcomeToken.burnOutcome(config.marketId, msg.sender, isYes, winningShares);
  reservedSettlement -= winningShares;
  collateralBalance -= winningShares;
  ```
- Any subsequent attempt to call `redeem()` queries `outcomeToken.balanceOf(msg.sender, ...)` which returns 0, immediately reverting with `Errors.NoSharesToRedeem()`.

### 3.3 Free Liquidity Drainage Protection
- `removeLiquidity` calculates available free surplus liquidity above the maximum potential liability:
  $$\text{Free Liquidity} = \text{Collateral Balance} - \max(q_{YES}, q_{NO})$$
- Liquidity providers can never drain the collateral reserved for winning payouts. Invariant test `invariant_CollateralAlwaysExceedsLiability` fuzzed 256 random trades and verified this holds across all trajectories.

### 3.4 Front-Running & MEV Slippage Protection
- Both `buy` and `sell` accept user-specified slippage bounds:
  - `buy(isYes, minSharesOut)`: Reverts with `Errors.SlippageExceeded()` if `sharesBought < minSharesOut`.
  - `sell(isYes, sharesIn, minBotOut)`: Reverts with `Errors.SlippageExceeded()` if `botProceeds < minBotOut`.

### 3.5 Numerical Overflow & Precision Loss
- Solc `0.8.24` includes default arithmetic overflow checks.
- Factored LMSR cost function $C(q_1, q_2) = \max(q_1, q_2) + b \ln(1 + \exp(-|q_1 - q_2|/b))$ bounds the exponent in $(0, 1]$, making exponential overflow mathematically impossible.
