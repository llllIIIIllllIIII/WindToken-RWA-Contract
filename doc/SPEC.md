# Project Codename: WindToken RWA
### Technical Specification (SPEC)
**Version:** v0.2 (OwnershipToken + Claimable USDC)  
**Last Updated:** 2025-11-01  

---

## 1. System Overview
WindToken RWA 的系統透過 OwnershipToken 將風力專案的擁有權代幣化，並以 USDC 直接分配收益。  
MVP 聚焦在單一風機專案與 ERC-20 OwnershipToken，未來仍可升級至 **多專案 Factory 模式** 或 **ERC-1155**。  

---

## 2. System Architecture
```
IoT Telemetry / Mock Data
↓
Off-chain Aggregation (FastAPI / Node Relayer) [Optional]
↓
WindTurbineProject + OwnershipToken (UUPS proxies)
↑
Frontend (Next.js + wagmi)
↑
User Wallet (MetaMask)
```
---
---

## 3. Smart Contract Design

### 3.1 Contract Overview
| Contract | Description | Phase |
|-----------|--------------|--------|
| `WindTurbineProject` | 募資、驗收、收益分配（記帳 + claim） | MVP |
| `OwnershipToken` | ERC-20 ownership token，轉帳時回報持有人變動 | MVP |
| `WindTurbineFactory` | 部署專案與 OwnershipToken 的 UUPS 代理 | MVP |
| `WindFarmEnergy` | ERC-1155 版本（多風機支援） | Phase 2+ |

---

### 3.2 MVP Contract (ERC-20 Ownership + USDC distribution)

MVP 核心邏輯：
- 募資階段：投資人以 USDC 出資（100 USDC 為單位），合約暫存資金並記錄貢獻。募資達標後一次性鑄造 OwnershipToken，並進入驗收（Commissioning）。
- 營運階段：Operator 報告收益 (`reportRevenue`) 並將 USDC 匯入合約；`distribute` 按 OwnershipToken 即時持有人比例將應得金額記入 `claimable`，使用者呼叫 `claim()` 提領。
- Treasury 可透過 `withdrawRemainder` 提領未分配餘額（排除 `claimable` 與待分潤鎖定資金）。
- 所有合約使用 UUPS Proxy，可緊急升級修正。

介面要點（摘錄）：
```solidity
function contribute(uint256 amount) external returns (uint256 mintedPreview);
function withdrawContribution(uint256 amount) external returns (uint256 refunded);
function reportRevenue(uint256 grossAmount, uint256 fees, string calldata reportCid, uint64 start, uint64 end)
    external
    returns (uint256 revenueId);
function distribute(uint256 revenueId) external returns (uint256 totalDistributed);
function claimable(address account) external view returns (uint256);
function claim() external returns (uint256 amount);
```
