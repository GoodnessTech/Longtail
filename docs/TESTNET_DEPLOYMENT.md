# LongTail Protocol: Bohr Testnet Deployment Evidence

## 1. Network Parameters
- **Network Name**: Bohr Testnet
- **Chain ID**: `968` (`0x3c8`)
- **Native Gas & Collateral Asset**: `BOT`
- **RPC Endpoint**: `https://rpc.bohr.life`
- **Block Explorer**: `https://scan.bohr.life/`
- **Deployer Wallet**: `0x34090545BD562b0bE1Cdc855F7cA9beE4566CE51`
- **Gas Pricing Model**: Legacy Format, 20 Gwei (`20000000000 wei`)

---

## 2. Core Protocol Deployments

| Contract Name | Contract Address | Transaction Hash | Explorer Link |
| :--- | :--- | :--- | :--- |
| **LongTailMarket Implementation** | `0xaEbB38aDF3AADCd959D0667EaCa505578b206413` | `0x2949c983f9c3a1541c2603b4e9d7393b9e8b3897b9771bb0d6145ddd0c0badda` | [View on BohrScan](https://scan.bohr.life/tx/0x2949c983f9c3a1541c2603b4e9d7393b9e8b3897b9771bb0d6145ddd0c0badda) |
| **LongTailOutcomeToken** | `0x4CD980838F7417a849C8d8dAF055Df50FD9648c6` | `0x970c4725a9138e08e7d02f136203610f7c96987230c3ebaff9fbd934eecca0d7` | [View on BohrScan](https://scan.bohr.life/tx/0x970c4725a9138e08e7d02f136203610f7c96987230c3ebaff9fbd934eecca0d7) |
| **LMSRPricingModel** | `0xfA58368866CA320da3deaA2F4fdDdf0228eDf273` | `0xf552bcaa86bd1d67f5a8c37a1bd91a1d9c747cb9170b7ea1b13092bcdb0c44f3` | [View on BohrScan](https://scan.bohr.life/tx/0xf552bcaa86bd1d67f5a8c37a1bd91a1d9c747cb9170b7ea1b13092bcdb0c44f3) |
| **OptimisticResolver** | `0x97c73c1E6864a4AD151191E6B4980f6AeDfbe2a9` | `0x36db10d0feaab7472f17d5a89b2079a167cceb51ceccdf304b8b945f189d2ee6` | [View on BohrScan](https://scan.bohr.life/tx/0x36db10d0feaab7472f17d5a89b2079a167cceb51ceccdf304b8b945f189d2ee6) |
| **LongTailMarketFactory** | `0xd72480faD3a5D732d753515dCf966aa93b9c4B8B` | `0x6638c82ea90ef1fb1c3f5dbff2f0ceeeb495aa689c6e1e5fd808d31b3d26a2b2` | [View on BohrScan](https://scan.bohr.life/tx/0x6638c82ea90ef1fb1c3f5dbff2f0ceeeb495aa689c6e1e5fd808d31b3d26a2b2) |
| **OutcomeToken.setFactory** | Call | `0xf2d716f034475e4c8bf2ffac955ce54d490989665e34d11cb76a43ad00c404f3` | [View on BohrScan](https://scan.bohr.life/tx/0xf2d716f034475e4c8bf2ffac955ce54d490989665e34d11cb76a43ad00c404f3) |
| **Resolver.setFactory** | Call | `0x24c7e8de78e2a393b9b6404cbb7aee2fb4465f613b1d12024e1e7b6da999dc9a` | [View on BohrScan](https://scan.bohr.life/tx/0x24c7e8de78e2a393b9b6404cbb7aee2fb4465f613b1d12024e1e7b6da999dc9a) |

---

## 3. End-to-End Testnet Lifecycle Transactions

Every transaction was broadcasted and mined on Bohr Testnet.

### 3.1 Market #1 Lifecycle (Ecosystem & Layer 1)
- **Question**: *"Will BOT Chain exceed 500,000 daily transactions in Q4 2026?"*
- **Clone Address**: `0x62cc194ad26910894ae6a7e6f1021752ba9c3fea`
- **Initial Seed**: `0.20 BOT`

| Step | Action | Tx Hash | Explorer Link |
| :--- | :--- | :--- | :--- |
| 1 | **Create Market (ID 1)** | `0x14a9463607474c6a2f593ce3eb6ea40dcce01ad23841d764c99c928a8046ab0f` | [View on BohrScan](https://scan.bohr.life/tx/0x14a9463607474c6a2f593ce3eb6ea40dcce01ad23841d764c99c928a8046ab0f) |
| 2 | **Buy YES Shares (0.05 BOT)** | `0x70dc8c82757eda86d5008b3ff4c1966e8f01af8352a28bbb4525ff47cf93d94c` | [View on BohrScan](https://scan.bohr.life/tx/0x70dc8c82757eda86d5008b3ff4c1966e8f01af8352a28bbb4525ff47cf93d94c) |
| 3 | **Buy NO Shares (0.04 BOT)** | `0x7daf7a76b4c90df623d1a61794e4c75946c2df9fa76ed45cdd3fec02661ec3c5` | [View on BohrScan](https://scan.bohr.life/tx/0x7daf7a76b4c90df623d1a61794e4c75946c2df9fa76ed45cdd3fec02661ec3c5) |
| 4 | **Sell YES Shares (Partial)** | `0x906659f59518063b013dc41d71ff62626097d2f936daade1b75c25e4e176df71` | [View on BohrScan](https://scan.bohr.life/tx/0x906659f59518063b013dc41d71ff62626097d2f936daade1b75c25e4e176df71) |
| 5 | **Add Liquidity (0.05 BOT)** | `0xd74154a92a570a2b60a2d8f6406aa182fdceac12e4f06ee50cf33a5245a2184a` | [View on BohrScan](https://scan.bohr.life/tx/0xd74154a92a570a2b60a2d8f6406aa182fdceac12e4f06ee50cf33a5245a2184a) |
| 6 | **Remove Liquidity (Partial)** | `0xcc37aa6866bc53962b7d439b091e7d1bc560252b7a7e523e97553e7b399946f6` | [View on BohrScan](https://scan.bohr.life/tx/0xcc37aa6866bc53962b7d439b091e7d1bc560252b7a7e523e97553e7b399946f6) |

### 3.2 Market #2 Lifecycle (AI & Autonomous Agents)
- **Question**: *"Will an Autonomous AI Agent execute a prediction market settlement on BOT Chain before December 2026?"*
- **Clone Address**: `0x8220b2b58ac444394a7f07130db5b448095071c8`
- **Initial Seed**: `0.15 BOT`

| Step | Action | Tx Hash | Explorer Link |
| :--- | :--- | :--- | :--- |
| 7 | **Create Market (ID 2)** | `0x27a9286ba539e0c3c90a62164f02e7e0f746033a41261ee4e6bfe7e2ae703eb1` | [View on BohrScan](https://scan.bohr.life/tx/0x27a9286ba539e0c3c90a62164f02e7e0f746033a41261ee4e6bfe7e2ae703eb1) |
| 8 | **Buy YES Shares (0.05 BOT)** | `0x8a550a349fed7dbe9f498648c17a33c8baf4bab785ce9beec86617c678da1ca3` | [View on BohrScan](https://scan.bohr.life/tx/0x8a550a349fed7dbe9f498648c17a33c8baf4bab785ce9beec86617c678da1ca3) |

### 3.3 Market #3 Lifecycle & Resolution Configuration
- **Question**: *"Will Bohr Testnet gas price remain at 20 Gwei throughout testing?"*
- **Clone Address**: `0x3b4abf8e4911d6fef029bacfe14bb996a1cb7619`
- **Initial Seed**: `0.15 BOT`

| Step | Action | Tx Hash | Explorer Link |
| :--- | :--- | :--- | :--- |
| 9 | **Create Market (ID 3)** | `0xc28d6161a773749f09eab4d4d0b004160b5fa22dbe3cce4a428faf6e48a92203` | [View on BohrScan](https://scan.bohr.life/tx/0xc28d6161a773749f09eab4d4d0b004160b5fa22dbe3cce4a428faf6e48a92203) |
| 10 | **Buy YES Shares (0.05 BOT)** | `0x377413ff34c440df855c4df58443adc621554b9f6dfd260f65a96d2a90b734aa` | [View on BohrScan](https://scan.bohr.life/tx/0x377413ff34c440df855c4df58443adc621554b9f6dfd260f65a96d2a90b734aa) |
| 11 | **Resolver Challenge Period (60s)** | `0x1f99db300aa35548020e9b492edc2f5977e7e3e19e2a97a8fd6232a9808f0db3` | [View on BohrScan](https://scan.bohr.life/tx/0x1f99db300aa35548020e9b492edc2f5977e7e3e19e2a97a8fd6232a9808f0db3) |
