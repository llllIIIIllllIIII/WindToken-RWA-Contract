ios/ or android/
# Implementation Plan: WindToken Issuance & Distribution MVP

**Branch**: `001-windtoken-issuance` | **Date**: 2025-10-27 | **Spec**: [`specs/001-windtoken-issuance/spec.md`](specs/001-windtoken-issuance/spec.md)
**Input**: Feature specification from `/specs/001-windtoken-issuance/spec.md`

## Summary

Build a hackathon-ready MVP that lets investors crowdfund micro wind turbine projects, receive ERC20 yield tokens, and collect monthly revenue distributions with full transparency. Core scope covers four upgradeable smart contracts (Factory, Project, Token, Oracle mock), a React + WalletConnect frontend, Foundry-based testing, and supporting docs/scripts tailored for Polygon Mumbai testnet. V2 roadmap introduces permissioned token (ERC-3643), identity verification (Self Protocol), and telemetry validation (Oasis ROFL).

## Technical Context

**Language/Version**: Solidity 0.8.24, TypeScript/JavaScript (React 18)  
**Primary Dependencies**: Foundry toolchain (`forge`, `cast`), OpenZeppelin Contracts Upgradeable, WalletConnect, ethers.js, Vite, IPFS pinning service (mocked)  
**Storage**: On-chain state (Polygon Mumbai); transparency reports anchored via IPFS CID (mock pinning for MVP)  
**Testing**: Foundry forge tests for contracts; Playwright/Vitest optional for frontend smoke (stretch)  
**Target Platform**: Polygon Mumbai testnet (deploy + demo); local Anvil node for development  
**Project Type**: Web + smart contracts (monorepo)  
**Performance Goals**: Contributions and distributions complete within single transactions for ≤10 holders; dashboard loads <2s using cached JSON; revenue reports published within 24h of event  
**Constraints**: 1-week hackathon, no KYC/AML, minimal external integrations, mock telemetry/revenue oracle, documentation + tests must ship with features  
**Scale/Scope**: Demo for ≤3 projects, ≤50 investors, ≤10 holders per distribution batch (document Merkle roadmap for scaling)

## Constitution Check

*Status: PASS (all gates addressed in plan)*

- Transparency: Each contribution, mint, commissioning, and distribution event emits detailed on-chain events and anchors IPFS reports.
- MVP Simplicity: Scope limited to core crowdfunding → minting → distribution flow; AMMs, lending, and complex liquidity mechanics deferred.
- Upgradeability: All contracts deployed behind UUPS proxies managed via Foundry scripts; upgrade docs included.
- Documentation: Spec, research, plan, data-model, quickstart, and demo README required per feature deliverable.
- Testing: Forge unit/integration tests required per story (red-green); CI enforces `forge test`.
- Stack mandate: React + WalletConnect frontend, Foundry + UUPS smart contracts confirmed.

## Project Structure

### Documentation (this feature)

```text
specs/001-windtoken-issuance/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── (API schemas if needed)
└── tasks.md
```

### Source Code (repository root)

```text
contracts/
├── factory/
│   └── WindTurbineFactory.sol
├── projects/
│   └── WindTurbineRWA.sol
├── tokens/
│   └── PowerToken.sol
└── mocks/
   ├── RevenueOracleMock.sol
   └── MockUSDC.sol

script/
├── DeployFactory.s.sol
├── DeployProject.s.sol
├── SeedDemo.s.sol
└── UpgradeProject.s.sol

test/
├── WindTurbineRWA.t.sol
├── Distribution.t.sol
└── Commissioning.t.sol

frontend/
├── src/
│   ├── pages/
│   │   ├── ProjectList.tsx
│   │   ├── ProjectDetail.tsx
│   │   └── RevenueDashboard.tsx
│   ├── components/
│   │   ├── WalletConnectButton.tsx
│   │   └── OperatorPanel.tsx
│   └── lib/
│       ├── contracts/
│       │   ├── factory.ts
│       │   └── rwa.ts
│       └── hooks/
├── public/
└── vite.config.ts

docs/
└── demo.md

.github/workflows/
└── ci.yml
```

**Structure Decision**: Foundry-native repo at root with `contracts/`, `script/`, and `test/`; Vite React frontend colocated under `frontend/`. Documentation stays in `specs/001-windtoken-issuance` and `docs/`. This layout keeps smart contracts and frontend decoupled while enabling shared deployment artifacts (`script/`, `frontend/src/lib/contracts/abis`).

## Complexity Tracking

No constitution violations. Upgrade roadmap and lack of KYC documented for transparency.

---

## Phase 0 – Outline & Research

### Unknowns → Research Tasks

- KYC/AML policy for MVP → Resolved: no KYC (documented in research.md).
- Token permissioning vs public ERC20 → Resolved: public ERC20 for speed; note ERC-3643 upgrade path.
- Settlement currency → Resolved: mock USDC (Polygon Mumbai) for stable accounting.
- Upgrade safety and proxy management in Foundry → Task: document `_authorizeUpgrade` governance and Foundry scripts.

### Research Findings (captured in `research.md`)

- Decisions logged with rationale and alternatives.
- Document UUPS upgrade steps, Merkle distribution roadmap, and IPFS anchoring approach.

**Artifacts**: `research.md` (complete)

---

## Phase 1 – Design & Contracts

### Data Model

- Entities: Project, Investor, Contribution, PowerToken, RevenueEvent, Distribution.
- Relationships + validation documented in `data-model.md`.

### Contract Interfaces (to be refined in `/contracts` if external APIs needed)

- Factory: `createProject`, `getProject`, upgrade hooks.
- RWA: `initialize`, `contribute`, `markCommissioned`, `reportRevenue`, `distribute`, `authorizeUpgrade`.
- PowerToken: `mint`, `setMinter` (owner-only), ERC20 standard interface.
- OracleMock: `submitRevenue` (for demo/testing).

### Quickstart

- Local: `forge install`, `forge test`, `anvil`, `pnpm dev` in frontend.
- Testnet: `forge script --rpc-url $MUMBAI_RPC --broadcast script/DeployFactory.s.sol` etc.
- Demo script outlines investor + operator flows.

### Agent Context Update

- Run `.specify/scripts/bash/update-agent-context.sh copilot` after plan approval to register Foundry + React stack in agent guidance.

**Artifacts**: `data-model.md`, `quickstart.md`, (future) `contracts/` schemas.

---

## Architecture & Module Plan

1. **Smart Contracts**
  - `WindTurbineFactory`: Deploys UUPS proxies, stores registry, sets operator + token addresses.
  - `WindTurbineRWA`: Manages state machine (Draft → Active), handles contributions (USDC `transferFrom` → mint), records revenue events, distributes via loop (≤10 holders) with events exposing CIDs.
  - `PowerToken`: ERC20, mint restricted to project contract, upgradeable-ready API for future ERC-3643 swap.
  - `RevenueOracleMock`: Demo revenue submitter; future replacement with real oracle (Oasis ROFL integration).

2. **Access Control**
  - `DEFAULT_ADMIN_ROLE` (multisig) controls upgrades + operator assignment.
  - Operator role stored per project; optional investor whitelist toggle for future permissioned mode.

3. **Frontend Modules**
  - WalletConnect integration (wagmi + WalletConnect v2).
  - Pages: campaign list, detail (approve + contribute), investor dashboard, operator panel, revenue dashboard.
  - Shared ABIs + hooks for Foundry-generated deployment artifacts.

4. **Testing Strategy**
  - Foundry unit tests per user story (contribute, commissioning, distribution).
  - Simulate revenue events and ensure rounding/zero-edge cases covered.
  - Optional property-based tests for proportional distributions.

5. **CI/CD**
  - GitHub Actions: `forge fmt --check`, `forge test`, `pnpm lint` (when frontend ready).
  - Deployment scripts produce `addresses.json` consumed by frontend.

6. **Upgrade & V2 Roadmap**
  - Document UUPS upgrade steps + governance in README.
  - V2 tasks: swap to ERC-3643, integrate Self Protocol for identity, connect Oasis ROFL telemetry feed, adopt Merkle distributor for scale.

---

## Timeline & Constraints

| Day | Focus | Deliverables |
|-----|-------|--------------|
| 0 | Repo setup, Foundry init, dependency install | Foundry scaffold, CI skeleton |
| 1 | Contracts US1 (contribute + mint) + tests | Passing forge tests for contributions |
| 2 | Frontend US1 + Mumbai deploy script | Contribute flow demo-ready |
| 3 | Revenue events + distribution logic/tests | Distribution demo via script |
| 4 | Commissioning flow + operator UI | State gating complete |
| 5 | Polish, docs, demo recording | Quickstart, demo.md, CI green |
| 6 | Buffer / iteration | Fixes, stretch goals |

Constraints: 1-week hackathon, minimal integrations, rely on mock data for revenue/telemetry, avoid scope creep beyond user stories.

---

## Next Steps

1. Initialize Foundry project (`forge init`) and apply structure above.
2. Implement tasks per `tasks.md`, ensuring tests precede implementation.
3. Keep documentation (quickstart, demo) updated with each feature completion.
4. Prepare final demo script covering investor → distribution journey and roadmap slides for v2 enhancements.

