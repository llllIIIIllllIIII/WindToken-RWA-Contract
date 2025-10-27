# Project Codename: WindToken RWA
### Technical Specification (SPEC)
**Version:** v0.1 (Upgradeable MVP Architecture)  
**Last Updated:** 2025-10-25  

---

## 1. System Overview
WindToken RWA’s system tokenizes real-world wind turbines and their energy output.  
The MVP version focuses on one turbine using **ERC-20**,  
but the architecture allows future migration to **ERC-1155 (multi-turbine)** or a **Factory-based upgrade**.

---

## 2. System Architecture
```
Mock Data / Chainlink Function
↓
FastAPI Backend (optional)
↓
Smart Contract (ERC-20 → ERC-1155 ready)
↑
Frontend (Next.js + Ethers.js)
↑
User Wallet (MetaMask)
```
---
---

## 3. Smart Contract Design

### 3.1 Contract Overview
| Contract | Description | Phase |
|-----------|--------------|--------|
| `WindEnergyToken` | ERC-20 energy token | MVP |
| `WindTurbineFactory` | Deploys new turbine tokens (future) | Phase 2+ |
| `WindFarmEnergy` | ERC-1155 version for multi-turbine support | Phase 2+ |

---

### 3.2 MVP Contract (ERC-20)
```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract WindEnergyToken is ERC20 {
    address public owner;
    uint256 public totalGenerated; // in kWh
    string public turbineName;
    string public turbineLocation;

    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) {
        owner = msg.sender;
        turbineName = "Demo Turbine A1";
        turbineLocation = "Tainan, Taiwan";
    }

    function mint(address to, uint256 amount) external {
        require(msg.sender == owner, "Only owner");
        _mint(to, amount);
        totalGenerated += amount;
    }

    function getTurbineInfo() external view returns (string memory, string memory, uint256) {
        return (turbineName, turbineLocation, totalGenerated);
    }
}
```
