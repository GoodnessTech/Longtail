// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { LongTailMarketFactory } from "../src/factory/LongTailMarketFactory.sol";
import { LongTailMarket } from "../src/market/LongTailMarket.sol";
import { LongTailOutcomeToken } from "../src/market/LongTailOutcomeToken.sol";
import { LMSRPricingModel } from "../src/pricing/LMSRPricingModel.sol";
import { OptimisticResolver } from "../src/resolution/OptimisticResolver.sol";

/// @notice Mainnet deployment script with multi-layer authorization safeguards.
/// @dev DO NOT RUN WITHOUT EXPLICIT SEPARATE AUTHORIZATION.
contract DeployBOTMainnetScript is Script {
    function run() external {
        // SAFEGUARD 1: Check environment variable explicitly allowing mainnet deployment
        bool allowMainnet = vm.envOr("ALLOW_MAINNET_DEPLOYMENT", false);
        require(allowMainnet, "CRITICAL SAFEGUARD: Mainnet deployment is disabled. Set ALLOW_MAINNET_DEPLOYMENT=true only with explicit authorization.");

        // SAFEGUARD 2: Chain ID check for BOT Chain Mainnet
        require(block.chainid == 677, "Chain ID must strictly be 677 for BOT Chain Mainnet");

        uint256 deployerPrivateKey = vm.envUint("MAINNET_PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);

        console.log("=== PREPARED SCRIPT: BOT CHAIN MAINNET DEPLOYMENT ===");
        console.log("Deployer Address:", deployerAddress);
        console.log("Chain ID:", block.chainid);

        vm.startBroadcast(deployerPrivateKey);

        LongTailMarket implementation = new LongTailMarket();
        LongTailOutcomeToken outcomeToken = new LongTailOutcomeToken("https://api.longtail.io/token/{id}.json");
        LMSRPricingModel pricingModel = new LMSRPricingModel();
        OptimisticResolver resolver = new OptimisticResolver(deployerAddress);

        // On mainnet, set challenge period to 24 hours (86400 seconds)
        resolver.setChallengePeriod(86400);

        LongTailMarketFactory factory = new LongTailMarketFactory(
            address(implementation),
            address(outcomeToken),
            address(resolver),
            address(pricingModel),
            deployerAddress
        );

        outcomeToken.setFactory(address(factory));
        resolver.setFactory(address(factory));

        vm.stopBroadcast();

        console.log("=== Mainnet Deployment Complete ===");
        console.log("Mainnet Factory Address:", address(factory));
    }
}
