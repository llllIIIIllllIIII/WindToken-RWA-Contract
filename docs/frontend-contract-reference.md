# WindToken 智能合約前端整合指南

> **維護說明**：每當智能合約介面或行為有任何改動，請同步更新此文件，確保前端開發與 AI agent 能取得最新資訊。

## 合約總覽

| 合約 | 角色 | 來源檔案 |
|------|------|----------|
| `WindTurbineFactory` | 工廠：部署專案 Proxy 與 OwnershipToken Proxy，維護專案註冊資訊 | `contracts/factory/WindTurbineFactory.sol` |
| `WindTurbineProject` | 專案核心：募資、驗收、收益分配（以 USDC 直接分配並由持有人 claim） | `contracts/projects/WindTurbineProject.sol` |
| `OwnershipToken` | 權益代幣：UUPS 升級版 ERC20，內建權限控制 | `contracts/tokens/OwnershipToken.sol` |
| `MockUSDC` | 測試用穩定幣（6 位小數） | `contracts/mocks/MockUSDC.sol` |

- 所有核心合約皆採 **UUPS Proxy**。工廠會自動建立 `ERC1967Proxy`，並呼叫 `initialize`。
- 募資固定目標：`1,000,000 USDC`（6 位小數表示為 `1_000_000 * 1e6`）。
- 最小出資單位：`100 USDC`（`minContributionUnit()` 可取得）。
- 募資結束後會自動將所有新鑄造的 OwnershipToken 質押；只有維持質押的代幣才會累積收益，可隨時解除／重新質押。

- 注意：本專案已由「雙代幣」設計調整為「單代幣」模式。系統只保留 OwnershipToken（代表持份），收益以 USDC 直接分配給持有人；合約在分配時把應得金額記入持有人可領餘額（`claimable`），使用者需手動呼叫 `claim()` 將 USDC 提領。YieldToken 相關設計已移除。

## ABI 與部署資訊

- ABIs 可由 Foundry 輸出：`forge build` 之後可於 `out/` 或 `bin/solc-output-compile-all.json` 取得。
- 建議建立 `frontend/src/artifacts/*.json`，保存合約 ABI 與部署網路資訊，供前端與 AI agent 共用。
- 建議提供 `.env` 或 `config/*.ts` 列出：
  - `factoryAddress`
  - `stablecoinAddress`
  - `projectImplementation` / `ownershipTokenImplementation`（若前端需顯示）

## WindTurbineFactory 介面摘要

```solidity
function createProject(ProjectDeploymentConfig calldata config)
    external onlyOwner
    returns (address projectProxy, address ownershipTokenProxy);
```

`ProjectDeploymentConfig` 重要欄位：
- `operator` / `treasury`：專案角色地址。
- `stablecoin`：USDC 地址。
- `tokenName` / `tokenSymbol` / `tokenDecimals`：對應 OwnershipToken。
- `fundingGoal` 必須等於 `1_000_000 * 1e6`。
- `contributionRate` 必須等於 `1e18`（代表每筆 100 USDC 對應 1e18 權益代幣）。

常用讀取函式：
- `projectCount()` 與 `projectAt(index)`：列出專案。
- `projects(address)`：回傳最新 `ProjectRecord`（包含 `state`、`fundingGoal` 等）。
- `isProject(address)`：確認是否為工廠部署的專案。

事件：
- `ProjectRegistered(index, projectProxy, ownershipTokenProxy, operator, treasury, stablecoin, metadataURI)`

## WindTurbineProject 介面摘要

### 常數 / Getter
- `minContributionUnit() -> uint256`: 100 USDC（六位小數表示 `100 * 1e6`）。
- `fundingGoal() -> uint256`: 1,000,000 USDC。
- `contributionRate() -> uint256`: 1e18（對應 OwnershipToken 18 位小數）。
- `state() -> ProjectState`: `Fundraising`, `Commissioning`, `Active`, `Closed`。
- 其他常見 getter：`totalRaised()`, `totalDistributed()`, `totalStaked()`, `ownershipToken()`, `stablecoin()`, `operator()`, `treasury()`。
- 使用者資產查詢：`stakedBalance(address)`, `unstakedBalance(address)`。

### 募資相關函式
```solidity
function previewContribution(uint256 amount)
    external view
    returns (uint256 mintAmount, uint256 newTotalRaised, bool fundingGoalMet);

function contribute(uint256 amount)
    external nonReentrant returns (uint256 mintedPreview);

function withdrawContribution(uint256 amount)
    external nonReentrant returns (uint256 refunded);
```
- `amount` 必須是 `minContributionUnit()` 的整數倍。
- 前端呼叫順序建議：
  1. 使用 `previewContribution` 取得可鑄造數量及是否達標。
  2. 先對 USDC 合約呼叫 `approve(projectAddress, amount)`。
  3. 再呼叫 `contribute(amount)`。
- 募資期間隨時可呼叫 `withdrawContribution(amount)` 退回出資。

### 狀態轉換
- 募資達標後內部呼叫 `_finalizeFundraising()`：
  - 為每位投資人一次性鑄造 OwnershipToken。
  - 觸發 `TokensBatchMinted(totalMinted, holderCount)`。
  - 狀態由 `Fundraising` → `Commissioning`。
- `markCommissioned(proofCid)`：由營運者觸發，進入 `Active` 狀態。

### 質押流程
```solidity
function stake(uint256 amount) external nonReentrant;
function unstake(uint256 amount) external nonReentrant;
const userAddress = await signer.getAddress();
```
- 募資結束後（進入 `Commissioning` 之前）系統會自動幫投資人質押全部新鑄造的 OwnershipToken。
- **只有質押中的代幣才會累積收益**。解除質押後的代幣若需要再次領取收益，必須重新呼叫 `stake`。
- `stake` 會檢查持有人可用（未質押）的代幣數量，`amount` 必須大於 0 且不得超過未質押餘額。
- `unstake` 支援部分解除質押，沒有手續費或冷卻期；解除後即可自由轉帳或交易。
- 事件對應：`Staked(holder, amount)`、`Unstaked(holder, amount)`，可供前端更新 UI 與通知。

// 若有未質押的代幣，可立即重新質押以繼續累積收益
const unstaked = await project.unstakedBalance(userAddress);
if (unstaked > 0n) {
  await project.stake(unstaked);
}

### 收益流程
```solidity
function reportRevenue(uint256 grossAmount, uint256 fees, string calldata reportCid, uint64 periodStart, uint64 periodEnd)
    external onlyRole(OPERATOR_ROLE)
    returns (uint256 revenueId);

function distribute(uint256 revenueId)
    external onlyRole(OPERATOR_ROLE) nonReentrant
    returns (uint256 totalDistributed);
```
- `reportRevenue` 會：
  - 從營運者拉入 `grossAmount` USDC。
  - 將 `fees` 匯給金庫（`treasury`）。
  - 將 `netRevenue` 鎖定於專案合約；若餘額不足會 revert。
- `distribute`：
  - 依照各地址「目前質押中的 OwnershipToken 數量」計算分潤，未質押的代幣不會收到收益。
  - 合約仍使用內部 `EnumerableSet` 維護持有人集合，前端可透過事件重建或後端服務提供。
  - 將每位持有人應得的 USDC 記入合約內的 `claimable` 餘額（合約不會在 `distribute` 時直接轉帳給使用者）。
  - 每次為持有人記帳時會 emit `FundsCredited(holder, amount)`，最後會發出 `RevenueDistributed` 以紀錄本期分潤總量。
  - 使用者必須呼叫 `claim()` 才會把累積的 USDC 實際轉到他們的錢包（或由授權的 relayer/後端代為呼叫）。

### 事件整理
`ContributionReceived(contributor, usdcAmount, tokenAmountPreview, totalRaised)`
`ContributionWithdrawn(contributor, usdcAmount, totalRaised)`
`FundingGoalReached(goal, timestamp)`
`TokensBatchMinted(totalMinted, holderCount)`
`Staked(holder, amount)`
`Unstaked(holder, amount)`
`CommissioningConfirmed(proofCid, timestamp)`
`RevenueReported(revenueId, grossRevenue, netRevenue, reportCid)`
`FundsCredited(holder, amount)`
`Claimed(holder, amount)`
`RevenueDistributed(revenueId, totalDistributed, holderCount)`


> **注意（Claim 流程）**：收益分配改為把 USDC 記入合約的 `claimable` 餘額，前端需呼叫 `project.claimable(address)` 顯示使用者可領金額，並在使用者按下 Claim 時呼叫 `project.claim()`。建議前端同時監聽 `FundsCredited` 與 `Claimed` 事件來維持即時 UI。

## OwnershipToken 介面摘要

- `initialize(name, symbol, decimals, project, admin)`：工廠在部署 Proxy 後呼叫。
- `project()`：回傳綁定的專案。
- `minter()` / `setMinter(address)`：
  - 預設 `project` 為 minter。
  - 只有 `DEFAULT_ADMIN_ROLE`（通常為 operator）可更新。
- `mint(to, amount)`：專案或授權 minter 呼叫。
- `burn(from, amount)`：minter 或持有人自行銷毀。
- 事件：`MinterUpdated(newMinter)`。
- 轉帳/鑄造/銷毀都會觸發專案的 `onTokenTransfer`，以維護持有人集合。

## 前端開發建議流程

1. **載入合約**：使用 wagmi / ethers 取得 `factory`, `project`, `ownershipToken`, `stablecoin` 的 contract 實例。
2. **專案列表**：
   - 呼叫 `factory.projectCount()` + `projectAt(i)` 取得專案地址。
   - 透過 `factory.projects(projectAddress)` 取出 `ProjectRecord`（含狀態）。
3. **募資畫面**：
   - 顯示 `project.totalRaised() / project.fundingGoal()`。
   - 使用 `project.minContributionUnit()` 決定輸入步長。
   - 執行 `previewContribution` → `approve` → `contribute`。
   - 允許 `withdrawContribution`（顯示可退金額 `investorInfo(msg.sender).totalContributed`）。
4. **募資完成後**：監聽 `TokensBatchMinted`、`FundingGoalReached`，提示用戶代幣已發放。
5. **收益期間**：
  - `project.revenueEventsCount()` + `getRevenueEvent(id)` 顯示收益記錄。
  - `project.hasPendingDistributions()` 用於提示待分潤事件。
  - 監聽 `FundsCredited` 與 `Claimed` 事件更新使用者可領金額，或定期輪詢 `project.claimable(user)`。
  - 提供 Claim 按鈕：呼叫 `project.claim()`，交易完成後重新查詢 `claimable` 與 USDC 餘額。
6. **代幣持有資訊**：
   - OwnershipToken 標準 ERC20 介面，可透過 `balanceOf`、`totalSupply` 顯示。
   - 若需要持有人列表，需由後端/子圖或事件掃描重建（合約未直接暴露 `EnumerableSet` 內容）。

## TypeScript 範例片段

```ts
import { ethers } from "ethers";
import factoryAbi from "./artifacts/WindTurbineFactory.json";
import projectAbi from "./artifacts/WindTurbineProject.json";
import erc20Abi from "./artifacts/ERC20.json";

const provider = new ethers.JsonRpcProvider(process.env.RPC_URL!);
const signer = new ethers.Wallet(process.env.PRIVATE_KEY!, provider);

const factory = new ethers.Contract(factoryAddress, factoryAbi, signer);
const projectAddr = await factory.projectAt(0);
const project = new ethers.Contract(projectAddr, projectAbi, signer);
const userAddress = await signer.getAddress();

const minUnit = await project.minContributionUnit();
const amount = minUnit * 5n; // 500 USDC
const usdc = new ethers.Contract(stablecoinAddress, erc20Abi, signer);
await usdc.approve(projectAddr, amount);
await project.contribute(amount);

const unstaked = await project.unstakedBalance(userAddress);
if (unstaked > 0n) {
  await project.stake(unstaked);
}

// 查詢並提領（若有可領金額）
const claimable = await project.claimable(userAddress);
if (claimable > 0n) {
  const tx = await project.claim();
  await tx.wait();
}
```

> **小提醒**：USDC 使用 6 位小數，顯示時請使用 `ethers.formatUnits(value, 6)`；OwnershipToken 預設 18 位小數。

## UUPS 升級注意事項

- 只有擁有 `UPGRADER_ROLE` 的帳號可以呼叫 `upgradeTo(newImplementation)`。
- 升級流程：部署新邏輯合約 → 使用 `cast send <proxy> "upgradeTo(address)" <new>`。
- 升級前後請更新此文件並通知前端。

---

若前端或 AI agent 需要額外範例或新的 API，請在修改合約後立即更新本文件並標註更新日期。