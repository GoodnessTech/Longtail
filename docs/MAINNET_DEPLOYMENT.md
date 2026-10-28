# LongTail Protocol: BOT Chain Mainnet Deployment Runbook

## 1. Network Specifications
- **Target Network**: BOT Chain Mainnet
- **Chain ID**: `677` (`0x2a5`)
- **Native Gas & Collateral Asset**: `BOT`
- **RPC Endpoint**: `https://rpc.botchain.ai`
- **Block Explorer**: `https://scan.botchain.ai/`
- **Documentation**: `https://dev-docs.botchain.ai/`

---

## 2. Deployment Authorization Status
> [!IMPORTANT]
> **MAINNET NON-DEPLOYMENT CONFIRMATION**:
> As strictly mandated by protocol guidelines, **NO transactions have been broadcasted to BOT Chain Mainnet (Chain ID 677)**.
> All production testing and live contract verification have been executed exclusively on **Bohr Testnet (Chain ID 968)**.
> Mainnet deployment is staged and prepared in `contracts/script/DeployBOTMainnet.s.sol` and requires explicit authorization.

---

## 3. Mainnet Safety Protections (`DeployBOTMainnet.s.sol`)
To prevent accidental broadcasting or misconfigured deployments to mainnet, the mainnet script enforces hardcoded assertion guards:
```solidity
require(block.chainid == 677, "Must be BOT Chain Mainnet (Chain ID 677)");
require(
    vm.envOr("ALLOW_MAINNET_DEPLOYMENT", false) == true,
    "Mainnet deployment not authorized. Set ALLOW_MAINNET_DEPLOYMENT=true"
);
```

---

## 4. Mainnet Parameter Configuration
When authorized for mainnet release, the following production parameters must be applied:

| Parameter | Testnet Setting | Mainnet Setting | Rational |
| :--- | :--- | :--- | :--- |
| **Resolver Challenge Period** | 60 seconds | 86,400 seconds (24 hours) | Allows ample time for global community review |
| **Minimum Proposal Bond** | 0.01 BOT | 50.00 BOT | Economic barrier against spam proposals |
| **Dispute Bond** | 0.02 BOT | 100.00 BOT | Double proposal bond for dispute skin-in-the-game |
| **Default Fee Basis Points** | 100 bps (1%) | 100 bps (1%) | Competitive prediction market take rate |
| **Max Fee Basis Points** | 500 bps (5%) | 500 bps (5%) | Hard ceiling preventing creator exploitation |
| **Arbitrator Address** | Deployer EOA | Protocol Multi-Sig / DAO | Decentralized governance adjudication |
| **Outcome Token URI** | `https://api.longtail.io/token/{id}.json` | `ipfs://` or Decentralized Metadata | Censorship-resistant metadata hosting |

---

## 5. Mainnet Execution Procedure

### Step 1: Environment Preparation
Create `.env.mainnet`:
```bash
PRIVATE_KEY=<AUTHORIZED_DEPLOYER_OR_LEDGER_ACCOUNT>
ALLOW_MAINNET_DEPLOYMENT=true
ETHERSCAN_API_KEY=<BOTSCAN_VERIFICATION_KEY>
```

### Step 2: Dry-Run Simulation
Simulate without broadcasting:
```bash
forge script script/DeployBOTMainnet.s.sol:DeployBOTMainnetScript \
  --rpc-url https://rpc.botchain.ai \
  --legacy \
  -vvvv
```

### Step 3: Broadcast with Ledger or Hardware Wallet
```bash
forge script script/DeployBOTMainnet.s.sol:DeployBOTMainnetScript \
  --rpc-url https://rpc.botchain.ai \
  --broadcast \
  --legacy \
  --verify \
  -vvvv
```

### Step 4: Post-Deployment Verification
1. Verify contract addresses on [BOTScan](https://scan.botchain.ai/).
2. Transfer `owner()` of `LongTailMarketFactory` and `OptimisticResolver` to the DAO Timelock / Multi-Sig.
3. Update `CONTRACT_ADDRESSES[677]` in `Longtail Frontend/src/config/contracts.ts`.
