# LongTail Protocol: Architecture Specification

## 1. Overview & Protocol Mission
**LongTail** is permissionless prediction-market infrastructure built natively on **BOT Chain** (and deployed to **Bohr Testnet**). The protocol democratizes forecasting by allowing anyone to create, price, trade, and provide liquidity to prediction markets for any verifiable question.

LongTail uses:
- **EIP-1167 Minimal Proxy Clones** to deploy new markets at ~80% reduced gas cost (~680k gas vs ~3.5M gas).
- **Logarithmic Market Scoring Rule (LMSR)** pricing engine guaranteeing continuous bid/ask liquidity with bounded protocol loss.
- **ERC-1155 Multi-Token Outcome Tokens** (`LongTailOutcomeToken`) with deterministic token IDs (`marketId << 1 | isYes ? 0 : 1`).
- **Bonded Optimistic Resolution** (`OptimisticResolver`) featuring decentralized proposals, challenge periods, dispute arbitration, and cancellation failsafes.
- **Native BOT Collateral & Settlement** with complete mathematical liability coverage ($Collateral \ge \max(q_{YES}, q_{NO})$).

---

## 2. Core Architecture Diagram

```
                        ┌──────────────────────────────────────┐
                        │        LongTailMarketFactory         │
                        │ 0xd72480faD3a5D732d753515dCf966aa93b9│
                        └──────────────────┬───────────────────┘
                                           │
                  ┌────────────────────────┼────────────────────────┐
                  │ creates EIP-1167 clone │                        │ registers
                  ▼                        ▼                        ▼
       ┌─────────────────────┐  ┌─────────────────────┐  ┌───────────────────────┐
       │   LongTailMarket    │  │   LongTailMarket    │  │  LongTailOutcomeToken │
       │     (Market #1)     │  │     (Market #2)     │  │ 0x4CD980838F7417a849C8│
       └──────────┬──────────┘  └──────────┬──────────┘  └───────────▲───────────┘
                  │                        │                         │
                  │ calls mint/burn        │ calls mint/burn         │
                  └────────────────────────┴─────────────────────────┘
                                           │
                  ┌────────────────────────┴────────────────────────┐
                  │                                                 │
                  ▼                                                 ▼
       ┌─────────────────────┐                           ┌─────────────────────┐
       │   LMSRPricingModel  │                           │  OptimisticResolver │
       │ 0xfA58368866CA320da3│                           │ 0x97c73c1E6864a4AD15│
       └─────────────────────┘                           └─────────────────────┘
```

---

## 3. Component Breakdown

### 3.1 LongTailMarketFactory (`LongTailMarketFactory.sol`)
- **Address**: `0xd72480faD3a5D732d753515dCf966aa93b9c4B8B`
- **Role**: Central protocol registry, EIP-1167 minimal proxy deployer, and market discoverability index.
- **Key Responsibilities**:
  - Validates market question length, closing timestamp bounds ($closing > block.timestamp$), resolution deadline bounds ($resolution > closing$), fee basis points ($\le 500$ bps), and non-zero seed liquidity.
  - Clones the canonical `LongTailMarket` implementation via OpenZeppelin `Clones.clone()`.
  - Initializes the clone with native BOT seed liquidity, setting initial $b = seedLiquidity$.
  - Maintains `marketAddresses` array and mapping of `creatorMarkets[creator]`.
  - Exposes paginated `getMarkets(offset, limit)` for high-performance frontend queries.
  - Collects protocol fees forwarded from markets and exposes `withdrawFees()`.

### 3.2 LongTailMarket Implementation (`LongTailMarket.sol`)
- **Address**: `0xaEbB38aDF3AADCd959D0667EaCa505578b206413`
- **Role**: Canonical logic contract instantiated by each minimal proxy clone.
- **Key Responsibilities**:
  - **State Machine**: `CREATED` $\rightarrow$ `ACTIVE` $\rightarrow$ `CLOSED` $\rightarrow$ `PROPOSED` $\rightarrow$ `DISPUTED` $\rightarrow$ `RESOLVED_YES` / `RESOLVED_NO` / `CANCELLED`.
  - **Trading**:
    - `buy(bool isYes, uint256 minSharesOut)`: Calculates gross/net cost, derives share quantity from pricing engine, mints ERC-1155 outcome tokens, and routes protocol fee to factory.
    - `sell(bool isYes, uint256 sharesIn, uint256 minBotOut)`: Burns ERC-1155 outcome tokens, calculates proceeds via pricing engine, and transfers native BOT.
  - **Liquidity Management**:
    - `addLiquidity()`: Accepts native BOT, increases total LP shares, and boosts pool depth.
    - `removeLiquidity(uint256 lpShares)`: Computes available free surplus liquidity above reserved maximum liabilities ($collateral - \max(q_{YES}, q_{NO})$) and safely burns LP shares.
  - **Settlement & Redemption**:
    - `redeem()`: Once resolved by the authorized resolver, pays out 1 BOT per winning share. Single-action non-reentrant execution preventing double-claims.
    - `claimRefund()`: If cancelled, refunds pro-rata collateral based on total shares outstanding.

### 3.3 LongTailOutcomeToken (`LongTailOutcomeToken.sol`)
- **Address**: `0x4CD980838F7417a849C8d8dAF055Df50FD9648c6`
- **Role**: Multi-token ERC-1155 representing outcome shares across all protocol markets.
- **Deterministic Token ID Scheme**:
  $$\text{tokenId} = (\text{marketId} \ll 1) \mid (\text{isYes} \ ? \ 0 : 1)$$
  - Market 1 YES: ID `2` (`0b0010`), Market 1 NO: ID `3` (`0b0011`)
  - Market 2 YES: ID `4` (`0b0100`), Market 2 NO: ID `5` (`0b0101`)
  - Market 3 YES: ID `6` (`0b0110`), Market 3 NO: ID `7` (`0b0111`)
- **Access Control**:
  - `mintOutcome` and `burnOutcome` are strictly restricted to the authorized market address resolved dynamically from `factory.getMarketAddress(marketId)`.

### 3.4 LMSRPricingModel (`LMSRPricingModel.sol`)
- **Address**: `0xfA58368866CA320da3deaA2F4fdDdf0228eDf273`
- **Role**: Stateless, modular LMSR pricing engine implementing `IPricingModel`.
- **Key Responsibilities**:
  - Numerically stable cost function using factored max-shift:
    $$C(q_1, q_2) = \max(q_1, q_2) + b \cdot \ln(1 + \exp(-|q_1 - q_2|/b))$$
  - Probability computation:
    $$P(YES) = \frac{\exp(q_{YES}/b)}{\exp(q_{YES}/b) + \exp(q_{NO}/b)} = \frac{1}{1 + \exp((q_{NO} - q_{YES})/b)}$$
  - Binary search calculation of shares for cost (`calcSharesForCost`) converging within 32 iterations.

### 3.5 OptimisticResolver (`OptimisticResolver.sol`)
- **Address**: `0x97c73c1E6864a4AD151191E6B4980f6AeDfbe2a9`
- **Role**: Decentralized optimistic resolution engine with economic bonds and dispute escalation.
- **Workflow**:
  1. Once trading period closes ($block.timestamp \ge closingTimestamp$), any party can call `proposeOutcome(marketId, outcome, evidenceURI)` by staking the proposal bond (0.01 BOT).
  2. Challenge window begins (60 seconds on Bohr Testnet).
  3. If unchallenged, anyone calls `finalizeProposal(marketId)` which sets the final outcome on the market contract and refunds the proposer's bond.
  4. If challenged, challenger posts dispute bond (0.02 BOT) via `disputeProposal(marketId, disputeEvidenceURI)`. The arbitrator reviews evidence and calls `resolveDispute(marketId, finalOutcome)`.

---

## 4. Storage Layout & Upgrade Boundaries
- **EIP-1167 Minimal Proxies**: Immutable delegatecall targets ensuring minimal footprint (~45 bytes per proxy).
- **Separation of Concerns**: State is stored exclusively within the individual proxy clones. Pricing models and resolvers are modular and can be specified per-market or upgraded at the factory default level.
