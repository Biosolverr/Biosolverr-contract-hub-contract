// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {LicenseNFT} from "../../src/marketplace/LicenseNFT.sol";
import {ContractMarketplace} from "../../src/marketplace/ContractMarketplace.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

contract FuzzTest is Test {
    LicenseNFT          nft;
    ContractMarketplace marketplace;
    MockERC20           token;

    address seller = makeAddr("seller");
    address buyer  = makeAddr("buyer");

    function setUp() public {
        token       = new MockERC20();
        nft         = new LicenseNFT();
        marketplace = new ContractMarketplace(
            address(nft), address(token), 250, 0.001 ether
        );
        nft.transferOwnership(address(marketplace));
        vm.deal(buyer, 1000 ether);
    }

    function testFuzz_OverpaymentRefunded(uint256 price, uint256 extra) public {
        price = bound(price, 0.001 ether, 10 ether);
        extra = bound(extra, 0, 5 ether);

        vm.prank(seller);
        uint256 lid = marketplace.listContract(address(0x1), price, "ipfs://m");

        uint256 buyerBefore = buyer.balance;
        vm.prank(buyer);
        marketplace.purchaseLicense{value: price + extra}(lid);
        assertEq(buyer.balance, buyerBefore - price);
    }

    function testFuzz_PlatformFeeNeverExceedsPrice(uint256 price, uint256 feeBps) public {
        feeBps = bound(feeBps, 0, 2000);
        price  = bound(price, 0.001 ether, 10 ether);

        marketplace.setPlatformFee(feeBps);

        vm.prank(seller);
        uint256 lid = marketplace.listContract(address(0x1), price, "ipfs://m");

        vm.prank(buyer);
        marketplace.purchaseLicense{value: price}(lid);

        uint256 fee    = (price * feeBps) / 10_000;
        uint256 payout = price - fee;

        assertEq(marketplace.platformEthAccrued(), fee);
        assertEq(marketplace.getPendingEarnings(seller), payout);
        assertEq(fee + payout, price);
    }

    function testFuzz_SellerPlusPlatformEqualsPrice(uint256 price) public {
        price = bound(price, 0.001 ether, 100 ether);

        vm.prank(seller);
        uint256 lid = marketplace.listContract(address(0x1), price, "ipfs://m");
        vm.prank(buyer);
        marketplace.purchaseLicense{value: price}(lid);

        uint256 sellerEarns   = marketplace.getPendingEarnings(seller);
        uint256 platformEarns = marketplace.platformEthAccrued();
        assertEq(sellerEarns + platformEarns, price);
    }
}
