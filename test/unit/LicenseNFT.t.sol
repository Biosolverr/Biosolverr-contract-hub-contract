// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {LicenseNFT} from "../../src/marketplace/LicenseNFT.sol";

contract LicenseNFTTest is Test {
    LicenseNFT nft;
    address owner  = address(this);
    address buyer  = makeAddr("buyer");
    address buyer2 = makeAddr("buyer2");

    bytes32 constant CID = keccak256("TestContract");

    function setUp() public {
        nft = new LicenseNFT();
    }

    // ── Mint ──────────────────────────────────────────────────────────────────

    function test_MintPerpetual() public {
        uint256 tid = nft.mintLicense(buyer, CID, "ipfs://1", 0);
        assertEq(nft.ownerOf(tid), buyer);
        assertTrue(nft.isLicenseValid(tid));
        assertEq(nft.getLicenseRemainingTime(tid), type(uint256).max);
        assertEq(nft.tokenContractId(tid), CID);
    }

    function test_MintTemporary() public {
        uint256 exp = block.timestamp + 30 days;
        uint256 tid = nft.mintLicense(buyer, CID, "ipfs://1", exp);
        assertTrue(nft.isLicenseValid(tid));
        assertGt(nft.getLicenseRemainingTime(tid), 0);
        assertLe(nft.getLicenseRemainingTime(tid), 30 days);
    }

    function test_Revert_MintExpiredExpiration() public {
        vm.expectRevert(LicenseNFT.InvalidExpiration.selector);
        nft.mintLicense(buyer, CID, "ipfs://1", block.timestamp - 1);
    }

    function test_Revert_MintZeroAddress() public {
        vm.expectRevert(LicenseNFT.ZeroAddress.selector);
        nft.mintLicense(address(0), CID, "ipfs://1", 0);
    }

    function test_Revert_MintNotOwner() public {
        vm.prank(buyer);
        vm.expectRevert();
        nft.mintLicense(buyer, CID, "ipfs://1", 0);
    }

    // ── Expiry ────────────────────────────────────────────────────────────────

    function test_LicenseExpires() public {
        uint256 exp = block.timestamp + 1 days;
        uint256 tid = nft.mintLicense(buyer, CID, "ipfs://1", exp);
        assertTrue(nft.isLicenseValid(tid));
        vm.warp(block.timestamp + 2 days);
        assertFalse(nft.isLicenseValid(tid));
        assertEq(nft.getLicenseRemainingTime(tid), 0);
    }

    // ── Extend ────────────────────────────────────────────────────────────────

    function test_ExtendLicense() public {
        uint256 exp = block.timestamp + 1 days;
        uint256 tid = nft.mintLicense(buyer, CID, "ipfs://1", exp);
        vm.warp(block.timestamp + 2 days);
        assertFalse(nft.isLicenseValid(tid));

        uint256 newExp = block.timestamp + 30 days;
        nft.extendLicense(tid, newExp);
        assertTrue(nft.isLicenseValid(tid));
    }

    function test_Revert_ExtendPastExpiration() public {
        uint256 tid = nft.mintLicense(buyer, CID, "ipfs://1", 0);
        vm.expectRevert(LicenseNFT.InvalidExpiration.selector);
        nft.extendLicense(tid, block.timestamp - 1);
    }

    // ── Revoke ────────────────────────────────────────────────────────────────

    function test_RevokeLicense() public {
        uint256 tid = nft.mintLicense(buyer, CID, "ipfs://1", 0);
        assertTrue(nft.isLicenseValid(tid));
        nft.revokeLicense(tid);
        assertFalse(nft.isLicenseValid(tid));
        assertEq(nft.getLicenseRemainingTime(tid), 0);
    }

    // ── Royalty ───────────────────────────────────────────────────────────────

    function test_RoyaltyValid() public {
        uint256 tid = nft.mintLicense(buyer, CID, "ipfs://1", 0);
        (address rec, uint256 amt) = nft.royaltyInfo(tid, 1 ether);
        assertEq(amt, 0.05 ether);
        assertEq(rec, owner);
    }

    function test_RoyaltyExpired() public {
        uint256 exp = block.timestamp + 1 days;
        uint256 tid = nft.mintLicense(buyer, CID, "ipfs://1", exp);
        vm.warp(block.timestamp + 2 days);
        (address rec, uint256 amt) = nft.royaltyInfo(tid, 1 ether);
        assertEq(rec, address(0));
        assertEq(amt, 0);
    }

    function test_SetRoyalty() public {
        nft.setRoyaltyInfo(750); // 7.5%
        uint256 tid = nft.mintLicense(buyer, CID, "ipfs://1", 0);
        (, uint256 amt) = nft.royaltyInfo(tid, 1 ether);
        assertEq(amt, 0.075 ether);
    }

    function test_Revert_RoyaltyOver100Percent() public {
        vm.expectRevert(LicenseNFT.InvalidRoyaltyBasisPoints.selector);
        nft.setRoyaltyInfo(10_001);
    }

    // ── Batch ─────────────────────────────────────────────────────────────────

    function test_MintBatch() public {
        address[] memory buyers     = new address[](3);
        bytes32[] memory cids       = new bytes32[](3);
        string[]  memory uris       = new string[](3);
        uint256[] memory exps       = new uint256[](3);

        buyers[0] = buyer;  buyers[1] = buyer2; buyers[2] = buyer;
        cids[0]   = CID;    cids[1]   = CID;    cids[2]   = keccak256("C2");
        uris[0]   = "i://1"; uris[1]  = "i://2"; uris[2]  = "i://3";
        exps[0]   = 0;
        exps[1]   = block.timestamp + 30 days;
        exps[2]   = block.timestamp + 60 days;

        uint256[] memory tids = nft.mintLicenseBatch(buyers, cids, uris, exps);
        assertEq(tids.length, 3);
        assertEq(nft.ownerOf(tids[0]), buyer);
        assertEq(nft.ownerOf(tids[1]), buyer2);
        assertTrue(nft.isLicenseValid(tids[0]));
        assertTrue(nft.isLicenseValid(tids[1]));
        assertTrue(nft.isLicenseValid(tids[2]));
    }

    function test_Revert_BatchLengthMismatch() public {
        address[] memory buyers = new address[](2);
        bytes32[] memory cids   = new bytes32[](3);
        string[]  memory uris   = new string[](2);
        uint256[] memory exps   = new uint256[](2);
        vm.expectRevert(LicenseNFT.ArrayLengthMismatch.selector);
        nft.mintLicenseBatch(buyers, cids, uris, exps);
    }

    // ── getLicensesForContract ────────────────────────────────────────────────

    function test_GetLicensesForContract() public {
        nft.mintLicense(buyer,  CID, "i://1", 0);
        nft.mintLicense(buyer2, CID, "i://2", 0);
        uint256[] memory tids = nft.getLicensesForContract(CID);
        assertEq(tids.length, 2);
    }

    // ── getLicenseInfo ────────────────────────────────────────────────────────

    function test_GetLicenseInfo() public {
        uint256 exp = block.timestamp + 30 days;
        uint256 tid = nft.mintLicense(buyer, CID, "i://1", exp);
        (address o, bytes32 cid, uint256 e, bool v) = nft.getLicenseInfo(tid);
        assertEq(o, buyer);
        assertEq(cid, CID);
        assertEq(e, exp);
        assertTrue(v);
    }

    // ── Fuzz ──────────────────────────────────────────────────────────────────

    function testFuzz_MintWithFutureExpiration(uint256 delta) public {
        delta = bound(delta, 1, 365 days * 10);
        uint256 exp = block.timestamp + delta;
        uint256 tid = nft.mintLicense(buyer, CID, "i://1", exp);
        assertTrue(nft.isLicenseValid(tid));
    }
}
