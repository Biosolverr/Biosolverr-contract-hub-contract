// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {LicenseNFT} from "../../src/marketplace/LicenseNFT.sol";
import {ContractMarketplace} from "../../src/marketplace/ContractMarketplace.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

contract ContractMarketplaceTest is Test {
    LicenseNFT          nft;
    ContractMarketplace marketplace;
    MockERC20           token;

    address owner  = address(this);
    address seller = makeAddr("seller");
    address buyer  = makeAddr("buyer");
    address author = makeAddr("author");

    uint256 constant PRICE       = 1 ether;
    uint256 constant PLATFORM_FEE = 250;
    uint256 constant MIN_DEPOSIT  = 0.001 ether;

    bytes32 constant CID = keccak256(abi.encodePacked("TestContract", "1.0.0"));

    function setUp() public {
        token       = new MockERC20();
        nft         = new LicenseNFT();
        marketplace = new ContractMarketplace(
            address(nft),
            address(token),
            PLATFORM_FEE,
            MIN_DEPOSIT
        );
        nft.transferOwnership(address(marketplace));
        vm.deal(buyer, 10 ether);
        vm.deal(author, 1 ether);
        token.mint(buyer, 1000 * 10 ** 6);
    }

    // ── Режим А: листинги ─────────────────────────────────────────────────────

    function test_ListContract() public {
        vm.prank(seller);
        uint256 id = marketplace.listContract(address(0x1), PRICE, "ipfs://meta");
        assertEq(id, 0);
        (address s,,uint256 p, bool a,) = marketplace.getListing(id);
        assertEq(s, seller);
        assertEq(p, PRICE);
        assertTrue(a);
    }

    function test_Revert_ListZeroPrice() public {
        vm.prank(seller);
        marketplace.listContract(address(0x1), 0, "ipfs://meta");
    }

    function test_Revert_ListEmptyMetadata() public {
        vm.prank(seller);
        marketplace.listContract(address(0x1), PRICE, "");
    }

    function test_PurchaseLicense() public {
        vm.prank(seller);
        uint256 lid = marketplace.listContract(address(0x1), PRICE, "ipfs://meta");
        vm.prank(buyer);
        uint256 tid = marketplace.purchaseLicense{value: PRICE}(lid);
        assertEq(nft.ownerOf(tid), buyer);
        assertTrue(nft.isLicenseValid(tid));
    }

    function test_Revert_InsufficientPayment() public {
        vm.prank(seller);
        uint256 lid = marketplace.listContract(address(0x1), PRICE, "ipfs://meta");
        vm.prank(buyer);
        vm.expectRevert(
            abi.encodeWithSelector(
                bytes4(0x42434445), 0.5 ether
            )
        );
        marketplace.purchaseLicense{value: 0.5 ether}(lid);
    }

    // ── FIX 1: платформенная комиссия ─────────────────────────────────────────

    function test_PlatformFeeAccrues() public {
        vm.prank(seller);
        uint256 lid = marketplace.listContract(address(0x1), PRICE, "ipfs://meta");
        vm.prank(buyer);
        marketplace.purchaseLicense{value: PRICE}(lid);

        uint256 expectedFee = (PRICE * PLATFORM_FEE) / 10_000;
        assertEq(marketplace.platformEthAccrued(), expectedFee);
    }

    function test_SellerEarningsCorrect() public {
        vm.prank(seller);
        uint256 lid = marketplace.listContract(address(0x1), PRICE, "ipfs://meta");
        vm.prank(buyer);
        marketplace.purchaseLicense{value: PRICE}(lid);

        uint256 fee    = (PRICE * PLATFORM_FEE) / 10_000;
        uint256 payout = PRICE - fee;
        assertEq(marketplace.getPendingEarnings(seller), payout);
    }

    function test_WithdrawPlatformFees() public {
        vm.prank(seller);
        uint256 lid = marketplace.listContract(address(0x1), PRICE, "ipfs://meta");
        vm.prank(buyer);
        marketplace.purchaseLicense{value: PRICE}(lid);

        uint256 fee    = (PRICE * PLATFORM_FEE) / 10_000;
        uint256 before = owner.balance;
        marketplace.withdrawPlatformFees();
        assertEq(address(this).balance, before + fee);
        assertEq(marketplace.platformEthAccrued(), 0);
    }

    function test_WithdrawDoesNotStealSellerFunds() public {
        vm.prank(seller);
        uint256 lid = marketplace.listContract(address(0x1), PRICE, "ipfs://meta");
        vm.prank(buyer);
        marketplace.purchaseLicense{value: PRICE}(lid);

        // Вывести платформенную комиссию
        marketplace.withdrawPlatformFees();

        // Продавец всё ещё может вывести своё
        uint256 fee    = (PRICE * PLATFORM_FEE) / 10_000;
        uint256 payout = PRICE - fee;
        assertEq(marketplace.getPendingEarnings(seller), payout);

        uint256 before = seller.balance;
        vm.prank(seller);
        marketplace.withdrawEarnings();
        assertEq(seller.balance, before + payout);
    }

    // ── Режим Б: ERC20 реестр ─────────────────────────────────────────────────

    function test_RegisterContract() public {
        vm.prank(author);
        marketplace.registerContract{value: MIN_DEPOSIT}(
            "TestContract", "TC", "1.0.0",
            keccak256("meta"), keccak256("src"), 100 * 10 ** 6
        );
        (address a,,,,,,,,,,,,) = marketplace.contracts(CID);
        assertEq(a, author);
    }

    function test_Revert_RegisterDuplicate() public {
        vm.prank(author);
        marketplace.registerContract{value: MIN_DEPOSIT}(
            "TestContract", "TC", "1.0.0",
            keccak256("meta"), keccak256("src"), 0
        );
        vm.prank(author);
        vm.deal(author, MIN_DEPOSIT);
        vm.expectRevert(
        );
        marketplace.registerContract{value: MIN_DEPOSIT}(
            "TestContract", "TC", "1.0.0",
            keccak256("meta"), keccak256("src"), 0
        );
    }

    // ── FIX 4: один покупатель — одна покупка ─────────────────────────────────

    function test_Revert_DoublePurchaseERC20() public {
        vm.prank(author);
        marketplace.registerContract{value: MIN_DEPOSIT}(
            "TestContract", "TC", "1.0.0",
            keccak256("meta"), keccak256("src"), 0
        );
        vm.prank(buyer);
        marketplace.purchaseLicense(CID);

        vm.prank(buyer);
        vm.expectRevert(
            abi.encodeWithSelector(
            )
        );
        marketplace.purchaseLicense(CID);
    }

    // ── FIX 7: рейтинг только от покупателей ──────────────────────────────────

    function test_Revert_RateWithoutPurchase() public {
        vm.prank(author);
        marketplace.registerContract{value: MIN_DEPOSIT}(
            "TestContract", "TC", "1.0.0",
            keccak256("meta"), keccak256("src"), 0
        );
        vm.prank(buyer);
        vm.expectRevert(
            abi.encodeWithSelector(
                ContractMarketplace.NotPurchased.selector, CID, buyer
            )
        );
        marketplace.rateContract(CID, 5);
    }

    function test_Revert_RateTwice() public {
        vm.prank(author);
        marketplace.registerContract{value: MIN_DEPOSIT}(
            "TestContract", "TC", "1.0.0",
            keccak256("meta"), keccak256("src"), 0
        );
        vm.prank(buyer);
        marketplace.purchaseLicense(CID);
        vm.prank(buyer);
        marketplace.rateContract(CID, 5);

        vm.prank(buyer);
        vm.expectRevert(
            abi.encodeWithSelector(
                ContractMarketplace.AlreadyRated.selector, CID, buyer
            )
        );
        marketplace.rateContract(CID, 4);
    }

    function test_RateAfterPurchase() public {
        vm.prank(author);
        marketplace.registerContract{value: MIN_DEPOSIT}(
            "TestContract", "TC", "1.0.0",
            keccak256("meta"), keccak256("src"), 0
        );
        vm.prank(buyer);
        marketplace.purchaseLicense(CID);
        vm.prank(buyer);
        marketplace.rateContract(CID, 5);
        assertEq(marketplace.getAverageRating(CID), 5);
    }
}
