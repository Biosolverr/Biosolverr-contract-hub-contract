// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IContractMarketplace {

    // ─── Events ───────────────────────────────────────────────────────────────
    event ContractListed(
        uint256 indexed listingId,
        address indexed seller,
        address contractAddress,
        uint256 price,
        string metadata
    );
    event LicensePurchased(
        uint256 indexed listingId,
        address indexed buyer,
        address indexed contractAddress,
        uint256 tokenId,
        uint256 price
    );
    event ListingDelisted(uint256 indexed listingId);
    event EarningsWithdrawn(address indexed seller, uint256 amount);
    event PlatformFeesWithdrawn(address indexed to, uint256 amount);
    event PlatformFeeUpdated(uint256 feeBps);
    event MinDepositUpdated(uint256 minDeposit);

    // ─── Errors ───────────────────────────────────────────────────────────────
    error ListingNotActive(uint256 listingId);
    error InsufficientPayment(uint256 required, uint256 provided);
    error NotListingOwner(address caller, uint256 listingId);
    error InvalidAddress();
    error InvalidPrice();
    error InvalidMetadata();
    error WithdrawFailed();
    error FeeTooHigh();
    error AlreadyPurchased(bytes32 contractId, address buyer);
    error AlreadyRated(bytes32 contractId, address rater);
    error NotPurchased(bytes32 contractId, address rater);
    error InvalidRating();
    error AlreadyRegistered(bytes32 contractId);
    error ContractDoesNotExist(bytes32 contractId);
    error AlreadyVerified(bytes32 contractId);
    error ContractNotActive(bytes32 contractId);
    error NotAuthor(bytes32 contractId);
    error DepositTooLow(uint256 required, uint256 sent);
    error NoDeposit();
    error MustDeactivateFirst();

    // ─── Structs ──────────────────────────────────────────────────────────────
    struct Listing {
        address seller;
        address contractAddress;
        uint256 price;
        bool active;
        string metadata;
    }

    // ─── Режим А: ETH листинги ────────────────────────────────────────────────
    function listContract(
        address contractAddress,
        uint256 price,
        string calldata metadata
    ) external returns (uint256 listingId);

    function delistContract(uint256 listingId) external;

    function purchaseLicense(uint256 listingId)
        external payable returns (uint256 tokenId);

    function purchaseLicenseWithExpiration(
        uint256 listingId,
        uint256 expirationTimestamp
    ) external payable returns (uint256 tokenId);

    function withdrawEarnings() external;
    function withdrawPlatformFees() external;

    function getPendingEarnings(address account) external view returns (uint256);
    function getListing(uint256 listingId) external view returns (
        address seller,
        address contractAddress,
        uint256 price,
        bool active,
        string memory metadata
    );
    function getTotalListings() external view returns (uint256);
}
