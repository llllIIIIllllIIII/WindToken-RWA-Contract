// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IOwnershipToken} from "../interfaces/IOwnershipToken.sol";
import {IWindTurbineFactory} from "../interfaces/IWindTurbineFactory.sol";
import {IWindTurbineProject} from "../interfaces/IWindTurbineProject.sol";

/// @title WindTurbineFactory
/// @notice 建立專案與權益代幣的工廠，同時維護註冊資訊。
contract WindTurbineFactory is Ownable, IWindTurbineFactory {
    address private _projectImplementation;
    address private _ownershipTokenImplementation;

    address[] private _projects;
    mapping(address project => ProjectRecord) private _registry;
    mapping(address project => bool) private _isProject;

    constructor(address projectImplementation_, address ownershipTokenImplementation_, address owner_)
        Ownable(owner_)
    {
        _projectImplementation = projectImplementation_;
        _ownershipTokenImplementation = ownershipTokenImplementation_;
    }

    /// @dev 回傳目前專案實作合約。
    function projectImplementation() external view override returns (address) {
        return _projectImplementation;
    }

    /// @dev 回傳目前權益代幣實作合約。
    function ownershipTokenImplementation() external view override returns (address) {
        return _ownershipTokenImplementation;
    }

    /// @dev 已建立專案的數量。
    function projectCount() external view override returns (uint256) {
        return _projects.length;
    }

    /// @dev 依序號取得專案地址。
    function projectAt(uint256 index) external view override returns (address) {
        require(index < _projects.length, "Factory: out of range");
        return _projects[index];
    }

    /// @dev 傳回最新狀態的專案紀錄。
    function projects(address project) external view override returns (ProjectRecord memory record) {
        record = _registry[project];
        if (record.projectProxy != address(0)) {
            record.state = IWindTurbineProject(project).state();
        }
    }

    /// @dev 取回所有專案紀錄（資料量大時請慎用）。
    function getProjects() external view override returns (ProjectRecord[] memory records) {
        uint256 length = _projects.length;
        records = new ProjectRecord[](length);
        for (uint256 i = 0; i < length; i++) {
            address project = _projects[i];
            ProjectRecord memory record = _registry[project];
            if (record.projectProxy != address(0)) {
                record.state = IWindTurbineProject(project).state();
            }
            records[i] = record;
        }
    }

    /// @dev 建立新專案與權益代幣，並註冊於工廠。
    function createProject(ProjectDeploymentConfig calldata config)
        external
        override
        onlyOwner
        returns (address projectProxy, address ownershipTokenProxy)
    {
        require(_projectImplementation != address(0), "Factory: project impl");
        require(_ownershipTokenImplementation != address(0), "Factory: token impl");
        require(config.operator != address(0), "Factory: operator");
        require(config.treasury != address(0), "Factory: treasury");
        require(address(config.stablecoin) != address(0), "Factory: stablecoin");
        require(config.fundingGoal == 1_000_000 * 1e6, "Factory: goal");
        require(config.contributionRate == 1e18, "Factory: rate");
        require(config.ownershipToken == address(0), "Factory: preset token");

        projectProxy = address(new ERC1967Proxy(_projectImplementation, ""));

        bytes memory tokenInit = abi.encodeCall(
            IOwnershipToken.initialize,
            (config.tokenName, config.tokenSymbol, config.tokenDecimals, projectProxy, config.operator)
        );
        ownershipTokenProxy = address(new ERC1967Proxy(_ownershipTokenImplementation, tokenInit));

        IWindTurbineProject.ProjectConfig memory projectConfig = IWindTurbineProject.ProjectConfig({
            operator: config.operator,
            stablecoin: address(config.stablecoin),
            treasury: config.treasury,
            ownershipToken: ownershipTokenProxy,
            metadataURI: config.metadataURI,
            commissioningDocsURI: config.commissioningDocsURI,
            tokenName: config.tokenName,
            tokenSymbol: config.tokenSymbol,
            tokenDecimals: config.tokenDecimals,
            fundingGoal: config.fundingGoal,
            contributionRate: config.contributionRate
        });

        IWindTurbineProject(projectProxy).initialize(projectConfig);

        _projects.push(projectProxy);
        _isProject[projectProxy] = true;

        ProjectRecord storage record = _registry[projectProxy];
        record.projectProxy = projectProxy;
        record.ownershipToken = ownershipTokenProxy;
        record.operator = config.operator;
        record.treasury = config.treasury;
        record.stablecoin = config.stablecoin;
        record.fundingGoal = config.fundingGoal;
        record.contributionRate = config.contributionRate;
        record.metadataURI = config.metadataURI;
        record.state = IWindTurbineProject.ProjectState.Fundraising;

        emit ProjectRegistered(
            _projects.length - 1,
            projectProxy,
            ownershipTokenProxy,
            config.operator,
            config.treasury,
            address(config.stablecoin),
            config.metadataURI
        );
    }

    /// @dev 更新專案與 PowerToken 的實作合約。
    function setTemplates(address projectImplementation_, address ownershipTokenImplementation_)
        external
        override
        onlyOwner
    {
        require(projectImplementation_ != address(0), "Factory: project impl");
        require(ownershipTokenImplementation_ != address(0), "Factory: token impl");
        _projectImplementation = projectImplementation_;
        _ownershipTokenImplementation = ownershipTokenImplementation_;
        emit TemplatesUpdated(projectImplementation_, ownershipTokenImplementation_);
    }

    /// @dev 檢查指定地址是否由本工廠部署。
    function isProject(address account) external view override returns (bool) {
        return _isProject[account];
    }
}
