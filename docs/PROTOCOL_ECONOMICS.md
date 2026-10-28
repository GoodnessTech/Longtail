# LongTail Protocol: Economics & Tokenomics

## 1. Native BOT Asset Mechanics
**LongTail** uses native `BOT` as both the network gas asset and the sole collateral backing for prediction markets:
- **No Synthetic Wrapped Token Friction**: Users trade and provide liquidity directly using native `BOT`. No `WETH` or `WBOT` wrapping approval transactions required.
- **Gas Alignment**: Every trade, liquidity provision, and redemption burns Bohr Testnet / BOT Chain gas and expands the utility of the native token.
- **Payoff Scale**: 1 outcome share redeems for exactly $1.00 \text{ BOT}$ upon positive resolution.

---

## 2. Fee Routing & Treasury Split
Protocol fees are configured per-market at creation time, bounded by protocol governance:
- **Default Fee**: 100 basis points ($1.00\%$).
- **Maximum Allowed Fee**: 500 basis points ($5.00\%$). Enforced by `LongTailMarketFactory.sol:71`.
- **Fee Collection Flow**:
  1. On each `buy(isYes, minSharesOut)`:
     $$\text{fee} = \frac{\text{msg.value} \cdot \text{feeBps}}{10000}$$
     $$\text{netCost} = \text{msg.value} - \text{fee}$$
     The fee is immediately forwarded to `factory` via low-level call:
     ```solidity
     (bool feeSent, ) = factory.call{ value: fee }("");
     if (!feeSent) revert Errors.TransferFailed();
     ```
  2. The factory tracks accumulated protocol fees and exposes `withdrawFees()` to the authorized protocol treasury.
  3. Market LPs capture the remaining value appreciation through LMSR pool depth growth.

---

## 3. Liquidity Provider Mechanics & Free Liquidity

### 3.1 Initial Seed Liquidity
When creating a market, the creator provides native BOT seed liquidity (e.g., 0.15 - 0.20 BOT).
- The seed sets the initial LMSR liquidity parameter: $b = \text{seedLiquidity}$.
- Initial LP shares are minted 1:1 with the seed:
  $$\text{initialLpShares} = \text{msg.value}$$

### 3.2 Free Liquidity vs. Reserved Settlement Payouts
A critical security invariant in LongTail is that **LP withdrawals must never compromise the protocol's ability to pay out winning traders**.

At any time:
$$\text{Max Liability} = \begin{cases} q_{YES} & \text{if resolved YES} \\ q_{NO} & \text{if resolved NO} \\ \max(q_{YES}, q_{NO}) & \text{if active} \end{cases}$$

The **Free Liquidity** available for LP withdrawal is:
$$\text{Free Liquidity} = \max\left(0, \text{Collateral Balance} - \text{Max Liability}\right)$$

### 3.3 LP Share Value & Withdrawal
When an LP calls `removeLiquidity(lpShares)`:
$$\text{Withdrawal Amount} = \frac{\text{lpShares}}{\text{totalLpShares}} \cdot \text{Free Liquidity}$$
If an LP attempts to withdraw an amount exceeding Free Liquidity, the call reverts with `Errors.InsufficientLiquidity()`.

---

## 4. Economic Security & Bond Dynamics in Optimistic Resolution
`OptimisticResolver` establishes economic incentives for honest market resolution:
- **Proposal Bond**: $0.01 \text{ BOT}$ minimum.
- **Dispute Bond**: $0.02 \text{ BOT}$ minimum ($2 \times$ proposal bond).
- **Incentive Alignment**:
  - Honest proposer receives 100% of their bond back upon finalization.
  - If a proposer lies and is successfully challenged, the challenger receives the proposer's forfeited bond as a bounty.
  - If a challenger files a frivolous dispute, their dispute bond is forfeited and awarded to the proposer.
