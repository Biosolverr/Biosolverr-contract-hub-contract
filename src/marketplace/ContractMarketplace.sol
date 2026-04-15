// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IContractMarketplace} from "../interfaces/IContractMarketplace.sol";
import {ILicenseNFT} from "../interfaces/ILicenseNFT.sol";

contract ContractMarketplace is Ownable, ReentrancyGuard, Pausable, IContractMarketplace {

    // ══════════════════════════════════════════════════════════════════════════
    //  STORAGE
    // ══════════════════════════════════════════════════════════════════════════

    ILicenseNFT public immutable LICENSE_NFT;
    IERC20      public immutable paymentToken;

    uint256 public platformFeeBps;
    uint256 public minDeposit;

    // ── Режим А: ETH листинги ─────────────────────────────────────────────────

    uint256 private _nextListingId;
    mapping(uint256 => Listing)  private _listings;
    mapping(address => uint256)  private _pendingEarnings;

    /// FIX 1: отдельный счётчик комиссии платформы
    uint256 private _platformEthAccrued;

    // ── Режим Б: ERC20 реестр ─────────────────────────────────────────────────

    struct ContractInfo {
        address payable author;
        string  name;
        string  symbol;
        string  version;
        bytes32 metadataHash;
        bytes32 sourceHash;
        uint256 licensePrice;
        bool    verified;
        bool    isActive;
        uint256 totalSales;
        uint256 ratingSum;
        uint256 ratingCount;
        uint256 depositAmount;
    }

    mapping(bytes32 => ContractInfo)                    public  contracts;
    bytes32[]                                           public  contractList;
    mapping(address => uint256)                         public  reputation;

    /// FIX 4: один покупатель — одна покупка
    mapping(bytes32 => mapping(address => bool))        private _hasPurchased;

    /// FIX 7: рейтинг только от покупателей, один раз
    mapping(bytes32 => mapping(address => bool))        private _hasRated;

    // ── Events (Режим Б) ──────────────────────────────────────────────────────

    event ContractRegistered(
        bytes32 indexed contractId,
        address indexed author,
        string name,
        string version
    );
    event ContractVerified(bytes32 indexed contractId, address indexed verifier);
    event ContractRatedEvent(
        bytes32 indexed contractId,
        address indexed rater,
        uint256 rating
    );
    event ReputationIncreased(address indexed author, uint256 increment);
    event DepositWithdrawn(
        bytes32 indexed contractId,
        address indexed author,
        uint256 amount
    );
    event ERC20LicensePurchased(
        bytes32 indexed contractId,
        address indexed buyer,
        uint256 price
    );

    // ══════════════════════════════════════════════════════════════════════════
    //  CONSTRUCTOR
    // ══════════════════════════════════════════════════════════════════════════

    constructor(
        address _licenseNFT,
        address _paymentToken,
        uint256 _platformFeeBps,
        uint256 _minDeposit
    ) Ownable(msg.sender) {
        if (_licenseNFT == address(0) || _paymentToken == address(0))
            revert InvalidAddress();
        if (_platformFeeBps > 2000) revert FeeTooHigh();

        LICENSE_NFT    = ILicenseNFT(_licenseNFT);
        paymentToken   = IERC20(_paymentToken);
        platformFeeBps = _platformFeeBps;
        minDeposit     = _minDeposit;
    }

    // ══════════════════════════════════════════════════════════════════════════
    //  РЕЖИМ А: ETH ЛИСТИНГИ
    // ══════════════════════════════════════════════════════════════════════════

    function listContract(
        address contractAddress,
        uint256 price,
        string calldata metadata
    ) external override whenNotPaused returns (uint256 listingId) {
        if (contractAddress == address(0)) revert InvalidAddress();
        if (price == 0) revert InvalidPrice();
        if (bytes(metadata).length == 0) revert InvalidMetadata();

        listingId = _nextListingId++;
        _listings[listingId] = Listing({
            seller:          msg.sender,
            contractAddress: contractAddress,
            price:           price,
            active:          true,
            metadata:        metadata
        });

        emit ContractListed(listingId, msg.sender, contractAddress, price, metadata);
    }

    function delistContract(uint256 listingId) external override {
        Listing storage lst = _listings[listingId];
        if (!lst.active) revert ListingNotActive(listingId);
        if (lst.seller != msg.sender) revert NotListingOwner(msg.sender, listingId);
        lst.active = false;
        emit ListingDelisted(listingId);
    }

    function purchaseLicense(uint256 listingId)
        external payable override nonReentrant whenNotPaused
        returns (uint256 tokenId)
    {
        return _purchaseETH(listingId, 0);
    }

    function purchaseLicenseWithExpiration(
        uint256 listingId,
        uint256 expirationTimestamp
    ) external payable override nonReentrant whenNotPaused returns (uint256 tokenId) {
        return _purchaseETH(listingId, expirationTimestamp);
    }

    function withdrawEarnings() external override nonReentrant {
        uint256 amount = _pendingEarnings[msg.sender];
        if (amount == 0) revert WithdrawFailed();
        _pendingEarnings[msg.sender] = 0;
        (bool ok,) = msg.sender.call{value: amount}("");
        if (!ok) revert WithdrawFailed();
        emit EarningsWithdrawn(msg.sender, amount);
    }

    /// FIX 1: выводим только накопленную комиссию платформы
    function withdrawPlatformFees() external override onlyOwner nonReentrant {
        uint256 amount = _platformEthAccrued;
        if (amount == 0) revert WithdrawFailed();
        _platformEthAccrued = 0;
        (bool ok,) = owner().call{value: amount}("");
        if (!ok) revert WithdrawFailed();
        emit PlatformFeesWithdrawn(owner(), amount);
    }

    function getPendingEarnings(address account)
        external view override returns (uint256)
    {
        return _pendingEarnings[account];
    }

    function getListing(uint256 listingId)
        external view override returns (
            address seller,
            address contractAddress,
            uint256 price,
            bool active,
            string memory metadata
        )
    {
        Listing storage lst = _listings[listingId];
        return (lst.seller, lst.contractAddress, lst.price, lst.active, lst.metadata);
    }

    function getTotalListings() external view override returns (uint256) {
        return _nextListingId;
    }

    function platformEthAccrued() external view returns (uint256) {
        return _platformEthAccrued;
    }

    // ── Internal A ────────────────────────────────────────────────────────────

    function _purchaseETH(uint256 listingId, uint256 expiration)
        internal returns (uint256 tokenId)
    {
        Listing storage lst = _listings[listingId];
        if (!lst.active) revert ListingNotActive(listingId);
        if (msg.value < lst.price) revert InsufficientPayment(lst.price, msg.value);

        address seller          = lst.seller;
        address contractAddress = lst.contractAddress;
        uint256 price           = lst.price;

        lst.active = false;

        // FIX 1: комиссия в отдельный счётчик
        uint256 fee    = (price * platformFeeBps) / 10_000;
        uint256 payout = price - fee;
        _pendingEarnings[seller] += payout;
        _platformEthAccrued      += fee;

        // Минтим NFT
        bytes32 cid = keccak256(abi.encodePacked(contractAddress));
        tokenId = LICENSE_NFT.mintLicense(
            msg.sender,
            cid,
            lst.metadata,
            expiration
        );

        // Сдача
        if (msg.value > price) {
            (bool ok,) = msg.sender.call{value: msg.value - price}("");
            if (!ok) revert WithdrawFailed();
        }

        emit LicensePurchased(listingId, msg.sender, contractAddress, tokenId, price);
    }

    // ══════════════════════════════════════════════════════════════════════════
    //  РЕЖИМ Б: ERC20 РЕЕСТР
    // ══════════════════════════════════════════════════════════════════════════

    function registerContract(
        string calldata name,
        string calldata symbol,
        string calldata version,
        bytes32 metadataHash,
        bytes32 sourceHash,
        uint256 licensePrice
    ) external payable whenNotPaused {
        if (msg.value < minDeposit) revert DepositTooLow(minDeposit, msg.value);
        if (bytes(name).length == 0) revert InvalidMetadata();

        bytes32 id = keccak256(abi.encodePacked(name, version));
        if (contracts[id].author != address(0)) revert AlreadyRegistered(id);

        contracts[id] = ContractInfo({
            author:        payable(msg.sender),
            name:          name,
            symbol:        symbol,
            version:       version,
            metadataHash:  metadataHash,
            sourceHash:    sourceHash,
            licensePrice:  licensePrice,
            verified:      false,
            isActive:      true,
            totalSales:    0,
            ratingSum:     0,
            ratingCount:   0,
            depositAmount: msg.value
        });
        contractList.push(id);
        emit ContractRegistered(id, msg.sender, name, version);
    }

    function verifyContract(bytes32 contractId) external onlyOwner {
        ContractInfo storage c = contracts[contractId];
        if (c.author == address(0)) revert ContractDoesNotExist(contractId);
        if (c.verified) revert AlreadyVerified(contractId);
        c.verified = true;
        emit ContractVerified(contractId, msg.sender);
    }

    /// @notice Покупка лицензии за ERC20 (Режим Б)
    function purchaseLicense(bytes32 contractId)
        external nonReentrant whenNotPaused
    {
        ContractInfo storage c = contracts[contractId];
        if (!c.isActive) revert ContractNotActive(contractId);

        // FIX 4: один покупатель — одна покупка
        if (_hasPurchased[contractId][msg.sender])
            revert AlreadyPurchased(contractId, msg.sender);
        _hasPurchased[contractId][msg.sender] = true;

        uint256 price  = c.licensePrice;
        uint256 fee    = (price * platformFeeBps) / 10_000;
        uint256 payout = price - fee;

        require(
            paymentToken.transferFrom(msg.sender, address(this), price),
            "Payment failed"
        );
        if (payout > 0) {
            require(
                paymentToken.transfer(c.author, payout),
                "Transfer failed"
            );
        }

        c.totalSales++;
        reputation[c.author]++;

        emit ReputationIncreased(c.author, 1);
        emit ERC20LicensePurchased(contractId, msg.sender, price);
    }

    /// FIX 7: рейтинг только от покупателей, один раз
    function rateContract(bytes32 contractId, uint256 rating) external {
        if (rating < 1 || rating > 5) revert InvalidRating();

        if (!_hasPurchased[contractId][msg.sender])
            revert NotPurchased(contractId, msg.sender);
        if (_hasRated[contractId][msg.sender])
            revert AlreadyRated(contractId, msg.sender);

        _hasRated[contractId][msg.sender] = true;

        ContractInfo storage c = contracts[contractId];
        c.ratingSum   += rating;
        c.ratingCount++;
        emit ContractRatedEvent(contractId, msg.sender, rating);
    }

    function toggleContractActive(bytes32 contractId) external {
        if (contracts[contractId].author != msg.sender)
            revert NotAuthor(contractId);
        contracts[contractId].isActive = !contracts[contractId].isActive;
    }

    function withdrawDeposit(bytes32 contractId) external nonReentrant {
        ContractInfo storage c = contracts[contractId];
        if (c.author != msg.sender) revert NotAuthor(contractId);
        if (c.isActive) revert MustDeactivateFirst();
        uint256 amount = c.depositAmount;
        if (amount == 0) revert NoDeposit();
        c.depositAmount = 0;
        payable(msg.sender).transfer(amount);
        emit DepositWithdrawn(contractId, msg.sender, amount);
    }

    function getAverageRating(bytes32 contractId) external view returns (uint256) {
        ContractInfo storage c = contracts[contractId];
        if (c.ratingCount == 0) return 0;
        return c.ratingSum / c.ratingCount;
    }

    function hasPurchased(bytes32 contractId, address buyer)
        external view returns (bool)
    {
        return _hasPurchased[contractId][buyer];
    }

    function getVerifiedContracts() external view returns (bytes32[] memory) {
        return _filterContracts(true);
    }

    function getUnverifiedContracts() external view returns (bytes32[] memory) {
        return _filterContracts(false);
    }

    // ── Admin ─────────────────────────────────────────────────────────────────

    function setPlatformFee(uint256 feeBps) external onlyOwner {
        if (feeBps > 2000) revert FeeTooHigh();
        platformFeeBps = feeBps;
        emit PlatformFeeUpdated(feeBps);
    }

    function setMinDeposit(uint256 _minDeposit) external onlyOwner {
        minDeposit = _minDeposit;
        emit MinDepositUpdated(_minDeposit);
    }

    function pause()   external onlyOwner { _pause(); }
    function unpause() external onlyOwner { _unpause(); }

    receive() external payable {}

    // ── Internal ──────────────────────────────────────────────────────────────

    function _filterContracts(bool verified)
        internal view returns (bytes32[] memory)
    {
        uint256 count;
        for (uint256 i; i < contractList.length; ++i) {
            if (contracts[contractList[i]].verified == verified) ++count;
        }
        bytes32[] memory result = new bytes32[](count);
        uint256 idx;
        for (uint256 i; i < contractList.length; ++i) {
            if (contracts[contractList[i]].verified == verified) {
                result[idx++] = contractList[i];
            }
        }
        return result;
    }
}
