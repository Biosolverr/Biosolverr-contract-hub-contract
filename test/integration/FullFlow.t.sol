// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import {LicenseNFT} from "../../src/marketplace/LicenseNFT.sol";
import {ContractFactory} from "../../src/marketplace/ContractFactory.sol";
import {ContractMarketplace} from "../../src/marketplace/ContractMarketplace.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {MockImplementation} from "../mocks/MockImplementation.sol";

import {IContractFactory} from "../../src/interfaces/IContractFactory.sol";

contract FullFlowTest is Test {

    LicenseNFT nft;
    ContractFactory factory;
    ContractMarketplace marketplace;
    MockERC20 token;
    MockImplementation impl;

    address owner = address(this);
    address seller = makeAddr("seller");
    address buyer = makeAddr("buyer");
    address author = makeAddr("author");

    uint256 constant PRICE = 1 ether;
    uint256 constant PLATFORM_FEE = 250;
    uint256 constant MIN_DEPOSIT = 0.001 ether;

    bytes32 constant CID =
        keccak256(abi.encodePacked("TestContract", "1.0.0"));

    function setUp() public {
        token = new MockERC20();
        nft = new LicenseNFT();
        impl = new MockImplementation();

        factory = new ContractFactory(address(nft));

        marketplace = new ContractMarketplace(
            address(nft),
            address(token),
            PLATFORM_FEE,
            MIN_DEPOSIT
        );

        nft.transferOwnership(address(marketplace));

        factory.registerImplementation(CID, address(impl), "v1.0");

        vm.deal(buyer, 10 ether);
        vm.deal(author, 1 ether);

        token.mint(buyer, 1000 * 10 ** 6);
    }

    function test_FullCycle_ETH() public {
        vm.prank(seller);
        uint256 lid = marketplace.listContract(address(impl), PRICE, "ipfs://meta");

        vm.prank(buyer);
        uint256 tid = marketplace.purchaseLicense{value: PRICE}(lid);

        assertEq(nft.ownerOf(tid), buyer);
        assertTrue(nft.isLicenseValid(tid));

        uint256 fee = (PRICE * PLATFORM_FEE) / 10_000;
        uint256 payout = PRICE - fee;

        uint256 before = seller.balance;

        vm.prank(seller);
        marketplace.withdrawEarnings();

        assertEq(seller.balance, before + payout);

        uint256 ownerBefore = address(this).balance;

        marketplace.withdrawPlatformFees();

        assertEq(address(this).balance, ownerBefore + fee);

        LicenseNFT nft2 = new LicenseNFT();
        ContractFactory f2 = new ContractFactory(address(nft2));

        f2.registerImplementation(CID, address(impl), "v1.0");

        uint256 factoryTid =
            nft2.mintLicense(buyer, CID, "ipfs://f", 0);

        vm.prank(buyer);
        address clone = f2.deployContract(CID, factoryTid);

        assertEq(MockImplementation(clone).owner(), buyer);
        assertTrue(MockImplementation(clone).ping());
    }

    function test_FullCycle_ERC20() public {
        vm.prank(author);

        marketplace.registerContract{value: MIN_DEPOSIT}(
            "TestContract",
            "TC",
            "1.0.0",
            keccak256("meta"),
            keccak256("src"),
            100 * 10 ** 6
        );

        marketplace.verifyContract(CID);

        vm.prank(buyer);
        token.approve(address(marketplace), 100 * 10 ** 6);

        vm.prank(buyer);
        marketplace.purchaseLicense(CID);

        assertEq(marketplace.reputation(author), 1);
        assertTrue(marketplace.hasPurchased(CID, buyer));

        vm.prank(buyer);
        marketplace.rateContract(CID, 5);

        assertEq(marketplace.getAverageRating(CID), 5);

        vm.prank(author);
        marketplace.toggleContractActive(CID);

        uint256 before = author.balance;

        vm.prank(author);
        marketplace.withdrawDeposit(CID);

        assertEq(author.balance, before + MIN_DEPOSIT);
    }

    function test_LicenseExpiry_BlocksDeploy() public {
        LicenseNFT nft2 = new LicenseNFT();
        ContractFactory f2 = new ContractFactory(address(nft2));

        f2.registerImplementation(CID, address(impl), "v1.0");

        uint256 exp = block.timestamp + 1 days;

        uint256 tid = nft2.mintLicense(buyer, CID, "ipfs://t", exp);

        vm.warp(block.timestamp + 2 days);

        vm.prank(buyer);

        vm.expectRevert(
            abi.encodeWithSelector(
                bytes4(keccak256("LicenseNotValid(uint256)"))
                tid
            )
        );

        f2.deployContract(CID, tid);
    }

    function test_RevokedLicense_BlocksDeploy() public {
        LicenseNFT nft2 = new LicenseNFT();
        ContractFactory f2 = new ContractFactory(address(nft2));

        f2.registerImplementation(CID, address(impl), "v1.0");

        uint256 tid = nft2.mintLicense(buyer, CID, "ipfs://t", 0);

        nft2.revokeLicense(tid);

        vm.prank(buyer);

        vm.expectRevert(
            abi.encodeWithSelector(
                IContractFactory.LicenseNotValid.selector,
                tid
            )
        );

        f2.deployContract(CID, tid);
    }
}
