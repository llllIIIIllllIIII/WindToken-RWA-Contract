```markdown
# Data Model: WindToken Issuance & Distribution

**Feature**: specs/001-windtoken-issuance/spec.md
**Created**: 2025-10-27

## Entities

- Project
  - id: UUID / uint256
  - operator: address
  - metadata: {name, location, capacity_kw}
  - fundingGoal: uint256 (in settlement currency smallest unit)
  - tokenParams: {name, symbol, decimals, initialRate}
  - state: enum {Draft, Fundraising, Commissioning, Active, Closed}
  - commissionedAt: timestamp | null
  - createdAt: timestamp

- Investor
  - wallet: address (primary identifier)
  - contributions: list of Contribution ids
  - balance: uint256 (token balance cached for quick queries)

- Contribution
  - id: txHash | sequential id
  - projectId: Project.id
  - investor: address
  - amount: uint256 (settlement currency)
  - mintedTokens: uint256
  - timestamp: ISO8601
  - txHash: string

- Token (PowerToken)
  - contractAddress: address
  - totalSupply: uint256
  - decimals: uint8
  - permissioningFlag: boolean (false for MVP)

- RevenueEvent
  - id: sequential
  - projectId: Project.id
  - period: string (e.g., 2025-10)
  - grossRevenue: uint256
  - fees: uint256
  - netRevenue: uint256
  - ipfsCid: string (signed report)
  - recordedAt: timestamp

- Distribution
  - id: sequential
  - revenueEventId: RevenueEvent.id
  - totalDistributed: uint256
  - perHolderData: reference to distribution details (or merkleRoot)
  - txHash: string
  - createdAt: timestamp

## Relationships

- Project 1:N Contribution
- Project 1:1 PowerToken
- Project 1:N RevenueEvent
- RevenueEvent 1:N Distribution (usually 1:1 for simple flow)

## Validation rules

- contribution.amount > 0
- contributions sum <= fundingGoal while Fundraising
- mintedTokens computed by tokenomics formula: minted = floor(amount * rate)

## State transitions (Project.state)

- Draft -> Fundraising: set when operator opens campaign
- Fundraising -> Commissioning: when fundingGoal met or operator closes fundraising
- Commissioning -> Active: when commissioning proof accepted
- Active -> Closed: when project lifecycle ends or operator closes

```
