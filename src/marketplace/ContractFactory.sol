// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {IContractFactory} from "../interfaces/IContractFactory.sol";
import {ILicenseNFT} from "../interfaces/ILicenseNFT.sol";

contract ContractFactory is Ownable, IContractFactory {
    using Clones for address;

    // ─── Errors ───────────────────────────────────────────────────────────────



    // ─── Storage ──────────────────────────────────────────────────────────────

    struct ImplVersion {
        address addr;
        string metadata;
        bool deprecated;
    }

    mapping(bytes32 => ImplVersion[]) private _versions;
    mapping(address => bytes32) private _instanceContractId;
    mapping(address => mapping(bytes32 => address[])) private _userDeployments;
    mapping(uint256 => bool) private _licenseUsed;

    ILicenseNFT public immutable licenseNFT;

    // ─── Constructor ──────────────────────────────────────────────────────────

    constructor(address _licenseNFT) Ownable(msg.sender) {
        if (_licenseNFT == address(0)) revert InvalidImplementationAddress();
        licenseNFT = ILicenseNFT(_licenseNFT);
    }

    // ─── Registration ─────────────────────────────────────────────────────────

    function registerImplementation(
        bytes32 contractId,
        address implementation,
        string calldata metadata
    ) external override onlyOwner {
        if (implementation == address(0)) revert InvalidImplementationAddress();

        uint256 ver = _versions[contractId].length;

        _versions[contractId].push(
            ImplVersion({
                addr: implementation,
                metadata: metadata,
                deprecated: false
            })
        );

        emit ImplementationRegistered(contractId, implementation, ver, metadata);
    }

    function upgradeImplementation(
        bytes32 contractId,
        address newImplementation,
        string calldata metadata
    ) external override onlyOwner {
        if (newImplementation == address(0)) revert InvalidImplementationAddress();

        uint256 ver = _versions[contractId].length;

        _versions[contractId].push(
            ImplVersion({
                addr: newImplementation,
                metadata: metadata,
                deprecated: false
            })
        );

        emit ImplementationUpgraded(contractId, ver, newImplementation);
    }

    function deprecateImplementation(bytes32 contractId, uint256 version)
        external
        override
        onlyOwner
    {
        ImplVersion[] storage vers = _versions[contractId];

        if (version >= vers.length || vers[version].addr == address(0)) {
            revert ImplementationNotFound();
        }

        vers[version].deprecated = true;

        emit ImplementationDeprecated(contractId, version);
    }

    // ─── Deployment ───────────────────────────────────────────────────────────

    function deployContract(bytes32 contractId, uint256 licenseTokenId)
        external
        override
        returns (address clone)
    {
        _checkLicense(contractId, licenseTokenId);

        uint256 ver = _activeVersion(contractId);

        clone = _deploy(contractId, ver, licenseTokenId);
    }

    function deployContractWithVersion(
        bytes32 contractId,
        uint256 licenseTokenId,
        uint256 version
    ) external override returns (address clone) {
        _checkLicense(contractId, licenseTokenId);

        ImplVersion[] storage vers = _versions[contractId];

        if (version >= vers.length || vers[version].addr == address(0)) {
            revert ImplementationNotFound();
        }

        if (vers[version].deprecated) {
            revert ImplementationNotFound();
        }

        clone = _deploy(contractId, version, licenseTokenId);
    }

    function deployContractBatch(
        bytes32[] calldata contractIds,
        uint256[] calldata licenseTokenIds
    ) external override returns (address[] memory clones) {
        if (contractIds.length != licenseTokenIds.length) {
            revert ArrayLengthMismatch();
        }

        clones = new address[](contractIds.length);

        for (uint256 i; i < contractIds.length; ++i) {
            _checkLicense(contractIds[i], licenseTokenIds[i]);

            uint256 ver = _activeVersion(contractIds[i]);

            clones[i] = _deploy(contractIds[i], ver, licenseTokenIds[i]);
        }
    }

    // ─── Views ────────────────────────────────────────────────────────────────

    function getImplementationInfo(bytes32 contractId, uint256 version)
        external
        view
        override
        returns (
            address implementation,
            uint256 versionNum,
            bool isActive,
            string memory metadata
        )
    {
        ImplVersion[] storage vers = _versions[contractId];

        if (version >= vers.length) {
            revert ImplementationNotFound();
        }

        ImplVersion storage v = vers[version];

        return (v.addr, version, !v.deprecated, v.metadata);
    }

    function getActiveImplementation(bytes32 contractId)
        external
        view
        override
        returns (
            address implementation,
            uint256 version,
            string memory metadata
        )
    {
        version = _activeVersion(contractId);

        ImplVersion storage v = _versions[contractId][version];

        return (v.addr, version, v.metadata);
    }

    function getInstanceContractId(address instance)
        external
        view
        override
        returns (bytes32)
    {
        return _instanceContractId[instance];
    }

    function getUserDeployments(address user, bytes32 contractId)
        external
        view
        override
        returns (address[] memory)
    {
        return _userDeployments[user][contractId];
    }

    function isLicenseUsed(uint256 tokenId)
        external
        view
        override
        returns (bool)
    {
        return _licenseUsed[tokenId];
    }

    // ─── Internal ─────────────────────────────────────────────────────────────

    function _checkLicense(bytes32 contractId, uint256 tokenId) internal {
        (bool ok, bytes memory data) =
            address(licenseNFT).staticcall(
                abi.encodeWithSignature("ownerOf(uint256)", tokenId)
            );

        if (!ok) revert LicenseNotValid(tokenId);

        address tokenOwner = abi.decode(data, (address));

        if (tokenOwner != msg.sender) {
            revert NotLicenseOwner(tokenId);
        }

        if (!licenseNFT.isLicenseValid(tokenId)) {
            revert LicenseNotValid(tokenId);
        }

        bytes32 licContractId = licenseNFT.tokenContractId(tokenId);

        if (licContractId != contractId) {
            revert LicenseMismatch(contractId, licContractId);
        }

        if (_licenseUsed[tokenId]) {
            revert LicenseAlreadyUsed(tokenId);
        }

        _licenseUsed[tokenId] = true;
    }

    function _activeVersion(bytes32 contractId) internal view returns (uint256) {
        ImplVersion[] storage vers = _versions[contractId];

        if (vers.length == 0) {
            revert ImplementationNotFound();
        }

        for (uint256 i = vers.length; i > 0; --i) {
            if (!vers[i - 1].deprecated) {
                return i - 1;
            }
        }

        revert ImplementationNotFound();
    }

    function _deploy(
        bytes32 contractId,
        uint256 version,
        uint256 licenseTokenId
    ) internal returns (address clone) {
        ImplVersion storage v = _versions[contractId][version];

        clone = v.addr.clone();

        (bool ok, ) = clone.call(
            abi.encodeWithSignature("initialize(address)", msg.sender)
        );

        if (!ok) {
            (bool hasInit, ) = clone.staticcall(
                abi.encodeWithSignature("initialize(address)", msg.sender)
            );

            if (!hasInit) {
                revert InitializationFailed();
            }
        }

        _instanceContractId[clone] = contractId;
        _userDeployments[msg.sender][contractId].push(clone);

        emit ContractDeployed(clone, contractId, msg.sender, version);

        licenseTokenId; // silence warning
    }
}
