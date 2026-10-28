# LongTail: Permissionless Prediction-Market Infrastructure on BOT Chain

[![Solidity](https://img.shields.io/badge/Solidity-0.8.24-363636?logo=solidity)](https://soliditylang.org/)
[![Foundry](https://img.shields.io/badge/Built%20With-Foundry-orange)](https://getfoundry.sh/)
[![Network](https://img.shields.io/badge/Network-Bohr%20Testnet%20(968)-blue)](https://scan.bohr.life/)
[![Tests](https://img.shields.io/badge/Tests-31%2F31%20Passing-brightgreen)](docs/TESTING.md)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

**LongTail** is permissionless prediction-market infrastructure built natively on **BOT Chain** and deployed to **Bohr Testnet (Chain ID 968)**. The protocol enables anyone to create, price, trade, and provide liquidity to prediction markets for any verifiable question.

---

## Key Highlights

- **Native BOT Collateral & Settlement**: No wrapped token friction (`WETH`/`WBOT`). All collateral and gas transactions use native `BOT`.
- **EIP-1167 Minimal Proxy Clones**: Deploys lightweight prediction markets with an ~80% gas reduction (~680k gas vs ~3.5M gas).
- **Logarithmic Market Scoring Rule (LMSR)**: Mathematically stable pricing engine $C(q_1, q_2) = \max(q_1, q_2) + b \ln(1 + \exp(-|q_1 - q_2|/b))$ guaranteeing continuous bid/ask liquidity and proving $Collateral \ge \max(q_{YES}, q_{NO})$ at all times.
- **ERC-1155 Outcome Multi-Tokens**: Deterministic token ID scheme: $\text{tokenId} = (\text{marketId} \ll 1) \mid (\text{isYes} \ ? \ 0 : 1)$.
- **Optimistic Resolution with Bonded Challenges**: Economic resolution protocol with 60s challenge windows on testnet, evidence attachments, and arbitrator adjudication.
- **7-View Integrated Frontend**: Complete web application preserving custom Bolt dark styling (`#0d0c0b`, `#f38c5c`), typography (`Manrope`, `DM Mono`), with real wallet connections, live quotes, and on-chain trade execution.

---

## Deployed Contract Directory (Bohr Testnet - Chain ID 968)

| Contract | Address | Explorer Link |
| :--- | :--- | :--- |
| **LongTailMarketFactory** | `0xd72480faD3a5D732d753515dCf966aa93b9c4B8B` | [BohrScan](https://scan.bohr.life/tx/0x6638c82ea90ef1fb1c3f5dbff2f0ceeeb495aa689c6e1e5fd808d31b3d26a2b2) |
| **LongTailMarket (Implementation)** | `0xaEbB38aDF3AADCd959D0667EaCa505578b206413` | [BohrScan](https://scan.bohr.life/tx/0x2949c983f9c3a1541c2603b4e9d7393b9e8b3897b9771bb0d6145ddd0c0badda) |
| **LongTailOutcomeToken** | `0x4CD980838F7417a849C8d8dAF055Df50FD9648c6` | [BohrScan](https://scan.bohr.life/tx/0x970c4725a9138e08e7d02f136203610f7c96987230c3ebaff9fbd934eecca0d7) |
| **LMSRPricingModel** | `0xfA58368866CA320da3deaA2F4fdDdf0228eDf273` | [BohrScan](https://scan.bohr.life/tx/0xf552bcaa86bd1d67f5a8c37a1bd91a1d9c747cb9170b7ea1b13092bcdb0c44f3) |
| **OptimisticResolver** | `0x97c73c1E6864a4AD151191E6B4980f6AeDfbe2a9` | [BohrScan](https://scan.bohr.life/tx/0x36db10d0feaab7472f17d5a89b2079a167cceb51ceccdf304b8b945f189d2ee6) |

### Active Market Proxies (EIP-1167 Clones)
- **Market #1** (Ecosystem & L1): `0x62cc194ad26910894ae6a7e6f1021752ba9c3fea` ([BohrScan Tx](https://scan.bohr.life/tx/0x14a9463607474c6a2f593ce3eb6ea40dcce01ad23841d764c99c928a8046ab0f))
- **Market #2** (AI & Tech): `0x8220b2b58ac444394a7f07130db5b448095071c8` ([BohrScan Tx](https://scan.bohr.life/tx/0x27a9286ba539e0c3c90a62164f02e7e0f746033a41261ee4e6bfe7e2ae703eb1))
- **Market #3** (Bohr Testnet): `0x3b4abf8e4911d6fef029bacfe14bb996a1cb7619` ([BohrScan Tx](https://scan.bohr.life/tx/0xc28d6161a773749f09eab4d4d0b004160b5fa22dbe3cce4a428faf6e48a92203))

---

## On-Chain Lifecycle Evidence

The entire transaction lifecycle was executed and confirmed on Bohr Testnet:
1. **Market 1 Created**: `0x14a9463607474c6a2f593ce3eb6ea40dcce01ad23841d764c99c928a8046ab0f`
2. **Buy YES (0.05 BOT)**: `0x70dc8c82757eda86d5008b3ff4c1966e8f01af8352a28bbb4525ff47cf93d94c`
3. **Buy NO (0.04 BOT)**: `0x7daf7a76b4c90df623d1a61794e4c75946c2df9fa76ed45cdd3fec02661ec3c5`
4. **Sell YES**: `0x906659f59518063b013dc41d71ff62626097d2f936daade1b75c25e4e176df71`
5. **Add Liquidity (0.05 BOT)**: `0xd74154a92a570a2b60a2d8f6406aa182fdceac12e4f06ee50cf33a5245a2184a`
6. **Remove Liquidity**: `0xcc37aa6866bc53962b7d439b091e7d1bc560252b7a7e523e97553e7b399946f6`
7. **Market 2 Created**: `0x27a9286ba539e0c3c90a62164f02e7e0f746033a41261ee4e6bfe7e2ae703eb1`
8. **Market 2 Buy YES (0.05 BOT)**: `0x8a550a349fed7dbe9f498648c17a33c8baf4bab785ce9beec86617c678da1ca3`
9. **Market 3 Created**: `0xc28d6161a773749f09eab4d4d0b004160b5fa22dbe3cce4a428faf6e48a92203`
10. **Market 3 Buy YES (0.05 BOT)**: `0x377413ff34c440df855c4df58443adc621554b9f6dfd260f65a96d2a90b734aa`
11. **Resolver Challenge Window (60s)**: `0x1f99db300aa35548020e9b492edc2f5977e7e3e19e2a97a8fd6232a9808f0db3`

---

## Repository Structure

```
.
├── contracts/                        # Foundry Smart Contract Project
│   ├── src/
│   │   ├── factory/                  # Factory and clone registry
│   │   ├── market/                   # Market logic, state, and ERC-1155 outcome tokens
│   │   ├── pricing/                  # LMSR pricing model
│   │   ├── resolution/               # Optimistic resolver and challenge bonds
│   │   └── libraries/                # FixedPointMath and custom errors
│   ├── test/                         # Foundry unit, integration, and fuzz test suite
│   ├── script/                       # Deployment and lifecycle execution scripts
│   └── foundry.toml                  # Solc 0.8.24 configuration
├── Longtail Frontend/                # React / TypeScript / Vite Application
│   ├── src/
│   │   ├── config/                   # Chain definitions and contract ABIs
│   │   ├── services/                 # Centralized blockchain client
│   │   ├── App.tsx                   # 7 full-featured protocol views
│   │   └── index.css                 # Custom design system tokens
│   └── package.json
└── docs/                             # Comprehensive Technical Documentation
    ├── ARCHITECTURE.md               # Contract relationships and minimal proxy design
    ├── PRICING_MODEL.md              # Mathematical LMSR derivation & solvency proof
    ├── PROTOCOL_ECONOMICS.md         # Tokenomics, fees, and free liquidity formulas
    ├── SECURITY.md                   # Threat analysis, reentrancy guards, and access matrix
    ├── TESTING.md                    # 31/31 passed test breakdown and gas report
    ├── TESTNET_DEPLOYMENT.md         # Bohr Testnet deployment evidence
    ├── MAINNET_DEPLOYMENT.md         # BOT Mainnet deployment runbook and safety guards
    ├── CONTRACT_ADDRESSES.md         # Multi-network contract directory
    ├── VERCEL_DEPLOYMENT.md          # Production Vercel deployment runbook
    └── IMPLEMENTATION_PLAN.md        # Architecture audit and progress checklist
```

---

## Quickstart & Verification

### Run Smart Contract Tests
```bash
cd contracts
forge test -vvv
```

### Run Frontend Locally
```bash
cd "Longtail Frontend"
npm install
npm run dev
```

### Production Build & Vercel Deployment
```bash
# Build locally or on Vercel
npm run build
```
For complete production deployment instructions, see [docs/VERCEL_DEPLOYMENT.md](docs/VERCEL_DEPLOYMENT.md).

Connect any EVM wallet (MetaMask, OKX, Rabby) to **Bohr Testnet**:
- **RPC URL**: `https://rpc.bohr.life`
- **Chain ID**: `968`
- **Currency**: `BOT`
- **Explorer**: `https://scan.bohr.life`

