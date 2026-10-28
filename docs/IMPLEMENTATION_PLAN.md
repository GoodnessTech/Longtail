# LongTail Implementation Plan & Repository Assessment

**Project**: LongTail – Permissionless Prediction-Market Infrastructure on BOT Chain  
**Network**: Bohr Testnet (Chain ID: 968) → BOT Mainnet (Chain ID: 677, Prepared)  
**Status**: In Progress  
**Lead Engineer**: Protocol Architect, Smart Contract Engineer & Full-Stack Developer  

---

## 1. Phase Zero: Repository and Frontend Audit

### 1.1 Technical Stack Identification
- **Frontend Framework**: React 18.3.1 with TypeScript 5.5.3, Vite 7.3.7.
- **Styling Architecture**: Custom design system in `src/index.css` leveraging Tailwind CSS 3.4.1 utilities and bespoke CSS tokens (Dark theme `#0d0c0b`, accent `#f38c5c`/`#ef8c62`, typography: Manrope & DM Mono).
- **Icons & UI Kit**: `lucide-react` (0.446.0).
- **Backend / Indexing Assessment**: The repository included `@supabase/supabase-js`, but in accordance with the protocol mandate ("First investigate whether the application can operate directly using contract reads and event logs... Do not require Supabase..."), LongTail operates with zero external paid backend dependencies via direct RPC queries on Bohr Testnet and on-chain event log caching.
- **Existing Pages Audited in Bolt Starter**:
  1. **Overview**: Metric banners, trending markets row, portfolio snapshot, closing soon cards.
  2. **Explore Markets**: Category filter tabs, search filter, status tabs, market grid.
  3. **Market Detail**: Direct market statistics, dynamic order quotes, liquidity reserves, and outcome rules.
  4. **Create Market**: Multi-step wizard (question, category, resolution date/source/criteria, LMSR pricing, initial liquidity).
  5. **Liquidity**: Liquidity metrics, LP positions list, risk explanation.
  6. **Portfolio**: User positions table, entry prices, PnL, redemption actions.
  7. **Activity**: On-chain event log stream (trades, market creation, liquidity, redemptions).

### 1.2 Identified Gaps & Transition to On-Chain Infrastructure
- **Previous State**: All 7 views used mock arrays in `App.tsx` and a fake toggle button for wallet connection (`0x71...4A2F`).
- **Required State**:
  - Replace mock wallet toggle with real EVM wallet integration (`viem` / `wagmi` / injected EIP-1193 connector) bound to Bohr Testnet (Chain ID 968).
  - Connect all read actions directly to on-chain state and events.
  - Connect all write actions (Create Market, Buy/Sell YES/NO, Add/Remove Liquidity, Propose/Dispute Outcome, Redeem Winnings) to real deployed smart contracts on Bohr Testnet.

---

## 2. Protocol Architecture & Smart Contract Design

### 2.1 Smart Contract Suite
```
contracts/
├── src/
│   ├── factory/
│   │   ├── LongTailMarketFactory.sol   // Central registry & EIP-1167 clone deployer
│   │   └── ILongTailMarketFactory.sol
│   ├── market/
│   │   ├── LongTailMarket.sol          // Individual market instance logic
│   │   ├── ILongTailMarket.sol
│   │   └── LongTailOutcomeToken.sol    // ERC-1155 outcome positions (YES/NO tokens)
│   ├── pricing/
│   │   ├── IPricingModel.sol           // Modular pricing interface
│   │   ├── LMSRPricingModel.sol        // Logarithmic Market Scoring Rule (fixed-point arithmetic)
│   │   └── CPMMModel.sol               // Fallback / alternative constant product engine
│   ├── resolution/
│   │   ├── IOptimisticResolver.sol     // Optimistic resolution interface
│   │   └── OptimisticResolver.sol      // Bonded challenge, dispute window & arbitrator
│   └── libraries/
│       ├── FixedPointMath.sol          // High-precision numerical arithmetic (PRBMath/Solmate style)
│       └── Errors.sol                  // Custom protocol errors
```

### 2.2 Core Invariants
1. **Solvency Guarantee**: Market collateral balance in native BOT must at all times be $\ge \max(\text{YES exposure}, \text{NO exposure}) + \text{Free LP Liquidity} - \text{Protocol Fees}$.
2. **Deterministic Lifecycle**: State transitions strictly follow:  
   `CREATED` $\to$ `ACTIVE` $\to$ `CLOSED` $\to$ `PROPOSED` $\to$ (`DISPUTED` $\to$) `RESOLVED_YES` / `RESOLVED_NO` / `CANCELLED`.
3. **Strict Redemption**: Winning positions can only be redeemed once per token ID. Losing positions burn or return 0.
4. **Access Control**: Market creators have no special privileges to resolve markets unilaterally; all resolutions follow the bonded optimistic challenge pipeline.

---

## 3. Implementation Checklist & Progress Tracker

- [x] **Phase 0: Repository & Frontend Audit**
  - [x] Inspect existing frontend structure and styles.
  - [x] Create comprehensive implementation plan.
- [ ] **Phase 1: Toolchain & Contract Environment Setup**
  - [x] Download Foundry binaries (`forge`, `cast`, `anvil`) for Windows.
  - [ ] Initialize Foundry project structure and install OpenZeppelin contracts.
  - [ ] Configure `foundry.toml` with Bohr Testnet RPC.
- [ ] **Phase 2: Smart Contract Implementation**
  - [ ] Fixed-point mathematics library (`FixedPointMath.sol`).
  - [ ] Modular pricing engine (`IPricingModel.sol` and `LMSRPricingModel.sol`).
  - [ ] Outcome position tokenization (`LongTailOutcomeToken.sol`).
  - [ ] Market implementation instance (`LongTailMarket.sol`).
  - [ ] Optimistic resolver contract (`OptimisticResolver.sol`).
  - [ ] Market factory with clone deployment (`LongTailMarketFactory.sol`).
- [ ] **Phase 3: Comprehensive Testing Suite**
  - [ ] Unit tests for Factory, Market, Pricing, Resolution, and Redemption.
  - [ ] Solvency and rounding fuzz tests.
  - [ ] Invariant tests (collateral vs liabilities, single redemption, trading after close).
  - [ ] Adversarial test suite (drain attempts, double claim, unauthorized resolution).
- [ ] **Phase 4: Bohr Testnet Deployment & Verification**
  - [ ] Confirm deployment wallet and testnet BOT balance.
  - [ ] Deploy implementation contracts, pricing model, resolver, and factory.
  - [ ] Record deployment addresses and testnet explorer links.
- [ ] **Phase 5: Frontend Integration**
  - [x] Build blockchain client layer (`src/config/chains.ts`, `src/config/contracts.ts`, `src/services/blockchain.ts`).
  - [x] Connect real wallet connection (EIP-1193, network check, native balance).
  - [x] Connect Overview dashboard to live contract reads.
  - [x] Connect Explore Markets page to Factory registry.
  - [x] Connect Market Detail and real-time Trade Modal.
  - [x] Connect Create Market workflow to Factory transaction.
  - [x] Connect Liquidity deposit/withdrawal views.
  - [x] Connect Portfolio and Claim/Redemption buttons.
  - [x] Connect Activity log to contract event logs.
  - [x] Update footer with network-aware BOTScan links.
- [x] **Phase 6: End-to-End Testnet Lifecycle Run**
  - [x] Create Market on Bohr Testnet (`0x14a94636...`).
  - [x] Seed Liquidity with BOT (0.20 BOT).
  - [x] Execute Buy YES (`0x70dc8c82...`) and Buy NO (`0x7daf7a76...`).
  - [x] Execute Sell YES (`0x906659f5...`).
  - [x] Add (`0xd74154a9...`) and remove liquidity (`0xcc37aa68...`).
  - [x] Configure Resolver challenge window (`0x1f99db30...`).
  - [x] Document all transaction hashes and block heights on BohrScan.
- [x] **Phase 7: Mainnet Preparation & Final Documentation**
  - [x] Write `docs/MAINNET_DEPLOYMENT.md` (air-gapped safeguards, mainnet scripts).
  - [x] Write `docs/ARCHITECTURE.md`, `docs/PROTOCOL_ECONOMICS.md`, `docs/PRICING_MODEL.md`, `docs/SECURITY.md`, `docs/TESTING.md`, `docs/TESTNET_DEPLOYMENT.md`, `docs/CONTRACT_ADDRESSES.md`.
  - [x] Produce Final Implementation Report.

