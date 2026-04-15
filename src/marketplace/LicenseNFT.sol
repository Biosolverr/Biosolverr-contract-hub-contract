// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {ERC2981} from "@openzeppelin/contracts/token/common/ERC2981.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ILicenseNFT} from "../interfaces/ILicenseNFT.sol";

contract LicenseNFT is ERC721, ERC721URIStorage, ERC721Enumerable, ERC2981, Ownable, ILicenseNFT {

    // ─── Storage ──────────────────────────────────────────────────────────────

    struct LicenseData {
        bytes32 contractId;
        uint256 expiration; // 0 = бессрочная
        bool    revoked;
    }

    uint256 private _nextTokenId;

    mapping(uint256 => LicenseData)   private _licenses;
    mapping(bytes32 => uint256[])     private _contractLicenses;

    // ─── Constructor ──────────────────────────────────────────────────────────

    constructor() ERC721("ContractHub License", "CHL") Ownable(msg.sender) {
        _setDefaultRoyalty(msg.sender, 500); // 5%
    }

    // ─── Mint ─────────────────────────────────────────────────────────────────

    function mintLicense(
        address to,
        bytes32 contractId,
        string calldata tokenURI_,
        uint256 expiration
    ) external override onlyOwner returns (uint256 tokenId) {
        if (to == address(0)) revert ZeroAddress();
        if (expiration != 0 && expiration <= block.timestamp) revert InvalidExpiration();

        tokenId = _nextTokenId++;
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, tokenURI_);

        _licenses[tokenId] = LicenseData({
            contractId: contractId,
            expiration: expiration,
            revoked:    false
        });
        _contractLicenses[contractId].push(tokenId);

        emit LicenseMinted(to, tokenId, contractId, expiration);
    }

    function mintLicenseBatch(
        address[] calldata buyers,
        bytes32[] calldata contractIds,
        string[] calldata tokenURIs,
        uint256[] calldata expirations
    ) external override onlyOwner returns (uint256[] memory tokenIds) {
        uint256 len = buyers.length;
        if (
            len != contractIds.length ||
            len != tokenURIs.length   ||
            len != expirations.length
        ) revert ArrayLengthMismatch();

        tokenIds = new uint256[](len);
        for (uint256 i; i < len; ++i) {
            if (buyers[i] == address(0)) revert ZeroAddress();
            uint256 exp = expirations[i];
            if (exp != 0 && exp <= block.timestamp) revert InvalidExpiration();

            uint256 tokenId = _nextTokenId++;
            _safeMint(buyers[i], tokenId);
            _setTokenURI(tokenId, tokenURIs[i]);

            _licenses[tokenId] = LicenseData({
                contractId: contractIds[i],
                expiration: exp,
                revoked:    false
            });
            _contractLicenses[contractIds[i]].push(tokenId);

            emit LicenseMinted(buyers[i], tokenId, contractIds[i], exp);
            tokenIds[i] = tokenId;
        }
    }

    // ─── Management ───────────────────────────────────────────────────────────

    /// @notice Продлить лицензию — принимает абсолютный timestamp
    function extendLicense(uint256 tokenId, uint256 newExpiration)
        external override onlyOwner
    {
        if (newExpiration != 0 && newExpiration <= block.timestamp)
            revert InvalidExpiration();
        _licenses[tokenId].expiration = newExpiration;
        emit LicenseExtended(tokenId, newExpiration);
    }

    /// @notice Отозвать лицензию навсегда
    function revokeLicense(uint256 tokenId) external override onlyOwner {
        _licenses[tokenId].revoked = true;
        emit LicenseRevoked(tokenId);
    }

    // ─── Views ────────────────────────────────────────────────────────────────

    function isLicenseValid(uint256 tokenId) public view override returns (bool) {
        LicenseData storage lic = _licenses[tokenId];
        if (_ownerOf(tokenId) == address(0)) return false;
        if (lic.revoked) return false;
        if (lic.expiration == 0) return true;
        return block.timestamp < lic.expiration;
    }

    function getLicenseRemainingTime(uint256 tokenId)
        external view override returns (uint256)
    {
        LicenseData storage lic = _licenses[tokenId];
        if (lic.revoked) return 0;
        if (lic.expiration == 0) return type(uint256).max;
        if (block.timestamp >= lic.expiration) return 0;
        return lic.expiration - block.timestamp;
    }

    function getLicenseInfo(uint256 tokenId)
        external view override returns (
            address owner_,
            bytes32 contractId_,
            uint256 expiration_,
            bool    isValid_
        )
    {
        return (
            _ownerOf(tokenId),
            _licenses[tokenId].contractId,
            _licenses[tokenId].expiration,
            isLicenseValid(tokenId)
        );
    }

    function tokenContractId(uint256 tokenId)
        external view override returns (bytes32)
    {
        return _licenses[tokenId].contractId;
    }

    function getLicensesForContract(bytes32 contractId)
        external view override returns (uint256[] memory)
    {
        return _contractLicenses[contractId];
    }

    // ─── Royalties ────────────────────────────────────────────────────────────

    function setRoyaltyInfo(uint256 basisPoints) external override onlyOwner {
        if (basisPoints > 10_000) revert InvalidRoyaltyBasisPoints();
        _setDefaultRoyalty(owner(), uint96(basisPoints));
        emit RoyaltyUpdated(basisPoints);
    }

    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        public view override returns (address receiver, uint256 royaltyAmount)
    {
        if (!isLicenseValid(tokenId)) return (address(0), 0);
        return super.royaltyInfo(tokenId, salePrice);
    }

    // ─── ERC-721 overrides ────────────────────────────────────────────────────

    function _update(address to, uint256 tokenId, address auth)
        internal override(ERC721, ERC721Enumerable) returns (address)
    {
        return super._update(to, tokenId, auth);
    }

    function _increaseBalance(address account, uint128 value)
        internal override(ERC721, ERC721Enumerable)
    {
        super._increaseBalance(account, value);
    }

    function tokenURI(uint256 tokenId)
        public view override(ERC721, ERC721URIStorage) returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public view override(ERC721, ERC721Enumerable, ERC721URIStorage, ERC2981)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
