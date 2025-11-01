# WindToken RWA Platform (Hackathon MVP)

This repository hosts the WindToken hackathon MVP for crowdfunded micro wind turbines. Investors crowdfund projects, receive ERC20 yield tokens, and collect monthly revenue distributions with transparent reporting.

## Repository Layout

- `contracts/` — Solidity sources: `WindTurbineFactory`, `WindTurbineRWA`, `PowerToken`, mocks.
- `script/` — Foundry deployment/upgrade scripts (`DeployFactory.s.sol`, etc.).
- `test/` — Forge tests covering contributions, commissioning, and distribution flows.
- `frontend/` — React + WalletConnect client (campaign list, detail, dashboard, operator tools).
- `docs/` — Demo materials and presentation assets.
- `lib/forge-std/` — Foundry standard library (installed via `forge`).

## Tooling

- Smart contracts: Foundry (`forge`, `cast`, `anvil`), OpenZeppelin upgradeable contracts, UUPS proxies.
- Frontend: React 18, Vite, ethers.js, wagmi + WalletConnect.
- Testnet: Polygon Mumbai for live MVP demonstrations.

## Common Commands

```bash
# Install dependencies
forge install

# Build contracts
forge build

# Run tests
forge test

# Format Solidity
forge fmt

# Start local node
anvil

# Deploy to Mumbai (example)
forge script script/DeployFactory.s.sol --rpc-url $MUMBAI_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY --broadcast
```


## Foundry Reference

- Official docs: <https://book.getfoundry.sh/>
- `forge --help`, `anvil --help`, `cast --help` for command usage.
