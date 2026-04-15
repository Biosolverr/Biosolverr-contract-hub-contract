// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import {LicenseNFT} from "../../src/marketplace/LicenseNFT.sol";
import {ContractFactory} from "../../src/marketplace/ContractFactory.sol";
import {MockImplementation} from "../mocks/MockImplementation.sol";
import {IContractFactory} from "../../src/interfaces/IContractFactory.sol";

contract ContractFactoryTest is Test {
    LicenseNFT nft;
    ContractFactory factory;
    MockImplementation impl;

    address user = makeAddr("user");

    bytes32 constant CID = keccak256(abi.encodePacked("Test", "1.0"));

    function setUp() public {
        nft = new LicenseNFT();
        impl = new MockImplementation();

        factory = new ContractFactory(address(nft));
        factory.registerImplementation(CID, address(impl), "v1");

        vm.deal(user, 10 ether);
    }

    function _mintLicense(address to, uint256 exp) internal returns (uint256) {
        return nft.mintLicense(to, CID, "ipfs://t", exp);
    }

    // ── License checks ─────────────────────────────────

    function test_Revert_NotLicenseOwner() public {
        uint256 tid = _mintLicense(user, 0);

        vm.prank(makeAddr("hacker"));
        vm.expectRevert(
            abi.encodeWithSelector(
                IContractFactory.NotLicenseOwner.selector,
                tid
            )
        );

        factory.deployContract(CID, tid);
    }

    function test_Revert_ExpiredLicense() public {
        uint256 exp = block.timestamp + 1 days;
        uint256 tid = nft.mintLicense(user, CID, "ipfs://t", exp);

        vm.warp(block.timestamp + 2 days);

        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                IContractFactory.LicenseNotValid.selector,
                tid
            )
        );

        factory.deployContract(CID, tid);
    }

    function test_Revert_WrongContractId() public {
        bytes32 wrongCID = keccak256("Wrong");
        uint256 tid = _mintLicense(user, 0);

        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                IContractFactory.LicenseMismatch.selector,
                wrongCID,
                CID
            )
        );

        factory.deployContract(wrongCID, tid);
    }

    function test_Revert_LicenseAlreadyUsed() public {
        uint256 tid = _mintLicense(user, 0);

        vm.prank(user);
        factory.deployContract(CID, tid);

        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                IContractFactory.LicenseAlreadyUsed.selector,
                tid
            )
        );

        factory.deployContract(CID, tid);
    }
}
