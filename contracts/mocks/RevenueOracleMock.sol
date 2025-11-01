// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IRevenueOracle} from "../interfaces/IRevenueOracle.sol";

/// @title RevenueOracleMock
/// @notice 以手動提交方式模擬每月收益資訊的預言機。
contract RevenueOracleMock is Ownable, IRevenueOracle {
    struct RevenueData {
        uint256 grossRevenue;
        uint256 fees;
        uint256 netRevenue;
        string reportCid;
        uint64 periodStart;
        uint64 periodEnd;
        uint64 recordedAt;
    }

    address private immutable _project;
    address private _reporter;

    uint256 private _revenueCount;
    mapping(uint256 revenueId => RevenueData) private _revenues;

    event ReporterUpdated(address indexed reporter);

    /// @param project_ 專案合約位址，方便前端校驗來源。
    /// @param owner_ 擁有者，可更新報告者並提交收益。
    /// @param reporter_ 初始可提交收益的帳號；若為零則沿用 owner。
    constructor(address project_, address owner_, address reporter_) Ownable(owner_) {
        require(project_ != address(0), "RevenueOracle: project required");
        _project = project_;
        _setReporter(reporter_ == address(0) ? owner_ : reporter_);
    }

    /// @dev 回傳對應的專案合約。
    function project() external view override returns (address) {
        return _project;
    }

    /// @dev 供報告者提交收益資料，並儲存於合約內。
    function submitRevenue(
        uint256 grossRevenue,
        uint256 fees,
        string calldata reportCid,
        uint64 periodStart,
        uint64 periodEnd
    ) external override returns (uint256 revenueId) {
        require(msg.sender == _reporter || msg.sender == owner(), "RevenueOracle: unauthorized");
        require(grossRevenue >= fees, "RevenueOracle: fees exceed gross");
        require(periodEnd >= periodStart, "RevenueOracle: invalid period");

        uint64 recordedAt = uint64(block.timestamp);
        uint256 netRevenue = grossRevenue - fees;

        revenueId = ++_revenueCount;
        _revenues[revenueId] = RevenueData({
            grossRevenue: grossRevenue,
            fees: fees,
            netRevenue: netRevenue,
            reportCid: reportCid,
            periodStart: periodStart,
            periodEnd: periodEnd,
            recordedAt: recordedAt
        });

        emit RevenueSubmitted(revenueId, grossRevenue, fees, netRevenue, reportCid, periodStart, periodEnd);
    }

    /// @dev 取得最新一次提交的收益資訊，若尚未提交則回傳預設值。
    function latestRevenue()
        external
        view
        override
        returns (
            uint256 grossRevenue,
            uint256 fees,
            uint256 netRevenue,
            string memory reportCid,
            uint64 periodStart,
            uint64 periodEnd,
            uint64 recordedAt
        )
    {
        if (_revenueCount == 0) {
            return (0, 0, 0, "", 0, 0, 0);
        }

        RevenueData storage record = _revenues[_revenueCount];
        return (
            record.grossRevenue,
            record.fees,
            record.netRevenue,
            record.reportCid,
            record.periodStart,
            record.periodEnd,
            record.recordedAt
        );
    }

    /// @dev 透過編號查詢任一歷史收益紀錄。
    function revenueById(uint256 revenueId)
        external
        view
        returns (
            uint256 grossRevenue,
            uint256 fees,
            uint256 netRevenue,
            string memory reportCid,
            uint64 periodStart,
            uint64 periodEnd,
            uint64 recordedAt
        )
    {
        RevenueData storage record = _revenues[revenueId];
        return (
            record.grossRevenue,
            record.fees,
            record.netRevenue,
            record.reportCid,
            record.periodStart,
            record.periodEnd,
            record.recordedAt
        );
    }

    /// @dev 查詢目前允許提交收益的帳號。
    function reporter() external view returns (address) {
        return _reporter;
    }

    /// @dev 僅限擁有者可更新報告者權限。
    function setReporter(address newReporter) external onlyOwner {
        _setReporter(newReporter);
    }

    /// @dev 內部工具：檢查並更新報告者。
    function _setReporter(address newReporter) private {
        require(newReporter != address(0), "RevenueOracle: reporter required");
        _reporter = newReporter;
        emit ReporterUpdated(newReporter);
    }
}
