// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {LicenseNFT} from "../../src/marketplace/LicenseNFT.sol";
import {ContractFactory} from "../../src/marketplace/ContractFactory.sol";
import {MockImplementation} from "../mocks/MockImplementation.sol";

contract ContractFactoryTest is Test {
    LicenseNFT         nft;
    ContractFactory    factory;
    MockImplementation impl;

    address owner = address(this);
    address user  = makeAddr("user");

    bytes32 constant CID = keccak256("TestContract");

    function setUp() public {
        nft     = new LicenseNFT();
        factory = new ContractFactory(address(nft));
        impl    = new MockImplementation();
        factory.registerImplementation(CID, address(impl), "v1.0");
    }

    function _mintLicense(address to, uint256 exp) internal returns (uint256) {
        return nft.mintLicense(to, CID, "ipfs://t", exp);
    }

    // ── Deploy ────────────────────────────────────────────────────────────────

    function test_DeployContract() public {
        uint256 tid   = _mintLicense(user, 0);
        vm.prank(user);
        address clone = factory.deployContract(CID, tid);
        assertTrue(clone != address(0));
        assertEq(factory.getInstanceContractId(clone), CID);
        address[] memory deps = factory.getUserDeployments(user, CID);
        assertEq(deps[0], clone);
    }

    function test_DeployInitializesOwner() public {
        uint256 tid   = _mintLicense(user, 0);
        vm.prank(user);
        address clone = factory.deployContract(CID, tid);
        assertEq(MockImplementation(clone).owner(), user);
    }

    // ── FIX 3: лицензия используется один раз ────────────────────────────────

    function test_Revert_LicenseAlreadyUsed() public {
        uint256 tid = _mintLicense(user, 0);
        vm.prank(user);
        factory.deployContract(CID, tid);

        // Вторая попытка с той же лицензией
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(ContractFactory.LicenseAlreadyUsed.selector, tid)
        );
        factory.deployContract(CID, tid);
    }

    function test_IsLicenseUsed() public {
        uint256 tid = _mintLicense(user, 0);
        assertFalse(factory.isLicenseUsed(tid));
        vm.prank(user);
        factory.deployContract(CID, tid);
        assertTrue(factory.isLicenseUsed(tid));
    }

    // ── License checks ────────────────────────────────────────────────────────

    function test_Revert_NotLicenseOwner() public {
        uint256 tid = _mintLicense(user, 0);
        vm.prank(makeAddr("hacker"));
        vm.expectRevert(
            abi.encodeWithSelector(ContractFactory.NotLicenseOwner.selector, tid)
        );
        factory.deployContract(CID, tid);
    }

    function test_Revert_ExpiredLicense() public {
        uint256 exp = block.timestamp + 1 days;
        uint256 tid = nft.mintLicense(user, CID, "ipfs://t", exp);
        vm.warp(block.timestamp + 2 days);
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(ContractFactory.LicenseNotValid.selector, tid)
        );
        factory.deployContract(CID, tid);
    }

    function test_Revert_WrongContractId() public {
        bytes32 wrongCID = keccak256("WrongContract");
        uint256 tid      = _mintLicense(user, 0);
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                ContractFactory.LicenseMismatch.selector,
                wrongCID, CID
            )
        );
        factory.deployContract(wrongCID, tid);
    }

    // ── Versioning ────────────────────────────────────────────────────────────

    function test_DeployWithVersion() public {
        MockImplementation impl2 = new MockImplementation();
        factory.upgradeImplementation(CID, address(impl2), "v2.0");

        uint256 tid = _mintLicense(user, 0);
        vm.prank(user);
        address clone = factory.deployContractWithVersion(CID, tid, 0); // v1.0
        assertTrue(clone != address(0));
    }

    function test_Revert_DeprecatedVersion() public {
        factory.deprecateImplementation(CID, 0);
        uint256 tid = _mintLicense(user, 0);
        vm.prank(user);
        vm.expectRevert(ContractFactory.ImplementationNotFound.selector);
        factory.deployContract(CID, tid);
    }

    // ── Batch ─────────────────────────────────────────────────────────────────

    function test_DeployBatch() public {
        bytes32 CID2 = keccak256("Contract2");
        MockImplementation impl2 = new MockImplementation();
        factory.registerImplementation(CID2, address(impl2), "v1.0");

        uint256 t1 = nft.mintLicense(user, CID,  "i://1", 0);
        uint256 t2 = nft.mintLicense(user, CID2, "i://2", 0);

        bytes32[] memory cids  = new bytes32[](2);
        uint256[] memory tids  = new uint256[](2);
        cids[0] = CID;  cids[1] = CID2;
        tids[0] = t1;   tids[1] = t2;

        vm.prank(user);
        address[] memory clones = factory.deployContractBatch(cids, tids);
        assertEq(clones.length, 2);
        assertTrue(clones[0] != address(0));
        assertTrue(clones[1] != address(0));
    }
}
