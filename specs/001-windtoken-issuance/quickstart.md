```markdown
# Quickstart: WindToken Issuance MVP (local + Mumbai demo)

**Created**: 2025-10-27
**Feature**: specs/001-windtoken-issuance

## Prerequisites

- Node 18+ and npm
- Hardhat (dev dependency)
- An RPC key for Polygon Mumbai (e.g., Alchemy/Infura) for testnet deploys
- A wallet with Mumbai testnet funds for deploy & demo

## Local dev (fast)

1. Install dependencies

```bash
npm install
```

2. Run tests

```bash
npx hardhat test
```

3. Start a local frontend (from `frontend/`)

```bash
cd frontend
npm install
npm run dev
```

## Deploy to Polygon Mumbai (demo)

1. Set env vars in `.env`: `MUMBAI_RPC_URL`, `DEPLOYER_PRIVATE_KEY`

2. Deploy contracts (example)

```bash
npx hardhat run --network mumbai scripts/deployFactory.js
```

3. Create a demo project via deploy script or console

```bash
npx hardhat run --network mumbai scripts/deployProject.js
```

4. Seed demo investors using `scripts/seedDemoAccounts.js` (uses mock USDC)

## Demo flow

1. Open frontend, connect wallet via WalletConnect.
2. Browse project and click Contribute (approve mock USDC then contribute).
3. Operator (in operator wallet) mark commissioning complete.
4. Trigger revenue event in operator UI (or via `npx hardhat run --network mumbai scripts/triggerRevenue.js`).
5. Observe distribution transactions and the updated balances in frontend.

## Notes

- For the hackathon, use mock USDC on Mumbai and simple batch distributions to keep gas costs low.
- If offline (no RPC), run a local Hardhat node: `npx hardhat node` and deploy to it for a fully local demo.

```
