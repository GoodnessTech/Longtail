// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { LongTailMarketFactory } from "../src/factory/LongTailMarketFactory.sol";
import { LongTailMarket } from "../src/market/LongTailMarket.sol";
import { LongTailOutcomeToken } from "../src/market/LongTailOutcomeToken.sol";
import { LMSRPricingModel } from "../src/pricing/LMSRPricingModel.sol";
import { OptimisticResolver } from "../src/resolution/OptimisticResolver.sol";

contract DeployBohrTestnetScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);

        console.log("=== LongTail Bohr Testnet Deployment ===");
        console.log("Deployer Address:", deployerAddress);
        console.log("Chain ID:", block.chainid);
        require(block.chainid == 968, "Must be deployed to Bohr Testnet (Chain ID 968)");

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy Implementation
        LongTailMarket implementation = new LongTailMarket();
        console.log("LongTailMarket Implementation deployed at:", address(implementation));

        // 2. Deploy Outcome Token
        LongTailOutcomeToken outcomeToken = new LongTailOutcomeToken("https://api.longtail.io/token/{id}.json");
        console.log("LongTailOutcomeToken deployed at:", address(outcomeToken));

        // 3. Deploy LMSR Pricing Model
        LMSRPricingModel pricingModel = new LMSRPricingModel();
        console.log("LMSRPricingModel deployed at:", address(pricingModel));

        // 4. Deploy Optimistic Resolver
        OptimisticResolver resolver = new OptimisticResolver(deployerAddress);
        console.log("OptimisticResolver deployed at:", address(resolver));

        // 5. Deploy Market Factory
        LongTailMarketFactory factory = new LongTailMarketFactory(
            address(implementation),
            address(outcomeToken),
            address(resolver),
            address(pricingModel),
            deployerAddress
        );
        console.log("LongTailMarketFactory deployed at:", address(factory));

        // 6. Connect Factory authorizations
        outcomeToken.setFactory(address(factory));
        console.log("Configured outcomeToken factory authorization");

        resolver.setFactory(address(factory));
        console.log("Configured resolver factory authorization");

        vm.stopBroadcast();

        console.log("=== Deployment Complete ===");
        console.log("Factory Address:", address(factory));
    }
}
