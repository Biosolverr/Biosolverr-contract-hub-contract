// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {ContractMarketplace} from "../src/marketplace/ContractMarketplace.sol";

contract RegisterContract is Script {
    function run() external {
        uint256 deployerKey        = vm.envUint("PRIVATE_KEY");
        address marketplaceAddress = vm.envAddress("MARKETPLACE_ADDRESS");

        string  memory name        = "EscrowTemplate";
        string  memory symbol      = "ESCROW";
        string  memory version     = "1.0.0";
        bytes32 metadataHash       = keccak256("ipfs://QmExampleMetadata");
        bytes32 sourceHash         = keccak256("ipfs://QmExampleSource");
        uint256 licensePrice       = 50 * 10 ** 6;
        uint256 deposit            = 0.001 ether;

        vm.startBroadcast(deployerKey);

        ContractMarketplace marketplace =
            ContractMarketplace(payable(marketplaceAddress));

        marketplace.registerContract{value: deposit}(
            name, symbol, version, metadataHash, sourceHash, licensePrice
        );

        bytes32 contractId = keccak256(abi.encodePacked(name, version));
        console2.log("Registered contractId:");
        console2.logBytes32(contractId);

        vm.stopBroadcast();
    }
}
