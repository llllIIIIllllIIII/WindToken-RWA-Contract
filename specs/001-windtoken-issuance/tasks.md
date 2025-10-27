````markdown
---

description: "Tasks for hackathon MVP delivery"

---

# Tasks: WindToken Issuance & Distribution (MVP)

**Input**: Design documents from `/specs/001-windtoken-issuance/`
**Prerequisites**: plan.md (ready), spec.md (ready), research.md (ready), data-model.md (ready), quickstart.md (in-progress)

Note: Tests are REQUIRED per constitution. Write tests first for each user story and ensure they fail before implementation.

## Phase 1: Setup (Shared Infrastructure)

- [x] T001 Create repository structure per plan in repo root (contracts/, scripts/, test/, frontend/, specs/) - Owner=you | Size=Small
- [ ] T002 Initialize Foundry project (`forge init --force .`) and add `.env.example` with Mumbai RPC keys placeholders - Owner=you | Size=Small
- [ ] T003 Add base README with demo outline and link to `specs/001-windtoken-issuance/quickstart.md` - Owner=Marketing | Size=Small
- [ ] T004 [P] Add GitHub Actions CI to run `forge test` on PRs (`.github/workflows/ci.yml`) - Owner=you | Size=Small
- [ ] T005 [P] Initialize frontend scaffold (`frontend/`) with Vite React, add basic routing and WalletConnect wiring placeholders - Owner=UI/UX | Size=Medium

---

## Phase 2: Foundational (Blocking Prerequisites)

- [ ] T006 Install OpenZeppelin upgradeable contracts via `forge install` and document dependencies in `foundry.toml` - Owner=you | Size=Small
- [ ] T007 Configure `foundry.toml` with default profile, optimizer, and RPC endpoints (anvil, mumbai) - Owner=you | Size=Small
- [ ] T008 Implement admin/operator role strategy notes in `specs/001-windtoken-issuance/research.md` and cross-link in README - Owner=BD | Size=Small
- [ ] T009 [P] Prepare deploy scripts: `script/DeployFactory.s.sol`, `script/DeployProject.s.sol`, `script/SeedDemo.s.sol` - Owner=you | Size=Medium
- [ ] T010 [P] Add mock stablecoin `contracts/mocks/MockUSDC.sol` and ensure faucet function present - Owner=you | Size=Small
- [ ] T011 Add address registry output `deployments/addresses.json` emitted by scripts for frontend consumption - Owner=you | Size=Small

**Checkpoint**: Foundation ready – user stories can begin.

---

## Phase 3: User Story 1 - Invest in Project (Priority: P1) 🎯 MVP

Goal: Investor contributes to a project and receives minted tokens proportionally; project state reflects contribution.

Independent Test: From a fresh project, approve mock USDC, call `contribute(X)`, verify investor receives correct token amount and events emitted.

### Tests (REQUIRED)

- [ ] T012 [P] [US1] Contract test: contribution→mint flow in `test/WindTurbineRWA.t.sol` - Owner=you | Size=Medium
- [ ] T013 [P] [US1] Contract test: fundraising state guards and goal close in `test/WindTurbineRWA_State.t.sol` - Owner=you | Size=Small

### Implementation

- [ ] T014 [P] [US1] Implement PowerToken owner mint restriction and decimals config in `contracts/tokens/PowerToken.sol` - Owner=you | Size=Small
- [ ] T015 [US1] Implement fundraising open/close transitions in `contracts/projects/WindTurbineRWA.sol` - Owner=you | Size=Small
- [ ] T016 [US1] Implement `contribute(uint256 amount)` with USDC `transferFrom` and mint rate calc in `contracts/projects/WindTurbineRWA.sol` - Owner=you | Size=Medium
- [ ] T017 [US1] Implement events: `Contribution`, `GoalReached`, supply metrics in `contracts/projects/WindTurbineRWA.sol` - Owner=you | Size=Small
- [ ] T018 [US1] Upgrade factory to deploy proxy + initialize RWA and set token owner in `contracts/factory/WindTurbineFactory.sol` and `script/DeployProject.s.sol` - Owner=you | Size=Medium
- [ ] T019 [P] [US1] Frontend: ProjectList page and fetching addresses from `deployments/addresses.json` in `frontend/src/pages/ProjectList.tsx` - Owner=UI/UX | Size=Small
- [ ] T020 [US1] Frontend: ProjectDetail with approve+contribute flow in `frontend/src/pages/ProjectDetail.tsx` - Owner=UI/UX | Size=Medium
- [ ] T021 [US1] Docs: update quickstart with US1 demo steps in `specs/001-windtoken-issuance/quickstart.md` - Owner=Marketing | Size=Small

**Checkpoint**: US1 independently functional and testable.

---

## Phase 4: User Story 3 - Monthly Revenue Reporting & Distribution (Priority: P1)

Goal: Record a monthly revenue event and distribute proportional payouts to token holders; publish signed report (IPFS CID in event).

Independent Test: Trigger `reportRevenue(R, cid)` then `distribute(revId)`; balances increase proportionally; events recorded.

### Tests (REQUIRED)

- [ ] T022 [P] [US3] Contract test: revenue event + distribution math in `test/Distribution.t.sol` - Owner=you | Size=Medium
- [ ] T023 [P] [US3] Contract test: edge cases (zero supply, rounding) in `test/DistributionEdgeCases.t.sol` - Owner=you | Size=Small

### Implementation

- [ ] T024 [US3] Implement `reportRevenue(gross, cid)` with fee calc in `contracts/projects/WindTurbineRWA.sol` - Owner=you | Size=Small
- [ ] T025 [US3] Implement `distribute(revenueEventId)` basic loop for ≤10 holders in `contracts/projects/WindTurbineRWA.sol` - Owner=you | Size=Medium
- [ ] T026 [P] [US3] Add `RevenueOracleMock` wiring in scripts and optional frontend operator trigger in `frontend/src/components/OperatorPanel.tsx` - Owner=UI/UX | Size=Small
- [ ] T027 [US3] Frontend: Revenue dashboard showing events and distributions in `frontend/src/pages/RevenueDashboard.tsx` - Owner=UI/UX | Size=Medium
- [ ] T028 [US3] Docs: add sample signed report JSON + pin to IPFS, record CID in `specs/.../quickstart.md` - Owner=BD | Size=Small

**Checkpoint**: US3 independently functional and testable.

---

## Phase 5: User Story 2 - Project Commissioning (Priority: P2)

Goal: Operator marks commissioning complete with proof (IPFS CID); project transitions to Active; distributions allowed only when Active.

Independent Test: Mark commissioned with CID; state becomes Active; distribution reverts if not Active.

### Tests (REQUIRED)

- [ ] T029 [P] [US2] Contract test: only operator can commission; state gating in `test/Commissioning.t.sol` - Owner=you | Size=Small

### Implementation

- [ ] T030 [US2] Implement `markCommissioned(cid)` storing CID + state transition in `contracts/projects/WindTurbineRWA.sol` - Owner=you | Size=Small
- [ ] T031 [US2] Frontend: Operator control to upload CID and mark commissioned in `frontend/src/components/OperatorPanel.jsx` - Owner=UI/UX | Size=Small
- [ ] T032 [US2] Docs: commissioning flow and validation steps in `specs/.../quickstart.md` - Owner=Marketing | Size=Small

**Checkpoint**: US2 independently functional and testable.

---

## Phase N: Polish & Cross-Cutting Concerns

- [ ] T033 [P] Security review: reentrancy guards and SafeERC20 usage pass in `contracts/projects/WindTurbineRWA.sol` - Owner=you | Size=Small
- [ ] T034 [P] Gas review: batch size and distribution loop constraints documented in `research.md` - Owner=you | Size=Small
- [ ] T035 [P] Frontend UX polish: loading states and error toasts across pages in `frontend/src/components/*` - Owner=UI/UX | Size=Small
- [ ] T036 Prepare demo script and screen recording storyboard in `docs/demo.md` - Owner=Marketing | Size=Small
- [ ] T037 Finalize `specs/.../quickstart.md` and repo README with end-to-end steps - Owner=Marketing | Size=Small

---

## Dependencies & Execution Order

- Setup (Phase 1) → Foundational (Phase 2) → US1 (P1) → US3 (P1) → US2 (P2) → Polish
- US1 and US3 can proceed in parallel after foundational is complete if separate owners work in distinct files.

## Parallel Opportunities

- All tasks marked [P] are parallelizable. Typical splits:
  - Contracts vs. Frontend
  - Tests vs. Implementation (different files)
  - Docs vs. Code

## Implementation Strategy

1) MVP First: Complete US1 end-to-end; demo contribution→mint.  
2) Add US3 distributions; demo monthly revenue.  
3) Add US2 commissioning and state gating.  
4) Polish docs and demo.

````
