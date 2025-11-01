```markdown
# Feature Specification: WindToken Issuance & Distribution

**Feature Branch**: `001-windtoken-issuance`
**Created**: 2025-10-27
**Status**: Draft
**Input**: User description: "DeFi-enabled Real World Asset platform for small wind turbines allowing crowdfunding, tokenized ownership (ERC20/permissioned), monthly revenue reporting and distribution, on-chain transparency, and a minimal MVP DeFi integration focused on issuance and distribution."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Invest in Project (Priority: P1)

As an individual investor, I want to browse active turbine projects, contribute funds to a specific project, and receive tokens proportional to my contribution so that I hold a transferable claim on future electricity yields.

**Why this priority**: This is the primary value flow enabling crowdfunding and token ownership.

**Independent Test**: Using a seeded test project, a test wallet can submit a contribution transaction and immediately receive the correct token amount. Token balance reflects proportional share.

**Acceptance Scenarios**:
1. **Given** a funded project open for investment, **When** an investor submits a contribution of X units (multiple of 100 USDC) of the designated stablecoin, **Then** the system escrows the funds, records the investor's proportional share, and exposes the expected mint amount for later settlement.
2. **Given** the project reaches the funding goal of 1,000,000 USDC, **When** fundraising finalizes, **Then** the contract batch-mints tokens to each investor based on their final contribution and transitions the project to the commissioning state.
3. **Given** fundraising is still in progress, **When** an investor requests to withdraw Y units (multiple of 100 USDC) not exceeding their contribution, **Then** the contract returns the funds and updates the investor's recorded share accordingly.

---

### User Story 2 - Project Commissioning (Priority: P2)

As a project operator, I want to register procurement and installation milestones, record commissioning completion, and trigger token issuance windows so the project can commence revenue production and distributions.

**Why this priority**: Projects must be verifiably commissioned before revenue distribution begins.

**Independent Test**: Operator can record a commissioning event; the event appears in the project's history and enables revenue distribution scheduling.

**Acceptance Scenarios**:
1. **Given** a registered project in pre-commissioning, **When** the operator uploads commissioning proof and marks the commissioning complete, **Then** the system records the milestone on-chain (or via anchored verifiable storage) and moves project to "Active" state.

---

### User Story 3 - Monthly Revenue Reporting & Distribution (Priority: P1)

As a token holder, I want to receive transparent monthly reports of revenue and receive distributions proportional to my token holdings so I can realize yield from the asset.

**Why this priority**: Revenue distribution is the financial value proposition to investors.

**Independent Test**: A simulated revenue event triggers distribution logic that transfers funds to token holders proportional to balances; reports are published and verifiable against on-chain events.

**Acceptance Scenarios**:
1. **Given** an active project with recorded revenue of R for the month, **When** the operator (or an automated process) triggers distribution, **Then** each token holder receives (balance/totalSupply) * R and a signed report is published.

---

### Edge Cases

- Partial funding where a project does not reach a minimum threshold: funds are either refunded or held per project policy (see Assumptions).
- Commissioning fails after funds disbursed: policy for remediation and potential clawback must be defined.
- Contribution or distribution transactions failing due to gas/chain issues: retries and manual reconciliation processes required.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST allow a project operator to create a project with metadata: location, capacity (kW), expected yield model, funding goal, and commissioning milestones.
- **FR-002**: The system MUST accept investor contributions in 100 USDC increments, escrow them until the project reaches the 1,000,000 USDC goal, and mint tokens proportional to each investor's final contribution once fundraising concludes.
- **FR-002a**: The system MUST allow contributors to withdraw all or part of their escrowed funds (in 100 USDC increments) while the fundraising state is active.
- **FR-003**: Tokens MUST be transferable on-chain unless explicitly restricted by a permissioning policy recorded in the project spec.
- **FR-004**: The system MUST support recording commissioning milestones and state transitions (e.g., Draft → Fundraising → Commissioning → Active → Closed).
- **FR-005**: The system MUST enable monthly revenue events to be recorded and distributed to token holders proportionally; distributions MUST be traceable on-chain.
- **FR-006**: The system MUST publish on-chain or verifiable off-chain transparency artifacts capturing funds flow, token minting events, supply metrics, and distribution events.
- **FR-007**: The MVP MUST NOT include AMM or lending integrations — DeFi scope limited to issuance and distribution flows.
- **FR-008**: All smart contracts used for token issuance and fund handling MUST be deployable behind upgradeable proxies following the project's governance pattern (UUPS is the project standard and MUST be documented in the plan).

### Non-Functional Requirements

- **NFR-001**: Distribution processing for a monthly revenue cycle MUST complete (on-chain or via settlement process) within 7 days of the revenue event being recorded.
- **NFR-002**: Transactional transparency artifacts (on-chain events or signed reports) MUST be available for audit within 24 hours of each state change.
- **NFR-003**: Critical token and distribution contract logic MUST have automated contract tests covering happy path and key edge cases.

## Key Entities *(include if feature involves data)*

- **Project**: id, operator, metadata (location, capacity), funding goal, milestones, token parameters.
- **Investor**: wallet address, contributions, token balance, KYC status (if applicable).
- **Contribution**: amount, currency, timestamp, transaction hash, project id.
- **Token**: token contract address, totalSupply, decimals, metadata, permissioning flags.
- **RevenueEvent**: period, grossRevenue, fees, netRevenue, supporting documents (signed report, invoice), on-chain anchor.
- **Distribution**: distribution id, revenueEventId, totalDistributed, perHolder amounts, transaction hashes.

## Success Criteria *(mandatory)*

- **SC-001**: Investors can complete an end-to-end investment (select project → contribute → receive tokens) in under 5 minutes on testnet.
- **SC-002**: Token issuance correctness: for a provided contribution dataset, minted token balances must match the documented tokenomics formula with 100% accuracy.
- **SC-003**: Monthly distribution correctness: for a simulated revenue event, all token holders receive their proportional share and all distribution transactions are recorded and verifiable on-chain.
- **SC-004**: Transparency availability: for any distribution or minting event, a signed report or on-chain events are accessible and verifiable within 24 hours.
- **SC-005**: Test coverage: core contract flows (minting, transfer, distribution, upgrade safety checks) have automated tests and pass in CI.

## Assumptions & Constraints

- Assumption: MVP targets a public testnet environment with mock KYC (none required); legal compliance for production will be addressed in future phases.
- Assumption: Investor contributions and revenue distributions settle in a single stablecoin (mock USDC on Polygon Mumbai for the demo).
- Assumption: Tokens remain freely transferable ERC-20 assets during the MVP; permissioned variants are deferred to the v2 roadmap.
- Constraint: Project constitution mandates front-end patterns and contract upgradeability (front-end: React + WalletConnect; contracts: UUPS proxies). These are project-level constraints and must be documented in the plan.

## Review & Acceptance Checklist

The reviewer MUST verify the following before accepting the spec into planning:

- [ ] The spec includes P1 user story for investor investment and acceptance scenarios.
- [ ] Tokenomics formula for minting is documented and example calculations are provided in the plan.
- [ ] Commissioning milestones and the transition to Active are documented.
- [ ] Distribution mechanics and fee structures are defined (who charges fees, when and how fees are applied).
- [ ] On-chain transparency artifacts and anchors are specified (events, reports, IPFS hashes, etc.).
- [ ] Tests required for core contract flows are listed and located in the plan/tasks.
- [ ] Clarification decisions (KYC, token permissioning, settlement currency) are captured in the Assumptions section and research notes.

```

*** End Patch