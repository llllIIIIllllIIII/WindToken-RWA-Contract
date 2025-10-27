```markdown
# Research: WindToken Issuance - Decisions & Rationale

**Feature**: specs/001-windtoken-issuance/spec.md
**Created**: 2025-10-27

## Decision 1 — KYC / AML policy

- Decision: NO KYC for MVP (KYC deferred)
- Rationale: For a hackathon MVP and public demo on testnet we minimize legal friction and implementation scope. Avoiding KYC lets us use a public ERC-20 flow, reduces UI complexity, and accelerates delivery within the 1-week timebox.
- Alternatives considered:
  - Require KYC for all investors (adds compliance, identity provider integration, permissioned token requirements, increases scope significantly).
  - Hybrid (KYC only for large investors): reduces risk but adds complexity for threshold logic and onboarding.
- Implications: Permissioning and legal guardrails must be added in v2 for mainnet deployments. For demo we will use mock stablecoin and test wallets.

## Decision 2 — Token permissioning

- Decision: PUBLIC ERC-20 for MVP (transferable token)
- Rationale: Matches "no KYC" decision, simplifies secondary market demo, and speeds development. The token will be mintable by the associated WindTurbineRWA contract only.
- Alternatives considered:
  - Permissioned token (ERC-3643): better for compliance but requires identity/registry systems.
  - Hybrid approaches (transfer windows): adds governance complexity.
- Implications: v2 roadmap will include ERC-3643 migration path and on-chain permission registry if stakeholders require KYC.

## Decision 3 — Settlement currency

- Decision: Use stablecoin (mock USDC on Polygon Mumbai) for contributions and distributions in MVP.
- Rationale: Stablecoins remove price-volatility noise from revenue accounting and make distribution math easier to demonstrate. Using a mock USDC contract on testnet ensures reproducible demos.
- Alternatives considered:
  - Native chain token (MATIC/ETH): simpler UX but introduces volatility for revenue calculations.
  - Multi-currency support: increases implementation complexity for conversion and accounting.
- Implications: For mainnet, choose an audited stablecoin (USDC/USDT) and ensure proper bridging/wrap considerations.

## Other research notes

- Upgradeability: Use UUPS (OpenZeppelin) for on-chain upgrade path, with `_authorizeUpgrade` restricted to a multisig admin account.
- Distribution scaling: For hackathon MVP, handle small-holder distributions on-chain in batches; document Merkle-based claim distribution as v2.
- Off-chain anchoring: Use IPFS for signed monthly reports and emit events with IPFS CID for traceability.

```
