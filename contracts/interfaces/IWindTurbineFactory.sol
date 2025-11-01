// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IWindTurbineProject} from "./IWindTurbineProject.sol";

interface IWindTurbineFactory {
    struct ProjectDeploymentConfig {
        address operator;
        IERC20 stablecoin;
        address treasury;
        address ownershipToken;
        string metadataURI;
        string commissioningDocsURI;
        string tokenName;
        string tokenSymbol;
        uint8 tokenDecimals;
        uint256 fundingGoal;
        uint256 contributionRate;
    }

    struct ProjectRecord {
        address projectProxy;
        address ownershipToken;
        address operator;
        address treasury;
        IERC20 stablecoin;
        uint256 fundingGoal;
        uint256 contributionRate;
        string metadataURI;
        IWindTurbineProject.ProjectState state;
    }

    event ProjectRegistered(
        uint256 indexed projectId,
        address indexed projectProxy,
        address indexed ownershipToken,
        address operator,
        address treasury,
        address stablecoin,
        string metadataURI
    );

    event TemplatesUpdated(address projectImplementation, address ownershipTokenImplementation);

    /// Current logic contract used when deploying new project proxies.
    function projectImplementation() external view returns (address);

    /// Current OwnershipToken implementation used by proxies created via the factory.
    function ownershipTokenImplementation() external view returns (address);

    /// Total number of project proxies created so far.
    function projectCount() external view returns (uint256);

    /// Returns the project proxy address at the provided index.
    function projectAt(uint256 index) external view returns (address);

    /// Retrieves the cached registry record for an existing project proxy.
    function projects(address project) external view returns (ProjectRecord memory);

    /// Returns the full list of project records (use with care for large sets).
    function getProjects() external view returns (ProjectRecord[] memory);

    /// Deploys a new project proxy plus OwnershipToken and stores them in the registry.
    function createProject(ProjectDeploymentConfig calldata config)
        external
        returns (address projectProxy, address ownershipToken);

    /// Updates the UUPS implementation addresses for future deployments.
    function setTemplates(address projectImplementation, address ownershipTokenImplementation) external;

    /// Checks if an address was deployed by this factory.
    function isProject(address account) external view returns (bool);
}
