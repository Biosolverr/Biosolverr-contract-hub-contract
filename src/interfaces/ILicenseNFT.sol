// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ILicenseNFT {

    // ─── Events ───────────────────────────────────────────────────────────────
    event LicenseMinted(
        address indexed to,
        uint256 indexed tokenId,
        bytes32 indexed contractId,
        uint256 expirationTimestamp
    );
    event LicenseExtended(uint256 indexed tokenId, uint256 newExpirationTimestamp);
    event LicenseRevoked(uint256 indexed tokenId);
    event RoyaltyUpdated(uint256 newRoyaltyBasisPoints);

    // ─── Errors ───────────────────────────────────────────────────────────────
    error InvalidExpiration();
    error InvalidRoyaltyBasisPoints();
    error NotLicenseOwner(address caller, uint256 tokenId);
    error LicenseExpired(uint256 tokenId);
    error ArrayLengthMismatch();
    error ZeroAddress();

    // ─── Mint ─────────────────────────────────────────────────────────────────
    function mintLicense(
        address to,
        bytes32 contractId,
        string calldata tokenURI_,
        uint256 expiration
    ) external returns (uint256 tokenId);

    function mintLicenseBatch(
        address[] calldata buyers,
        bytes32[] calldata contractIds,
        string[] calldata tokenURIs,
        uint256[] calldata expirations
    ) external returns (uint256[] memory tokenIds);

    // ─── Management ───────────────────────────────────────────────────────────
    function extendLicense(uint256 tokenId, uint256 newExpiration) external;
    function revokeLicense(uint256 tokenId) external;

    // ─── Views ────────────────────────────────────────────────────────────────
    function isLicenseValid(uint256 tokenId) external view returns (bool);
    function getLicenseRemainingTime(uint256 tokenId) external view returns (uint256);
    function getLicenseInfo(uint256 tokenId) external view returns (
        address owner_,
        bytes32 contractId_,
        uint256 expiration_,
        bool isValid_
    );
    function tokenContractId(uint256 tokenId) external view returns (bytes32);
    function getLicensesForContract(bytes32 contractId) external view returns (uint256[] memory);

    // ─── Royalties ────────────────────────────────────────────────────────────
    function setRoyaltyInfo(uint256 basisPoints) external;
}
