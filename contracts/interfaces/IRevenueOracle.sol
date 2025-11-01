// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IRevenueOracle {
    event RevenueSubmitted(
        uint256 indexed revenueId,
        uint256 grossRevenue,
        uint256 fees,
        uint256 netRevenue,
        string reportCid,
        uint64 periodStart,
        uint64 periodEnd
    );

    /// Project contract that consumes submitted revenue data.
    function project() external view returns (address);

    /// Records monthly revenue details and returns the identifier used by the project.
    function submitRevenue(
        uint256 grossRevenue,
        uint256 fees,
        string calldata reportCid,
        uint64 periodStart,
        uint64 periodEnd
    ) external returns (uint256 revenueId);

    /// Latest submitted revenue datapoint, mirroring the emitted event payload.
    function latestRevenue()
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
        );
}
