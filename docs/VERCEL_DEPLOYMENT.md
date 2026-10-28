# Vercel Deployment Guide — LongTail Protocol

This guide outlines the production deployment workflow for the LongTail prediction-market interface on [Vercel](https://vercel.com).

The codebase is pre-configured with zero-friction settings supporting two deployment strategies:
1. **Repository Root Deployment (Default & Recommended)**
2. **Subdirectory Root Deployment (`Longtail Frontend`)**

---

## Pre-Deployment Verification

The frontend has been verified for production readiness:
- **Build tool**: Vite 7 + React 18 + TypeScript 5
- **Typecheck**: `tsc --noEmit -p tsconfig.app.json` passing with 0 errors
- **Production Bundle**: Optimized single-page application (`dist/index.html` ~0.71 kB, JS bundle ~190 kB)
- **Styling**: Tailwind CSS + custom dark design system (`#0d0c0b`, `#f38c5c`)
- **Default Network**: Pre-configured for Bohr Testnet (Chain ID 968) with on-chain deployed contracts

---

## Strategy A: Root Deployment (Recommended)

When importing the repository directly from GitHub (`https://github.com/GoodnessTech/Longtail.git`):

1. **Import Project**: In the Vercel dashboard, click **Add New** → **Project** and select `GoodnessTech/Longtail`.
2. **Framework Preset**: Vercel will automatically detect `Vite`.
3. **Root Directory**: Leave as `./` (default).
4. **Build & Output Settings**: Pre-configured via root `vercel.json`:
   - **Install Command**: `cd "Longtail Frontend" && npm install`
   - **Build Command**: `cd "Longtail Frontend" && npm run build`
   - **Output Directory**: `Longtail Frontend/dist`
5. Click **Deploy**.

---

## Strategy B: Subdirectory Deployment

If you prefer pointing Vercel directly to the frontend subfolder:

1. In the Vercel Project Import screen, click **Edit** next to **Root Directory**.
2. Select or enter `Longtail Frontend`.
3. Vercel will automatically use:
   - **Framework Preset**: `Vite`
   - **Build Command**: `npm run build`
   - **Output Directory**: `dist`
   - **Install Command**: `npm install`
4. The nested `Longtail Frontend/vercel.json` provides SPA routing rewrites.
5. Click **Deploy**.

---

## Environment Variables (Optional)

All contracts and RPC endpoints for Bohr Testnet are built in as standard fallbacks. If you wish to override them (e.g. for custom deployments or private RPCs), configure these in **Project Settings → Environment Variables**:

| Variable | Default Value | Description |
| :--- | :--- | :--- |
| `VITE_BOHR_RPC_URL` | `https://rpc.bohr.life` | Bohr Testnet JSON-RPC endpoint |
| `VITE_CHAIN_ID` | `968` | Network Chain ID |
| `VITE_FACTORY_ADDRESS` | `0xd72480faD3a5D732d753515dCf966aa93b9c4B8B` | LongTailMarketFactory proxy |
| `VITE_MARKET_IMPL_ADDRESS` | `0xaEbB38aDF3AADCd959D0667EaCa505578b206413` | LongTailMarket implementation |
| `VITE_OUTCOME_TOKEN_ADDRESS` | `0x4CD980838F7417a849C8d8dAF055Df50FD9648c6` | LongTailOutcomeToken (ERC-1155) |
| `VITE_PRICING_MODEL_ADDRESS` | `0xfA58368866CA320da3deaA2F4fdDdf0228eDf273` | LMSRPricingModel |
| `VITE_RESOLVER_ADDRESS` | `0x97c73c1E6864a4AD151191E6B4980f6AeDfbe2a9` | OptimisticResolver |

---

## Single-Page Application (SPA) Routing

Both root `vercel.json` and `Longtail Frontend/vercel.json` define:
```json
{
  "rewrites": [
    {
      "source": "/(.*)",
      "destination": "/index.html"
    }
  ]
}
```
This guarantees that direct URL navigation, deep links, and browser refreshes on any tab (`/explore`, `/create`, `/portfolio`, `/liquidity`, `/activity`) resolve to `index.html` without returning 404 HTTP errors.
