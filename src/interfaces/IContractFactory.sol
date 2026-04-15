// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IContractFactory {

    // ─── Events ───────────────────────────────────────────────────────────────
    event ImplementationRegistered(
        bytes32 indexed contractId,
        address indexed implementation,
        uint256 version,
        string metadata
    );
    event ImplementationUpgraded(
        bytes32 indexed contractId,
        uint256 indexed version,
        address newImplementation
    );
    event ImplementationDeprecated(bytes32 indexed contractId, uint256 indexed version);
    event ContractDeployed(
        address indexed clone,
        bytes32 indexed contractId,
        address indexed deployer,
        uint256 version
    );

    // ─── Errors ───────────────────────────────────────────────────────────────
    error InvalidImplementationAddress();
    error ImplementationNotFound();
    error LicenseNotValid(uint256 tokenId);
    error LicenseAlreadyUsed(uint256 tokenId);
    error NotLicenseOwner(uint256 tokenId);
    error LicenseMismatch(bytes32 expected, bytes32 actual);
    error ArrayLengthMismatch();
    error InitializationFailed();

    // ─── Registration ─────────────────────────────────────────────────────────
    function registerImplementation(
        bytes32 contractId,
        address implementation,
        string calldata metadata
    ) external;

    function upgradeImplementation(
        bytes32 contractId,
        address newImplementation,
        string calldata metadata
    ) external;

    function deprecateImplementation(bytes32 contractId, uint256 version) external;

    // ─── Deployment ───────────────────────────────────────────────────────────
    function deployContract(bytes32 contractId, uint256 licenseTokenId)
        external returns (address clone);

    function deployContractWithVersion(
        bytes32 contractId,
        uint256 licenseTokenId,
        uint256 version
    ) external returns (address clone);

    function deployContractBatch(
        bytes32[] calldata contractIds,
        uint256[] calldata licenseTokenIds
    ) external returns (address[] memory clones);

    // ─── Views ────────────────────────────────────────────────────────────────
    function getImplementationInfo(bytes32 contractId, uint256 version)
        external view returns (
            address implementation,
            uint256 versionNum,
            bool isActive,
            string memory metadata
        );

    function getActiveImplementation(bytes32 contractId)
        external view returns (
            address implementation,
            uint256 version,
            string memory metadata
        );

    function getInstanceContractId(address instance) external view returns (bytes32);

    function getUserDeployments(address user, bytes32 contractId)
        external view returns (address[] memory);

    function isLicenseUsed(uint256 tokenId) external view returns (bool);
}
