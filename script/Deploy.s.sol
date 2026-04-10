// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {LicenseNFT} from "../src/marketplace/LicenseNFT.sol";
import {ContractFactory} from "../src/marketplace/ContractFactory.sol";
import {ContractMarketplace} from "../src/marketplace/ContractMarketplace.sol";

contract Deploy is Script {
    function run() external {
        uint256 deployerKey  = vm.envUint("PRIVATE_KEY");
        address paymentToken = vm.envAddress("PAYMENT_TOKEN");

        uint256 platformFeeBps = 250;
        uint256 minDeposit     = 0.001 ether;

        vm.startBroadcast(deployerKey);

        LicenseNFT nft = new LicenseNFT();
        console2.log("LicenseNFT      :", address(nft));

        ContractFactory factory = new ContractFactory(address(nft));
        console2.log("ContractFactory :", address(factory));

        ContractMarketplace marketplace = new ContractMarketplace(
            address(nft),
            paymentToken,
            platformFeeBps,
            minDeposit
        );
        console2.log("Marketplace     :", address(marketplace));

        nft.transferOwnership(address(marketplace));
        console2.log("NFT owner       -> Marketplace: OK");

        vm.stopBroadcast();

        console2.log("\n=== Deployment complete ===");
        console2.log("LicenseNFT      :", address(nft));
        console2.log("ContractFactory :", address(factory));
        console2.log("Marketplace     :", address(marketplace));
        console2.log("Platform fee    : 2.5%%");
        console2.log("Min deposit     : 0.001 ETH");
    }
}
